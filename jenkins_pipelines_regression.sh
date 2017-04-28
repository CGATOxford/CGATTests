#!/usr/bin/env bash

# References
# http://kvz.io/blog/2013/11/21/bash-best-practices/
# http://jvns.ca/blog/2017/03/26/bash-quirks/

# exit when a command fails
set -o errexit

# exit if any pipe commands fail
set -o pipefail

# exit when your script tries to use undeclared variables
#set -o nounset

# trace what gets executed
set -o xtrace

# Host to run pipeline from. Jenkins must be able to SSH into there.
SUBMIT_HOST=jenkins@cgath1

export HOME=/ifs/home/jenkins

export DRMAA_LIBRARY_PATH=/ifs/apps/system/sge-6.2/lib/lx24-amd64/libdrmaa.so
export SGE_ROOT=/ifs/apps/system/sge-6.2
export SGE_CLUSTER_NAME=cgat
export SGE_ARCH=lx24_x86
export SGE_CELL=default

export MODULEPATH=/usr/share/Modules/modulefiles:/etc/modulefiles:/ifs/apps/modulefiles
DIR_PUBLISH=/ifs/public/cgatpipelines/jenkins_report/
URL_SUB="s/\/ifs\/mirror\/jenkins\/PipelineRegressionTests\/report\/html/http:\/\/www.cgat.org\/downloads\/public\/cgatpipelines\/jenkins_report/"

# enter working directory. Needs to be on /ifs and mounted everywhere
# /ifs/projects not possible as jenkins not part of projects group.
# configured custom workspace folder as advanced setting via Jenkins web GUI
cd ${WORKSPACE}

# if no Python version is selected, default is Python 2.7
[[ -z "$JENKINS_PYTHON_VERSION" ]] && JENKINS_PYTHON_VERSION="2.7"

# setup environment
if [[ "$JENKINS_PYTHON_VERSION" == "2.7" ]] ; then

    # use /ifs/apps for py27
    eval `modulecmd bash load bio/all`

    # setup virtual environment
    virtualenv --system-site-packages python_ve

    # activate virtual environment
    source python_ve/bin/activate

elif [[ "$JENKINS_PYTHON_VERSION" == "3.5" ]] ; then

    # use conda for py35
    CONDA_HOME=${WORKSPACE}/conda-install

    # configure environment modules
    eval `modulecmd bash load bio/all`
    eval `modulecmd bash unload apps/R apps/python`

    # download and install conda
    wget http://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh
    bash /ifs/apps/Miniconda3-latest-Linux-x86_64.sh -b -p ${CONDA_HOME}
    export PATH=${CONDA_HOME}/bin:${PATH}

    # Configure conda
    conda config --set allow_softlinks False
    conda config --add channels 'conda-forge'
    conda config --add channels 'defaults'
    conda config --add channels 'r'
    conda config --add channels 'bioconda'

    # Update conda
    conda update --all -y

    # Install dependencies
    conda install cgat-scripts-devel cgat-pipelines-nosetests gcc 'python='$JENKINS_PYTHON_VERSION -y

else
    echo "unsupported python version ${JENKINS_PYTHON_VERSION}"
    exit 1
fi


if [[ $JENKINS_CLEAR_TESTS ]]; then
   for x in $JENKINS_CLEAR_TESTS; do
      echo "removing old test data for test: $x"
      rm -rf test_$x.dir test_$x.tgz test_$x.log
   done
   JENKINS_ONLY_UPDATE="true"
fi

# clear up previous tests
if [[ "$JENKINS_ONLY_UPDATE" == "false" ]]; then
    rm -rf prereq_* ctmp* test_* _cache _static _templates _tmp report *.log csvdb *.load *.tsv
fi

# print environment info
printenv

# at the moment, use develop so that the perl scripts are found.
sed -i'' -e '/REPO_REQUIREMENT/,/pass/d' ${WORKSPACE}/cgat/setup.py
sed -i'' -e '/# dependencies/,/dependency_links=dependency_links,/d' ${WORKSPACE}/cgat/setup.py
cd ${WORKSPACE}/cgat && python setup.py install

sed -i'' -e '/REPO_REQUIREMENT/,/pass/d' ${WORKSPACE}/CGATPipelines/setup.py
sed -i'' -e '/# dependencies/,/dependency_links=dependency_links,/d' ${WORKSPACE}/CGATPipelines/setup.py
cd ${WORKSPACE}/CGATPipelines && python setup.py develop

# copy test configuration files
cd ${WORKSPACE} && ln -fs config/{pipeline.ini,conf.py} .

error_report() {
    echo "Error detected"
    echo "Dumping log traces of test pipelines:"
    grep "ERROR" *.dir/pipeline.log
    grep -A 30 "Exception" *.dir/pipeline.log
    echo "Dumping error messages from pipeline_testing/pipeline.log:"
    sed -n '/start of error messages$/,/end of error messages$/p' pipeline.log
}

trap 'error_report' ERR

# run pipelines

echo "Starting pipelines"

if [[ $JENKINS_PYTHON_VERSION == "2.7" ]] ; then

    ssh ${SUBMIT_HOST} \
    "cd ${WORKSPACE} && \
     module load bio/all && \
     source python_ve/bin/activate && \
     python CGATPipelines/CGATPipelines/pipeline_testing.py -v 5 make full"

elif [[ "$JENKINS_PYTHON_VERSION" == "3.5" ]] ; then

    ssh ${SUBMIT_HOST} \
    "cd ${WORKSPACE} && \
     module load bio/all  && \
     module unload apps/R apps/python && \
     export PATH=${CONDA_HOME}/bin:${PATH} && \
     python CGATPipelines/CGATPipelines/pipeline_testing.py -v 5 make full"

else
    echo "unsupported python version ${JENKINS_PYTHON_VERSION}"
    exit 1
fi

echo "Building report"
python CGATPipelines/CGATPipelines/pipeline_testing.py -v 5 make build_report

echo "Publishing report"
cp -arf report/html/* ${DIR_PUBLISH}
find ${DIR_PUBLISH} -name "*.html" -exec perl -p -i -e ${URL_SUB} {} \;

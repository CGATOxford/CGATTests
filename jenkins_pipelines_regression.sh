#!/bin/bash -xe

# Host to run pipeline from. Jenkins must be able to SSH into there.
SUBMIT_HOST=jenkins@cgath1

export HOME=/ifs/jenkins/home

export DRMAA_LIBRARY_PATH=/ifs/apps/system/sge-6.2/lib/lx24-amd64/libdrmaa.so
export SGE_ROOT=/ifs/apps/system/sge-6.2
export SGE_CLUSTER_NAME=cgat
export SGE_ARCH=lx24_x86
export SGE_CELL=default

if [ -z "$JENKINS_PYTHON_VERSION" ] ; then
    JENKINS_PYTHON_VERSION="2.7"
fi

if [[ $JENKINS_PYTHON_VERSION == "2.7" ]] ; then
    PYTHON_MODULES="apps/python";
    PYTHON_EXECUTABLE="python2.7";
elif [[ $JENKINS_PYTHON_VERSION == "3.5" ]] ; then
    PYTHON_MODULES="apps/python3";
    PYTHON_EXECUTABLE="python3.5";
else
    echo "unsupported python version ${JENKINS_PYTHON_VERSION}"
    exit 1
fi

export MODULEPATH=/usr/share/Modules/modulefiles:/etc/modulefiles:/ifs/apps/modulefiles
eval `modulecmd bash load $(PYTHON_MODULES) apps/java apps/perl apps/graphlib bio/alignlib bio/all`

DIR_PUBLISH=/ifs/public/cgatpipelines/jenkins_report/
URL_SUB="s/\/ifs\/mirror\/jenkins\/PipelineRegressionTests\/report\/html/http:\/\/www.cgat.org\/downloads\/public\/cgatpipelines\/jenkins_report/"

# enter working directory. Needs to be on /ifs and mounted everywhere
# /ifs/projects not possible as jenkins not part of projects group.
cd $WORKSPACE
confdir="${WORKSPACE}/config"

if [ $JENKINS_CLEAR_TESTS ]; then
   for x in $JENKINS_CLEAR_TESTS; do
      echo "removing old test data for test: $x"
      rm -rf $WORKSPACE/test_$x.dir $WORKSPACE/test_$x.tgz $WORKSPACE/test_$x.log
   done
   JENKINS_ONLY_UPDATE="true"
fi

# clear up previous tests
if [ $JENKINS_ONLY_UPDATE == "false" ]; then
    rm -rf $WORKSPACE/test_* $WORKSPACE/prereq_* csvdb *.log md5_*
fi

# setup virtual environment
rm -rf test_python
PYTHON_EXEC=`/usr/bin/which ${PYTHON_EXECUTABLE}`
virtualenv --python=${PYTHON_EXEC} --system-site-packages test_python

printenv

# activate virtual environment
source test_python/bin/activate

# at the moment, use develop so that the perl scripts are found.
cd $WORKSPACE/cgat && python setup.py install
cd $WORKSPACE/CGATPipelines && python setup.py develop

# copy test configuration files
cd $WORKSPACE
ln -fs ${confdir}/{pipeline.ini,conf.py} .

error_report() {
    echo "Error detected"
    echo "Dumping log traces of test pipelines:"
    grep "ERROR" *.dir/pipeline.log
    echo "Dumping error messages from pipeline_testing/pipeline.log:"
    sed -n '/start of error messages$/,/end of error messages$/p' pipeline.log
}

trap 'error_report' ERR

# run pipelines

echo "Starting pipelines"
ssh ${SUBMIT_HOST} "cd ${WORKSPACE} && source test_python/bin/activate && python CGATPipelines/CGATPipelines/pipeline_testing.py -v 5 -p 10 make full"

echo "Building report"
python CGATPipelines/CGATPipelines/pipeline_testing.py -v 5 -p 10 make build_report

echo "Publishing report"
cp -arf report/html/* ${DIR_PUBLISH}/
find ${DIR_PUBLISH}/ -name "*.html" -exec perl -p -i -e ${URL_SUB} {} \;

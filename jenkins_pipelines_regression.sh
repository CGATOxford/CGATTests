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

# configure module
unset -f module
module() {  eval `/usr/bin/modulecmd bash $*`; }

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

# use automated installation
bash CGATPipelines/install-CGAT-tools.sh --jenkins --env-name jenkins-env

# Parameterised testing
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
ssh ${SUBMIT_HOST} \
   "cd ${WORKSPACE} && \
    source ${WORKSPACE}/conda-install/bin/activate jenkins-env && \
    module load bio/gatk-full bio/homer  && \
    cgatflow testing make full -v 5"


echo "Building report"
source ${WORKSPACE}/conda-install/bin/activate jenkins-env
cgatflow testing make build_report -v 5

echo "Publishing report"
cp -arf report/html/* ${DIR_PUBLISH}
find ${DIR_PUBLISH} -name "*.html" -exec perl -p -i -e ${URL_SUB} {} \;


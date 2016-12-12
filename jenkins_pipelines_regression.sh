#!/bin/bash -xe

# Host to run pipeline from. Jenkins must be able to SSH into there.
SUBMIT_HOST=jenkins@cgath1

export HOME=/ifs/jenkins/home

export DRMAA_LIBRARY_PATH=/ifs/apps/system/sge-6.2/lib/lx24-amd64/libdrmaa.so
export SGE_ROOT=/ifs/apps/system/sge-6.2
export SGE_CLUSTER_NAME=cgat
export SGE_ARCH=lx24_x86
export SGE_CELL=default

export MODULEPATH=/usr/share/Modules/modulefiles:/etc/modulefiles:/ifs/apps/modulefiles
eval `modulecmd bash load apps/java apps/python apps/perl apps/graphlib bio/alignlib bio/all apps/emacs`

# enter working directory. Needs to be on /ifs and mounted everywhere
# /ifs/projects not possible as jenkins not part of projects group.
cd $WORKSPACE
confdir="${WORKSPACE}/config"


if [ $JENKINS_CLEAR_TESTS ]; then
   for x in $JENKINS_CLEAR_TESTS; do
      rm -rf $WORKSPACE/test_$x
   done
   JENKINS_ONLY_UPDATE="false"
fi

# clear up previous tests
if [ $JENKINS_ONLY_UPDATE == "false" ]; then
    rm -rf $WORKSPACE/test_* $WORKSPACE/prereq_* csvdb *.log md5_*
fi

# setup virtual environment
virtualenv --system-site-packages test_python

printenv

# activate virtual environment
source test_python/bin/activate

cd $WORKSPACE/cgat && python setup.py install
cd $WORKSPACE/CGATPipelines && python setup.py develop

# copy test configuration files
cd $WORKSPACE
ln -fs ${confdir}/{pipeline.ini,conf.py} .

# run pipelines

echo "Starting pipelines"
ssh ${SUBMIT_HOST} "cd ${WORKSPACE} && source test_python/bin/activate && python CGATPipelines/CGATPipelines/pipeline_testing.py -v 5 -p 10 make full"

echo "Building report"
python CGATPipelines/CGATPipelines/pipeline_testing.py -v 5 -p 10 make build_report

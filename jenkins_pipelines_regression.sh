#!/bin/bash

export DRMAA_LIBRARY_PATH=/ifs/apps/system/sge-6.2/lib/lx24-amd64/libdrmaa.so
export SGE_ROOT=/ifs/apps/system/sge-6.2
export SGE_CLUSTER_NAME=cgat
export SGE_ARCH=lx24_x86
export SGE_CELL=default

export MODULEPATH=/usr/share/Modules/modulefiles:/etc/modulefiles:/ifs/apps/modulefiles
eval `modulecmd bash load apps/java apps/python apps/perl apps/graphlib bio/alignlib bio/all apps/emacs`

# enter working directory. Needs to be on /ifs and mounted everywhere
# /ifs/projects not possible as jenkins not part of projects group.
workdir=/ifs/mirror/jenkins/PipelineRegressionTests
confdir=/ifs/mirror/jenkins/config

if [ ! -d $workdir ]; then
    mkdir $workdir
else
    if [ $JENKINS_ONLY_UPDATE == "false" ]; then
	rm -rf $workdir/test_* $workdir/prereq_* csvdb *.log md5_*
    fi
fi

cd $workdir

# setup virtual environment
virtualenv --system-site-packages test_python

# activate virtual environment
source test_python/bin/activate

# install CGAT code and scripts. These need to be installed on
# a shared location.
# TODO: checkout appropriate repository and branch from github
if [ ! -d cgat ]; then
    git clone git@github.com:CGATOxford/cgat.git cgat
else
    echo "Using existing cgat repository"
fi
cd cgat
git pull
python setup.py develop
cd $workdir

if [ ! -d CGATPipelines ]; then
    git clone git@github.com:CGATOxford/CGATPipelines.git CGATPipelines
else
    echo "Using exiting CGATPipelines repository"
fi
cd CGATPipelines
git pull
python setup.py develop
cd $workdir

# copy test configuration files
cd $workdir
rm -rf ${workdir}/config
git clone git@github.com:CGATOxford/CGATTests.git config
ln -fs $confdir/{pipeline.ini,conf.py} .

qrsh 'echo "running on `hostname`"'

# run pipelines
echo "Starting pipelines"
python CGATPipelines/CGATPipelines/pipeline_testing.py -v 5 -p 10 make full
echo "Building report"
python CGATPipelines/CGATPipelines/pipeline_testing.py -v 5 -p 10 make build_report

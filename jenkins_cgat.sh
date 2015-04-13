#!/bin/bash

export DRMAA_LIBRARY_PATH=/ifs/apps/system/sge-6.2/lib/lx24-amd64/libdrmaa.so
export SGE_ROOT=/ifs/apps/system/sge-6.2
export SGE_CLUSTER_NAME=cgat
export SGE_ARCH=lx24_x86
export SGE_CELL=default

export MODULEPATH=/usr/share/Modules/modulefiles:/etc/modulefiles:/ifs/apps/modulefiles
eval `modulecmd bash load apps/java apps/python apps/perl apps/graphlib bio/alignlib bio/all apps/emacs`

# enter working directory. Needs to be on /ifs and mounted everywhere
workdir=/ifs/scratch/jenkins

if [ ! -d $workdir ]; then
    mkdir $workdir
else
    rm -rf $workdir/test_* $workdir/prereq_* *.log
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
    git clone --depth=1 git@github.com:CGATOxford/cgat.git cgat
fi
cd cgat
git pull
python setup.py develop
cd $workdir

if [ ! -d CGATPipelines ]; then
    git clone --depth=1 git@github.com:CGATOxford/CGATPipelines.git CGATPipelines
fi
cd CGATPipelines
git pull
python setup.py develop
cd $workdir

# copy test configuration files
cd $workdir
cp /ifs/devel/andreas/pipeline_testing/save/{conf.py,pipeline.ini} .

# run pipelines
python CGATPipelines/CGATPipelines/pipeline_testing.py -v 5 -p 10 make full >& jenkins.log

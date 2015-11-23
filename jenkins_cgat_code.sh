#!/bin/bash

export DRMAA_LIBRARY_PATH=/ifs/apps/system/sge-6.2/lib/lx24-amd64/libdrmaa.so
export SGE_ROOT=/ifs/apps/system/sge-6.2
export SGE_CLUSTER_NAME=cgat
export SGE_ARCH=lx24_x86
export SGE_CELL=default

export MODULEPATH=/usr/share/Modules/modulefiles:/etc/modulefiles:/ifs/apps/modulefiles
eval `modulecmd bash load apps/java apps/python apps/perl apps/graphlib bio/alignlib bio/all apps/emacs`

# number of parallel jobs to run for testing
NUM_JOBS=4

# enter working directory. Needs to be on /ifs and mounted everywhere
# /ifs/projects not possible as jenkins not part of projects group.
WORKDIR=/ifs/mirror/jenkins/CGATCode

if [ ! -d ${WORKDIR} ]; then
    mkdir ${WORKDIR}
fi

cd ${WORKDIR}

# setup virtual environment
virtualenv --system-site-packages test_python

# activate virtual environment
source test_python/bin/activate

# install CGAT code and scripts. These need to be installed on
# a shared location.
# TODO: checkout appropriate repository and branch from github
if [ ! -d cgat ]; then
    git clone ${WORKSPACE} cgat
else
    echo "Using existing cgat repository"
fi
cd cgat
git checkout ${GIT_BRANCH}
git pull
python setup.py build
python setup.py develop

# some debugging information
echo "----------------------------------------------"
printenv
echo "----------------------------------------------"

# run tests
cd ${WORKDIR}/cgat
echo -e "restrict:\n    manifest:\n" > tests/_test_commandline.yaml
py.test -n ${NUM_JOBS} tests/test_*.py


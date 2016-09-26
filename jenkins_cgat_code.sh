#!/bin/bash -x

export DRMAA_LIBRARY_PATH=/ifs/apps/system/sge-6.2/lib/lx24-amd64/libdrmaa.so
export SGE_ROOT=/ifs/apps/system/sge-6.2
export SGE_CLUSTER_NAME=cgat
export SGE_ARCH=lx24_x86
export SGE_CELL=default

export MODULEPATH=/usr/share/Modules/modulefiles:/etc/modulefiles:/ifs/apps/modulefiles
eval `modulecmd bash load bio/all`

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
# update does not work
rm -rf cgat

if [ ! -d cgat ]; then
    git clone ${WORKSPACE} cgat
else
    echo "Using existing cgat repository"
fi
cd cgat
git fetch
git checkout ${GIT_BRANCH}
python setup.py build
python setup.py develop

# some debugging information
echo "----------------------------------------------"
printenv
which python
python -c 'import numpy; print numpy.version.version'
python -c 'import pysam; print pysam.__version__'
python -c 'import matplotlib; print matplotlib.__version__'
python -c 'from matplotlib.externals.six.moves.urllib.parse import quote'
echo "----------------------------------------------"

# run tests
cd ${WORKDIR}/cgat
echo -e "restrict:\n    manifest:\n" > tests/_test_commandline.yaml
# Issues with py.test and CGAT paths
# py.test -n ${NUM_JOBS} tests/test_*.py
# nosetests --processes ${NUM_JOBS} tests/test_*.py
# Running all tests with multiple processes fails, there seem to
# issues with what libraries are being picked up (VE problems?)
nosetests tests/test_import.py
nosetests tests/test_style.py
nosetests tests/test_commandline.py
nosetests tests/test_scripts.py

#!/bin/bash -xe

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
eval `modulecmd bash load ${PYTHON_MODULES} bio/all`

# number of parallel jobs to run for testing
NUM_JOBS=4

# enter working directory. Needs to be on /ifs and mounted everywhere
# /ifs/projects not possible as jenkins not part of projects group.
WORKDIR=/ifs/mirror/jenkins/${JOB_NAME}

if [ ! -d ${WORKDIR} ]; then
    mkdir -p ${WORKDIR}
fi

cd ${WORKDIR}
# setup virtual environment
rm -rf test_python
PYTHON_EXEC=`/usr/bin/which ${PYTHON_EXECUTABLE}`
virtualenv --python=${PYTHON_EXEC} --system-site-packages test_python

# activate virtual environment
source test_python/bin/activate

cd cgat && python setup.py develop

cd ${WORKDIR}
PYTHON=`which python`
NOSE=`which nosetests`

# some debugging information
echo "----------------------------------------------"
printenv
which python
python -c 'import numpy; print numpy.version.version'
python -c 'import pysam; print pysam.__version__'
python -c 'import matplotlib; print matplotlib.__version__'
python -c 'from matplotlib.externals.six.moves.urllib.parse import quote'
echo "python is $PYTHON"
echo "nose is $NOSE"
echo "----------------------------------------------"

# run tests
cd ${WORKDIR}/cgat
echo -e "restrict:\n    manifest:\n" > tests/_test_commandline.yaml
# Issues with py.test and CGAT paths
# py.test -n ${NUM_JOBS} tests/test_*.py
# nosetests --processes ${NUM_JOBS} tests/test_*.py
# Running all tests with multiple processes fails, there seem to
# issues with what libraries are being picked up (VE problems?)
$PYTHON $NOSE -v tests/test_import.py
$PYTHON $NOSE -v tests/test_style.py
$PYTHON $NOSE -v tests/test_commandline.py
$PYTHON $NOSE -v tests/test_scripts.py

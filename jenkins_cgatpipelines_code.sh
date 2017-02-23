#!/bin/bash -xe

if [ -z "$JENKINS_PYTHON_VERSION" ] ; then
    JENKINS_PYTHON_VERSION="2.7"
fi

if [ $JENKINS_PYTHON_VERSION != "2.7" ] && [ $JENKINS_PYTHON_VERSION != "3.5" ] ; then
    echo "unsupported python version ${JENKINS_PYTHON_VERSION}"
    exit 1
fi

# export env variables to installation script
export JENKINS_PYTHON_VERSION
export TEST_ALL=1

# Required when testing install-CGAT-tools.sh on a branch called SLV-install-jenkins
# wget -O install-CGAT-pipelines.sh https://raw.githubusercontent.com/CGATOxford/CGATPipelines/SLV-install-jenkins/install-CGAT-tools.sh
# bash install-CGAT-pipelines.sh --jenkins

# install and test cgat scripts
bash install-CGAT-tools.sh --jenkins


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

if [[ -z "$JENKINS_PYTHON_VERSION" ]] ; then
    JENKINS_PYTHON_VERSION="2.7"
fi

if [[ "$JENKINS_PYTHON_VERSION" != "2.7" ]] && [[ "$JENKINS_PYTHON_VERSION" != "3.5" ]] ; then
    echo "unsupported python version ${JENKINS_PYTHON_VERSION}"
    exit 1
fi

# export env variables to installation script
export JENKINS_PYTHON_VERSION
export TEST_ALL=1

# Required when testing install-CGAT-tools.sh on a branch called SLV-install-jenkins
#wget -O install-CGAT-scripts.sh https://raw.githubusercontent.com/CGATOxford/cgat/SLV-install-jenkins/install-CGAT-tools.sh
#bash install-CGAT-scripts.sh --jenkins

# install and test cgat scripts
bash install-CGAT-tools.sh --jenkins


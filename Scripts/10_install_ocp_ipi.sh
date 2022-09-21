#!/bin/bash
# OCP4 Installation (IPI - VMware/AWS)


# STATUS:  Work in Progress.  Trying to make this less dependent on the host it's
#           running on and PULL everything needed for all the tasks.
#          This works for me at this point, but I am definitely open to
#           suggestions for improvement.

# NOTES:  I am going to create this to be run on a Linux host, at this point.

#  ############  #  ############
##          START HERE
#  ############  #  ############
### Start your TMUX Session (if you are running this on the terminal and not as a script)
case $(echo $BASHRCSOURCED) in
  Y)
    export SHORTDATE=`date +%F`
    which tmux || sudo yum -y install tmux
    tmux new -s OCP4-${SHORTDATE}|| tmux attach -t OCP4-${SHORTDATE}
  ;;
  *)
    echo "Note:  will proceed"
  ;;
esac

## Parameters and Variables
### Cluster Identity
export OCP_BASE_DOMAIN=ocp.clouditoutloud.com
export OCP_CLUSTER_NAME=testcluster
export REGION="us-east-1"
export PLATFORM=aws
export AWS_DEFAULT_PROFILE="ocp-admin"

export THEDATE=`date +%F-%H%M` 
export SHORTDATE=`date +%F`

## If you decide to install a specific version (or Architecture), then explore the following:
export ARCH=amd64
# export ARCH=arm64
# export OCP_VERSION=stable-4.6
# export OCP_VERSION=latest-4.6
# export OCP_VERSION=4.6.26
#export OCP_VERSION=latest  # Note: "latest" might not be tested and may actually be a non-successful candidate version
export OCP_VERSION=stable

export OCP4_BASE=${HOME}/OCP4/
[ ! -d $OCP4_BASE ] && mkdir $OCP4_BASE; cd $OCP4_BASE
export OCP4_DIR=${OCP_CLUSTER_NAME}.${OCP_BASE_DOMAIN}-${THEDATE}; mkdir $OCP4_DIR
export OCP_INSTALL_DIR="${OCP4_BASE}/installer-${SHORTDATE}" 
[ ! -d ${OCP_INSTALL_DIR} ] && { mkdir ${OCP_INSTALL_DIR}; cd $_; } || { cd ${OCP_INSTALL_DIR}; }

## Pre-reqs
### Some housekeeping (host packages)
#sudo yum -y install wget tar unzip bind-utils git

### Set ENVIRONMENT VARS
### NOTE:  Need to figure out the image search for ARM64 (2022-01-30)
case $ARCH in
  arm64)
    export OCP_INSTALL_OCP_RELEASE_IMAGE_OVERRIDE=quay.io/openshift-release-dev/ocp-release-nightly:4.9.0-0.nightly-arm64-2021-08-16-154214
  ;;
  *)
    export OCP_RELEASE_IMAGE=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp/$OCP_VERSION/release.txt | grep 'Pull From: quay.io' | awk -F ' ' '{print $3}')
  ;;
esac
echo "RELEASE IMAGE (for $OCP_VERSION): $OCP_RELEASE_IMAGE $OCP_INSTALL_OCP_RELEASE_IMAGE_OVERRIDE"

# First, identify the files and make sure they are present
### SSH tweaks
SSH_KEY_FILE="${HOME}/.ssh/id_rsa-${OCP_BASE_DOMAIN}"
SSH_KEY_FILE_PUB="${HOME}/.ssh/id_rsa-${OCP_BASE_DOMAIN}.pub"
[ ! -f $SSH_KEY_FILE_PUB ] && { ssh-keygen -tecdsa -b521 -E sha512 -N '' -f $SSH_KEY_FILE; }
SSH_KEY=$(cat $SSH_KEY_FILE_PUB)

PULL_SECRET_FILE=${OCP4_BASE}pull-secret.txt
[ ! -f $PULL_SECRET_FILE ] && { echo "ERROR: Pull Secret File Not Available. Hit CTRL-C within 10 seconds."; sleep 10; exit 9; }
PULL_SECRET=$(cat $PULL_SECRET_FILE)
export OCP_BASE_DOMAIN SSH_KEY PULL_SECRET OCP_CLUSTER_NAME AWS_DEFAULT_PROFILE
echo -e "Base Domain: $OCP_BASE_DOMAIN \nCluster Name: $OCP_CLUSTER_NAME \nAWS Default Profile:  $AWS_DEFAULT_PROFILE \nSSH Key: $SSH_KEY"
echo "Pull Secret is hydrated"

case $PLATFORM in
  aws)
    aws configure list
  ;;
esac

case $OCP_BASE_DOMAIN in
  linuxrevolution.com)
    REPO_NAME=matrix.lab
  ;;
  *)
    REPO_NAME=${OCP_BASE_DOMAIN}
  ;;
esac
echo "Repo Name: $REPO_NAME"

# Download the client and installer
cd $OCP_INSTALL_DIR
[ -e $OCP_VERSION ] && OCP_VERSION="stable"
case `uname` in
  Linux)
    for FILE in openshift-install-linux.tar.gz openshift-client-linux.tar.gz
    do
      [ ! -f ${FILE} ] && { wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OCP_VERSION}/${FILE}; tar -xvzf ${FILE}; }
    done
  ;;
  Darwin)
    for FILE in openshift-install-mac.tar.gz openshift-client-mac.tar.gz
    do
      [ ! -f ${FILE} ] && { curl https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OCP_VERSION}/${FILE} -o ${FILE}; tar -xvzf ${FILE}; }
    done
  ;;
esac

## Deploy (create) the cluster
eval "$(ssh-agent -s)"
ssh-add ${HOME}/.ssh/id_rsa-${OCP_BASE_DOMAIN}
cd ${OCP4_BASE}

## Pull down a copy of the install-config with no personal data (you'll
#   add your own personal data in a bit)
case $ARCH in
  arm64)
    INSTALL_CONFIG=install-config-${PLATFORM}-${OCP_CLUSTER_NAME}.${OCP_BASE_DOMAIN}-arm64.yaml
  ;;
  *)
    INSTALL_CONFIG=install-config-${PLATFORM}-${OCP_CLUSTER_NAME}.${OCP_BASE_DOMAIN}.yaml
  ;;
esac
echo "Installation Configuration: $INSTALL_CONFIG"
[ ! -f $INSTALL_CONFIG ] && { wget https://raw.githubusercontent.com/cloudxabide/${REPO_NAME}/main/Files/$INSTALL_CONFIG; echo "You need to update the config file found in this directory"; }

# The following creates the "install-config" - you should then make a copy of it
# ${OCP_INSTALL_DIR}/openshift-install create install-config --dir=${OCP4_DIR}/ --log-level=info

# Using the previously created install config....
#   Create an install-config.yaml from the template using
#   the ENV variables set earlier (SSHKEY and PULLSECRET)
# rm -rf ${OCP4_DIR}; mkdir ${OCP4_DIR}
envsubst < $INSTALL_CONFIG > ${OCP4_DIR}/install-config.yaml
# vi ${OCP4_DIR}/install-config.yaml

# Create the IAM role request
#oc adm release extract quay.io/openshift-release-dev/ocp-release:4.y.z-x86_64 --credentials-requests --cloud=aws
# cd $OCP_INSTALL_DIR; oc adm release extract quay.io/openshift-release-dev/ocp-release:4.11.5-x86_64 --credentials-requests --cloud=aws; cd -

# Let's roll
MYLOG="${OCP4_DIR}/mylog.log"
echo "Start: `date`" >> $MYLOG
${OCP_INSTALL_DIR}/openshift-install create manifests --dir=${OCP4_DIR}/

${OCP_INSTALL_DIR}/openshift-install create cluster --dir=${OCP4_DIR}/ --log-level=debug
echo "End: `date`" >> $MYLOG
# or....
# ${OCP_INSTALL_DIR}/openshift-install create cluster --dir=${OCP4_DIR}/ --log-level=debug > ${OCP4_DIR}/installation.log 2>&1

export KUBECONFIG=${OCP4_DIR}/auth/kubeconfig

# ${OCP_INSTALL_DIR}/openshift-install destroy cluster --dir=${OCP4_DIR}/ --log-level=debug

build_installer() {
git clone https://github.com/openshift/installer.git ${INSTALLER_DIR}
cd ${INSTALLER_DIR}
TAGS=libvirt hack/build.sh
cd -
}



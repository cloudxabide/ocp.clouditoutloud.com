#!/bin/bash


Notes() {
# Lets Encrypt Certificates

* Status:   
  * Work in Progress (2020-10-29)  
  * Still a bit of a mess - needs some cleanup (2021-08-24)  
  * Definitely a mess (2022-02-27) - the primary struggle:  this file explains how to create new Certs, as well as redeploy existing
* Purpose:  
  * To detail what is necessary to utilize LetsEncrypt certs in your   
          cluster.  Additionally, I may try to figure out where the certs you  
          provide in your inventory, actually end up on the filesystem.  
* Credit:   
  * Please see the references at the bottom of this doc.  A fellow Red Hatter (Karan Singh) wrote a great article.  
* Notes:     
  * You can run this as a non-root user - in my case, morpheus  
  
## Overview
My environment is a home lab which has a single ingress/egress point and a single IP.  I also have a domain (linuxrevolution.com) with DNS provided by route53.  Generally OpenShift has a tertiary domain provided - "cloudapps" is usually referenced - in my case it is "ocp4-mwn" (ocp4-mwn.linuxrevolution.com).  My tertiary domain is also handled by route53.

## The process
I'm not going to provide details on how to install RHEL, nor LetsEncrypt - mostly because there are *plenty* of docs out there, and the moment I run "git push" my docs will probably be out of date.  

Create your top-level domain (TLD) in AWS Route53 (and ONLY your TLD).  This actually took me a bit to figure out, as it is NOT intuitive.  You start with your TLD with no reference to OCP.  Then create your certs (which creates a bunch of entries (TXT records) and then removes them.  Once complete, you will need to then create your 2 x A records (api.<cluster_name>.<domain> and *.apps.<cluster_name>.<domain>).  NOTE:  You *can* create subdomains from your TLD, but it's a bit of a PITA (and not worth it, IMO, since we only need 2 static IP entries).
}

## Pre-reqs
export SHORTDATE=`date +%F`
export PLATFORM=aws 
export OCP_CLUSTER_NAME=testcluster
export OCP_BASE_DOMAIN=ocp.clouditoutloud.com

# DEFINE AND CREATE CERTIFICATE DIRECTORIES
export CERTDIR_BASE=$HOME/certificates/$SHORTDATE-$PLATFORM-$OCP_CLUSTER_NAME-$OCP_BASE_DOMAIN; mkdir -p $CERTDIR_BASE
export CERTDIR_TLD=${CERTDIR_BASE}/TLD; mkdir $CERTDIR_TLD
export CERTDIR_API=${CERTDIR_BASE}/API; mkdir $CERTDIR_API

# PULL DOWN ACME.SH
cd $CERTDIR_BASE
git clone https://github.com/acmesh-official/acme.sh.git
cd acme.sh
./acme.sh --register-account -m cloudxabide@gmail.com

AWS_USER="ocp-route53-admin"
export AWS_ACCESS_KEY_ID=$(grep -A2 $AWS_USER ~/.aws/credentials | grep aws_access_key_id | awk -F\= '{ print $2 }' | sed 's/ //g')
export AWS_SECRET_ACCESS_KEY=$(grep -A2 $AWS_USER ~/.aws/credentials | grep aws_secret_access_key | awk -F\= '{ print $2 }' | sed 's/ //g')
echo -n "$AWS_ACCESS_KEY_ID $AWS_SECRET_ACCESS_KEY"; echo
[ -z $AWS_SECRET_ACCESS_KEY ] && echo "hol'up - you did not set your AWSCLI vars yet"

export LE_API=$(oc whoami --show-server | cut -f 2 -d ':' | cut -f 3 -d '/' | sed 's/-api././')
export LE_WILDCARD=$(oc get ingresscontroller default -n openshift-ingress-operator -o jsonpath='{.status.domain}')
export LE_TLD=$OCP_BASE_DOMAIN
echo -e "\nTop Level Domain: $LE_TLD \nAPI Endpoint: $LE_API \nApps Wildcard: $LE_WILDCARD \n"

# NOTE:  resulting files will be deposited in ~/.acme.sh apparently
#  Create 2 sets of CERTs 
#   Cert:  Wildcard and "Apex" domain
# Output:  ${HOME}/.acme.sh/*.apps.testcluster.ocp.clouditoutloud.com/
echo "${CERTDIR_BASE}/acme.sh/acme.sh --issue -d *.${LE_WILDCARD} -d *.${LE_TLD} --dns dns_aws"
cd ${CERTDIR_BASE} && ./acme.sh/acme.sh --issue -d *.${LE_WILDCARD} -d *.${LE_TLD} --dns dns_aws

#   Cert: API
# Output:  ${HOME}/.acme.sh/api.testcluster.ocp.clouditoutloud.com/
echo "${CERTDIR_BASE}/acme.sh/acme.sh --issue -d ${LE_API} --dns dns_aws"
cd ${CERTDIR_BASE} && ./acme.sh/acme.sh --issue -d ${LE_API} --dns dns_aws

## Deploy Certs (new or reuse) to host you're on
### Create PEM Files from the Let's Encrypt results
# API
cp ${HOME}/.acme.sh/api.testcluster.ocp.clouditoutloud.com/* $CERTDIR_API
cd ${CERTDIR_BASE} && ./acme.sh/acme.sh --install-cert -d ${LE_API} --cert-file ${CERTDIR_API}/cert.pem --key-file ${CERTDIR_API}/key.pem --fullchain-file ${CERTDIR_API}/fullchain.pem --ca-file ${CERTDIR_API}/ca.cer

# Wildcard and Apex
cp ${HOME}/.acme.sh/'*.apps.testcluster.ocp.clouditoutloud.com'/* ${CERTDIR_TLD}
cd ${CERTDIR_BASE} && ./acme.sh/acme.sh --install-cert -d *.${LE_WILDCARD} -d *.${LE_TLD} --cert-file ${CERTDIR_TLD}/cert.pem --key-file ${CERTDIR_TLD}/key.pem --fullchain-file ${CERTDIR_TLD}/fullchain.pem --ca-file ${CERTDIR_TLD}/ca.cer

### ### ### ### ### 
## Update OpenShift 
### ### ### ### ### 
#This section details what is needed on the OCP side 

#NOTE: Need to update this to apply previously created certs (usually stored in ~/.acme, or something)
[ -e $CERTDIR ] && { export CERTDIR=$(dirname $(find $HOME/certificates -name fullchain.pem | grep $OCP_BASE_DOMAIN | tail -1)); }
for FILE in fullchain.pem key.pem
do 
  echo "File:  ${CERTDIR}/$FILE"
  case `file -b ${CERTDIR}/$FILE` in
    'PEM certificate') 
      openssl x509 -in ${CERTDIR}/$FILE -noout -text --dates | grep ^not 
      openssl x509 -in ${CERTDIR}/$FILE -noout -text | grep DNS  ;;
    'PEM RSA private key') echo "PEM private key found"; openssl rsa -text -noout -in ${CERTDIR}/$FILE | grep Private   ;;
  esac
  echo 
done

# The CA cert should be the same in both TLD and API directories - so, just picked the wildcard directory 
export CA_CERT=$(find $CERTDIR_TLD -name ca.cer)
[ -f $CA_CERT ] && { oc create configmap custom-ca --from-file=ca-bundle.crt=$CA_CERT -n openshift-config; }
oc patch proxy/cluster --type=merge --patch='{"spec":{"trustedCA":{"name":"custom-ca"}}}'

# Ingress Certificate (Wildcard and Apex)
[ -f ${CERTDIR_TLD}/fullchain.pem ] && oc create secret tls ingress-certs --cert=${CERTDIR_TLD}/fullchain.pem --key=${CERTDIR_TLD}/key.pem -n openshift-ingress
oc patch ingresscontroller default -n openshift-ingress-operator --type=merge --patch='{"spec": { "defaultCertificate": { "name": "ingress-certs" }}}'

# API Certificate
[ -f ${CERTDIR_API}/fullchain.pem ] && oc create secret tls api-certs --cert=${CERTDIR_API}/fullchain.pem --key=${CERTDIR_API}/key.pem -n openshift-config
oc patch apiserver cluster --type=merge --patch='{"spec": { "servingCerts": {"namedCertificates": [{"names": [ "api.testcluster.ocp.clouditoutloud.com"], "servingCertificate": {"name": "api-certs" }}]}}}'
# Make sure config has been updated
oc get apiserver cluster -o yaml
# Make sure new config has been applied
oc get clusteroperators kube-apiserver
oc project openshift-apiserver 
o

# 4 (I think) operators will update and pods will be redeployed
while true; do oc get pods -n openshift-authentication | egrep "Init"; sleep 2; done 

echo | openssl s_client -connect api.testcluster.ocp.clouditoutloud.com:6443 -servername api.testcluster.ocp.clouditoutloud.com | sed -n /BEGIN/,/END/p | egrep "^depth"
echo | openssl s_client -connect test.apps.testcluster.ocp.clouditoutloud.com:443 -servername test.apps.api.testcluster.ocp.clouditoutloud.com | sed -n /BEGIN/,/END/p | egrep "^depth"

exit 0

################# ################# ################# ################# #################
# Cleanup (start over - remove the comment signs to use this command)
```
# oc delete # secret #  router-certs -n # openshift-ingress
```

### Public Doc on how to use Lets Encrypt in an automated fashion
https://medium.com/@karansingh010/lets-automate-let-s-encrypt-tls-certs-for-openshift-4-211d6c081875

## Notes 
I had attempted to do all this by manually creating my certs, etc... thankfully the "automated" process (above) works instead ;-)  
* --from-file=/root/OCP4/Certs/chain1.pem  
* --cert=/root/OCP4/Certs/cert1.pem  
* --key=/root/OCP4/Certs/privkey1.pem  

You will get 4 files from LetsEncrypt in /etc/letsencrypt/archive 

cert1.pem <- certfile  
chain1.pem <- cafile  
fullchain1.pem <- I suspect not used, but.. it might be the cafile?  
privkey1.pem <- keyfile  

Review the Certs
```
cd /root/OCP4/Certs
for FILE in `ls *2.pem`; do echo "## $FILE"; openssl x509 -in $FILE -noout -text ; done
```

## References
https://medium.com/@karansingh010/lets-automate-let-s-encrypt-tls-certs-for-openshift-4-211d6c081875  

Don't *acutally* use this one - but, it's good to review:  
https://docs.openshift.com/container-platform/4.11/security/certificates/replacing-default-ingress-certificate.html

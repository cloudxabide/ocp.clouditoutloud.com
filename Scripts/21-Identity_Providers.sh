# Identity Providers

# HTPASSWORD=""
HTPASSWD_FILE=${OCP4_DIR}/htpasswd

htpasswd -b -c $HTPASSWD_FILE morpheus $HTPASSWORD
htpasswd -b $HTPASSWD_FILE ocpguest $HTPASSWORD
htpasswd -b $HTPASSWD_FILE ocpadmin $HTPASSWORD

oc create secret generic htpass-secret --from-file=htpasswd=${HTPASSWD_FILE} -n openshift-config
cat << EOF > ${OCP4_DIR}/idp-cr-HTPasswd.yaml
---
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
  - name: HTPasswd 
    mappingMethod: claim
    type: HTPasswd
    htpasswd:
      fileData:
        name: htpass-secret
EOF

oc apply -f ${OCP4_DIR}/idp-cr-HTPasswd.yaml
# Need to automate this wait-period and then status check (to make sure pods have restarted)
sleep 90

# Watch the pods until they "re-settle" before proceeding - usually like 2 minutes?
oc get pods -n openshift-authentication -w
sudo su - -c "oc login -u ocpadmin -p $HTPASSWORD --server=$OCP4API:$OCP4APIPORT"
oc adm policy add-cluster-role-to-user cluster-admin ocpadmin

exit 0

## References
https://access.redhat.com/documentation/en-us/red_hat_directory_server/11/html/administration_guide/examples-of-common-ldapsearches   
https://docs.openshift.com/container-platform/4.10/authentication/identity_providers/configuring-ldap-identity-provider.html   
https://developers.redhat.com/blog/2019/08/02/how-to-configure-ldap-user-authentication-and-rbac-in-red-hat-openshift-3-11#ldap_details  


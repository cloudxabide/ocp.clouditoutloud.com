#!/bin/bash

# Registry *should* exist in s3 already
oc get configs.imageregistry.operator.openshift.io -o yaml > registry-0.yaml

## Customize the OpenShift Console logo

cd ${OCP4_DIR}
wget -O ./OCP-CIOL.png https://github.com/cloudxabide/ocp.clouditoutloud.com/raw/main/Images/OCP-CIOL.png

oc create configmap console-custom-logo --from-file ${OCP4_DIR}/OCP-CIOL.png  -n openshift-config
oc patch console.operator.openshift.io cluster --type merge --patch '{"spec":{"customization":{"customLogoFile":{"key":"OCP-CIOL.png"}}}}'
oc patch console.operator.openshift.io cluster --type merge --patch '{"spec":{"customization":{"customLogoFile":{"name":"console-custom-logo"}}}}'
oc patch console.operator.openshift.io cluster --type merge --patch '{"spec":{"customization":{"customProductName":"LinuxRevolution Console"}}}'

# OR...
update_header_logo_manual() {
oc edit console.operator.openshift.io cluster
# Update spec: customization: customLogoFile: {key,name}:
## add after "spec:operatorLogLevel: Normal"
  operatorLogLevel: Normal
  customization:
    customLogoFile:
      key: OCP-CIOL.png
      name: console-custom-logo
    customProductName: LinuxRevolution Console
}

exit 0

## Enable "Simple Content Access (SCA)" for entitled builds
Status:  Work in Progress - I don't actually know how to fix this yet
https://docs.openshift.com/container-platform/4.10/cicd/builds/running-entitled-builds.html
https://docs.openshift.com/container-platform/4.10/support/remote_health_monitoring/insights-operator-simple-access.html

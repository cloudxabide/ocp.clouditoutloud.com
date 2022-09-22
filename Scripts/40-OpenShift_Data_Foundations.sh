#!/bin/bash

note() {
# OpenShift Data Foundation (ODF) - FKA Container Storage (OCS)

A *very* brief overview of how to deploy ODF, which is likely to change.
}



# I export the vars set here to allow envsubst to utilize them.  
export ROLE=odf
export PLATFORM=vsphere
export OCP_CLUSTER_NAME=ocp4-mwn
export DOMAIN_NAME=linuxrevolution.com
export INFRASTRUCTURE_ID=$(oc get -o jsonpath='{.status.infrastructureName}{"\n"}' infrastructure cluster)

OCP4_DIR=$(dirname $(find ${HOME} -name terraform.*tfstate | tail -1))
echo -e " Role: $ROLE\n InfrastructureId: $INFRASTRUCTURE_ID\n Hypervisor: $PLATFORM\n ClusterName: $OCP_CLUSTER_NAME\n DomainName: $DOMAIN_NAME"

export MACHINESET_MANIFEST=machineset-$PLATFORM-$OCP_CLUSTER_NAME.$DOMAIN_NAME-$ROLE.yaml

# Create the machineset
cd $OCP4_DIR
rm $MACHINESET_MANIFEST
wget https://raw.githubusercontent.com/cloudxabide/matrix.lab/main/Files/$MACHINESET_MANIFEST -O ${MACHINESET_MANIFEST}.tmp
envsubst < $MACHINESET_MANIFEST.tmp > $OCP4_DIR/$MACHINESET_MANIFEST
cat $OCP4_DIR/$MACHINESET_MANIFEST

# Create Machines and Watch
oc create -f $OCP4_DIR/$MACHINESET_MANIFEST
oc get machines -n openshift-machine-api -w

# Review 
oc get machineset -n openshift-machine-api 
ODF_MACHINESET=$(oc get machineset -n openshift-machine-api | grep $ROLE | awk '{ print $1 }')
oc describe machineset $ODF_MACHINESET -n openshift-machine-api
```

## Label and Annotate the Storage Nodes (please see NOTE beloew)
-- NOTE: These *should* already exist as part of the machineset configuration being applied
```
for NODE in $(oc get nodes | grep odf | awk '{ print $1 }'); do oc label nodes $NODE node-role.kubernetes.io/infra=''; done
for NODE in $(oc get nodes | grep odf | awk '{ print $1 }'); do oc label nodes $NODE cluster.ocs.openshift.io/openshift-storage=""; done
for NODE in $(oc get nodes | grep odf | awk '{ print $1 }'); do oc adm taint node $NODE node.ocs.openshift.io/storage="true":NoSchedule; done

oc annotate namespace openshift-storage openshift.io/node-selector=
```

## Install OCS Operator
### WebUI
Browse to https://console-openshift-console.apps.ocp4-mwn.linuxrevolution.com/operatorhub/all-namespaces  

* Search for OpenShift Data Foundation
* install the Operator
* Create StorageSystem 
  * "Taint nodes"
  * Default (SDN)

![Deploy ODF](../images/Deploy_ODF.png)

### CLI
To see what operator(s) is(are) available
```
oc get packagemanifests | grep odf
```

Get 
  * channel
  * catalog source
  * catalog source namespace

#### Install the OperatorGroup
WIP

#### Install the Operator
You may either create a project with the appropriate tolerations, etc.. or add the tolerations to an existing one
```
( oc get namespace openshift-storage ) || {
wget https://raw.githubusercontent.com/cloudxabide/matrix.lab/main/Files/openshift-storage-project.yaml
oc create -f openshift-storage-project.yaml 
} && {
oc annotate namespace openshift-storage openshift.io/node-selector=
oc patch namespace openshift-storage --type=merge -p '{"spec":{"config":{"tolerations":[{"effect":"NoSchedule","key": "node-role.kubernetes.io/infra","value":"true","operator":"Equal"},{"effect":"NoExecute","key": "node-role.kubernetes.io/infra","value":"true","operator":"Equal"}]}}}'
for SUB in ` oc get subs -n openshift-storage | grep -v ^NAME | awk '{ print $1 }'`
do 
  oc patch sub/$SUB -n openshift-storage --type=merge -p '{"spec":{"config":{"tolerations":[{"effect":"NoSchedule","key": "node-role.kubernetes.io/infra","value":"true","operator":"Equal"},{"effect":"NoExecute","key": "node-role.kubernetes.io/infra","value":"true","operator":"Equal"}]}}}'
  echo "$SUB has been updated"
done
}

export NAMESPACE=openshift-storage
export OPERATOR_NAME=odf-operator

export CHANNEL=stable-4.9
export CURRENT_CSV=odf-operator.v4.9.2
#$(oc get packagemanifests odf-operator -o jsonpath="{range .status.channels[*]}Channel: {.name} currentCSV: {.currentCSV}{'\n'}{end}")
export CATALOG_SOURCE=$(oc get packagemanifests odf-operator -o jsonpath={.status.catalogSource})
export CATALOG_SOURCE_NAMESPACE=$(oc get packagemanifests odf-operator -o jsonpath={.status.catalogSourceNamespace})
cat << EOF > $OPERATOR_NAME.yaml
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: '$OPERATOR_NAME'
  namespace: '$NAMESPACE'
spec:
  channel: '$CHANNEL'
  installPlanApproval: Automatic
  name: '$OPERATOR_NAME'
  source: '$CATALOG_SOURCE'
  sourceNamespace: '$CATALOG_SOURCE_NAMESPACE'
  startingCSV: '$CURRENT_CSV'
EOF
cat $OPERATOR_NAME.yaml
oc apply -f $OPERATOR_NAME.yaml
```

### Show taints
```
oc get nodes -o=jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.taints[*].key}{"\n"}{end}'
```

## References
https://access.redhat.com/documentation/en-us/red_hat_openshift_data_foundation/4.9/html/managing_and_allocating_storage_resources/how-to-use-dedicated-worker-nodes-for-openshift-data-foundation_rhodf
https://red-hat-storage.github.io/ocs-training/training/infra-nodes/ocs4-infra-nodes.html#_machine_sets_for_creating_infrastructure_nodes

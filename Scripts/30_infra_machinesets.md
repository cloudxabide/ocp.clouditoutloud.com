#!/bin/bash
# Infra Machinesets

# Technically we are retrieving the ClusterID
CLUSTER_ID=$(oc get -o jsonpath='{.status.infrastructureName}{"\n"}' infrastructure cluster)
INFRASTRUCTURE_ID=$CLUSTER_ID

# Determine which region the machineSets are for (by grabbing the first one)
MACHINESET_FIRST=$(oc get machineset -n openshift-machine-api | awk '{ print $1 }' | grep -v ^NAME | head -1)

AWS_REGION=$(oc get machineset $MACHINESET_FIRST -n openshift-machine-api -o jsonpath='{.spec.template.spec.providerSpec.value.placement.region}{"\n"}')

# Determine what zones the worker nodes currently exist in
ZONES=""
for MACHINESET in $(oc get machineset -n openshift-machine-api | awk '{ print $1 }' | grep -v ^NAME)
do 
  ZONES+=" $(oc get machineset $MACHINESET -n openshift-machine-api -o jsonpath='{.spec.template.spec.providerSpec.value.placement.availabilityZone}{"\n"}')"
done

wget <blah - machineset template> machineset-infra-aws.ocp.clouditoutloud.com.yaml
# Using the Zones we discovered, we need to create a machineset for each
# Using evnsubst - need to replace: 
# INFRASTRUCTURE_ID AMI_ID AWS_REGION AWS_ZONE
for AWS_ZONE in $ZONES
do 
 envsubst < blah template  > machineset-infra-aws-${AWS_ZONE}.ocp.clouditoutloud.com.yaml 
done
 
# Create machineset for each AZ
for AWS_ZONE in $ZONES
do
  oc create -f  machineset-infra-aws-${AWS_ZONE}.ocp.clouditoutloud.com.yaml
done

exit 0

# References
# https://docs.openshift.com/container-platform/4.11/machine_management/creating-infrastructure-machinesets.html

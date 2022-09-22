#!/bin/bash

## Setup your oc Client Environment
```
su - morpheus
HTPASSWORD=NotAPassword
OCP4API=api.testcluster.ocp.clouditoutloud.com
OCP4APIPORT=6443
echo | openssl s_client -connect $OCP4API:$OCP4APIPORT -servername $OCP4API  | sed -n /BEGIN/,/END/p > ~/$OCP4API.pem
oc login --certificate-authority=$HOME/$OCP4API.pem --username=`whoami` --password=$HTPASSWORD --server=$OCP4API:$OCP4APIPORT

## www_clouditoutloud_com
MYPROJ="ciolwelcomepage"
oc new-project $MYPROJ --description="Welcome Page" --display-name="CloudItOutLoud Welcome Page" || { echo "ERROR: something went wrong"; exit 9; }
#oc new-app httpd~https://github.com/cloudxabide/ocp_clouditoutloud_com/
oc new-app php:7.3~https://github.com/cloudxabide/ocp_clouditoutloud_com/
echo '{ "kind": "List", "apiVersion": "v1", "metadata": {}, "items": [ { "kind": "Route", "apiVersion": "v1", "metadata": { "name": "wwwclouditoutloudcom", "creationTimestamp": null, "labels": { "app": "wwwclouditoutloudcom" } }, "spec": { "host": "www.clouditoutloud.com", "to": { "kind": "Service", "name": "ocpclouditoutloudcom" }, "port": { "targetPort": 8080 }, "tls": { "termination": "edge" } }, "status": {} } ] }' | oc create -f -
echo '{ "kind": "List", "apiVersion": "v1", "metadata": {}, "items": [ { "kind": "Route", "apiVersion": "v1", "metadata": { "name": "wwwappstestclusterocpclouditoutloudcom", "creationTimestamp": null, "labels": { "app": "wwwclouditoutloudcom" } }, "spec": { "host": "www.apps.testcluster.ocp.clouditoutloud.com", "to": { "kind": "Service", "name": "ocpclouditoutloudcom" }, "port": { "targetPort": 8080 }, "tls": { "termination": "edge" } }, "status": {} } ] }' | oc create -f -
sleep 3
# If you want to test round-robin and app scaling
oc scale deployment/wwwclouditoutloudcom --replicas=3
while true; do curl --silent https://www.clouditoutloud.com/phpinfo.php | grep Hostname; sleep 1; done

sleep 60

## HexGL
### Create Your Project and Deploy App (HexGL)
```
# HexGL is a HTML5 video game resembling WipeOut from back in the day (Hack the Planet!)
MYPROJ="hexgl"
oc new-project $MYPROJ --description="HexGL Video Game" --display-name="HexGL Game" || { echo "ERROR: something went wrong"; sleep 5; exit 9; }
oc new-app php:7.3~https://github.com/cloudxabide/HexGL.git --image-stream="openshift/php:latest" --strategy=source

# Wait for the build to complete (CrashLoopBackoff is "normal" for this build)
while true; do oc get pods | egrep Init; sleep 2; done

# Add a route (hexgl.clouditoutloud.com)
echo '{ "kind": "List", "apiVersion": "v1", "metadata": {}, "items": [ { "kind": "Route", "apiVersion": "v1", "metadata": { "name": "hexgl-apex", "creationTimestamp": null, "labels": { "app": "hexgl" } }, "spec": { "host": "hexgl.clouditoutloud.com", "to": { "kind": "Service", "name": "hexgl" }, "port": { "targetPort": 8080 }, "tls": { "termination": "edge" } }, "status": {} } ] }' | oc create -f -

# Add a route (hexgl.apps.testcluster.ocp.clouditoutloud.com)
echo '{ "kind": "List", "apiVersion": "v1", "metadata": {}, "items": [ { "kind": "Route", "apiVersion": "v1", "metadata": { "name": "hexgl-fqdn", "creationTimestamp": null, "labels": { "app": "hexgl" } }, "spec": { "host": "hexgl.apps.testcluster.ocp.clouditoutloud.com", "to": { "kind": "Service", "name": "hexgl" }, "port": { "targetPort": 8080 }, "tls": { "termination": "edge" } }, "status": {} } ] }' | oc create -f -

# Once the app is built (and running) update the deployment
sleep 120
oc scale deployment.apps/php --replicas=0
oc scale deployment.apps/hexgl --replicas=3

exit 0

# 
At some point you will be able to browse to (depending on the route you enabled):  
https://hexgl.clouditoutloud.com/




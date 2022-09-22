# Using Webhooks
For this example, I will be updating the HTML code for my website
https://www.ocp.clouditoutloud.com -->> https://github.com/cloudxabide/ocp_cloudioutloud_com

## Github
I have little/no interest in doing this anywhere other than Github at this time.  So, I'll start with that.

### Retrive the a Secret (Openshift)
```
oc get bc ocpclouditoutloudcom -n ciolwelcomepage -o jsonpath='{ .spec.triggers[?(@.type=="GitHub")].github.secret }'
```

### Retrieve the Webhook Payload URL (to add to Github's config)
This is an absolute travesty of a method to this value, but works...
```
oc describe bc | egrep github | grep -v ^URL
```

Use the URL you gathered to create a Github Webhook (change it to JSON), and replace <secret> with the value you obtained.

## References
https://docs.openshift.com/container-platform/4.6/builds/triggering-builds-build-hooks.html



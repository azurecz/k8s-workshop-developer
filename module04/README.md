# Prepare deployment files
cd ../module04
sed -i 's/YOURACRNAME/'$ACR_NAME'/g' *.yaml


# Use Volume to map persistent static content shared across SPA Pods
Up to this point Microsoft logo in our frontend app has been packaged with container. For situations with much more static content or need for some content management on top of running instances we might leverage shared Volume. This might be more efficient from storage and speed of deployment perspective and content such as images or documents can be managed outside of CI/CD pipelines such as with Content Management System.

Create Azure Files storage in Azure, create share and upload new image.
```
# Create storage account
export STORAGE_NAME=tomaskubestorage198
az storage account create -n $STORAGE_NAME \
    -g $RESOURCE_GROUP \
    --sku Standard_LRS

# Get storage key and create share
export STORAGE_KEY=$(az storage account keys list -g $RESOURCE_GROUP -n $STORAGE_NAME --query [0].value -o tsv
)
az storage share create -n images \
    --account-name $STORAGE_NAME \
    --account-key $STORAGE_KEY

# Upload image
az storage file upload -s images \
    --source ./ms.jpg \
    --account-name $STORAGE_NAME \
    --account-key $STORAGE_KEY
```

Create secret with storage connection details
```
kubectl create secret generic images-secret \
    --from-literal=azurestorageaccountname=$STORAGE_NAME \
    --from-literal=azurestorageaccountkey=$STORAGE_KEY \
    -n myapp
```

Deploy modified myappspa deployment. We are using Volume implemented by our share and map it container file system on path where images are. Note that Volume mapping takes precedent over existing files. All created Pods will see the same share.
```
kubectl apply -f 01-myappspa-deploy.yaml -n myapp
```

Wait until Deployment object upgrades our environment. Close existing application window and open our app again. You should see image change from Microsoft logo to Azure logo we have mapped to application via share.

# Use ConfigMap to tweek nginx.conf
Currently for our probes we are accessing root of SPA application which is too big taking away network and storage IO. We might one some more lightweight probe to check health status. Also we want to standardize on single url for all apps (/health) and do not want to implement changes in code itself. NGINX allows for configuring such health paths itself.

We want to change NGINX configuration without rebuilding container image. There might more configuration options that we want to tweek during deployment perhaps providing different settings for dev, test and production environment. General rule is not to change container image between environments!

We will solve this by using ConfigMap in Kubernetes. It can consist of key value pair that we can map into our Pod as environmental variables. In our case configuration is actualy more complex configuration file. This is also possible with ConfigMap. First let's use configuration file healthvhost.conf and package it as ConfigMap. 

```
kubectl create configmap healthvhostconf --from-file=healthvhost.conf -n myapp
kubectl describe configmap healthvhostconf -n myapp
```

First we will use changed Deployment with ConfigMap mapped to file system to proper locaiton where nginx expects configuration file and check it works.

```
kubectl apply -f 02-myappspa-deploy.yaml -n myapp
```

Wait for Deployment to redeploy Pods and check our /health URL works.
```
curl http://$INGRESS_IP.xip.io/health
```

Looks good. We will now change our probes implementation to point to /health.
```
kubectl apply -f 03-myappspa-deploy.yaml -n myapp
```

# Use init container to create version file outside of main container startup script


# Use sidecar container to modify log messages


# Use CronJob to periodically extract data from Postgresql

# Enhance Ingress
## Enable cookie-based sticky sessions
## Enable rate limit
## Enable HTTPS
## Autoenroll Let's encrypt certificate (optional)
## Enable authentication on Ingress (optional)





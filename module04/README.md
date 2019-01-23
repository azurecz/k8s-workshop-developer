# Prepare deployment files
cd ../module04
sed -i 's/YOURACRNAME/'$ACR_NAME'/g' *.yaml
sed -i 's/YOURINGRESSIP/'$INGRESS_IP'/g' *.yaml


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

# Use ConfigMap to tweek nginx configuration
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

# Use init container to create information file outside of main container startup script
Suppose now we need to know inside of our Pod what Kubernetes namespace it has been created in. More over we want to write it into file that will be accessible via URL. We will use passing this information via Downward API and also use init container to prepare file before running our main container.

We will add initContainer to our Pod definition. That container will be started before all other containers and Kubernetes will wait for it to finish first. This can used to preload cache or do any other preparations before you are ready to run your main container. We will also leverage Downward API to inject information about used image into Pod as environmental variable. For now init container will just print it on screen so we can capture it in logs.
```
kubectl apply -f 04-myappspa-deploy.yaml -n myapp
```

Checkout logs from our info container
```
kubectl logs myappspa-7b74455b84-rf2c6 -n myapp -c info   # Change to your Pod name
```

Should work. Now we want to put this information as file on our site so we need some way how init container can write to file system that main container can read from. We will use Volume for this, but this time it will not be implemented as outside resource, but rather is Volume valid only on Pod level mounted to both containers. Let's do it.
```
kubectl apply -f 05-myappspa-deploy.yaml -n myapp
```

Check it out
```
curl http://$INGRESS_IP.xip.io/info/namespace.txt
```

# Use CronJob to periodically extract data from Postgresql
In this example we will investigate how to use Kubernetes to run scheduled batch jobs. This is very useful for certain computation scenarios such as rendering or machine learning, but also for periodical tasks. In our demo we will shedule periodic task to dump data from postgresql into csv file stored on share in Azure storage.

We will reuse storage account we have created for images, but create new share in it.
```
az storage share create -n exports \
    --account-name $STORAGE_NAME \
    --account-key $STORAGE_KEY
```

Than we need to gather connection details you used for creating database in previous modules and store them in Kubernetes secret with naming convention used by psql command line utility.
```
kubectl create secret generic psql -n myapp \
    --from-literal PGUSER=$POSTGRESQL_USER@$POSTGRESQL_NAME \
    --from-literal PGPASSWORD=$POSTGRESQL_PASSWORD \
    --from-literal PGHOST=$POSTGRESQL_NAME.postgres.database.azure.com \
    --from-literal PGDATABASE=todo
```

Schedule job to run every 2 minutes.
```
kubectl apply -f 06-export.yaml -n myapp
```

Job will run every 2 minutes. After while check files in your storage account.

```
az storage file list -s exports -o table \
    --account-name $STORAGE_NAME \
    --account-key $STORAGE_KEY
```


# Enhance Ingress
Ingress object allows for basic configuration such as routing rules, but NGINX implementation support way more features beyond what is available in Ingress specification. Enhanced options can be configured using annotations.

## Enable cookie-based sticky sessions
At this point our front end is load balanced with no session persistence. That is OK for our application, but suppose we work with different one, that is not fully stateless and therefore need to ensure client session always go to same instance. 

First check you are getting responses from multiple replicas.
```
curl http://${INGRESS_IP}.xip.io/info.txt   # Repeat multiple times
```

Deploy modified Ingress object with annotation to enable session cookie-based persistence.
```
kubectl apply -f 07-myappspa-ing.yaml -n myapp
```

Now we will capture cookie and use it with next request. Ensure you are always getting response from the same instance.

```
curl -c mycookie http://${INGRESS_IP}.xip.io/info.txt
curl -b mycookie http://${INGRESS_IP}.xip.io/info.txt   # Repeat multiple times
```

There are way more configurations options beyond scope of this workshops. To name a few:
* TLS encryption using certificate stored as Kubernetes secret
* Automation of certificate enrollment (eg. with Let's encrypt) using cert-manager project
* Rate limit on requests per minute
* Source IP filtering
* Basic authentication
* OAuth2
* Canary including complex ones such as by header or cookie
* Cors
* Redirect
* Proxy features such as url rewrite
* Buffering
* Lua rules


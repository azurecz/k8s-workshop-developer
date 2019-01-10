# java-k8s-workshop

## prepare environment

We will use shell.azure.com cloud shell (bash) for experiments.
Before you will start please create FORK of our repo git@github.com:azurecz/java-k8s-workshop.git 

```bash
mkdir myexperiment
cd myexperiment

# clone repo first
git clone git@github.com:azurecz/java-k8s-workshop.git

# and now lets step into folder with project files.
cd java-k8s-workshop
```

## try it with private container registry

We will use Azure container registry for our images, lets deploy ACR and push images there ..

```bash
# variables
export RESOURCE_GROUP=JTEST
export LOCATION="northeurope"
export ACR_NAME=valdaakssec001
```


```bash
# create resource group
az group create --location ${LOCATION} --name ${RESOURCE_GROUP}

# create ACR
az acr create --name $ACR_NAME --resource-group $RESOURCE_GROUP --sku Standard --location ${LOCATION} --admin-enabled true

# Get ACR_URL for future use with docker-compose and build
export ACR_URL=$(az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query "loginServer" --output tsv)
echo $ACR_URL

# Get ACR key for our experiments
export ACR_KEY=$(az acr credential show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query "loginServer" --output tsv)
echo $ACR_KEY
```


```bash
# build SPA application in ACR - build has to be done from folder with source codes: java-k8s-workshop
az acr build --registry $ACR_NAME --image myappspa:v1 ./src/myappspa
```

## try to run quickly some container

```bash
export RESOURCE_GROUP=QTEST
export LOCATION="northeurope"

az container create -g ${RESOURCE_GROUP} -l ${LOCATION} --name myapp --image ${ACR_NAME}.azurecr.io/myappspa:v1 --ports 8080 --ip-address public
```

Grab public IP address from output and now you can test it with your browser ..

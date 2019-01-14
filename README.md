# java-k8s-workshop
This repo contains materials for one-day Java apps on Azure Kubernetes Service training scheduled for 30th of January 2019.

**WORK IN PROGRESS**

# Lab preparation

We will use shell.azure.com cloud shell (bash) for experiments.
Before you will start please create FORK of our repo `git@github.com:azurecz/java-k8s-workshop.git`

## Clone repo

```bash
mkdir myexperiment
cd myexperiment

# clone repo first
git clone git@github.com:azurecz/java-k8s-workshop.git

# and now lets step into folder with project files.
cd java-k8s-workshop
```

## Create Azure Container Registry

We will use Azure container registry for our images, lets deploy ACR and push images there ..

```bash
# variables
export RESOURCE_GROUP=JTEST
export LOCATION="northeurope"
export ACR_NAME=valdaakssec001
export AKS_CLUSTER_NAME=myaks

# create resource group
az group create --location ${LOCATION} --name ${RESOURCE_GROUP}

# create ACR
az acr create --name $ACR_NAME --resource-group $RESOURCE_GROUP --sku Standard --location ${LOCATION} --admin-enabled true

# Get ACR_URL for future use with docker-compose and build
export ACR_URL=$(az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query "loginServer" --output tsv)
echo $ACR_URL

# Get ACR key for our experiments
export ACR_KEY=$(az acr credential show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query "passwords[0].value" --output tsv)
echo $ACR_KEY
```

## Create Azure Kubernetes Service

```bash
# aks - create cluster
az aks create --resource-group ${RESOURCE_GROUP} --name ${AKS_CLUSTER_NAME} \
  --no-ssh-key --kubernetes-version 1.11.5 \
  --node-count 3 --node-vm-size Standard_DS1_v2 \
  --location ${LOCATION}
# kube config
az aks get-credentials --name ${AKS_CLUSTER_NAME} --resource-group ${RESOURCE_GROUP}
# patch kubernetes configuration to be able to access dashboard
kubectl create clusterrolebinding kubernetes-dashboard \
  -n kube-system --clusterrole=cluster-admin \
  --serviceaccount=kube-system:kubernetes-dashboard
```

## Setup access for AKS to ACR

```bash
# Get the id of the service principal configured for AKS
CLIENT_ID=$(az aks show --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME --query "servicePrincipalProfile.clientId" --output tsv)

# Get the ACR registry resource id
ACR_ID=$(az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query "id" --output tsv)

# Create role assignment
az role assignment create --assignee $CLIENT_ID --role Reader --scope $ACR_ID
```

# Labs

## [01 - Building Java application containers](01%20-%20Building%20Java%20application%20containers/README.md)

## [02 - Introduction to Azure Kubernetes Service](02%20-%20Introduction%20to%20Azure%20Kubernetes%20Service/README.md)

## [03 - Deploy Java application to Azure Kubernetes Service](03%20-%20Deploy%20Java%20application%20to%20Azure%20Kubernetes%20Service/README.md)

## [04 - Optimizing deployment in Kubernetes](04%20-%20Optimizing%20deployment%20in%20Kubernetes/README.md)

## [05 - CI-CD with AKS, GitHub and Jenkins](05%20-%20CI-CD%20with%20AKS%2C%20GitHub%20and%20Jenkins/README.md)


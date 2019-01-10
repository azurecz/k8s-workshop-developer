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
export AKS_CLUSTER_NAME=myaks
```

### AKS

```bash
# aks - create cluster
az aks create --resource-group ${RESOURCE_GROUP} --name ${AKS_CLUSTER_NAME} \
  --no-ssh-key --kubernetes-version 1.11.5 \
  --node-count 3 --node-vm-size Standard_DS1_v2 \
  --location ${LOCATION}
# kube config
az aks get-credentials --name ${AKS_CLUSTER_NAME} --resource-group ${RESOURCE_GROUP}
# patch kubernetes configuration to be able to access control plane
kubectl create clusterrolebinding kubernetes-dashboard \
  -n kube-system --clusterrole=cluster-admin \
  --serviceaccount=kube-system:kubernetes-dashboard
```

### AKS + helm

```bash
# Create a service account for Helm and grant the cluster admin role.
cat <<EOF | kubectl create -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: tiller
  namespace: kube-system
EOF

# initialize helm
helm init --service-account tiller --upgrade

# after while check if helm is installed in cluster
helm version
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
export ACR_KEY=$(az acr credential show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query "passwords[0].value" --output tsv)
echo $ACR_KEY
```


```bash
# build SPA application in ACR - build has to be done from folder with source codes: java-k8s-workshop
az acr build --registry $ACR_NAME --image myappspa:v1 ./src/myappspa
```

## try to run some container

```bash
az container create -g ${RESOURCE_GROUP} -l ${LOCATION} --name myapp --image ${ACR_URL}/myappspa:v1 --ports 80 --ip-address public --registry-username ${ACR_NAME} --registry-password "${ACR_KEY}"
```

Grab public IP address from output and now you can test it with your browser ..


## aks - acr access role

```bash
# Get the id of the service principal configured for AKS
CLIENT_ID=$(az aks show --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME --query "servicePrincipalProfile.clientId" --output tsv)

# Get the ACR registry resource id
ACR_ID=$(az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query "id" --output tsv)

# Create role assignment
az role assignment create --assignee $CLIENT_ID --role Reader --scope $ACR_ID
```

## app to aks

```bash
# install nginx
helm install --name default-ingress stable/nginx-ingress

# wait for deployment - we have to collect public IP address.
kubectl get svc
```


```bash
# build images (from directory java-k8s-workshop)
az acr build --registry $ACR_NAME --image myappspa:v1 ./src/myappspa
az acr build --registry $ACR_NAME --image myapptodo:v1 ./src/myapptodo

# create namespace
kubectl create namespace myapp

# create secrets

# create deployment
kubectl apply -f myapp-deploy --namespace myapp

# cleanup deployment

```
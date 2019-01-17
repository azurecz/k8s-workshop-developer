# CI/CD

```bash
# goto directory for this lab
cd ../module05
```

## Prepare to CI/CD with helm.

Helm is template engine (deployment engine) for kubernetes.

Please change IP address of your ingress controller and name of your Azure Container Registry in `helm upgrade` command below.

```bash
# create namespace
kubectl create namespace myapp

# create secrets
POSTGRESQL_URL="jdbc:postgresql://${POSTGRESQL_NAME}.postgres.database.azure.com:5432/todo?user=${POSTGRESQL_USER}@${POSTGRESQL_NAME}&password=${POSTGRESQL_PASSWORD}&ssl=true"
kubectl create secret generic myrelease-myapp \
  --from-literal=postgresqlurl="$POSTGRESQL_URL" \
  --namespace myapp

# add helm charts from local to ACR repo
az configure --defaults acr=${ACR_NAME}
# get access token for helm (similar to docker login)
az acr helm repo add
# pack helm repo
helm package helm/myapp
# push repo to ACR(helm)
az acr helm push myapp-0.1.0.tgz

# list repos (two examples)
az acr helm list

helm update
helm search ${ACR_NAME}

# deploy from ACR helm repository
helm upgrade --install myrelease ${ACR_NAME}/myapp --namespace='myapp' --set-string appspa.image.repository="${ACR_NAME}.azurecr.io/myappspa",appspa.image.tag='v1',apptodo.image.repository="${ACR_NAME}.azurecr.io/myapptodo",apptodo.image.tag='v1',apphost='0.0.0.0.xip.io'

# clean-up deployment
helm delete --purge myrelease
# delete namespace
kubectl delete namespace myapp
```

## CI/CD based on GitHub + Azure Container Registry build + Flux delivery to kubernetes

This CI/CD demo contains CI simple pipeline in Azure Container Registry and CD pipeline in FLUX (git based delivery system - https://github.com/weaveworks/flux ).

### ACR based CI pipeline

There we will define two build tasks - for building SPA web GUI and TODO microservice.

```bash
# set default ACR name
az configure --defaults acr=${ACR_NAME}
# build manualy / last parameter of command is your forked github repo
az acr run -f module05/acr-flux/myapp-ci.yaml https://github.com/valda-z/java-k8s-workshop.git
```

## CI/CD in Jenkins (AKS + ACR)

## CI/CD in Azure DevOps

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

# Get ingress public IP
export INGRESS_IP=$(kubectl get svc default-ingress-nginx-ingress-controller -o=custom-columns=EXTERNAL-IP:.status.loadBalancer.ingress[*].ip | grep -v "EXTERNAL-IP")
echo "You will be able to access application on this URL: http://${INGRESS_IP}.xip.io"

# deploy from ACR helm repository
helm upgrade --install myrelease ${ACR_NAME}/myapp --namespace='myapp' --set-string appspa.image.repository="${ACR_NAME}.azurecr.io/myappspa",appspa.image.tag='v1',apptodo.image.repository="${ACR_NAME}.azurecr.io/myapptodo",apptodo.image.tag='v1',apphost="${INGRESS_IP}.xip.io"

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

Now let's prepare task triggered by github commit. We will need access token for this task, there is description: https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/ .

```bash
# now prepare task triggered by github commit
az acr task create -n myapp -f module05/acr-flux/myapp-ci.yaml \
  -c https://github.com/valda-z/java-k8s-workshop.git \
  --pull-request-trigger-enabled true \
  --git-access-token 0000000000000000000000000000000000000000

# list tasks
az acr task list -o table

# list run history
az acr task list-runs -o table
```

Now we can create small commit in our repo and check via `az acr task list-runs -o table` if build was triggered and status of build.

### Handle CI (ACR build) to FLUX CD

There is space for some homework and creative solution. You can use Azure LogicApp or any other technique to handle webhooks from ACR to trigger CD tasks (by commit changes to github repo with flux configuration).

### CD by FLUX

## CI/CD in Jenkins (AKS + ACR)

## CI/CD in Azure DevOps

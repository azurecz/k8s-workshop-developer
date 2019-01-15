# CI/CD

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

# deploy from directory java-k8s-workshop
helm upgrade --install myrelease myapp-helm --namespace='myapp' --set-string appspa.image.repository='#####.azurecr.io/myappspa',appspa.image.tag='v1',apptodo.image.repository='#####.azurecr.io/myapptodo',apptodo.image.tag='v1',apphost='0.0.0.0.xip.io'

# clean-up deployment
helm delete --purge myrelease
# delete namespace
kubectl delete namespace myapp
```
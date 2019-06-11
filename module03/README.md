# 03 - Deploy application to Azure Kubernetes Service

```bash
# goto directory for this lab
cd ../module03
```

## Create PostgreSQL service

```bash
#variables
. ../rc

# create PostgreSQL server in Azure
az postgres server create --resource-group ${RESOURCE_GROUP} \
  --name ${POSTGRESQL_NAME}  --location ${LOCATION} \
  --admin-user ${POSTGRESQL_USER} --admin-password ${POSTGRESQL_PASSWORD} \
  --sku-name B_Gen5_1 --version 9.6

# Get PostgreSQL FQDN (we will need in later on for configuration)
POSTGRES_FQDN=$(az postgres server show --resource-group ${RESOURCE_GROUP} --name ${POSTGRESQL_NAME} --query "fullyQualifiedDomainName" --output tsv)
echo $POSTGRES_FQDN

# create PostgreSQL database in Azure
az postgres db create --resource-group ${RESOURCE_GROUP} \
  --server-name ${POSTGRESQL_NAME}   \
  --name todo

# enable access for Azure resources (only for services running in azure)
az postgres server firewall-rule create \
  --server-name ${POSTGRESQL_NAME} \
  --resource-group ${RESOURCE_GROUP} \
  --name "AllowAllWindowsAzureIps" --start-ip-address "0.0.0.0" --end-ip-address "0.0.0.0"
```

## Deploy apps to AKS

Replace your image names (ACR name) in files `myapp-deploy/myappspa-rs.yaml` and `myapp-deploy/myapptodo-rs.yaml`.

Replace public IP address of your nginx ingress controller for host rule in files `myapp-deploy/myappspa-ing.yaml` and `myapp-deploy/myapptodo-ing.yaml`. 

```bash
# Change yaml files to your ACR name
sed -i 's/YOURACRNAME/'$ACR_NAME'/g' myapp-deploy/*.yaml

# Get ingress public IP
export INGRESS_IP=$(kubectl get service ingress-nginx-ingress-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "You will be able to access application on this URL: http://${INGRESS_IP}.xip.io"

# Change YAML files for ingress
sed -i 's/YOURINGRESSIP/'$INGRESS_IP'/g' myapp-deploy/*.yaml
```

```bash
# create namespace
kubectl create namespace myapp

# create secrets
POSTGRESQL_URL="jdbc:postgresql://${POSTGRESQL_NAME}.postgres.database.azure.com:5432/todo?user=${POSTGRESQL_USER}@${POSTGRESQL_NAME}&password=${POSTGRESQL_PASSWORD}&ssl=true"
kubectl create secret generic myapptodo-secret \
  --from-literal=postgresqlurl="$POSTGRESQL_URL" \
  --namespace myapp

# create deployment
kubectl apply -f myapp-deploy --namespace myapp
```

### Deploy canary (v2 of SPA application)

Now we will create canary deployment with version v2 and we will balance there 10% of traffic.

```bash
# Change yaml files to your ACR name
sed -i 's/YOURACRNAME/'$ACR_NAME'/g' myapp-deploy-canary/*.yaml

# Get ingress public IP
export INGRESS_IP=$(kubectl get service ingress-nginx-ingress-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "You will be able to access application on this URL: http://${INGRESS_IP}.xip.io"

# Change YAML files for ingress
sed -i 's/YOURINGRESSIP/'$INGRESS_IP'/g' myapp-deploy-canary/*.yaml
```

```bash
# create deployment
kubectl apply -f myapp-deploy-canary --namespace myapp
```

Is traffic really balanced to app versions? Let's find out.
```
while true; do curl http://${INGRESS_IP}.xip.io/info.txt; done
```

Enforce traffic routing only to canary based on HEADER values in requests.
```
while true; do curl -H "myappspa-canary-v2: always" http://${INGRESS_IP}.xip.io/info.txt; done
```

### Note

There are way more configurations options beyond scope of this workshop. To name a few:
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

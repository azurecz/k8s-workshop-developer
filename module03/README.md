# 03 - Deploy Java application to Azure Kubernetes Service

## Create PostgreSQL service

```bash
export POSTGRESQL_NAME="valdaakspostgresql001"
export POSTGRESQL_USER="myadmin"
export POSTGRESQL_PASSWORD="VerySecurePassword123..."

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

```bash
# goto directory for this lab
cd ../module03
```

Replace your image names (ACR name) in files `myapp-deploy/myappspa-rs.yaml` and `myapp-deploy/myapptodo-rs.yaml`.

Replace public IP address of your nginx ingress controller for host rule in files `myapp-deploy/myappspa-ing.yaml` and `myapp-deploy/myapptodo-ing.yaml`. 

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

# cleanup deployment
kubectl delete namespace myapp
```

# 01 - Building Java application containers

## Build image in Azure Container Registry

```bash
# enter directory with source codes
cd '01 - Building Java application containers'/

# build SPA application in ACR - build has to be done from folder with source codes: java-k8s-workshop
az acr build --registry $ACR_NAME --image myappspa:v1 ./src/myappspa
```

## Try to run some container in Azure Container Instances

```bash
az container create -g ${RESOURCE_GROUP} -l ${LOCATION} --name myapp --image ${ACR_URL}/myappspa:v1 --ports 80 --ip-address public --registry-username ${ACR_NAME} --registry-password "${ACR_KEY}"
```

Grab public IP address from output and now you can test it with your browser ..

And finally we can delete container instance from Azure Portal ...

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

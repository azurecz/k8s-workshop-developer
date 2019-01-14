# 01 - Building Java application containers

## Build image in Azure Container Registry

```bash
# enter directory with source codes
cd '01 - Building Java application containers'/

# build SPA application in ACR - build has to be done from folder with source codes: java-k8s-workshop
az acr build --registry $ACR_NAME --image myappspa:v1 ./src/myappspa
# build JAVA microservice (spring-boot)
az acr build --registry $ACR_NAME --image myapptodo:v1 ./src/myapptodo
```

## Try to run some container in Azure Container Instances

```bash
az container create -g ${RESOURCE_GROUP} -l ${LOCATION} --name myapp --image ${ACR_URL}/myappspa:v1 --ports 80 --ip-address public --registry-username ${ACR_NAME} --registry-password "${ACR_KEY}"
```

Grab public IP address from output and now you can test it with your browser ..

And finally we can delete container instance from Azure Portal ...


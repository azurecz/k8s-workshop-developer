# Jump to lab directory
cd module02

# Change yaml files to your ACR name
```
sed -i 's/YOURACRNAME/'$ACR_NAME'/g' *.yaml
```

# Deploy single Pod
First we will deploy single Pod. Note we are using imagePullPolicy set to Always, which requires download image always from Azure Container Registry rather than using cache on node. This might sound less efficient, but is considered best practice from security perspective. In our simple example whole AKS cluster is trusted for ACR, but you might want different administrators have different level of access to ACR. Credentials to ACR would be checked everytime Kubernetes downloads image from repository and we do not want to bypass this by running from unathenticated local cache on node.
```
kubectl apply -f 01-myappspa-pod.yaml
```

We can list running Pods. With -w we can stream changes od Pod status so you might see status changing from ContainerCreating to Running etc.
```
kubectl get pods -w
```

If something goes wrong check more details about Pod including log of state changes.
```
kubectl describe pod spa
```

Note that you can also get logs via kubectl (use -f for streaming).
```
kubectl logs spa
```

Pod is basic unit of deployment and by itself it does not provide additional functionality such as redeploying Pod if something goes wrong (such as node going down). We can see that by deleting Pod. It will just die and no other Pod will be deployed as replacement.
```
kubectl delete pod spa
kubectl get pods -w
```

# Use Deployment instead
Rather that using Pod directly let's create Deployment object. Controller than creates ReplicaSet and making sure that desired number of Pods is always running. There are few more configurations we have added as best practice that we are going to need later in lab:
* labels - Kubernetes identify objects by their labels. For example ReplicaSet (as created automatically by Deploment) use queries on labels to understand how many Pods are running vs. desired state. Labels keys and values have no actual predefined meanings, it is up to you to decide what to use. 
* securityContext - It is best practice whenever possible to run containers as non-root user. Our configuration enforces that and refuse to run container image that would require root. Note that some systems based on Kubernetes do not even allow to run containers under root.
* livenessProbe - Kubernetes is checking whether main container process is running. If it fails and exit, Kubernetes will restart container. But there might be situation when process stays up, but hangs and not service any requests. Therefore we want to add livenessProbe to check health more comprehensively. Note probes can be network based (our example) or command based (you can periodically run script in container)
* readinessProbe - At this point we do not have any load balancer infront of our Pod, but when we add it, it will use readinessProbe to understand what instances (Pods) are ready to serve traffic. Why is this different from livenessProbe? Failed livenessProbe leads to container restart while failed readinessProbe will not hurt Pod, just will not send traffic to it. Sometimes your application need some additional time after boot before getting fully ready (eg. fill the cache first) or you might want to signal that Pod is overloaded and do not want any more traffic.
* resources limit - Always set limits on reasources. You do not want misbehaving Pod to steel all CPU time and eat all memory on Node hurting other Pods running there
* resource requests - Scheduler place Pods on Nodes using sophisticated algorithm. By requesting resources scheduler will substract it from overall Node capacity. Also this is important for Node autoscaling scenario. As Kubernetes scheduler would not be able to place Pod to any Node (all are occupied) it can trigger event to add more Nodes automatically.

Let's create our Deployment and check what it creates.
```
kubectl apply -f 02-myappspa-deploy.yaml
kubectl get deploy,rs,pods
```

We will now kill our Pod and see how Kubernetes will make sure our environment is consistent with desired state (which means create Pod again). Pod name is pretty long so when using Bash you might want to enable autocomplete so tab key works.
```
source <(kubectl completion bash)
kubectl delete pod myappspa-54bb8c6b7c-p9n6v    # replace with your Pod name
kubectl get pods
```

# Scale Deployment
We will now scale our Deployment to 3 instances. File 03-myappspa-deploy.yaml is the same as previous version except for number of instances. Kubernetes will keep first instance running, but will add two more to make our desired state reality. Note with -o wide we will get more information including Node on which Pod is running.
```
kubectl apply -f 03-myappspa-deploy.yaml
kubectl get pods -o wide
```

Now let's play a little bit with labels. There are few ways how you can print it on output or filter by label. Try it out.
```
# print all labels
kubectl get pods --show-labels    

# filter by label
kubectl get pods -l app=myapp

# add label collumn
kubectl get pods -L app,component
```

Note that the way how ReplicaSet (created by Deployment) is checking whether environment comply with desired state is by looking at labels. Loog for Selector in output.
```
kubectl get rs
kubectl describe rs myappspa-54bb8c6b7c   # put your actual rs name here
```

Suppose now that one of your Pods behaves strangely. You want to get it out, but not kill it, so you can do some more troubleshooting. We can edit Pod and change its label app: myappspa to something else such as app: spaisolated. What you expect to happen?
```
export EDITOR=nano
kubectl edit pod myappspa-54bb8c6b7c-xr98s    # change to your Pod name
kubectl get pods --show-labels
```

What happened? As we have changed label ReplicaSet controller no longer see 3 instances with desired labels, just 2. Therefore it created one additional instance. What will happen if you change label back to its original value?
```
kubectl edit pod myappspa-54bb8c6b7c-xr98s    # change to your Pod name
kubectl get pods --show-labels
```

Kubernetes have killed one of your Pods. Now we have 4 instances, but desired state is 3, so controller removed one of those.

# Create externally accessible Service
Kubernetes includes internal load balancer and service discovery called Service. This creates internal virtual IP address (cluster IP), load balancing rules are DNS records in internal DNS service. In order to get access to Service from outside AKS has implemented driver for type: LoadBalancer which calls Azure and deploy rules to Azure Load Balancer. By default it will create externally accessible public IP, but can be also configured for internal LB (for apps that should be accessible only within VNET or via VPN).

Let's create one. Note "selector". That is way how Service identifies Pods to send traffic to. We have intentionaly included labels app and component, but not type (you will see why later in lab).
```
kubectl apply -f 04-myappspa-service.yaml
kubectl get service
```

Note that external IP can be in pending state for some time until Azure configures everything.

Wait for IP to get allocated. Kubectl supports jsonpath for searching and getting only specific data. This can be very useful in scripts. Get external IP and check you can access app in browser and via curl.
```
export extPublicIP=$(kubectl get service myappspa -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl $extPublicIP/info.txt
```

Is traffic really balanced to instances? Let's find out.
```
while true; do curl $extPublicIP/info.txt; done
```

# Deploy another Pod and test connectivity
What about accessing Service from other Pods? This is what cluster IP is for and there is internal DNS name resolution. We will no create simple ubuntu-based Pod.
```
kubectl apply -f 05-ubuntu-pod.yaml
```

For troubleshooting you can exec into container and run some commands there or even jump using interactive mode to shell. Note this is just for troubleshooting - you should never change anything inside running containers this way. Always build new container image or modify external configuration (we will come to this later) rather than doing things inside.

Jump into container and try access to service using DNS record.
```
kubectl exec -ti ubuntu -- /bin/bash
curl myappspa/info.txt
```

# Rolling upgrade
Kubernetes Deployment support rolling upgrade to newer container images. If you change image in desired state (typically you change tag to roll to new version of your app). Deployment will create new ReplicaSet with new version and orchestrate rolling upgrade. It will add new version Pod and when it is fully up it removes one with older version and so until original ReplicaSet is on size 0. Since tags we used for Service identification are the same for both we will not experience any downtime.

In one window start curl in loop.
```
while true; do curl $extPublicIP/info.txt; done
```

Focus on version which is on end of string. No in different window deploy new version of Deploment with different image tag and see what is going on.
```
kubectl apply -f 06-myappspa-deploy.yaml
```

# Canary release
Sometimes rolling upgrade is too fast. You would like to release more slowly and deploy one canary Pod and observe behavior for some time before rolling other instances to new version as well. Remember our Service definition is based on labels app and component, not type. We can create new Deployment with different type value. It will behave as separate Deployment, but from Service perspective it will look the same so Service will include it balancing.

First let's rollback to version one. We can simply deploy Deployment with v1 image tag again.
```
kubectl apply -f 07-myappspa-deploy.yaml
```

Keep pinging app in one window. Wait for rollback to finish so we get only v1 responses.
```
while true; do curl $extPublicIP/info.txt; done
```

OK. Now let's deploy canary Deployment with single Pod. We should see roughly 25% of requests hit v2.
```
kubectl apply -f 08-myappspa-canary-deploy.yaml
```

Note native Kubernetes tools will assign traffic based on number of Pods. Sometimes you might want to send just 10% of traffic to canary, but that would require running 9 Pods of v1 and 1 Pod of v2. Or you might want send traffic to canary based on information in request header (such as debug flag). This is not possible with plain Kubernetes, but there are extentension that allow that. Most popular is Istio which is outside of scope of this lab.

# Clean up
At this point let's delete our experiments. We will deploy complete application in next module.

```
kubectl delete deployment myappspa,myappspa-canary
kubectl delete service myappspa
```

# Install Helm and Ingress
In module03 we will install complete application including reverse proxy (Ingress object). It allows for creation of L7 rules including things such as cookie based session persistency, TLS termination, URL routing and other important features. Before we do that we need to install Ingress controller and implementation. In our lab we will use NGINX flavor.

In order to ease installation we will use Helm as deployment and packaging tool. Basically Helm allows to package multiple Kubernetes objects into single operation, provide versioning and lifecycle management. Before we move to module03 let's prepare Helm environment. You will use Helm heavily in module05 where you will get more details.

Helm CLI component is preinstalled in Azure Cloud Shell so you can skip this step. If you are using your own computer first you would need to download Helm CLI.
```
cd ./helm
wget https://storage.googleapis.com/kubernetes-helm/helm-v2.9.1-linux-amd64.tar.gz
tar -zxvf helm-v2.9.1-linux-amd64.tar.gz
sudo cp linux-amd64/helm /usr/local/bin
rm -rf linux-amd64/
```

Create account in Kubernetes for Helm, install server-side component and check it.

```bash
# Create a service account for Helm and grant the cluster admin role.
kubectl apply -f helm-account.yaml

# initialize helm
helm init --service-account tiller --upgrade

# after while check if helm is installed in cluster
helm version
```

Let's now use Helm to deploy nginx Ingress solution.
```
helm install --name ingress stable/nginx-ingress \
  --set rbac.create=true \
  --set controller.image.tag=0.21.0
```

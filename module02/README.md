# Jump to lab directory
cd module02

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

# Deploy another Pod and test connectivity
(check DNS entries from Pod, check curl from Pod, check curl from outside, check balancing)

# Rolling upgrade

# Canary release

# Install Helm and Ingress (WORK IN PROGRESS)
## AKS + helm

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



# Deploy single Pod
(run it, kill it)

# Use Deployment instead
(run it, kill it, see it recover)

# Scale Deployment

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



# Kubernetes Minikube Lab: Pulling a Private Docker Image into a Pod

## 🎯 Project Goal

The main goal of this project is:

> **I have a private Docker Hub repository containing an image, and I want Kubernetes/Minikube to pull that private image and run it as a Pod.**

Image used:

```text
krishnapavan007/pvt:img1
```

The project also covers exposing the Nginx Pod through a Kubernetes Service and understanding how networking differs between Minikube and AWS/KOPS.

---

# 1. Architecture

Our final setup looks like this:

```text
                 Docker Hub
                    🔒
                    |
                    | private image
                    ↓
          krishnapavan007/pvt:img1
                    |
                    | imagePullSecrets
                    ↓
             Kubernetes Secret
                dockerCred
                    |
                    ↓
               Minikube
                    |
             ┌──────┴──────┐
             ↓             ↓
          Service          Pod
          :80              :80
             |          10.244.0.4
             └──────────────┘
```

The important point is:

**`docker login` on the EC2 host does NOT automatically give Kubernetes permission to pull the private image.**

Kubernetes needs a registry authentication Secret.

---

# 2. Environment

Example environment:

```text
AWS EC2
   ↓
Minikube
   ↓
Kubernetes
```

Minikube is being used as the Kubernetes cluster.

This is different from running a managed/cloud-integrated Kubernetes cluster such as EKS or a KOPS cluster on AWS.

---

# 3. Private Docker Repository

The image is stored in a private Docker Hub repository:

```text
krishnapavan007/pvt:img1
```

Because the repository is private, Kubernetes must authenticate to Docker Hub before pulling the image.

---

# 4. Docker Registry Authentication

## Important distinction

Running:

```bash
docker login
```

authenticates the Docker client on that machine.

It does NOT automatically configure Kubernetes Pods to authenticate to Docker Hub.

The Kubernetes equivalent for pulling a private image is a Docker registry Secret.

---

# 5. Create the Docker Registry Secret

Create the Secret in the same namespace where the Pod will run:

```bash
kubectl create secret docker-registry dockerCred \
  --docker-username=krishnapavan007 \
  --docker-password='YOUR_PASSWORD' \
  --docker-server=https://index.docker.io/v1/ \
  -n dev
```

### What does `--docker-server` mean?

It does NOT mean that we need to create or own a Docker server.

Docker Hub is the container registry.

```text
Docker Hub
   ↓
index.docker.io
```

Therefore:

```bash
--docker-server=https://index.docker.io/v1/
```

means:

> These credentials are for Docker Hub.

---

# 6. Verify the Secret

```bash
kubectl get secrets -n dev
```

Expected:

```text
dockerCred
```

You can also check:

```bash
kubectl get secret dockerCred -n dev
```

Expected type:

```text
kubernetes.io/dockerconfigjson
```

The Secret is namespace-scoped.

Therefore:

```text
Secret in dev
     ↓
Pod in dev
```

works.

But:

```text
Secret in default
     ↓
Pod in dev
```

does NOT work.

---

# 7. Pod YAML

The Pod must use `imagePullSecrets`.

Example:

```yaml
apiVersion: v1
kind: Pod

metadata:
  name: mypod
  namespace: dev
  labels:
    app: myapp

spec:
  imagePullSecrets:
    - name: dockerCred

  containers:
    - name: cont01
      image: krishnapavan007/pvt:img1
      ports:
        - containerPort: 80
```

---

# 8. `imagePullSecrets` vs `envFrom`

This was one of the important problems encountered.

### Wrong for registry authentication

```yaml
envFrom:
  - secretRef:
      name: dockerCred
```

`envFrom` means:

> Take values from a Secret and expose them as environment variables inside the container.

It does NOT tell Kubernetes how to authenticate while pulling an image.

### Correct

```yaml
imagePullSecrets:
  - name: dockerCred
```

This tells Kubernetes:

> Use this registry credential when pulling the private image.

### Remember

```text
envFrom
   ↓
Environment variables inside container

imagePullSecrets
   ↓
Authentication for pulling private container images
```

---

# 9. Why the ImagePullBackOff Happened

Initially the Pod was showing:

```text
ImagePullBackOff
```

The event contained an error similar to:

```text
pull access denied
repository does not exist or may require authorization
authorization failed
```

The reason was that the Pod was not using the Docker registry Secret correctly.

Once we changed:

```yaml
envFrom:
```

to:

```yaml
imagePullSecrets:
```

the Pod was able to authenticate and pull the private image.

---

# 10. Pod Immutability Problem

After changing the Pod YAML, we tried:

```bash
kubectl apply -f pod.yml
```

and Kubernetes returned an error similar to:

```text
The Pod "mypod" is invalid:
spec: Forbidden
```

The reason:

> Most of a running Pod's specification is immutable.

We had already created:

```text
mypod
```

and then attempted to add/change:

```yaml
imagePullSecrets:
```

Kubernetes does not allow that kind of Pod update.

### Correct solution

Delete the existing Pod:

```bash
kubectl delete pod mypod -n dev
```

Then recreate it:

```bash
kubectl apply -f pod.yml
```

Check:

```bash
kubectl get pods -n dev
```

Expected:

```text
mypod   1/1   Running
```

---

# 11. Important Correction: Can a Pod use `kubectl apply`?

YES.

This is an important misconception.

A Pod **can absolutely be created using**:

```bash
kubectl apply -f pod.yml
```

`kubectl apply` is NOT only for Deployments.

You can use it with:

```text
Pod
Deployment
Service
ConfigMap
Secret
StatefulSet
DaemonSet
Ingress
...
```

The issue is not that Pods cannot use `apply`.

The issue is:

> **An existing Pod has many immutable fields.**

So this works:

```bash
kubectl apply -f pod.yml
```

when creating the Pod.

But after the Pod exists, changing certain fields may fail.

For many Pod specification changes, the normal approach is:

```bash
kubectl delete pod mypod -n dev
kubectl apply -f pod.yml
```

---

# 12. Why Deployments Are Usually Better

In real Kubernetes workloads, we normally don't create application Pods directly.

Instead:

```text
Deployment
    ↓
ReplicaSet
    ↓
Pod
```

A Deployment manages Pods for us.

For example:

```yaml
apiVersion: apps/v1
kind: Deployment

metadata:
  name: myapp
  namespace: dev

spec:
  replicas: 1

  selector:
    matchLabels:
      app: myapp

  template:
    metadata:
      labels:
        app: myapp

    spec:
      imagePullSecrets:
        - name: dockerCred

      containers:
        - name: cont01
          image: krishnapavan007/pvt:img1
          ports:
            - containerPort: 80
```

With a Deployment, changing the image or other supported Pod-template fields causes Kubernetes to create a new Pod rather than trying to mutate the existing Pod in place.

For learning Kubernetes fundamentals, however, creating a Pod directly is completely valid.

---

# 13. Service

We created a Service:

```yaml
apiVersion: v1
kind: Service

metadata:
  name: servicelb
  namespace: dev

spec:
  type: LoadBalancer

  selector:
    app: myapp

  ports:
    - port: 80
      targetPort: 80
```

The Service selector:

```yaml
selector:
  app: myapp
```

must match the Pod label:

```yaml
labels:
  app: myapp
```

Otherwise the Service won't find the Pod.

---

# 14. Endpoint

We initially had a problem where the Service had no running Pod behind it.

Once the Pod became `Running`, we checked:

```bash
kubectl get endpoints servicelb -n dev
```

and got:

```text
servicelb   10.244.0.4:80
```

This is important.

It means:

```text
Service
   ↓
Pod
10.244.0.4:80
```

The Service has successfully discovered the Pod.

You may see a warning:

```text
v1 Endpoints is deprecated
```

This is because newer Kubernetes versions prefer EndpointSlice.

You can use:

```bash
kubectl get endpointslice -n dev
```

for the modern API.

---

# 15. Pod IP vs Service IP vs NodePort

These addresses have different purposes.

## Pod IP

Example:

```text
10.244.0.4
```

This is the Pod's IP.

It is part of the Kubernetes/Minikube Pod network.

It is NOT a public IP.

---

## Service ClusterIP

Example:

```text
10.108.115.97
```

This is the Service's internal virtual IP.

It is used to reach the Service from within the Kubernetes cluster.

It is NOT a public IP.

---

## NodePort

Our Service showed something like:

```text
80:32146/TCP
```

This means:

```text
Service port = 80
NodePort     = 32146
```

Minikube can provide a URL such as:

```text
http://192.168.49.2:32146
```

Here:

```text
192.168.49.2
```

is a private Minikube/node IP.

It is NOT a public IP.

And:

```text
32146
```

is the NodePort.

---

# 16. Why `curl http://10.244.0.4` Didn't Work

We tried:

```bash
curl http://10.244.0.4
```

from the EC2 host.

That may not work because:

```text
10.244.0.4
```

belongs to the Minikube Pod network.

The EC2 host is outside that Pod network.

A better test is to test from inside Kubernetes.

For example:

```bash
kubectl run testcurl \
  -n dev \
  --rm \
  -it \
  --image=curlimages/curl \
  -- sh
```

Then:

```bash
curl http://10.244.0.4
```

Or, preferably, test the Service:

```bash
curl http://servicelb.dev.svc.cluster.local
```

That tests:

```text
testcurl Pod
      ↓
Service
      ↓
Nginx Pod
```

---

# 17. Minikube `LoadBalancer` vs AWS LoadBalancer

This was another major learning point.

## AWS/KOPS/EKS

On a cloud-integrated Kubernetes cluster:

```text
Internet
    ↓
AWS Load Balancer
    ↓
Kubernetes Service
    ↓
Pod
```

AWS can provision a real Load Balancer.

You may get a DNS name like:

```text
xxxxx.elb.amazonaws.com
```

That can be Internet-facing, depending on the configuration.

---

# 18. Minikube

Our environment is:

```text
AWS EC2
   ↓
Minikube
   ↓
Kubernetes
```

When we create:

```yaml
type: LoadBalancer
```

Minikube does NOT automatically create an AWS ELB.

Therefore we should NOT expect:

```text
xxxxx.elb.amazonaws.com
```

just because the Service type is `LoadBalancer`.

Minikube has its own mechanisms for accessing Services.

---

# 19. `minikube tunnel`

We used:

```bash
minikube tunnel
```

This helps Minikube provide connectivity for `LoadBalancer` Services.

But:

> `minikube tunnel` does NOT create an AWS Elastic Load Balancer.

It is a Minikube-specific mechanism.

Therefore it should not be confused with:

```text
AWS Load Balancer
+
AWS public DNS
```

---

# 20. `minikube service`

We also used:

```bash
minikube service servicelb -n dev --url
```

It returned something similar to:

```text
http://192.168.49.2:32146
```

This is essentially an access path through the Minikube node/NodePort.

Conceptually:

```text
192.168.49.2:32146
          ↓
      Service :80
          ↓
      Pod :80
```

Again:

```text
192.168.49.2
```

is private, not a public Internet IP.

---

# 21. Service Type Recommendation for Minikube

For normal Minikube practice:

## ClusterIP

Use when you want internal Kubernetes communication.

```yaml
type: ClusterIP
```

Good for:

```text
Pod → Service → Pod
```

This is the default Service type.

---

## NodePort

Use when you want to practice external access in Minikube.

```yaml
type: NodePort
```

This is often the easiest option for a Minikube lab.

Conceptually:

```text
Client
   ↓
Minikube Node IP:NodePort
   ↓
Service
   ↓
Pod
```

---

## LoadBalancer

Use it when specifically learning LoadBalancer behavior.

```yaml
type: LoadBalancer
```

It is useful to understand the Kubernetes concept, but don't expect Minikube to automatically create an AWS ELB.

---

# 22. Recommended Learning Order

A good progression is:

```text
1. Pod
   ↓
2. ClusterIP Service
   ↓
3. NodePort Service
   ↓
4. LoadBalancer Service on Minikube
   ↓
5. LoadBalancer Service on AWS/EKS/KOPS
```

This makes the networking concepts much easier to understand.

---

# 23. Useful Debugging Commands

## Check Pods

```bash
kubectl get pods -n dev -o wide
```

## Detailed Pod information

```bash
kubectl describe pod mypod -n dev
```

## Pod logs

```bash
kubectl logs mypod -n dev
```

## Check Services

```bash
kubectl get svc -n dev
```

## Detailed Service information

```bash
kubectl describe svc servicelb -n dev
```

## Check Service endpoints

```bash
kubectl get endpoints servicelb -n dev
```

Modern alternative:

```bash
kubectl get endpointslice -n dev
```

## Check Secrets

```bash
kubectl get secrets -n dev
```

## Check a specific Secret

```bash
kubectl get secret dockerCred -n dev
```

## Watch Pod status

```bash
kubectl get pods -n dev -w
```

## Get Minikube service URL

```bash
minikube service servicelb -n dev --url
```

## Start Minikube tunnel

```bash
minikube tunnel
```

---

# 24. Final Mental Model

Remember these four things:

```text
10.244.0.4
    ↓
Pod IP
    ↓
Internal Pod network
```

```text
10.x.x.x
    ↓
ClusterIP
    ↓
Internal Service
```

```text
32146
    ↓
NodePort
    ↓
Port exposed by the Kubernetes node
```

```text
xxxxx.elb.amazonaws.com
    ↓
AWS Load Balancer DNS
    ↓
Actual cloud load balancer
```

And the most important distinction:

```text
Private Docker image
       ↓
imagePullSecrets
       ↓
Kubernetes can authenticate to registry
       ↓
Pod starts
```

---

# 25. Final Working Flow

Your project ultimately works like this:

```text
                 Docker Hub
                    🔒
                    |
                    | krishnapavan007/pvt:img1
                    ↓
              Private Registry
                    ↑
                    |
              dockerCred Secret
                    ↑
                    |
             imagePullSecrets
                    ↑
                    |
                 Pod spec
                    |
                    ↓
                Minikube
                    |
                    ↓
              Nginx Pod
             10.244.0.4:80
                    ↑
                    |
                 Service
                  :80
                    |
             NodePort 32146
                    |
                    ↓
          Minikube access path
```

## The core lesson

The original goal was simply:

> **Pull a private Docker Hub image and run it as a Kubernetes Pod.**

The critical pieces required were:

1. Private image exists in Docker Hub.
2. Create a `docker-registry` Secret.
3. Secret must be in the same namespace as the Pod.
4. Pod must use `imagePullSecrets`.
5. The image name/tag must be correct.
6. If changing immutable Pod fields, delete and recreate the Pod.
7. A Service needs a matching Pod label/selector.
8. An Endpoint confirms that the Service found the Pod.
9. Minikube does not automatically create an AWS ELB/DNS name.
10. `ClusterIP`, `NodePort`, and `LoadBalancer` are Service types whose external behavior depends on the Kubernetes environment.

This gives you a reusable reference for the entire lab.

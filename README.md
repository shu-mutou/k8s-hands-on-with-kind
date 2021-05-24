Kubernetes sandbox
==================

## Setup

### 1. Use official kind

* Run `get-kind.sh [-i <kind version>] [-n <kindest/node version>]`
  + Download specified version of `kind` and latest version of `kubectl`.
  + Then, copy them as `kind-[version]` and `kubectl-[latest version]` into `tools` directory.
  + Also, create symbolic links `kind` for specified version of `kind` and `kubectl` for `kubectl-[latest version]` into `tools` directory.
  + Furthermore, create config file for `kind` with specified version of `kindest/node` image, i.e. kubernetes version, as `./tmp/kind.yaml`.
* Options:
  + Specify `kind` version and `kindest/node` version with hash from [release site for kind](https://github.com/kubernetes-sigs/kind/releases)
  + kind version
    - Default: `v0.11.0`
  + kindest/node version
    - Default: `kindest/node:v1.21.1@sha256:fae9a58f17f18f06aeac9772ca8b5ac680ebbed985e266f711d936e91d113bad`

### 1'. Use custom kind (optional)

* Clone `kind` source code with `git clone https://github.com/kubernetes-sigs/kind`.
* Change code and commit them into your specified branch.
* Run `build-kind.sh [-s <source code directory>] [-b <branch>] [-n <kindest/node version>]`
  + Build `kind` from source code.
  + Then, copy it as `kind-[branch]` into `tools` directory.
  + Also, create symbolic link `kind` for `kind-[branch]` into `tools` directory.
* Options
  + branch
    - Default: `master`
  + kind source directory
    - Default: `${GOPATH}/src/github.com/kubernetes-sigs/kind`
  + kindest/node version
    - Specify applicable version of `kindest/node` for your `kind` branch with hash from [release site for kind](https://github.com/kubernetes-sigs/kind/releases).
    - Default: `kindest/node:v1.21.1@sha256:fae9a58f17f18f06aeac9772ca8b5ac680ebbed985e266f711d936e91d113bad`

### 2. Use custom Kubernetes (optional)

NOTE: Kubernetes v1.21.0 or later needs `docker buildx` to build. And `docker buildx` needs `docker ce` v19.03 or later. In ubuntu 20.04, the version of docker is v19.03.x but not enabled `buildx`. If so, setup `buildx` as followings.

```
mkdir -p ${HOME}/.docker/cli-plugins
wget -nc -O ${HOME}/.docker/cli-plugins/docker-buildx https://github.com/docker/buildx/releases/download/v0.5.1/buildx-v0.5.1.linux-amd64`
chmod +x ${HOME}/.docker/cli-plugins/docker-buildx
```

Also, create `${HOME}/.docker/config.json` add `{"experimental": "enabled"}` into it. 

* Clone `kubernetes` source code with `git clone https://github.com/kubernetes/kubernetes`.
* Change code and commit them into your specified branch.
* Run `build-node-image.sh [-s <source code directory>] [-b <branch>]`
  + Build all of `kubernetes` components from kubernetes source code.
  + Then, build kubernetes container image for `kind` node as `kindest/node:[branch]` into local docker host.
  + Also, copy built `kubectl` to `kubectl-[branch]` in `tools` directory.
  + Furthermore, create symbolic link `kubectl` for `kubectl-[branch]` into `tools` directory.
* Options
  + branch
    - Default: `master`
  + kubernetes source directory
    - Default: `${GOPATH}/src/github.com/kubernetes/kubernetes`

## Run Kubernetes with kind

* Run `./run-kind.sh [-c <kind config file>] [-x]`
  + Create `kubernetes` cluster with specified version of `kind` and `kindest/node`.
  + Also, create `./kubectl.sh` as alias of symbolic link `kubectl` that run with `kubeconfig` for created cluster.
* Options:
  + kind config
    - Config for kind cluster.
    - Default: `./tmp/kind.yaml`
  + x
    - Ignore deploying Kubernetes Dashboard
    - Default: deploying Kubernetes Dashboard

## Exercise 1 - enough for common application developer

* Deploy nginx
  ```
  ./kubectl.sh create deployment nginx --image=nginx:1.15 --port=80
  ```
  Confirm with following:
  ```
  ./kubectl.sh get deploy,pod
  ```
* Expose nginx
  ```
  ./kubectl.sh expose deployment nginx --type=NodePort --port=80 -oyaml --dry-run=client > tmp/nginx.svc.yaml
  ```
  Add `nodePort: 30001` under `ports` in `tmp/nginx.svc.yaml`, then run following:
  ```
  ./kubectl.sh apply -f tmp/nginx.svc.yaml
  ```
  Confirm with following:
  ```
  ./kubectl.sh get svc -owide
  ```
* Access nginx with browser `http://localhost:30001`
* Create PersistentVolume and PersistentVolumeClaim.
  ```
  mkdir -p volume/nginx
  ./kubectl.sh apply -f example/pv.yaml
  ./kubectl.sh apply -f example/pvc.yaml
  ```
  Confirm with following:
  ```
  ./kubectl.sh get pv,pvc
  ```
* Use PersistentVolumeClaim for web root directory in nginx deployment.
  ```
  ./kubectl.sh get deployment nginx -oyaml > tmp/nginx.deploy.yaml
  ```
  Add followings:
  ```
  .....
  spec:
    .....
    template:
      .....
      spec:
        .....
        containers:
          .....
          volumeMounts:
          - mountPath: "/usr/share/nginx/html"
            name: nginx-volume
        volumes:
        - name: nginx-volume
          persistentVolumeClaim:
            claimName: nginx-pvc
  .....
  ```
  Then run following:
  ```
  ./kubectl.sh apply -f tmp/nginx.deploy.yaml
  ```
  Confirm with following:
  ```
  ./kubectl.sh get pv,pvc,pod
  ```
* Add `volume/nginx/index.html`.
  ```
  echo "Hello!" > volume/nginx/index.html
  ```
  Then confirm `http://localhost:30001` via browser.

## Exercise 2 - required for CKAD

* Scheduling pods for Ingress controller.
  Confirm current labels attached in nodes.
  ```
  ./kubectl.sh get nodes --show-labels
  ```
  Set label into control-plane node for Ingress controller.
  ```
  ./kubectl.sh label nodes kind-cluster-control-plane ingress-ready='true'
  ```
  Note: `ingress-ready='true'` is used in the following manifest for `ingress-nginx-controller`. The pod for Ingress controller will be scheduled by this label.
  Confirm labels added in control-plane nodes.
  ```
  ./kubectl.sh get nodes kind-cluster-control-plane --show-labels
  ```
* Install Ingress NGINX Controller
  ```
  wget -nc -O tmp/ingress-nginx-controller.yaml https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml
  ```
  And add `nodePort: 30080` and `nodePort: 30443` into `ingress-nginx-controller` Service.
  Then install it:
  ```
  ./kubectl.sh apply -f tmp/ingress-nginx-controller.yaml
  ```
* Create Ingress for nginx Service via nginx-ingress-controller and modify nginx Service.
  See [`example/nginx-ingress.yaml`](example/nginx-ingress.yaml), create `test/` directory for Ingress `nginx-ingress`, and create `index.html` file into it.
  ```
  mkdir -p volume/nginx/test
  echo "Here is /test/ via Ingress" > volume/nginx/test/index.html
  ```
  Then run following:
  ```
  ./kubectl.sh apply -f example/nginx-ingress.yaml
  ```
* Access nginx `http://localhost:30080/test/` via Ingress.

_TBD_

* Rollout deployment
  + Update image
  + History
  + Restart
  + Undo

## References for kind

* [Configure file for kind](https://kind.sigs.k8s.io/docs/user/configuration/)
  + [Configure directory for Persistent Volume](https://kind.sigs.k8s.io/docs/user/configuration/#extra-mounts)
  + [Configure port for NodePort](https://kind.sigs.k8s.io/docs/user/configuration/#extra-port-mappings)
* [Ingress NGINX](https://kind.sigs.k8s.io/docs/user/ingress#ingress-nginx)
* [LoadBalancer with metallb](https://kind.sigs.k8s.io/docs/user/loadbalancer/)

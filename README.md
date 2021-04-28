Kubernetes sandbox
==================

## With kind

* Run `./run-kind.sh`. It downloads `kind` and `kubectl`, then create Kubernetes cluster.

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
  See `example/nginx-ingress.yaml`, create `test/` directory for Ingress `nginx-ingress`, and create `index.html` file into it.
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

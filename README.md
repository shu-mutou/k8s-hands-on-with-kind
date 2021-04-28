Kubernetes sandbox
==================

## With kind

* Run `./run-kind.sh`. It downloads `kind` and `kubectl`, then create Kubernetes cluster.

## Exercise 1

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
* Add `volume/nginx/index.html` and confirm `http://localhost:30001` via browser.

## Exercise 2

_TBD_

* Create Ingress using nginx-ingress-controller.
* Access nginx via Ingress.

## Exercise 3

_TBD_

* Scheduling pods.

## References for kind

* [Configure file for kind](https://kind.sigs.k8s.io/docs/user/configuration/)
  + [Configure directory for Persistent Volume](https://kind.sigs.k8s.io/docs/user/configuration/#extra-mounts)
  + [Configure port for NodePort](https://kind.sigs.k8s.io/docs/user/configuration/#extra-port-mappings)
* [LoadBalancer with metallb](https://kind.sigs.k8s.io/docs/user/loadbalancer/)

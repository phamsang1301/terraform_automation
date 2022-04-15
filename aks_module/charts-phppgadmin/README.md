# phpPgAdmin
This is a Helm chart that deploys a phpPgAdmin instance to your Kubernetes cluster.

## Prerequisites
This install assumes you have an existing Kubernetes cluster installed and a [postgresql](https://github.com/kubernetes/charts/tree/master/stable/postgresql) instance deployed.

## Package
Once you've cloned this repo, you can create your helm package by running the following command in the repo's root directory:
```
helm package .
```

## Install
You now need to grab the ClusterIP of your PostgreSQL service.
```
kubectl get svc 
```
Filter through the list of services and grab the ClusterIP associated with your PostgreSQL service. Next you can install phpPgAdmin into your Kubernetes cluster by targeting your packaged archive:
```
helm install --set phppgadmin.serverHost={postgresql-clusterip},phppgadmin.serverPost={postgresql-port} phppgadmin-chart-0.1.0.tgz
```
The deployment will take a little while to provision a public IP for the service. You can watch for this using the following command:
```
kubectl get svc -w -l app=phppgadmin-chart
```

## Configure
When the deployment has finished and you have an external IP for your phpPgAdmin service, you can go to the phpPgAdmin web portal at `http://{phpPgAdmin-externalip}:8080/`.

Once web portal has loaded, you'll need to authenticate a new connection to your PostgreSQL database by clicking on the `Servers` tab.

## Ingress
The default behaviour of this helm chart is to create a new load balancer service.

If you have an ingress controller deployed and would rather use ingress, you need to enable it in the `values.yaml` file.
You will need to also provide values for hostname and configure a TLS secret or leverage Let's Encrypt using [Kube-Lego](https://github.com/jetstack/kube-lego). Once configured, change the `service.type` value to `ClusterIP`.

Assuming the `host` header is correct in your HTTP request, you can hit the external ip of the ingress controller and it should route to your phppgadmin instance.

![image](https://user-images.githubusercontent.com/98753976/162679572-a87c8f6c-afb7-4b95-930b-ff946e681f5e.png)

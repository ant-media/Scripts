# Ant Media Server 

Ant Media Server Helm chart for Kubernetes

## Introduction
Ant Media Server installs the following
- Edge/Origin pods
- MongoDB 
- Ingress

## Prerequisites
- Kubernetes >= 1.23
- Helm v3
- cert-manager

## Installing the Chart
Add the AMS repository to Helm:
```shell script
helm repo add eks https://ant-media.github.io/Scripts/helm
helm update
helm install antmedia --set origin={origin}.{example.com} --set edge={edge}.{example.com}
```

## Installing SSL 
If you are going to use Let's Encrypt, you should create your DNS records according to the ingress IP addresses in the `kubectl get ingress` output after installation and follow the document below.

https://resources.antmedia.io/docs/ams-kubernetes-deployment#-to-install-an-ssl-certificate

## Upgrade
The old installation must be uninstalled completely before installing the new version.

## Uninstalling the Chart
```sh
helm delete antmedia 
```

## Parameters

| Parameter                               | Description                                                                                              | Default                                                                            |
|------------------------------------------------| -------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| `image`                                        | image repository                                                                                         | `antmedia/enterprise:latest` |
| `origin`                                       | Domain name of Origin server                                                                             | `{}`                                                                        |
| `edge`                                         | Domain name of Edge server                                                                               | `{}`                                                                     |
| `hostNetwork`                                  | If `false`, use turn server                                                                              | `true`                                                                            |
| `mongodb`                                      | MongoDB host                                                                                             | `mongo`                                                                     |
| `autoscalingOrigin.targetCPUUtilizationPercentage`                            | Target CPU utilization percentage for autoscaler for Origin                                                                          | `60`                                                                               |
| `autoscalingOrigin.minReplicas`                                 | Minimum number of deployment replicas for the compute container.                                                                                | `1`                                                                               |
| `autoscalingOrigin.maxReplicas`                                  | Maximum number of deployment replicas for the compute container.                                    | `10`                                                                               |
| `autoscalingEdge.targetCPUUtilizationPercentage`                                 | Target CPU utilization percentage for autoscaler for Edge                         | `60`                                                                                |
| `autoscalingEdge.minReplicas`                          | Minimum number of deployment replicas for the compute container.     | `1`                                                                               |
| `autoscalingEdge.maxReplicas`                               | Maximum number of deployment replicas for the compute container.                                                         | `10`                                                                               |



## Example Usage
```
helm install antmedia --set origin=origin.antmedia.io --set edge=edge.antmedia.io --set autoscalingEdge.targetCPUUtilizationPercentage=20 --set autoscalingEdge.minReplicas=2

```



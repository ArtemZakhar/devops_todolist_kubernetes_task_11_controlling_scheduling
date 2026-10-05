#!/bin/bash

kind create cluster --config cluster.yml

kubectl apply -f .infrastructure/mysql/ns.yml
kubectl apply -f .infrastructure/mysql/configMap.yml
kubectl apply -f .infrastructure/mysql/secret.yml
kubectl apply -f .infrastructure/mysql/service.yml

kubectl taint nodes -l app=mysql app=mysql:NoSchedule --overwrite

kubectl apply -f .infrastructure/mysql/statefulSet.yml
kubectl wait --for=condition=Ready pod/mysql-0 -n mysql --timeout=300s

kubectl apply -f .infrastructure/app/ns.yml
kubectl apply -f .infrastructure/app/pv.yml
kubectl apply -f .infrastructure/app/pvc.yml
kubectl apply -f .infrastructure/app/secret.yml
kubectl apply -f .infrastructure/app/configMap.yml
kubectl apply -f .infrastructure/app/clusterIp.yml
kubectl apply -f .infrastructure/app/deployment.yml
kubectl apply -f .infrastructure/app/hpa.yml

kubectl wait --for=condition=Available deployment/todoapp -n todoapp --timeout=300s

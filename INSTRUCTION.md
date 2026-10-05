# Task 11: Node labels, taints, and scheduling

## Prerequisites

- Docker, [kind](https://kind.sigs.k8s.io/), `kubectl`

## Cluster layout (`cluster.yml`)

- **1** control-plane node (no `app` label for scheduling tasks)
- **2** workers with label **`app=mysql`**
- **3** workers with label **`app=todoapp`**
- **1** worker without `app` label

Re-create cluster before each full run:

```bash
kind delete cluster --name kind
chmod +x bootstrap.sh
./bootstrap.sh
```

## What `bootstrap.sh` does

1. `kind create cluster --config cluster.yml`
2. Deploy MySQL (namespace, ConfigMap, Secret, Service)
3. **Taint** nodes with `app=mysql`: `app=mysql:NoSchedule`
4. Deploy **StatefulSet** (tolerations + affinity) and wait for `mysql-0`
5. Deploy **todoapp** (Deployment + HPA) and wait until Available

## 1. Inspect node labels and taints

```bash
kubectl get nodes -L app
kubectl get nodes -l app=mysql -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
kubectl describe node -l app=mysql | grep -E 'Name:|Labels:|Taints:'
kubectl describe node -l app=todoapp | grep -E 'Name:|Labels:'
```

On `app=mysql` nodes you should see taint **`app=mysql:NoSchedule`**.

## 2. Validate MySQL StatefulSet scheduling

```bash
kubectl get pods -n mysql -o wide
kubectl get statefulset mysql -n mysql
```

Expected:

- Pods run only on nodes with **`app=mysql`** (node affinity **required**).
- **Two** MySQL pods (`replicas: 2`) on **different** nodes (pod anti-affinity on `app=mysql`, `topologyKey: kubernetes.io/hostname`).
- Pods tolerate taint `app=mysql:NoSchedule`.

Check affinity/tolerations on a pod:

```bash
kubectl get pod mysql-0 -n mysql -o yaml | grep -A40 affinity
kubectl get pod mysql-0 -n mysql -o yaml | grep -A10 tolerations
```

## 3. Validate todoapp Deployment scheduling

```bash
kubectl get pods -n todoapp -l app=todoapp -o wide
```

Expected:

- Pods **prefer** nodes with **`app=todoapp`** (`preferredDuringSchedulingIgnoredDuringExecution`, weight 100).
- With HPA `minReplicas: 2`, two todoapp pods should land on **different** nodes when possible (pod anti-affinity **required** on `app=todoapp`).

Describe scheduling for one pod:

```bash
POD=$(kubectl get pods -n todoapp -l app=todoapp -o jsonpath='{.items[0].metadata.name}')
kubectl get pod "$POD" -n todoapp -o yaml | grep -A30 affinity
```

## 4. Application health (optional)

```bash
kubectl port-forward -n todoapp service/todoapp-service 8080:80
curl -sS http://127.0.0.1:8080/api/health
```

## Troubleshooting

| Symptom | Check |
|---------|--------|
| MySQL pods Pending | Taint without toleration, or no free `app=mysql` nodes |
| Two MySQL on one node | Fix pod anti-affinity list + `matchLabels` |
| todoapp Pending | Not enough nodes for anti-affinity (need ≥2 `app=todoapp` workers for 2 replicas) |
| Taint command fails | Cluster not created or nodes not labeled yet |

## Clean up

```bash
kind delete cluster --name kind
```

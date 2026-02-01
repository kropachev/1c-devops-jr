# Подключение Kubernetes для агентов

Jenkins создает временные Pod-ы агентов через Kubernetes API.

## Подготовка рабочей директории

Все манифесты и файлы, относящиеся к Jenkins и агентам, храним в одном месте.

```bash
mkdir -p /k3s-1c-ci/jenkins/agents
cd /k3s-1c-ci/jenkins/agents
```

Если права на `/k3s-1c-ci` еще не настраивались:

```bash
sudo chgrp -R k3s /k3s-1c-ci
sudo chmod -R 2775 /k3s-1c-ci
```

## Создаем отдельный namespace для Jenkins-агентов

```bash
kubectl create namespace jenkins-agents --dry-run=client -o yaml | kubectl apply -f -
```

Проверка:
```bash
kubectl get namespace jenkins-agents
```
## Создаем секрет с учетными данными для доступа к registry

Агенты - это временные Pod-ы запускать их будем в отдельном namespace.

```bash
kubectl -n jenkins-agents create secret docker-registry registry-auth \
  --docker-server=registry.onecci.lan \
  --docker-username=registryusr \
  --docker-password='registrypass'
```

Проверка:
```bash
kubectl -n jenkins-agents get secret registry-auth
```


## ServiceAccount для Jenkins-агентов

Jenkins Kubernetes plugin работает от имени ServiceAccount, указанного в Pod Template.

Создаем файл `sa-jenkins-agent.yaml`
```bash
nano sa-jenkins-agent.yaml
```

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins-agent
  namespace: jenkins-agents
imagePullSecrets:
  - name: registry-auth
```

Применяем:

```bash
kubectl apply -f sa-jenkins-agent.yaml
```

## Права для создания и управления Pod-ами (RBAC)

Настройка прав, чтобы Jenkins мог создавать агентов.

### Role (права внутри namespace)

Создаем файл `role-jenkins-agent.yaml`:

```bash
nano role-jenkins-agent.yaml
```

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: jenkins-agent-role
  namespace: jenkins-agents
rules:
  - apiGroups: [""]
    resources:
      - pods
      - pods/log
      - pods/exec
      - events
      - configmaps
      - secrets
    verbs:
      - get
      - list
      - watch
      - create
      - delete
      - patch
      - update
```

> Примечание: `configmaps` и `secrets` нужны, если ты монтируешь их в агентские Pod-ы. Если нет - можно позже ужесточить.

### RoleBinding

Создаем файл `rb-jenkins-agent.yaml`:

```bash
nano rb-jenkins-agent.yaml
```

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: jenkins-agent-rb
  namespace: jenkins-agents
subjects:
  - kind: ServiceAccount
    name: jenkins-agent
    namespace: jenkins-agents
roleRef:
  kind: Role
  name: jenkins-agent-role
  apiGroup: rbac.authorization.k8s.io
```

Применяем все RBAC-манифесты:

```bash
kubectl apply -f role-jenkins-agent.yaml
kubectl apply -f rb-jenkins-agent.yaml
```

Проверка:

```bash
kubectl -n jenkins-agents get sa
kubectl -n jenkins-agents get role,rolebinding
```

## Добавление CA-сертификата

Корневой CA-сертификат хранится централизованно и используется всеми клиентами,
которые обращаются к сервисам `*.onecci.lan` по HTTPS.

Создаем - **ConfigMap** (CA не является секретом). ConfigMap создается **в каждом namespace**, где есть клиенты (Jenkins, CI-агенты и т.д.).

```bash
kubectl create configmap onecci-root-ca \
  --from-file=onecci-root-ca.crt=/k3s-1c-ci/tls/onecci-root-ca.crt \
  -n jenkins-agents 
```

## Jenkins: добавляем Kubernetes Cloud

```
Manage Jenkins - Nodes and Clouds - Configure Clouds
```

### Add a new cloud - Kubernetes

**Минимальная конфигурация:**

| Поле | Значение |
| - | - |
| Kubernetes URL | `https://kubernetes.default.svc.cluster.local` |
| Kubernetes Namespace | `jenkins-agents` |
| Credentials | `- none -` |
| Jenkins URL | `https://jenkins.onecci.lan` |


Жмем **Test Connection** - должно быть успешно.

В Kubernetes URL мы указали kubernetes.default.svc - это встроенный Service Kubernetes, который всегда указывает на API-server текущего кластера. Мы указываем это значение, потому что Jenkins развернут внутри этого же k3s-кластера и может обращаться к Kubernetes API по внутреннему DNS-имени.

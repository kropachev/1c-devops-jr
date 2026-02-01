# Установка Docker Registry

Для работы пайплайна нам понадобятся **образы агентов 1C**, которые будут запускаться внутри кластера k3s. По лицензионным ограничениям образы 1С, содержащие платформу 1С или связанные с ней компоненты **нельзя распространять публично**. Это значит мы не можем создать образ и загрузить его в публичный докерхаб. Решением будет **локальный Docker Registry**.

Разворачиваем Docker Registry в k3s с доступом по HTTPS, аутентификацией и постоянным хранилищем данных.

Мы получим:
- Доступ по имени `registry.onecci.lan`
- HTTPS с сертификатом (Kubernetes TLS Secret)
- Аутентификация по логину/паролю (basic auth через htpasswd)
- Данные образов в PersistentVolume (PVC)

## Подготовка рабочей директории

Все манифесты и файлы будем хранить на сервере в одном месте.
```bash
mkdir -p /k3s-1c-ci/registry
cd /k3s-1c-ci/registry
```

## Namespace

Создаем namespace
```bash
kubectl create namespace registry --dry-run=client -o yaml | kubectl apply -f -
```

Проверка:
```bash
kubectl get ns registry
```
## Настройка доверия для containerd (k3s) при работе с registry

Для registry по HTTPS k3s/containerd должен знать, каким CA доверять.

Создаем (или дополняем) файл:
```bash
sudo nano /etc/rancher/k3s/registries.yaml
```

Добавляем конфигурацию (пример для `registry.onecci.lan`):
```yaml
configs:
  "registry.onecci.lan":
    tls:
      ca_file: /etc/ssl/certs/ca-certificates.crt
```

Применяем изменения (перечитывание конфигурации containerd):
```bash
sudo systemctl restart k3s
```

## TLS Secret из сертификата

Команда создает Secret или обновляет, если, например, был перевыпущен сертификат:
```bash
kubectl create secret tls onecci.lan.tls \
  --cert=/k3s-1c-ci/tls/tls.crt \
  --key=/k3s-1c-ci/tls/tls.key \
  -n registry \
  --dry-run=client -o yaml | kubectl apply -f -
```

Проверяем:
```bash
kubectl get secret onecci.lan.tls -n registry
```

## Создаем учетку доступа (basic auth)

Без аутентификации любой, кто видит адрес Registry, сможет пушить и вытягивать образы. 

Генерируем bcrypt прямо в кластере, временным pod’ом.
- `registryusr` - имя пользователя registry
- `registrypass` - пароль;
```bash
kubectl -n registry run htpasswd-gen \
  --image=httpd:2.4-alpine \
  --restart=Never \
  --command -- sh -c "htpasswd -Bbn registryusr registrypass"
```

Выводим результат в файл:
- `htpasswd` - файл, в которых будет записана пара логин и пароль
```bash
kubectl -n registry logs htpasswd-gen > htpasswd
```

Удаляем pod:
```bash
kubectl -n registry delete pod htpasswd-gen
```

Проверяем:
```bash
head -n1 htpasswd
```

Создаем secret `registry-auth`:

```bash
kubectl -n registry create secret generic registry-auth \
  --from-file=htpasswd=./htpasswd \
  --dry-run=client -o yaml | kubectl apply -f -
```

Проверяем секрет
```bash
kubectl -n registry get secret registry-auth
```

## Создаем конфигурацию Registry

Здесь мы  включаем basic auth, задаем путь хранения образов, оставляем Registry слушать HTTP (TLS делает Traefik).

Создаем файл 
```bash
nano registry-config.yml
```
Содержимое:
```yaml
version: 0.1

log:
  # просто метка сервиса в логах
  fields:
    service: registry

storage:
  filesystem:
    # где Registry хранит blobs и manifests
    # это путь внутри контейнера, мы примонтируем сюда PVC
    rootdirectory: /var/lib/registry
  delete:
    enabled: true

http:
  # Registry слушает внутри кластера на 5000/tcp
  addr: :5000

  headers:
    # базовая защита - запрещает браузеру угадывать content-type
    X-Content-Type-Options:
      - nosniff

auth:
  htpasswd:
    # имя realm, которое увидит клиент при запросе логина
    realm: basic-realm

    # путь к файлу htpasswd внутри контейнера
    # мы примонтируем secret registry-auth в /auth
    path: /auth/htpasswd
```

Создаем ConfigMap `registry-config`:
```bash
kubectl -n registry create configmap registry-config \
  --from-file=config.yml=./registry-config.yml \
  --dry-run=client -o yaml | kubectl apply -f -
```

Проверяем:
```bash
kubectl -n registry get configmap registry-config
```

## Создаем PVC для данных Registry

Без PVC данные будут жить в контейнере и потеряются при пересоздании pod

Наш кластер состоит из одного узла и мы будем использовать local-path (k3s default) - данные на локальном диске ноды, просто и быстро.  
При добавлении узлов или переходе в production логика PVC **не меняется**, меняется только `StorageClass` (например, NFS / Longhorn / Ceph).

### PVC манифест (storage по умолчанию для одного узла)

Создаем `pvc.yml`:

```bash
nano pvc.yml
```
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: registry-data
  namespace: registry
spec:
  # ReadWriteOnce - том монтируется на одну ноду и один pod
  # для Registry (replicas: 1) это нормально
  accessModes:
    - ReadWriteOnce

  # storageClassName можно указать явно.
  # если не указывать - будет использован default StorageClass.
  # storageClassName: local-path

  resources:
    requests:
      # сколько места нужно под образы
      storage: 20Gi
```

Пояснение по поводу значения `storage: 20Gi` - это сообщение этому pod можно использовать том размером до 20 GiB, место занимается фактически использованное, а не заявленное. 

Применяем и проверяем:

```bash
kubectl apply -f pvc.yml
kubectl -n registry get pvc registry-data
```

## Создаем Deployment и Service

Deployment описывает, как запускать pod Registry: какой образ, какие порты, какие переменные, какие тома и секреты подключить. Deployment следит, чтобы нужное число pod было запущено (у нас replicas: 1).

Service дает pod стабильный DNS-адрес и порт внутри кластера. Ingress (Traefik) направляет трафик в Service, а не в pod напрямую.

Probes - настройки проверок:
- **livenessProbe** (живой ли контейнер) - Kubernetes перезапустит контейнер, если проверка долго не проходит.

- **readinessProbe** (проверка готовности) - Kubernetes не будет отправлять трафик в pod, пока проверка не проходит.

Создаем файл 
```bash
nano registry.yml
```

Содержимое файла:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: registry
  namespace: registry
spec:
  # Registry обычно запускается в 1 экземпляре, потому что стандартный filesystem storage
  # не рассчитан на многоподовую работу без общего хранилища и блокировок.
  replicas: 1

  selector:
    matchLabels:
      app: registry

  template:
    metadata:
      labels:
        app: registry

    spec:
      containers:
        - name: registry
          image: registry:2

          ports:
            - containerPort: 5000
          volumeMounts:
            # данные Registry (PVC)
            - name: data
              mountPath: /var/lib/registry

            # htpasswd из secret
            - name: auth
              mountPath: /auth
              readOnly: true

            # config.yml из ConfigMap
            - name: config
              mountPath: /etc/docker/registry
              readOnly: true

          livenessProbe:
            tcpSocket:
              port: 5000
            initialDelaySeconds: 10
            periodSeconds: 10

          readinessProbe:
            tcpSocket:
              port: 5000
            initialDelaySeconds: 5
            periodSeconds: 5

      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: registry-data

        - name: auth
          secret:
            secretName: registry-auth

        - name: config
          configMap:
            name: registry-config
---
apiVersion: v1
kind: Service
metadata:
  name: registry
  namespace: registry
spec:
  selector:
    app: registry

  ports:
    - name: http
      port: 5000
      targetPort: 5000
```

Применяем:

```bash
kubectl apply -f registry.yml
```
Проверяем:
```bash
kubectl -n registry get deploy,po,svc
```

## Настройка Ingress

Создаем файл настроек Ingress.
```bash
nano registry-ingress.yaml
```
Пример манифеста:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: registry
  namespace: registry
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  ingressClassName: traefik
  tls:
    - secretName: onecci.lan.tls
      hosts:
        - registry.onecci.lan
  rules:
    - host: registry.onecci.lan
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: registry
                port:
                  number: 5000

```

Применяем манифест и проверяем:

```bash
kubectl apply -f registry-ingress.yaml
kubectl -n registry get ingress
```

## Шаг 9. Проверка доступа по HTTPS

С клиента:

```bash
curl -Ik https://registry.onecci.lan/v2/
```

Ожидаемые варианты:

- `401 Unauthorized` - это нормально, значит TLS работает и Registry требует логин
- ошибки TLS - значит клиент не доверяет сертификату (актуально для самоподписанных)

# Установка Portainer

Portainer - это веб-интерфейс для управления контейнерными средами (в том числе Kubernetes).  
Portainer не нужен для выполнения пайплайна, но в нем удобно смотреть статус подов, логи и т.д.  
На этом шаге мы установим Portainer в кластер k3s через Helm-чарт.

Официальная документация Portainer по установке в Kubernetes:
- Deploy Portainer using Helm Chart: https://portainer.github.io/k8s/charts/portainer/  
- Install Portainer CE on Kubernetes (Bare Metal): https://docs.portainer.io/start/install-ce/server/kubernetes/baremetal

## Подготовка рабочей директории

Создаем папку для конфигов portainer.

```bash
mkdir -p /k3s-1c-ci/portainer
cd /k3s-1c-ci/portainer
```

## Создаем namespace

Namespace (namespace - пространство имен) - это механизм Kubernetes, который логически разделяет ресурсы внутри одного кластера.

```bash
kubectl create namespace portainer --dry-run=client -o yaml | kubectl apply -f -
```

## TLS Secret для Portainer

Создаем TLS Secret в namespace `portainer`:

```bash
kubectl create secret tls onecci.lan.tls \
  --cert=/k3s-1c-ci/tls/tls.crt \
  --key=/k3s-1c-ci/tls/tls.key \
  -n portainer \
  --dry-run=client -o yaml | kubectl apply -f -
```

Проверка:

```bash
kubectl get secret onecci.lan.tls -n portainer
```

## Создаем values.yaml (конфигурация установки)

Описываем установку декларативно через values.yaml.

Создаем файл:

```bash
nano portainer-values.yaml
```

```yaml
image:
  tag: lts

service:
  type: ClusterIP

ingress:
  enabled: true
  ingressClassName: traefik
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
  hosts:
    - host: portainer.onecci.lan
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: onecci.lan.tls

tls:
  force: false
```


## Добавляем репозиторий Portainer

Добавляем официальный репозиторий Portainer для Helm-чарта:

```bash
helm repo add portainer https://portainer.github.io/k8s/
helm repo update
```

## Установка Portainer через Helm

Выполняем команду установки.

```bash
helm upgrade --install portainer portainer/portainer \
  --namespace portainer \
  -f portainer-values.yaml
```
<details>
<summary>⚠️ Ошибка Error: Kubernetes cluster unreachable</summary>

> Здесь может появиться ошибка
> ```bash 
> Error: Kubernetes cluster unreachable: Get "http://localhost:8080/version": dial tcp 127.0.0.1:8080: connect: connection refused
>```
>Эта ошибка почти всегда означает что Helm не видит kubeconfig, поэтому пытается подключиться к “кластеру по >умолчанию” localhost:8080
>Самый простой способ решения указать kubeconfig k3s:
>```bash 
>export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
>kubectl get nodes
>```
>После этого повторите попытку установки.
</details>

## Проверка установки

Проверяем, что поды работают:

```bash
kubectl -n portainer get pods
```
Смотрим колонку **READY**. **0/1**, говорит о том что под запускается, а **1/1** означает что сервис готов и можно его использовать.

Проверяем сервис (тип ClusterIP):

```bash
kubectl -n portainer get svc
```

## Первый запуск

Portainer будет доступен по доменному имени через Traefik Ingress.  
Откройте в браузере:
```text
https://portainer.onecci.lan
```

> ⚠️ Важно! Если не успеть открыть страницу Portainer за 5 минут, Portainer заблокирует UI до перезапуска, при открытии страницы будет выдаваться ошибка `Your Portainer instance timed out for security purposes. To re-enable your Portainer instance, you will need to restart Portainer.` Решается просто - перезапуском командой `kubectl -n portainer rollout restart deployment/portainer`.

После создания пароля отображается мастер первоначальной настройки (Environment Wizard).

Portainer запущен внутри кластера k3s, поэтому он автоматически обнаружил локальное Kubernetes-окружение.  
Это подтверждается сообщением на экране:

```text
We have connected your local environment of Kubernetes to Portainer.
```

На экране мастера отображаются две кнопки:

**Get Started**
Использовать локальный Kubernetes-кластер, в котором запущен Portainer (наш k3s).

**Add Environments**
Подключение дополнительных окружений (другие Kubernetes-кластеры, Docker, Swarm и т.д.).

Для текущего сценария выбираем **Get Started** - локальный кластер.

Готово.
# Установка GitLab

## Подготовка рабочей директории

Создаем директорию для манифестов и конфигурационных файлов.
```bash
mkdir -p /k3s-1c-ci/gitlab
cd /k3s-1c-ci/gitlab
```

## Создаем namespace

```bash
kubectl create namespace gitlab --dry-run=client -o yaml | kubectl apply -f -
```

## TLS Secret из сертификата

Команда создает Secret или обновляет, если, например, был перевыпущен сертификат:
```bash
kubectl create secret tls onecci.lan.tls \
  --cert=/k3s-1c-ci/tls/tls.crt \
  --key=/k3s-1c-ci/tls/tls.key \
  -n gitlab \
  --dry-run=client -o yaml | kubectl apply -f -
```

Проверяем:
```bash
kubectl get secret onecci.lan.tls -n gitlab
```

## Фиксируем SSH host keys как Kubernetes Secrets

Это нужно, чтобы при пересоздании подов SSH fingerprint GitLab не менялся (иначе клиенты будут ругаться на MITM)

```bash
mkdir -p hostKeys
```
```bash
ssh-keygen -t rsa     -f hostKeys/ssh_host_rsa_key     -N ""
ssh-keygen -t ecdsa   -f hostKeys/ssh_host_ecdsa_key   -N ""
ssh-keygen -t ed25519 -f hostKeys/ssh_host_ed25519_key -N ""
```
```bash
kubectl -n gitlab create secret generic gitlab-gitlab-shell-host-keys \
  --from-file hostKeys \
  --dry-run=client -o yaml | kubectl apply -f -
```

## Настраиваем Traefik для SSH (TCP) порта GitLab

Traefik нужно открыть порт для GitLab Shell (SSH daemon). На реальном узле k3s порт 22 может быть занят системным SSH, поэтому делаем порт 2222.

### Добавляем HelmChartConfig для Traefik в k3s

В k3s любой манифест в `/var/lib/rancher/k3s/server/manifests` будет автоматически применяться.

Создаем файл:

```bash
sudo nano /var/lib/rancher/k3s/server/manifests/traefik-config-gitlab-ssh.yaml
```

```yaml
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    ports:
      gitlab-shell:
        expose:
            default: true
        port: 2222
        exposedPort: 2222
        protocol: TCP
```

Проверка, что Traefik применил конфиг:

```bash
kubectl -n kube-system get pods -l app.kubernetes.io/name=traefik
kubectl -n kube-system get svc traefik
```
В колонке `POT(S)` должен появиться порт `2222`.

### Создаем IngressRouteTCP для GitLab SSH

Проверяем группу CRD для apiVersion.
```bash
kubectl get crd | grep -i ingressroutetcp
```
- ingressroutetcps.traefik.io - apiVersion: traefik.io/v1alpha1  
- ingressroutetcps.traefik.containo.us - apiVersion: traefik.containo.us/v1alpha1  

Создаем файл настроек
```bash
nano gitlab-ssh-ingressroutetcp.yaml
```
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRouteTCP
metadata:
  name: gitlab-ssh
  namespace: gitlab
spec:
  entryPoints:
    - gitlab-shell
  routes:
    - match: HostSNI(`*`)
      services:
        - name: gitlab-gitlab-shell
          port: 2222
```

Применяем
```bash
kubectl apply -f gitlab-ssh-ingressroutetcp.yaml
```

Проверяем
```bash
kubectl -n gitlab get ingressroutetcp
kubectl -n gitlab describe ingressroutetcp gitlab-ssh
```

## Готовим values.yaml для GitLab Helm Chart

Создаем файл 
```bash
nano gitlab-values.yaml
```
```yaml
global:
  edition: ce

  hosts:
    domain: onecci.lan
    https: true

  ingress:
    class: traefik
    tls:
      secretName: onecci.lan.tls
    configureCertmanager: false

  shell:
    port: 2222

  registry:
    enabled: false

gitlab:
  webservice:
    resources:
      requests:
        memory: "1.5Gi"
        cpu: "500m"
    minReplicas: 1
    maxReplicas: 1
  
  sidekiq:
    resources:
      requests:
        memory: "1Gi"
        cpu: "500m"
    minReplicas: 1
    maxReplicas: 1

gitlab-runner:
  install: false

nginx-ingress:
  enabled: false

registry:
  enabled: false

installCertmanager: false
```

На что обратить внимание

- **global.edition: ce** - устанавливать community edition
- **global.hosts.domain** - используемый домен
- **global.ingress.class: traefik** - gitlab может попытаться использовать nginx-ingress
- **global.ingress.tls.secretName** - ранее мы создавали tls секрет, посмотреть можно командой `kubectl get secret -n <namespace>`
- **global.ingress.configureCertmanager: false** - не пытаться автоматически выпускать сертификат, использовать то что есть.
- **global.shell.port** - фиксирует ssh порт (мы настраивали 2222)
- **global.registry.enabled: true** - включает GitLab Container Registry
- **gitlab.webservice.resources.requests** - (опционально) минимальное количество ресурсов необходимое для запуска. По-умолчанию webservice запускается в двух экземплярах и просит по 2,5 гигабайт оперативки. Расточительно для хоумлаба.
- **gitlab.webservice.minReplicas/maxReplicas** -  (опционально) количество запускаемых экземпляров. Для хоумлаба ставим 1 (по-умполчанию 2).
- **gitlab.sidekiq.resources.requests** - (опционально) аналогичная настройка для сервиса sidekiq - минимальное количество ресурсов. По-умолчанию sidekiq просит по 2 гигабайта оперативки.
- **gitlab-runner.install: false** - во-первых мы будем использовать jenkins, во-вторых для установки раннера нужен токен, который можно получить только в установленном gitlab.
- **nginx-ingress.enabled: false** - отключает компонент nginx
- **installCertmanager: false** - отключает компонент cert-manager

## Установка GitLab через Helm

Добавляем Helm-репозиторий gitlab
```bash
helm repo add gitlab https://charts.gitlab.io
helm repo update
```
Выполняем установку
```bash
helm upgrade --install gitlab gitlab/gitlab \
  --namespace gitlab \
  -f gitlab-values.yaml \
  --timeout 20m
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

Проверяем:
```bash
helm -n gitlab status gitlab
kubectl -n gitlab get pods -o wide
kubectl -n gitlab get ingress
```

## Первый вход в GitLab

URL (в нашем примере) - `https://gitlab.onecci.lan`

Логин: `root`

Задаем пароль через toolbox:
```bash
kubectl -n gitlab exec -it $TOOLBOX_POD -- gitlab-rails runner "
u = User.find_by_username('root');
u.password = 'NewStrongPass123!';
u.password_confirmation = 'NewStrongPass123!';
if u.save
  puts 'SUCCESS: Password changed'
else
  puts 'ERROR: ' + u.errors.full_messages.join(', ')
end"
```

## Проверяем Git clone по HTTPS и SSH

### HTTPS

В GitLab создаем тестовый проект и выполняем команду:

```bash
git clone https://gitlab.onecci.lan/<group>/<project>.git
```

### SSH (порт 2222)

```bash
git clone ssh://git@gitlab.onecci.lan:2222/<group>/<project>.git
```

Если хотите, чтобы пользователи могли делать `git@gitlab.onecci.lan:<group>/<project>.git` без указания порта, тогда нужно освобождать порт 22 на узле или выносить GitLab SSH на отдельный IP.
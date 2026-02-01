# Установка SonarQube

## Настройка хоста

Прежде чем приступить непосредственно к установке SonarQube, необходимо подготовить хост.
Внутри SonarQube используется Elasticsearch, который предъявляет требования к параметрам ядра Linux и лимитам (кол-во открытых файлов, число потоков).

### vm.max\_map\_count

Увеличиваем лимит memory mappings для процессов. Elasticsearch активно использует mmap, и при низком значении SonarQube не запустится.

```bash
sudo sysctl -w vm.max_map_count=262144
sudo tee /etc/sysctl.d/99-sonarqube.conf >/dev/null <<'EOF'
vm.max_map_count=262144
EOF
sudo sysctl --system
```

Проверка:
```bash
sysctl vm.max_map_count
```

### fs.file-max

Увеличиваем общий лимит открываемых файлов в системе. SonarQube на пару с Elasticsearch открывают много файлов (индексы, сегменты, логи).
```bash
sudo tee -a /etc/sysctl.d/99-sonarqube.conf >/dev/null <<'EOF'
fs.file-max=65536
EOF
sudo sysctl --system
```

Проверка:
```bash
sysctl fs.file-max
```

## Подготовка рабочей директории

Создаем папку под конфиги SonarQube.
```bash
mkdir -p /k3s-1c-ci/sonarqube
cd /k3s-1c-ci/sonarqube
```

## Создаем namespace

```bash
kubectl create namespace sonarqube --dry-run=client -o yaml | kubectl apply -f -
```

## TLS Secret из сертификата

Команда создает Secret или обновляет, если, например, был перевыпущен сертификат:
```bash
kubectl create secret tls onecci.lan.tls \
  --cert=/k3s-1c-ci/tls/tls.crt \
  --key=/k3s-1c-ci/tls/tls.key \
  -n sonarqube \
  --dry-run=client -o yaml | kubectl apply -f -
```

Проверяем:
```bash
kubectl get secret onecci.lan.tls -n sonarqube
```

## Secret Monitoring passcode

`monitoringPasscode` - это служебный пароль SonarQube, который используется для доступа к техническому endpoint `/api/monitoring/metrics`.

- это **не пароль администратора** SonarQube;
- он **не используется для входа в UI**;
- его не нужно знать или вводить пользователям.

Вместо `NewStrongPass123!` нужно указать нужный пароль.
```bash
kubectl -n sonarqube create secret generic sonarqube-monitoring-passcode \
  --from-literal=passcode='NewStrongPass123!' \
  --dry-run=client -o yaml | kubectl apply -f -
```

## Создаем values.yaml (конфигурация установки)

Обратите внимание, нам необходим плагин `sonarqube-community-branch-plugin`, версии которого выходят с задрержной относительно самого SonarQube. Поэтому мы ставим не последнюю версию SonarQube, а ту версию, для которой подходит плагин. Далее в `yaml` блоки для плагина отмечены комментариями.

Создаем файл:

```bash
nano sonarqube-values.yaml
```

```yaml
community:
  enabled: true

# Фиксируем версию SonarQube под branch-plugin
image:
  repository: sonarqube
  tag: 25.9.0.112764-community
  pullPolicy: IfNotPresent

persistence:
  enabled: true
  storageClass: "local-path"
  size: 10Gi

postgresql:
  enabled: true
  persistence:
    enabled: true
    storageClass: "local-path"
    size: 20Gi

resources:
  requests:
    cpu: "1"
    memory: "2Gi"
  limits:
    cpu: "2"
    memory: "8Gi"

monitoringPasscodeSecretName: sonarqube-monitoring-passcode
monitoringPasscodeSecretKey: passcode

initSysctl:
  enabled: false
initFs:
  enabled: false

ingress:
  enabled: true
  ingressClassName: traefik
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
  hosts:
    - name: sonarqube.onecci.lan
      path: /
  tls:
    - secretName: onecci.lan.tls

# Механизм Helm Chart для установки плагинов
plugins:
  install:
    # Плагин 1С (BSL)
    - "https://github.com/1c-syntax/sonar-bsl-plugin-community/releases/download/v1.16.1/sonar-communitybsl-plugin-1.16.1.jar"
    # Community Branch Plugin
    - "https://github.com/mc1arke/sonarqube-community-branch-plugin/releases/download/25.9.0/sonarqube-community-branch-plugin-25.9.0.jar"

sonarProperties:
  # Настройки памяти и branch плагина для Web-процесса
  sonar.web.javaAdditionalOpts: "-Xms1024m -Xmx2048m -javaagent:/opt/sonarqube/extensions/plugins/sonarqube-community-branch-plugin-25.9.0.jar=web"
  # Настройки памяти и branch плагина для Compute Engine (обработка анализов)
  sonar.ce.javaAdditionalOpts:  "-Xms1024m -Xmx2048m -javaagent:/opt/sonarqube/extensions/plugins/sonarqube-community-branch-plugin-25.9.0.jar=ce"
  # Настройки памяти Java
  sonar.search.javaAdditionalOpts: "-Xms2048m -Xmx2048m"

# Для корректной работы UI (ветки / PR) плагин заменяет стандартный webapp SonarQube.
# Это реализуется с помощью настроек:
# - emptyDir volume
# - initContainer, который скачивает sonarqube-webapp.zip
# - монтирование в /opt/sonarqube/web

extraVolumes:
  - name: webapp
    emptyDir:
      sizeLimit: 50Mi

extraVolumeMounts:
  - name: webapp
    mountPath: /opt/sonarqube/web

extraInitContainers:
  - name: download-community-branch-webapp
    image: busybox:1.37
    volumeMounts:
      - name: webapp
        mountPath: /web
    command:
      - sh
      - -c
      - >
        wget -O /tmp/sonarqube-webapp.zip
        https://github.com/mc1arke/sonarqube-community-branch-plugin/releases/download/25.9.0/sonarqube-webapp.zip &&
        unzip -o /tmp/sonarqube-webapp.zip -d /web &&
        chmod -R 755 /web &&
        chown -R 1000:0 /web &&
        rm -f /tmp/sonarqube-webapp.zip
```

### На что обратить внимание в values.yaml

- `community.enabled: true` - обязательный флаг установки Community Build.
- `persistence.enabled` - включает создание постоянного тома (PVC) для хранения установленных плагинов и индексов Elasticsearch. Без этого после перезагрузки пода SonarQube начнет долгую переиндексацию.
- `postgresql.enabled` - явно указываем развертывание PostgreSQL.
- `resources.limits.memory` - ограничивает потребление оперативной памяти контейнером.
- `monitoringPasscodeSecretName/Key` - пароль, который используется для безопасного доступа и взаимодействия с внутренними метриками и API SonarQube из внешних систем мониторинга.
- `initSysctl.enabled` и `initFs.enabled` - запуск Pod в Restricted (ограниченных) пространствах имен без использования привилегированного режима (Root/Privileged).
- `ingress.*` - Traefik Ingress. Для k3s это основной способ дать доступ по доменному имени.
- `tls.secretName` - здесь используем единый wildcard secret `onecci.lan.tls`.
- `plugins.install` - официальный способ установки плагинов в Kubernetes через Helm.
- `extraEnv / SONAR_*_JAVAOPTS` - точка настройки памяти Java. Для больших анализов 1С чаще всего упираешься в CE и Search.

## Установка SonarSource через Helm

Подключаем официальный Helm-репозиторий SonarSource.
```bash
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
helm repo update
```

Проверяем
```bash
helm search repo sonarqube/sonarqube
```

Выполняем установку
```bash
helm upgrade --install sonarqube sonarqube/sonarqube \
  --namespace sonarqube \
  -f sonarqube-values.yaml \
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

Проверяем
```bash
helm -n sonarqube status sonarqube
kubectl -n sonarqube get pods -o wide
kubectl -n sonarqube get ingress
```

## Первый вход и пароли

Открываем URL:

- [https://sonarqube.onecci.lan](https://sonarqube.onecci.lan)

По умолчанию учетные данные: `admin / admin`. При первом входе SonarQube попросит сменить пароль.

## Проверки после установки

Необходимо убедиться, что процессы SonarQube и встроенного Elasticsearch получили корректные лимиты.

```bash
kubectl -n sonarqube exec -it deploy/sonarqube -- sh -lc 'ulimit -n && ulimit -u'
```
Ожидаемый результат:
- nofile ≥ 131072
- nproc ≥ 8192

Что делать, eсли значения вроде `4096` / `1024` и в логах есть ошибки Elasticsearch (например, `max file descriptors [4096] too low`).  
Поднимаем лимиты на хосте.

```bash
sudo systemctl edit k3s
```

Указываем значения:
```ini
[Service]
LimitNOFILE=131072
LimitNPROC=8192
```

Применяем изменения

```bash
sudo systemctl daemon-reexec
sudo systemctl restart k3s
```

После того как pod SonarQube снова станет Running, повторяем проверку
```bash
kubectl -n sonarqube exec -it deploy/sonarqube -- sh -lc 'ulimit -n && ulimit -u'
```
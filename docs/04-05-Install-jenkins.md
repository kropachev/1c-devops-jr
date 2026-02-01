# Установка Jenkins

В Kubernetes мы устанавливаем Jenkins официальным Helm-чартом `jenkinsci/jenkins`.

Инструкции:
- Jenkins - Installing on Kubernetes - Install Jenkins with Helm v3: https://www.jenkins.io/doc/book/installing/kubernetes/#install-jenkins-with-helm-v3
- Jenkins Helm chart (values.yaml): https://raw.githubusercontent.com/jenkinsci/helm-charts/main/charts/jenkins/values.yaml
- Kubernetes Service (NodePort): https://kubernetes.io/docs/concepts/services-networking/service/#type-nodeport

## Подготовка рабочей директории

```bash
mkdir -p /k3s-1c-ci/jenkins
cd /k3s-1c-ci/jenkins
```
Дальше все файлы будут лежать в этой папке.

## Создаем namespace `jenkins`

```bash
kubectl create namespace jenkins --dry-run=client -o yaml | kubectl apply -f -
```

## TLS Secret из сертификата

Команда создает Secret или обновляет, если, например, был перевыпущен сертификат:
```bash
kubectl create secret tls onecci.lan.tls \
  --cert=/k3s-1c-ci/tls/tls.crt \
  --key=/k3s-1c-ci/tls/tls.key \
  -n jenkins \
  --dry-run=client -o yaml | kubectl apply -f -
```

Проверяем:
```bash
kubectl get secret onecci.lan.tls -n jenkins
```

## Создаем ConfigMap с корневым CA-сертификатом

Корневой CA-сертификат не является секретом и хранится в Kubernetes в виде ConfigMap.
```bash
kubectl create configmap onecci-root-ca \
  --from-file=onecci-root-ca.crt=/k3s-1c-ci/tls/onecci-root-ca.crt \
  -n jenkins
```

Проверяем
```bash
kubectl -n jenkins get configmap onecci-root-ca
kubectl -n jenkins describe configmap onecci-root-ca
```

## Добавляем Helm-репозиторий Jenkins

```bash
helm repo add jenkinsci https://charts.jenkins.io
helm repo update
```

## Создаем PersistentVolume и StorageClass

Jenkins должен сохранять данные (`/var/jenkins_home`) между перезапусками Pod.

Создаем каталог на ноде(ах), где будет храниться Jenkins home:
```bash
sudo mkdir -p /data/jenkins-volume
sudo chown -R 1000:1000 /data/jenkins-volume
```

Скачиваем официальный манифест PV/StorageClass и примените его:
```bash
curl -fsSL -o jenkins-01-volume.yaml \
  https://raw.githubusercontent.com/jenkins-infra/jenkins.io/master/content/doc/tutorials/kubernetes/installing-jenkins-on-kubernetes/jenkins-01-volume.yaml
```
```bash
kubectl apply -f jenkins-01-volume.yaml
```

Проверяем
```bash
kubectl get pv
kubectl get storageclass
```

## Создаем ServiceAccount и RBAC

Jenkins должен уметь создавать динамические агенты (Pods) в Kubernetes. Для этого в официальной инструкции создается ServiceAccount `jenkins` и выдаются права через ClusterRole/ClusterRoleBinding.

```bash
curl -fsSL -o jenkins-02-sa.yaml \
  https://raw.githubusercontent.com/jenkins-infra/jenkins.io/master/content/doc/tutorials/kubernetes/installing-jenkins-on-kubernetes/jenkins-02-sa.yaml
```
```bash
kubectl apply -f jenkins-02-sa.yaml
```

Проверяем
```bash
kubectl -n jenkins get sa
kubectl get clusterrole jenkins
kubectl get clusterrolebinding jenkins
```

## Готовим `jenkins-values.yaml`

Официальная инструкция Jenkins предлагает взять `values.yaml` Helm-чарта как шаблон и внести несколько настроек. Так и поступим.

Скачиваем шаблон `values.yaml`:

```bash
curl -fsSL -o jenkins-values.yaml \
  https://raw.githubusercontent.com/jenkinsci/helm-charts/main/charts/jenkins/values.yaml
```

Открываем для редактирования `jenkins-values.yaml`.
```bash
nano jenkins-values.yaml
```

### ServiceAccount (используем созданный `jenkins`)

Блок `serviceAccount`, указываем использование созданного нами пользователя.

```yaml
serviceAccount:
  create: false
  name: jenkins
  annotations: {}
```

### Сервис (NodePort 32000)

Блок `controller` - `serviceType` и `nodePort`, нужно установить значения:

```yaml
controller:
  serviceType: NodePort
  nodePort: 32000
```

### Сертификаты, правим в разделе controller:

```yaml
controller:
  # --- CA: для git ---
  containerEnv:
    - name: GIT_SSL_CAINFO
      value: /usr/local/share/onecci-ca/onecci-root-ca.crt
```
GIT_SSL_CAINFO используется только для git/curl, он не влияет на Java (jnlp-агенты, Sonar).  
Для jnlp-агентов будет использоваться internal HTTP URL Jenkins.

### Отключаем JCasC

Отключаем JCasC (Jenkins Configuration as Code), чтобы наши настройки в графическом интерфейсе не сбрасывались при перезагрузках. (возможно отдельно рассмотрим конфигурацию через YAML).  
В разделе `controller` - `JCasC` нужно отключить `defaultConfig`.

```yaml
controller:
  JCasC:
    defaultConfig: false
```

### Хранилище (storageClass: jenkins-pv)

Блок `persistence` и включите persistence, указав storageClass `jenkins-pv`:
```yaml
persistence:
  enabled: true
  storageClass: jenkins-pv
```

### Монтируем раздел с сертификатами

```yaml
persistence:
  # CA монтируем в Pod контроллера как volume
  volumes:
    - name: onecci-root-ca
      configMap:
        name: onecci-root-ca

  mounts:
    - name: onecci-root-ca
      mountPath: /usr/local/share/onecci-ca
      readOnly: true
```

### Инициализировать плагины только один раз

Ищем блок `controller` -> `initializeOnce`, включаем:
```yaml
controller:
  initializeOnce: true
```

`values.yaml` готов.

## Устанавливаем Jenkins

Команда установки
```bash
chart=jenkinsci/jenkins
helm install jenkins -n jenkins -f jenkins-values.yaml $chart
```

Проверяем
```bash
kubectl get pods -n jenkins
kubectl get svc -n jenkins
```

Команда для обновления настроек, если менялся values.yaml.
```bash
helm upgrade jenkins jenkins/jenkins \
  -n jenkins \
  -f jenkins-values.yaml
```

## Получаем пароль администратора

Команда из инструкции Jenkins (пароль хранится в Kubernetes Secret релиза `jenkins`):

```bash
jsonpath="{.data.jenkins-admin-password}"
secret=$(kubectl get secret -n jenkins jenkins -o jsonpath=$jsonpath)
echo $(echo $secret | base64 --decode)
```

Логин: `admin`, если не меняли в процессе установки.

## Настройка Jenkins URL для Kubernetes-агентов

Jenkins UI доступен по HTTPS через Ingress,  а  Kubernetes-агенты должны подключаться к Jenkins по internal Service без TLS.

Выполняем настройку в интерфейса Jenkins:

**Manage Jenkins** - **System** - **Jenkins Location**

Устанавливаем Jenkins URL:
http://jenkins.jenkins.svc.cluster.local:8080


## Плагины, которые нужно установить

В интерфейсе Jenkins **Manage Jenkins** - **Plugins** - вкладка **Available plugins**

| Плагин | ID | Что делает |
| - | - | - |
| Blue Ocean | `blueocean` | UI для пайплайнов (визуально показывает стадии и шаги). |
| Git Pipeline for Blue Ocean | `blueocean-git-pipeline` | Git-интеграция для Blue Ocean. |
| Pipeline implementation for Blue Ocean | `blueocean-pipeline-api-impl` | Реализация Pipeline API для Blue Ocean. |
| Copy Artifact | `copyartifact` | Копирование артефактов между job/build. |
| HTTP Request | `http_request` | Шаги HTTP-запросов в Pipeline. |
| Node and Label parameter | `nodelabelparameter` | Параметр для выбора ноды/лейбла агента при запуске job. |
| Pipeline Aggregator View | `pipeline-aggregator-view` | Сводный экран пайплайнов по стадиям. |
| Pipeline Configuration History | `pipeline-config-history` | История изменений конфигурации job/пайплайнов. |
| Pipeline GitHub Notify Step | `pipeline-githubnotify-step` | Шаг `githubNotify` для статусов в GitHub. |
| Pipeline: Multibranch with defaults | `pipeline-multibranch-defaults` | Дефолтные настройки multibranch-пайплайнов. |
| Pipeline timeline | `pipeline-timeline` | Таймлайн стадий пайплайна (длительности). |
| Pipeline Utility Steps | `pipeline-utility-steps` | Утилиты в pipeline (readYaml, writeYaml, zip и т.д.). |
| SonarQube Scanner | `sonar` | Интеграция Jenkins с SonarQube и quality gate. | 
| Throttle Concurrent Builds | `throttle-concurrents` | Ограничение параллельных сборок. |
| Kubernetes | `kubernetes` | Запуск Jenkins agents как Pod в Kubernetes. |
| Pipeline | `workflow-aggregator` | Набор базовых Pipeline-плагинов. |
| Git | `git` | Git checkout/fetch и т.п. |
| Configuration as Code | `configuration-as-code` | Jenkins Configuration as Code (JCasC). |
| Allure | `allure` | Allure jenkins plugin |
| File Operations | `FileOperation` | File Operations Plugin |
| Timestamper | `Timestamper` |  |
---

## Отключаем плагины из списка

В интерфейсе Jenkins **Manage Jenkins** - **Plugins** - вкладка **Installed**

Отключаем плагины

| Плагин | ID | Что делает | 
| - | - | - | 
| OWASP Markup Formatter | `antisamy-markup-formatter` | Санитизация HTML-разметки в описаниях/комментариях. |
| Ant | `ant` | Поддержка Ant build steps. |
| Gradle | `gradle` | Поддержка Gradle build steps. |
| Matrix Authorization Strategy | `matrix-auth` | Матричная модель прав. |
| PAM Authentication | `pam-auth` | PAM-аутентификация (Linux). |
| LDAP | `ldap` | LDAP/AD-аутентификация. |

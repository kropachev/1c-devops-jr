# Настройка Jenkins агентов SonarQube

Перед добавлением агента требуется настроить аутентификацию Jenkins в SonarQube.  
Jenkins аутентифицируется в SonarQube через API-token, а Kubernetes-агенты просто используют уже настроенную интеграцию Jenkins  SonarQube.

## Генерация токена в SonarQube

Заходим в SonarQube под пользователем с правами анализа (обычно admin).

В правом верхнем углу - **иконка пользователя (A)** - **My Account**.

Вкладка **Security**.

В блоке **Generate Tokens** заполняем поля:

- **Name**: `jenkins`
- **Type**: `User Token`
- **Expires in**: `No expiration`

Нажимаем **Generate**

Сразу копируем токен, повторно его посмотреть нельзя.

## Добавляем SonarQube в Jenkins

Заходим в Jenkins.

**Manage Jenkins** - **System**

Ищем раздел **SonarQube servers**  
Нажимаем **Add SonarQube**

Заполняем поля:

- **Name**:	`SonarQube`
- **Server URL**: `http://sonarqube-sonarqube.sonarqube.svc.cluster.local:9000`
- **Server authentication token**: **Add** - **Jenkins**

**Credential**

В окне **Add Credential**:

- **Kind**: `Secret text`
- **Secret**: `(вставляем токен из SonarQube)`
- **Description**: `sonarqube admin token`

Нажимаем Add, выбираем созданный credential и жмем **Save**.

## Добавление агента в Jenkins (Pod Template)

В отличии от агентов 1С здесь используется стандартный образ для агента.  
В docker-swarm использовался официльный образ агента sonarqube, в который командами запуска добавлялся агент дженкинса. Теперь этот фокус не проходит. Мы будем использовать стандартный агент дженкинса, в который доустановим файлы для sonar-scanner.

**Manage Jenkins** - **Clouds** - **Kubernetes** - **Pod Templates** - **Add Pod Template**

### Основные параметры Pod Template

| Поле | Значение | Комментарий |
| - | - | - |
| Name | `sonar` | - |
| Namespace | `jenkins-agents` | namespace, в котором создаются Pod-ы агентов |
| Labels | `sonar   ` | используется Jenkins для выбора агента |
| Service Account | `jenkins-agent` | учетная запись Kubernetes для Pod-а |

### Добавляем аздел с сертификатом

**Volumes** - **Add Volume**.  
Тип **Config Map Volume**.

- `Name` - onecci-root-ca
- `Mount path` - /etc/gitlab-ca

### Добавляем YAML для инитконтейнера и установки sonar-scanner

**Raw YAML for the Pod** - вставляем содержимое.

```yaml
spec:
  volumes:
    - name: sonar-scanner
      emptyDir: {}

  initContainers:
    - name: sonar-scanner-installer
      image: sonarsource/sonar-scanner-cli:latest
      command: ['sh', '-c', 'cp -R /opt/sonar-scanner /sonar/']
      volumeMounts:
        - name: sonar-scanner
          mountPath: /sonar

  containers:
    - name: jnlp
      image: jenkins/inbound-agent:latest
      volumeMounts:
        - name: sonar-scanner
          mountPath: /sonar
      env:
        - name: PATH
          value: "/sonar/sonar-scanner/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        - name: GIT_SSL_CAINFO
          value: "/etc/gitlab-ca/onecci-root-ca.crt"
        - name: SSL_CERT_FILE
          value: "/etc/gitlab-ca/onecci-root-ca.crt"
```

### Контейнер агента

Переходим к разделу **Containers** и жмем **Add Container** и выбираем **Container Template**  
Заполняем поля:
| Поле | Значение | Комментарий |
| - | - | - |
| Name | `jnlp` | контейнер с именем `jnlp` используется Kubernetes plugin как Jenkins-агент |
| Docker image | `jenkins/inbound-agent:latest` | Агент Jenkins |
| Working directory | `/home/jenkins` | стандартная рабочая директория Jenkins |
| Allocate pseudo-TTY | ✅ | включаем |
| Command |  | не заполняем, даем плагину самому запускать агент |
| Arguments |  | не заполняем, не переопределяем запуск |

**Environment Variables** - **Add Environment Variable**.  
Добавляем переменные с типом **Environment Variable**.

| Key | Value |
| - | - |
| SONAR_SCANNER_JAVA_OPTS | -Xmx6g |
| PATH | /sonar/sonar-scanner/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin |
| GIT_SSL_CAINFO | /etc/gitlab-ca/onecci-root-ca.crt |
| SSL_CERT_FILE | /etc/git-ssl/onecci-root-ca.crt |

Нажимаем **Create** для сохранения.
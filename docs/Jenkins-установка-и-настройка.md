# 👨🏻 Jenkins, установка и настройка

Контейнер Jenkins доступен для установки прямо в Portainer из шаблона.

Если из-за сертификатов установка из шаблонов не возможна:

```
docker run jenkins/jenkins:lts-jdk11
```

Если при первом запуске Jenkins сообщит что не может установить защищенное соединение для установки плагинов, даже после настройки прокси, то необходимо добавить корневой сертификат - см. раздел Сертификаты.

Пароль для первого запуска можно найти в логах установки.

При первом запуске необходимо выбрать плагины.

* Отключаем плагины:

    * OWASP Markup Formatter
    * Ant
    * Gradle
    * Matrix Authorization Strategy
    * PAM Authentication
    * LDAP
* Включаем плагины:
    * Dashboard View
    * SSH Agent
    * JUnit
    * GitLab
    * GitHub
* После установки дополнительно установить плагины:
    * Allure
    * Blue Ocean
    * Copy Artifact
    * Docker Swarm
    * Git Pipeline for Blue Ocean
    * HTTP Request
    * Node and Label parameter
    * Pipeline Aggregator View
    * Pipeline Configuration History
    * Pipeline GitHub Notify Step
    * Pipeline implementation for Blue Ocean
    * Pipeline Multibranch with defaults
    * Pipeline timeline
    * Pipeline Utility Steps
    * SonarQube Scanner
    * Throttle Concurrent Builds
# Настройка Jenkins агентов 1С

Мы настраивали доступ к Docker Registry по прямому адресу без указания порта `https://registry.onecci.lan`

## Подготовка Docker-образа Jenkins-агента 1С

Для сборки образов используется отдельный репозиторий со скриптами автоматизированной установки платформы 1С и подготовки окружения Jenkins-агента.

Клонируем репозиторий
```bash
git clone https://github.com/Daabramov/Sonarqube-for-1c-docker.git
cd onec-docker
```

### Настройка параметров сборки

Создаем файл окружения:

```bash
cp .onec.env.example .env
nano .env
```

Минимально необходимые параметры:

```env
ONEC_VERSION=8.3.27.1606

ONEC_USERNAME=...
ONEC_PASSWORD=...

DOCKER_REGISTRY=registry.onecci.lan
DOCKER_IMAGE_PREFIX=onec
```

Пояснения:
- `ONEC_VERSION` - версия платформы 1С, которая будет установлена в образ
- `ONEC_USERNAME / ONEC_PASSWORD` - учетные данные для получения дистрибутивов 1С
- `DOCKER_REGISTRY` - адрес приватного Registry (без порта)
- `DOCKER_IMAGE_PREFIX` - префикс имен образов

### Сборка образа Jenkins-агента

Для Jenkins в Kubernetes используется специализированный сценарий сборки:

```bash
chmod +x build-base-k8s-jenkins-agent.sh
./build-base-k8s-jenkins-agent.sh
```

В результате:
- собирается Docker-образ агента;
- образ тегируется версией платформы 1С;
- образ публикуется в приватный Registry.

Пример итогового образа:

```
registry.onecci.lan/jenkins-agent:8.3.27.1606
```

---

## Добавление Jenkins-агента в Jenkins (Pod Template)

**Manage Jenkins** - **Clouds** - **Kubernetes** - **Pod Templates** - **Add Pod Template**

### Основные параметры Pod Template

| Поле | Значение | Комментарий |
| - | - | - |
| Name | onec-8-3-27-1606 | - |
| Namespace | jenkins-agents | namespace, в котором создаются Pod-ы агентов |
| Labels | 8.3.27.1606 agent | используется Jenkins для выбора агента |
| Image Pull Secret | registry-auth | секрет с учеткой для registry |
| Service Account | jenkins-agent | учетная запись Kubernetes для Pod-а |

### Раздел с сертификатом

1. **Volumes** - **Add Volume**.  
Тип **Config Map Volume**.

- **Name** - `onecci-root-ca`
- **Mount path** - `/etc/gitlab-ca`

1. Environment Variables - Add Environment Variable.  
Тип **Environment Variable**.

- **Key** - `GIT_SSL_CAINFO`
- **Value** - `/etc/gitlab-ca/onecci-root-ca.crt`

### Контейнер агента

Добавляем контейнер в Pod Template.

| Поле | Значение | Комментарий |
| - | - | - |
| Name | `jnlp` | контейнер с именем `jnlp` используется Kubernetes plugin как Jenkins-агент |
| Docker image | `registry.onecci.lan/base-jenkins-agent:8.3.27.1606` | - |
| Working directory | `/home/jenkins` | стандартная рабочая директория Jenkins |


Раскрываем Advanced
| Поле | Значение | Комментарий |
| - | - | - |
| Run As User ID | `0` | запуск контейнера под root |
| Limit Memory | `1024Mi` | лимит по оперативной памяти (в kubernetes с этим строго) | 

Жмем **Save** для сохранения настроек.
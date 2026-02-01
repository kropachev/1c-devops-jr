# Подготовка сервера и установка Kubernetes (K3s)

Мы установим **K3s** - облегченную версию Kubernetes, которая подходит для односерверной установки.

Что делает K3s
* Устанавливает Kubernetes API и компоненты
* Настраивает containerd - runtime для контейнеров
* Разворачивает кластер с одним узлом

## Подготовка сервера

Обновляем пакеты и устанавливаем базовые инструменты (curl, wget, git), необходимые для скачивания компонентов и работы с репозиториями.

Выполняем команды
```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y curl wget git ca-certificates lsb-release
```

### Создаем группу для доступа к Kubernetes и файлам конфигурации

Создадим отдельную системную группу, которой будет разрешено читать kubeconfig и конфигурационные файлы создаваемые в процессе установки сервисов.

```bash
sudo groupadd k3s
```

Добавь текущего пользователя (и всех остальных пользователей, которые будут работать с сервисом) в эту группу:

```bash
sudo usermod -aG k3s $USER
```

После добавления пользователя в группу **необходимо перелогиниться** или выполнить:

```bash
newgrp k3s
```

## Подготовка рабочей директории

Создаем папку для конфигов
```bash
mkdir -p /k3s-1c-ci
```

Добавляем права для группы `k3s`
```bash
sudo chgrp -R k3s /k3s-1c-ci
sudo chmod -R 2775 /k3s-1c-ci
```

## Установка k3s

Команда установки

```bash
curl -sfL https://get.k3s.io | sh -
```

Проверка установки

```bash
sudo kubectl get nodes
```

Вы должны увидеть узел со статусом `Ready`.

## Установка Helm

Helm (пакетный менеджер для Kubernetes) нужен, чтобы устанавливать приложения как Helm-чарт.

Официальная страница установки Helm: https://helm.sh/docs/intro/install

Этот скрипт поддерживается проектом Helm и размещен в их репозитории - https://github.com/helm/helm/blob/main/scripts/get-helm-3

```bash
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

Проверка:

```bash
helm version
```
Ожидаем увидеть `version.BuildInfo`... 
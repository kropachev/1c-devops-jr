# Агент 1С для Jenkins

Для работы пайплайна нам понадобится контейнер с 1С.

Клонируем к себе проект из репозитория https://github.com/kropachev/onec-docker, например в папку 

**var/devops/**.

```
git clone https://github.com/kropachev/onec-docker
```

Создаем копию файла **.onec.env.example** и переименовываем его в **.env**.

```
cp .onec.env.example .env
```

Внутри файла указываем нужную нам платформу и версию edt.

**ONEC_VERSION**=8.3.21.1302 (версия нужной платформы)

**DT_VERSION**=2021.2.7 (версия нужного edt)

**DOCKER_USERNAME**=192.168.1.50:5000 (ip и порт registry докера)

**ONEC_USERNAME**= (логин от сайта 1С).

**ONEC_PASSWORD**= (пароль от сайта 1С).

Сохраняем файл и переходим в терминал.

Последовательно выполняем команды

```
source .env
```
```
chmod +x ./build-base-jenkins-agent.sh
```
```
./build-base-jenkins-agent.sh
```
Возможно скрипт не будет выполняться, в этом случае нужно включить возможность использования **insecure registry** в docker.


Теперь настройки.

Путь: **Dashboard** - **Manage Jenkins** - **Manage nodes and clouds**.

Жмем **Configure Clouds** и в открывшемся окне скролим вниз до кнопки **Docker Agent templates**, нажимаем и жмем кнопку **Add Docker Agent template**.

Заполняем.

**Labels**: `8.3.21.1302` (версия платформы).

**Image**: `192.168.1.50:5000/base-jenkins-agent:8.3.21.1302` (ipАдресДокера:ПортRegistry/КонстантаНазваниеАгента:ВерсияПлатформы)

**Command**: очищаем (в самом агенте зашита команда).

**Working Directory**: `/home/jenkins`

**User**: `root`

**Port binds (newline-separated)**: `:5900` (да, с двоеточием перед номером порта)

Жмем **Save**.
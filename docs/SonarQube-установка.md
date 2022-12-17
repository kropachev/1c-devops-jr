# SonarQube, установка

Берем готовую сборку из репозитория [Daabramov/Sonarqube-for-1c-docker: Sonarqube dockerfile and docker compose for for 1C-Enterprise (github.com)](https://github.com/Daabramov/Sonarqube-for-1c-docker).

Создаем файл `docker-compose.yml` с содержимым из репозитория.

Порт можно вернуть на `9000`.

На хосте с докером необходимо выполнить команды:

```
echo "vm.max_map_count=262144" >> /etc/sysctl.conf
```
```
echo "sysctl -w fs.file-max=65536" >> /etc/sysctl.conf
```

Запускаем из командной строки

```
docker-compose up -d
```

В браузере открываем страницу по ip с нашей виртуалкой и портом 9000 (например http://192.168.10.50:9000).

Пароль и логин по умолчанию `admin`/`admin`.

Сразу потребуется создать новый пароль.

Создаем новый проект.

**Projects** - **Manualy**.

Ключ - **democonf**, Создать.

Вверху-справа жмем на кнопку с логотипом пользователя (**А**), выбираем **My Account**.

Закладка **Security**.

В поле **Generate Tokens** пишем `jenkins` и жмем **Generate**. 

Возвращаемся в Jenkins - **Manage Jenkins** - **Configure System**.

Ищмем разрел **SonarQube Servers**, жмем **Add SonarQube**.

Name: SonarQube

Server URL: наш урл с портом 9000 (http://192.168.1.50:9000)

**Server authentication token** - **Add**

В открывшемся окне **Kind**: **Secret text**

**Secret**: `наш токен`.

**Description**: `sonarqube admin token`

**Add**

Выбираем и сохраняем
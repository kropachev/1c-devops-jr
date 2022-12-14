# Прокси и дополнительные настройки

Оригинал - [Control Docker with systemd | Docker Documentation.](https://docs.docker.com/config/daemon/systemd/)

Если при попытке скачать образ докер сообщает что не может подключиться к хранилищу (`request canceled while waiting for connection`), то возможно проблема в прокси.

Для настройки прокси необходимо создать каталог для хранения файла конфигурации
```
sudo mkdir -p /etc/systemd/system/docker.service.d
```

Создать файл конфигурации
```
sudo nano /etc/systemd/system/docker.service.d/http-proxy.conf
```

Внутри файла указать настройки прокси
```
[Service]
Environment="HTTP_PROXY=myproxy.net:80"
Environment="HTTPS_PROXY=myproxy.net:80"
Environment="NO_PROXY=localhost, 127.0.0.0/8, ::1, 10.0.0.0/8"
```
Сохранить файл, перезагрузиться.
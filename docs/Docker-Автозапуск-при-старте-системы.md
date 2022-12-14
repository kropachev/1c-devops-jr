# Автозапуск Docker при старте системы

Оригинал - [Post-installation steps for Linux | Docker Documentation.](https://docs.docker.com/engine/install/linux-postinstall/)

По-умолчанию для Ubuntu автозапуск Docker уже сконфигурирован.

Если не запускается, то необходимо ввести следующие команды:

Для включения автозапуска
```
sudo systemctl enable docker.service
```
```
sudo systemctl enable containerd.service
```

Для отключения автозапуска
```
sudo systemctl disable docker.service
```
```
sudo systemctl disable containerd.service
```
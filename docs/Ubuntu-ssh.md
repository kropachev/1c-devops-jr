# SSH 

Если установлена десктоп версия, то возможно `ssh` будет не активирован.

Проверяем:

```
systemctl status ssh
```

Устанавливаем:

```
sudo apt update
```
```
sudo apt install openssh-server
```
# Создание сетевой папки

Установка сервера Samba.
```
sudo apt-get update
```
```
sudo apt-get install samba
```
```
sudo smbd start
```

При первом старте сервер Samba запросит имя пользователя и пароль для сетевого доступа. Нужно ввести имя локального пользователя и пароль.

Создание каталога на Ubuntu, к которому предоставляется доступ.
```
sudo mkdir /var/onecrep
```

Установка владельца для папки share (без владельца и без группы):
```
sudo chown nobody:nogroup /var/onecrep
```

Установка прав на полный доступ к папке share:
```
sudo chmod 777 /var/onecrep
```
Отредактируйте файл конфигурации smb.conf в любом текстовом редакторе.
```
sudo nano /etc/samba/smb.conf
```

Убедитесь, что в секции [global] добавлены следующие строки:

```
workgroup = WORKGROUP
map to guest = Bad User
usershare allow guests = Yes
```

Создайте секцию описания общего ресурса [onecrep], onecrep, в данном случае, это представление папки в сети.

```
[onecrep]
create mask = 0777
directory mask = 0777
guest ok = Yes
path = /var/onecrep/
read only = No
```

Перезапустите сервис samba:
```
sudo service smbd restart
```

Проверить активную конфигурацию smbd можно командой:
```
testparm -s
```
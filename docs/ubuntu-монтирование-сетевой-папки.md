# Монтирование сетевой папки

```
sudo mount -t cifs -o username=user1c,password=password1c,domain=ad,uid=1000,iocharset=utf8,file_mode=0777,dir_mode=0777 //localserver/1crepository /var/onecrep
```
`user1c` - Пользователь для доступа к сетевой папке.

`password1c` - Пароль для доступа к сетевой папке.

`//localserver/1crepository` - Сетевой путь.

`/var/onecrep` - локальный каталог, в который буде смонтирован сетевой путь.
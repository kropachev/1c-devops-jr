# GitHub, ошибки и особенности

## Ошибка при попытке клонировать проект из GitHub

```
Failed to connect to github.com port 443 after 21128 ms: Timed out
```

Если используется проки, то необходимо включить его использование для Git:

```
git config --global http.proxy http://your-proxy.net:80/
```

Для отключения прокси:
```
git config --global --unset http.proxy
```

## Ошибка при попытке клонировать проект из GitHub

```
SSL certificate problem: unable to get local issuer certificate
```

Часто бывает в компаниях, в которых подменяются сертификаты защищенных соединений. Проверку сертификата для GitHub можно отключить.

```
git config --global http.sslverify false
```

## Откат на определенный коммит (коммиты новее удаляются)

```
git reset --hard commit_id
```

`commit_id` - ид коммита, на который нужно откатиться.

```
git push --force
```

 

 
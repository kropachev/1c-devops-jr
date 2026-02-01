# Отключение ipv6

В некоторых случаях доступ к ресурсам в интернет может быть недоступен из-за неправильных настроек ipv6.

Проверка ipv6
```
ip a
```
![Alt text](images/ubuntu-ipv6.png)

Для отключения протокола необходимо выполнить команды
```
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
```
```
sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
```
```
sudo sysctl -w net.ipv6.conf.lo.disable_ipv6=1
```

Для проверки снова выполнить команду 

```
ip a
```
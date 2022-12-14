# Настройка прав

Оригинал - [Post-installation steps for Linux | Docker Documentation.](https://docs.docker.com/engine/install/linux-postinstall/)

Создаем группу пользователей docker.
```
sudo groupadd docker
```

Добавляем своего пользователя в эту группу.
```
sudo usermod -aG docker $USER
```

Активируем изменения группы.
```
newgrp docker
```

Перезагружаемся.

Проверяем возможность работы без полных прав (без добавления sudo перед командой).

```
docker run hello-world
``` 
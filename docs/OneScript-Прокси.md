# Прокси

Основной ответ - [opm install/update на Ubuntu 16.04 · Issue #811 · EvilBeaver/OneScript · GitHub](https://github.com/EvilBeaver/OneScript/issues/811)

Для использования opm прокси необходимо:

Создать файл настроек
```
sudo nano /etc/opm.cfg
```

Содержимое файла

```
{
    "Прокси": {
        "ИспользоватьПрокси": true,
        "ПроксиПоУмолчанию": false,
        "Сервер": "zproxy-mowpn.ru.rccad.net",
        "Порт": "80",
        "Пользователь": "",
        "Пароль": "",
        "ИспользоватьАутентификациюОС": false
    },
    "СоздаватьShСкриптЗапуска": false
}
```

Перезапустить машину.
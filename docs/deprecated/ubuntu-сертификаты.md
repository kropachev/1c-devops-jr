# Сертификаты

Если весь трафик дешифруется с использованием поддельных сертификатов, то сертификат необходимо добавить в корневые.

Сертификат должен иметь расширение crt. Если сертификат в формате pem (например выгружен из браузера), его следует конвертировать перед добавлением.
```
openssl x509 -outform der -in your-cert.pem -out your-cert.crt
```

Сертификат следует добавить в папку /usr/share/ca-certificates/extra (потребуются права администратора)
```
sudo cp your-cert.crt /usr/share/ca-certificates/extra/your-cert.crt
```

Затем выполнить одну из команд:

Обновление сертификатов

```
sudo update-ca-certificates
```

Интерактивное обновление сертификатов
```
sudo dpkg-reconfigure ca-certificates
```
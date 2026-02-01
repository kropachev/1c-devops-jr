
# Ошибка SSL certificate problem: unable to get local issuer certificate

При попытке клонировать репозиторий из GitLab (развернутого в k3s с собственными сертификатами) возникает ошибка:

```text
SSL certificate problem: unable to get local issuer certificate
```
Git не доверяет корневому центру сертификации (Root CA), которым подписан TLS-сертификат GitLab.

Самый простой вариант, установить root CA в хранилище операционной системы на клиенте.
Если по какой-то причине делать этого не хочется, можно добавить сертификат в локальный git.

Для примера используем сертификат
* Имя файла: `onecci-root-ca.crt`
* Тип: Root CA
* Формат: PEM
  (должен начинаться с `-----BEGIN CERTIFICATE-----`)

## Linux (Ubuntu)

Создаем каталог для CA Git

```bash
mkdir -p ~/.config/git/certs
```

Копируем сертификат в созданный каталог
```bash
cp onecci-root-ca.crt ~/.config/git/certs/
```

Итоговый путь:

```bash
~/.config/git/certs/onecci-root-ca.crt
```

Указываем Git использовать этот CA (только для нашего GitLab)
```bash
git config --global http."https://gitlab.onecci.lan".sslCAInfo \
"~/.config/git/certs/onecci-root-ca.crt"
```

Проверяем
```bash
git ls-remote https://gitlab.onecci.lan/<group>/<repo>.git
```

Если ошибка не появляется - настройка выполнена корректно.

## Windows (Git for Windows)

Создаем каталог для сертификатов
Рекомендуемый путь (без пробелов и кириллицы):
```bash
C:\Users\<USERNAME>\.git-certs\
```

Пример
```bash
C:\Users\Sergey\.git-certs\
```

Копируем файл сертификата в созданную паппку и получаем примерно такой итоговый путь
```bash
C:\Users\Sergey\.git-certs\onecci-root-ca.crt
```

Переключаем Git на OpenSSL backend
Git for Windows может использовать Windows certificate store (`schannel`), который **игнорирует `sslCAInfo`**.

Проверяем настройку
```bash
git config --global --get http.sslBackend
```

Если значение `schannel` или пусто - выполняем команду:
```bash
git config --global http.sslBackend openssl
```

Указываем Git использовать этот CA (только для нашего GitLab)
```bash
git config --global http."https://gitlab.onecci.lan".sslCAInfo \
"C:/Users/Sergey/.git-certs/onecci-root-ca.crt"
```

Проверяем
```bash
git ls-remote https://gitlab.onecci.lan/<group>/<repo>.git
```

Если ошибка не появляется - настройка выполнена корректно.
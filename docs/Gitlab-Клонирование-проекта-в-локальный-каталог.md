# Клонирование проекта в локальный каталог

В GitLab будут храниться файлы с исходниками вашей конфигурации. Если работа ведется с использованием хранилища (пока да), конфигурация из хранилища преобразуется в исходные файлы, которые отправляются в GitLab.

В GitLab мы уже создали пустой проект, сейчас создадим у себя папку для этого проекта, клонируем туда проект из GitLab, потом выгрузим из хранилища файлы конфигурации и отправим обратно в GitLab.

К этому времени уже должно существовать хранилище 1С, которое будет клонироваться, а так же должен быть устанолен OneScript.

Рассмотрим вариант работы из Windows (проще) и Ununtu.

## Клонирование проекта в локальный каталог Windows

Создаем папку на машине с установленной платформой. Например C:\GitRepo

В этот каталог gitsync будет сохранять файлы из хранилища.

Внутри этой папки, запускаем командную строку

Клонируем проект, в данном случае проект называется demodb.
```
git clone http://ubuntuserver1:11080/devteam/demodb
```

Потребуется ввести логин и пароль.

Создавать папки и файлы можно запустив VisualCode из папки репозитория.

Создаем каталог `src/cf` (скорее всего права тоже нужно будет расширить, если работа ведется в сетевой папке).

Внутри созданного каталога создаем файл `AUTHORS`, это файл сопоставления имен в хранилище и GitLab. Всех пользоваетелй хранилища необходимо сопоставить с пользователями GitLab.
Примерное содержание файла.

```
Администратор=root <root@example.com>
User=user <user@example.com>
```

Здесь же создается файл `VERSION` со следующим содержимым

```
<?xml version="1.0" encoding="UTF-8"?>
<VERSION>0</VERSION>
```

Коммитим изменения, можно из VSCode.

<details>
<summary>Возможно появится ошибка unsafe repository</summary>

Если появляется ошибка
```
fatal: unsafe repository ('/home/mc/demodb' is owned by someone else)
To add an exception for this directory, call:

        git config --global --add safe.directory /home/mc/demodb
```

Выполняем предложенную команду
```
git config --global --add safe.directory /home/mc/demodb
```

И повторяем 
```
git add .
```
</details>



<details>
<summary>Возможно появится ошибка Author identity unknown</summary>

Здесь тоже возможно появление ошибки
```
Author identity unknown

*** Please tell me who you are.

Run

  git config --global user.email "you@example.com"
  git config --global user.name "Your Name"

to set your account's default identity.
Omit --global to set the identity only in this repository.
```

Последовательно выполняем предложенные команды
```
git config --global user.name root
```
Где `root`, это имя пользователя

```
git config --global user.email root@example.com
```
Где `root@example.com`, это имейл пользователя

Повторяем
```
git commit -m "init"
```
</details>


Получаем примерно такой ответ
```
[main (root-commit) a750612] init
 2 files changed, 4 insertions(+)
 create mode 100755 src/cf/AUTHORS
 create mode 100755 src/cf/VERSION
 ```
Теперь отправляем
```
git push
```
Вводим логин и пароль от GitLab.

Готово.

## Клонирование проекта в локальный каталог Ubuntu

Сначала необходимо создать каталог. В этот каталог gitsync будет сохранять файлы из хранилища.

Чтобы не было проблем с правами на папки, лучше создать отдельную папку без владельца и прав, в которую складывать все исходники.
```
sudo mkdir /var/gitrep
```
```
sudo chown nobody:nogroup /var/gitrep
```
```
sudo chmod 777 /var/gitrep
```

Чтобы проще было работать с этой папкой, ее тоже можно расшарить.

Клонируем проект, в данном случае проект называется `demodb`.
```
git clone http://ubuntuserver1:1080/devteam/democonf
```
Потребуется ввести логин и пароль.

Внутри папки с именем проекта создаем каталог `src/cf` (скорее всего права тоже нужно будет расширить, если работа ведется в сетевой папке). Если работа ведется на сервере с gui то прямо из папки можно запустить vscode.
```
code .
```
Для работы из консоли:
```
mkdir src
```
```
cd src
```
```
mkdir cf
```

Внутри созданного каталога создаем файл `AUTHORS`, это файл сопоставления имен в хранилище и `GitLab`.

```
nano AUTHORS
```
Содержимое файла:
```
Администратор=root <root@example.com>
User=user <user@example.com>
```

Здесь же создается файл VERSION
```
nano VERSION
```
```
<?xml version="1.0" encoding="UTF-8"?>
<VERSION>0</VERSION>
```

На всякий случай расширяем права на файлы, чтобы не было проблем с доступом

```
sudo chown nobody:nogroup AUTHORS
```
```
sudo chmod 777 AUTHORS
```
```
sudo chown nobody:nogroup VERSION
```
```
sudo chmod 777 VERSION
```
Ну и к папкам

```
sudo chown nobody:nogroup demodb
```
```
sudo chmod 777 demodb
```
```
sudo chown nobody:nogroup src
```
```
sudo chmod 777 src
```
```
sudo chown nobody:nogroup cf
```
```
sudo chmod 777 cf
```

Коммитим изменения
```
git add .
```
<details>
<summary>Возможно появится ошибка unsafe repository</summary>

Если появляется ошибка
```
fatal: unsafe repository ('/home/mc/demodb' is owned by someone else)
To add an exception for this directory, call:

        git config --global --add safe.directory /home/mc/demodb
```

Выполняем предложенную команду
```
git config --global --add safe.directory /home/mc/demodb
```

И повторяем 
```
git add .
```
</details>

git commit -m "init"
<details>
<summary>Возможно появится ошибка Author identity unknown</summary>

Здесь тоже возможно появление ошибки
```
Author identity unknown

*** Please tell me who you are.

Run

  git config --global user.email "you@example.com"
  git config --global user.name "Your Name"

to set your account's default identity.
Omit --global to set the identity only in this repository.
```

Последовательно выполняем предложенные команды
```
git config --global user.name root
```
Где `root`, это имя пользователя

```
git config --global user.email root@example.com
```
Где `root@example.com`, это имейл пользователя

Повторяем
```
git commit -m "init"
```
</details>

Получаем примерно такой ответ

```
[main (root-commit) a750612] init
 2 files changed, 4 insertions(+)
 create mode 100755 src/cf/AUTHORS
 create mode 100755 src/cf/VERSION
```
Теперь отправляем
```
git push
```

Вводим логин и пароль от гитлаба.

Готово.
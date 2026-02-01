# Gitsync, синхронизация Хранилища 1С и Git

Пока мы работаем с хранилищем, будет необходимо переносить изменения из хранилища в 1С в проект git.
Синхронизация будет выполняться с использованием утилиты Gitsync. 
Эта утилита использует платформу 1С для работы, поэтому на машине с Gitsync должна быть установлена платформа и доступны лицензии.

Рассмотрены варианты работы из windows и ubuntu.

# Gitsync в Windows

Из-за необходимости использования платформы пока Gitsync запускается на машине с виндой, а не на CI сервере.

С эти связана необходимость создавать клон репозитория на  этой же машине.

На момент установки Gitsync уже должен быть установлен OneScript.

Устанавливаем Gitsync
```
opm install gitsync
```

Инициализация плагинов.
```
gitsync plugins init
```

Смотрим список плагинов.
```
gitsync plugins ls -a
```

Включаем необходимый минимум плагинов.
```
gitsync p e increment limit check-authors sync-remote
```

<details>
<summary>Если появляется ошибка</summary>

Если появляется ошибка
```powershell
КРИТИЧНАЯОШИБКА - {Модуль /home/administrator/.local/share/ovm/stable/lib/gitsync/src/core/Классы/internal/files/Модули/РаботаСФайлами.os / Ошибка в строке: 28 / Внешнее исключение (System.TypeInitializationException): The type initializer for 'Newtonsoft.Json.JsonWriter' threw an exception.}
```
![Alt text](images/Gitlab-gitsync-mono-error.png)

Значит не установлен mono.

Процесс установки описан на сайте проекта - [Download - Stable | Mono (mono-project.com)](https://www.mono-project.com/download/stable/#download-lin)

---

</details>

Проверяем.
```
gitsync plugins ls
```

Должен быть такой список, плагины отображаются как `[on]`.

```powershell
Каталог плагинов: </home/administrator/.local/share/gitsync/plugins>
Список плагинов:
 [on] [1.3.0] - increment - Плагин добавляет возможность инкрементальной выгрузки в конфигурации
 [on] [1.3.0] - limit - Плагин добавляет возможность ограничения на минимальный, максимальный номер версии хранилища, а так же на лимит на количество выгружаемых версий за один запуск
 [on] [1.3.0] - check-authors - Плагин добавляет функциональность проверки автора версии в хранилище и файла AUTHORS
 [on] [1.3.0] - sync-remote - Плагин добавляет функциональность синхронизации с удаленным репозиторием git
 ```
Выполняем синхронизацию,

где:

`gitsync`- имя пользователя хранилища;

`\\ubuntuserver1\onecrep` - путь к хранилищу 1с.

`C:\gitrep\erp\src\cf`- путь к git репозиторию.

`--ibconnection` - флаг необходимости использования конкретной базы для конвертации конфигурации

`/S"SERVER1C\serverbase"` - путь к сетевой базе, SERVER1C имя сервера, serverbase имя базы.

Вариант запуска из windows, папка хранилища сетевая, папка гита локальная (есть проблемы с сетевой папкой гита).

```powershell
gitsync sync -u gitsync \\ubuntuserver1\onecrep C:\gitrep\erp\src\cf
```
```powershell
gitsync --verbose --v8version "8.3.16.1876" --ibconnection /S"SERVER1C\serverbase" sync -u gitsync \\ubuntuserver1\onecrep C:\gitrep\erp\src\cf
```

Вариант запуска из windows для конвертации расширения

`--ext` - флаг, указывающий что это расширение.

`Коннект` -  Имя расширения, с которым оно будет подключено в базе.

`\\ubuntuserver1\connect` - путь к хранилищу 1с.

```powershell
gitsync --verbose --v8version "8.3.16.1876" --ibconnection /S"SRUMOWWAA001\gitsync" sync -u gitsync --ext Коннект \\ubuntuserver1\connect C:\gitrep\erp\src\cfe\connect
```

Дополнительные ключи

`--verbose` - признак отладки, для вывода дополнительной информации о процессе.

`--v8version "8.3.16.1876"` - версия платформы.

`--ibconnection /S"myserver\gitsync"` - использование существующей серверной базы. Путь к базе указан в формате “ИМЯСЕРВЕРА\ИМЯБАЗЫ”.

<details>
<summary>Возможные ошибки</summary>

Неправильный синтаксис `VERSION` и `AUTHORS`
```powershell
КРИТИЧНАЯОШИБКА - {Модуль /home/administrator/.local/share/ovm/stable/lib/gitsync/src/core/Классы/МенеджерСинхронизации.os / Ошибка в строке: 1442 / Внешнее исключение (System.Xml.        XmlException): Syntax for an XML declaration is invalid. Line 1, position 31.}
```

Возможно не установлена платформа
```
КРИТИЧНАЯОШИБКА - {Модуль /home/administrator/.local/share/ovm/stable/lib/gitsync/oscript_modules/v8runner/src/v8runner.os / Ошибка в строке: 1903 / Не задан путь к платформе 1С}
```

При запуске из винды возможно неправильно определяется путь. Необходимо замапить сетевой путь как диски. Кроме того, эти диски должны быть доступны в командной строке (cmd), для этого возможно потребуется изменение реестра.
```
CMD.EXE was started with the above path as the current directory.
```
---

</details>

В итоге получаем примерно такое сообщение об успехе

```powershell
C:\Windows\System32>gitsync sync -u user H:\ C:\GitRepo\demodb\src\cf
ИНФОРМАЦИЯ - Начало выполнение команды <sync>
ИНФОРМАЦИЯ - Начата синхронизация с git
ИНФОРМАЦИЯ - Номер синхронизированной версии: 0
ИНФОРМАЦИЯ - Номер последней версии в хранилище: 3
ИНФОРМАЦИЯ - Получаем исходники для версии 1, 28.05.2022 8:42:14
WARNING: Constructor of Console is obsolete. Use global property Консоль/Console
ИНФОРМАЦИЯ - Определяю тип возможной выгрузки конфигурации в файлы
ИНФОРМАЦИЯ - Тип выгрузки конфигурации в файлы: ПОЛНАЯ ВЫГРУЗКА
ИНФОРМАЦИЯ - Получаем исходники для версии 2, 28.05.2022 8:42:35
WARNING: Constructor of Console is obsolete. Use global property Консоль/Console
ИНФОРМАЦИЯ - Определяю тип возможной выгрузки конфигурации в файлы
ИНФОРМАЦИЯ - Тип выгрузки конфигурации в файлы: ИНКРЕМЕНТАЛЬНАЯ ВЫГРУЗКА
ИНФОРМАЦИЯ - Получаем исходники для версии 3, 28.05.2022 8:42:47
WARNING: Constructor of Console is obsolete. Use global property Консоль/Console
ИНФОРМАЦИЯ - Определяю тип возможной выгрузки конфигурации в файлы
ИНФОРМАЦИЯ - Тип выгрузки конфигурации в файлы: ИНКРЕМЕНТАЛЬНАЯ ВЫГРУЗКА
ИНФОРМАЦИЯ - Завершена синхронизации с git
ИНФОРМАЦИЯ - Завершено выполнение команды <sync>
```

Посмотреть результат можно выполнив команду
```
git log
```

Получится примерно такое
```
PS C:\GitRepo\demodb> git log
commit 9bd8410c8a29133d8073622ae675341f5a94198f (HEAD -> main)
Author: root <root@example.com>
Date:   Thu May 26 16:49:23 2022 +0300

    Еще один важный коммит

commit df901da57df706fedaecc35107756cdfac9bd196
Author: root <root@example.com>
Date:   Wed May 18 13:59:50 2022 +0300

    Важный коммит 1

:
```

Теперь пушим изменения на сервер.
```
git push
```

# Gitsync в Ubuntu

На момент установки Gitsync уже должен быть установлен OneScript.

Устанавливаем Gitsync
```
opm install gitsync
```

Инициализация плагинов.
```
gitsync plugins init
```

Смотрим список плагинов.
```
gitsync plugins ls -a
```

Включаем необходимый минимум плагинов.
```
gitsync p e increment limit check-authors sync-remote
```

<details>
<summary>Возможные ошибки</summary>

Если появляется ошибка 
```powershell
КРИТИЧНАЯОШИБКА - {Модуль /home/administrator/.local/share/ovm/stable/lib/gitsync/src/core/Классы/internal/files/Модули/РаботаСФайлами.os / Ошибка в строке: 28 / Внешнее исключение (System.TypeInitializationException): The type initializer for 'Newtonsoft.Json.JsonWriter' threw an exception.}
```
![Alt text](images/Gitlab-gitsync-mono-error.png)
Значит не установлен mono.

Процесс установки описан на сайте проекта - [Download - Stable | Mono (mono-project.com)](https://www.mono-project.com/download/stable/#download-lin)
---
</details>

Проверяем.
```
gitsync plugins ls
```

Должен быть такой список, плагины отображаются как `[on]`.
```
Каталог плагинов: </home/administrator/.local/share/gitsync/plugins>
Список плагинов:
 [on] [1.3.0] - increment - Плагин добавляет возможность инкрементальной выгрузки в конфигурации
 [on] [1.3.0] - limit - Плагин добавляет возможность ограничения на минимальный, максимальный номер версии хранилища, а так же на лимит на количество выгружаемых версий за один запуск
 [on] [1.3.0] - check-authors - Плагин добавляет функциональность проверки автора версии в хранилище и файла AUTHORS
 [on] [1.3.0] - sync-remote - Плагин добавляет функциональность синхронизации с удаленным репозиторием git
 ```

Выполняем синхронизацию,

где:

`gitsync`- имя пользователя хранилища;

`\\ubuntuserver1\onecrep` - путь к хранилищу 1с.

`C:\gitrep\erp\src\cf`- путь к git репозиторию.

`--ibconnection` - флаг необходимости использования конкретной базы для конвертации конфигурации

`/S"SERVER1C\serverbase"` - путь к сетевой базе, SERVER1C имя сервера, serverbase имя базы.

Вариант запуска из linux, папки локальные
```
gitsync sync -u user /var/onecrep /var/gitrep/democonf/src/cf
```
<details>
<summary>Возможные ошибки</summary>

Неправильный синтаксис `VERSION` и `AUTHORS`
```powershell
КРИТИЧНАЯОШИБКА - {Модуль /home/administrator/.local/share/ovm/stable/lib/gitsync/src/core/Классы/МенеджерСинхронизации.os / Ошибка в строке: 1442 / Внешнее исключение (System.Xml.        XmlException): Syntax for an XML declaration is invalid. Line 1, position 31.}
```

Возможно не установлена платформа
```powershell
КРИТИЧНАЯОШИБКА - {Модуль /home/administrator/.local/share/ovm/stable/lib/gitsync/oscript_modules/v8runner/src/v8runner.os / Ошибка в строке: 1903 / Не задан путь к платформе 1С}
```
---

</details>
# Исключения файлов из анализа

Если требуется исключить какие-то файлы из анализа (например регламентированные отчеты, в которых много ошибок дубликации кода), то необходимо изменить файл `sonar-project.properties`, который находится в папке проекта.

Исключения задаются в `sonar.cpd.exclusions`.

Есть особенность - кириллицу требуется переводить в юникод.

Ресурс для перевода в юникод - Юникод-кодировщик - [Таблица символов Юникода (unicode-table.com)](https://unicode-table.com/ru/tools/decoder/)

Пример файла:

```properties
sonar.projectKey=erp
sonar.projectName=erp

sonar.sources=src/cf

sonar.sourceEncoding=UTF-8

sonar.inclusions=**/*.bsl
sonar.cpd.exclusions=**/\u0420\u0435\u0433\u043b\u0430\u043c\u0435\u043d\u0442\u0438\u0440\u043e\u0432\u0430\u043d\u043d\u044b\u0439\u041e\u0442\u0447\u0435\u0442*/**/*.*
```
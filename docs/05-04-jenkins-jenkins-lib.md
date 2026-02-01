# Подключаем Jenkins-lib

Мы подошли к кульминационному моменту.

**Manage Jenkins** - **System**

Ищем раздел **Global Trusted Pipeline Libraries** и нажимаем **+Add**.

Заполняем

| Поле | Значение | Комментарий |
| - | - | - |
| Name | jenkins-lib | - |
| Default version | v0.16.0 | Берем последнюю версию |
| Load implicitly | ✅ | Чтобы эта библиотека всегда загружалась по умолчанию |
| Retrieval method | Modern SCM | - |
| Source Code Management | Git | - |
| Project Repository | https://github.com/firstBitMarksistskaya/jenkins-lib | - |

Жмем **Save**.
# Агент Sonarqube для Jenkins

К этому моменту контейнер SonarQube должен быть уже установлен.

**Dashboard** - **Manage Jenkins** - **Manage nodes and clouds** - **Configure Clouds**.

Скролим вниз, до кнопки **Docker Agent templates**. Нажимаем.

**Labels**: `sonar`

**Image**: `astrizhachuk/sonar-scanner-cli:latest` 
*(см kropachev/sonar-scanner-cli: Sonar Scanner for GitLab CI/CD and Jenkins (github.com))*

**Command**: не меняем.

**Working Directory**: `/home/jenkins`

**User**: `root`

Жмем **Save**.
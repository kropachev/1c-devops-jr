# HTTPS для сервисов в k3s

В нормальных условиях сертификат нам выдадут коллеги из инфраструктуры. А для домашнего использования мы выпустим сертификаты сами.

| Назначение | Файл | Где используется |
| - | - | - |
| **TLS-сертификат сервиса** | `tls.crt` + `tls.key` | Ingress / сервисы (HTTPS). TLS-сертификат нужен **серверу**, чтобы принимать HTTPS-соединения |
| **Корневой CA-сертификат** | `onecci-root-ca.crt`  | Клиенты (Jenkins, CI-агенты, runners, git, curl).  CA-сертификат нужен **клиенту**, чтобы считать этот TLS-сертификат доверенным |

## Подготовка рабочей директории

Создаем папку для наших сертификатов.

```bash
mkdir -p /k3s-1c-ci/tls
cd /k3s-1c-ci/tls
```
## Root CA

Root CA (корневой центр сертификации) используется для подписания серверных сертификатов
тестового контура CI. Root CA создается один раз и имеет увеличенный срок действия.

- НЕ загружается в Kubernetes
- НЕ используется в Ingress
- устанавливается в доверенные на узлах k3s
- опционально устанавливается на клиентские машины (браузеры)

Создаем конфигурацию Root CA:
```bash
nano openssl-root-ca.cnf
```

Содержимое файла `openssl-root-ca.cnf`.  
Обратите внимание - здесь не указываются ip или адреса наших доменов.
```ini
[ req ]
default_bits       = 4096
prompt             = no
default_md         = sha256
distinguished_name = dn
x509_extensions    = v3_ca

[ dn ]
C  = RU
ST = Test State
L  = Test Locality
O  = Test Organization
OU = 1C CI
CN = onecci Root CA

[ v3_ca ]
basicConstraints = critical, CA:TRUE, pathlen:0
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
```

Выпускаем Root CA (срок - 10 лет):
```bash
openssl req -x509 -new -nodes -days 3650 \
  -newkey rsa:4096 \
  -keyout onecci-root-ca.key \
  -out onecci-root-ca.crt \
  -config openssl-root-ca.cnf
```

Файлы Root CA:
- `onecci-root-ca.crt` - корневой сертификат
- `onecci-root-ca.key` - приватный ключ Root CA

> ⚠️ Приватный ключ Root CA (onecci-root-ca.key) нужно хранить максимально аккуратно. Он не должен попадать в Kubernetes и репозитории.

### Серверный сертификат

Создаем конфигурационный файл OpenSSL.
Данная конфигурация используется для выпуска серверного (leaf) сертификата.  
Параметр `CA:FALSE` означает, что сертификат не является центром сертификации.

```bash
nano openssl.cnf
```

Содержимое файла `openssl.cnf`:

```ini
[ req ]
default_bits       = 2048
prompt             = no
default_md         = sha256
distinguished_name = dn
req_extensions     = v3_req

[ dn ]
C  = RU
ST = Test State
L  = Test Locality
O  = Test Organization
OU = 1C CI
CN = *.onecci.lan

[ v3_req ]
subjectAltName = @alt_names

[ v3_ext ]
basicConstraints = critical, CA:FALSE
subjectAltName = @alt_names
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectKeyIdentifier = hash

[ alt_names ]
# wildcard
DNS.1 = *.onecci.lan
# по именам
# DNS.1 = portainer.onecci.lan
# DNS.4 = registry.onecci.lan
# DNS.4 = gitlab.onecci.lan
# DNS.2 = jenkins.onecci.lan
# DNS.3 = sonarqube.onecci.lan
```

<details>
  <summary>Описание параметров</summary>

#### Раздел `[ req ]`

- **default_bits = 2048** - длина RSA-ключа. 2048 бит является минимально рекомендуемым значением и поддерживается всеми браузерами и TLS-библиотеками
- **prompt = no** - отключает интерактивные вопросы при генерации сертификата. Все значения берутся из файла конфигурации
- **default_md = sha256** - алгоритм хеширования для подписи сертификата. SHA-256 является текущим стандартом
- **distinguished_name = dn** - ссылка на раздел `[ dn ]`, в котором описывается субъект сертификата
- **req_extensions = v3_req** - расширения, которые будут добавлены в CSR (запрос на сертификат)

#### Раздел `[ dn ]` (Distinguished Name)

Используется для заполнения идентификационной информации сертификата. 

- **C** - страна (Country).
- **ST** - регион / субъект (State).
- **L** - город или местоположение (Locality).
- **O** - организация (Organization).
- **OU** - подразделение (Organizational Unit).
- **CN** - Common Name. В современных TLS-реализациях **не участвует в проверке адреса**, оставлен для совместимости и читаемости.

#### Раздел `[ v3_ext ]` (X.509 расширения)

- **basicConstraints** - Ограничение роли сертификата: может ли он быть центром сертификации (CA):
  - `critical` - если клиент не понимает это поле, он обязан отклонить сертификат;
  - `CA:FALSE` - это конечный (leaf) сертификат, не имеющий права подписывать другие;
- **subjectAltName = @alt_names** - ключевое расширение. Определяет список допустимых адресов (IP или DNS), для которых сертификат считается валидным.
- **keyUsage** - определяет допустимое использование ключа:
  - `critical` - если клиент не понимает это поле, он обязан отклонить сертификат;
  - `digitalSignature` - разрешает подпись данных, подпись TLS-рукопожатия;
  - `keyEncipherment` - разрешает шифрование ключей при TLS-рукопожатии;
- **extendedKeyUsage = serverAuth** - указывает, что сертификат предназначен для серверной аутентификации (HTTPS).
- **subjectKeyIdentifier = hash** - указывает автоматически сформировать значение Subject Key Identifier как хеш открытого ключа при выпуске сертификата.

#### Раздел `[ alt_names ]`
В разделе заполняется список адресов сервисов, для которых выпускается сертификат.

Допустимы варианты:
- **DNS.1 = <адрес-сервиса>** - DNS.1, DNS.2 и т.д. запись для каждого имени.
- **DNS.1 = \*.onecci.lan** - вариант с **wildcard-сертификатом**, вместо перечисления всех сервисов можно указать одно имя со звездочкой. В этом случае сертификат будет валиден для всех поддоменов  

</details>

Генерируем приватный ключ и CSR (запрос на сертификат):
```bash
openssl req -new -nodes \
  -newkey rsa:2048 \
  -keyout tls.key \
  -out tls.csr \
  -config openssl.cnf
```

Подписываем CSR нашим Root CA и получаем серверный сертификат (leaf) (срок действия - 2 года):
```bash
openssl x509 -req -days 730 -sha256 \
  -in tls.csr \
  -CA onecci-root-ca.crt \
  -CAkey onecci-root-ca.key \
  -CAcreateserial \
  -out tls.crt \
  -extfile openssl.cnf \
  -extensions v3_ext
```

Получится три файла:

- `tls.crt` - серверный сертификат (leaf), подписанный Root CA
- `tls.key` - приватный ключ
- `tls.csr` -  можно хранить для повторного выпуска сертификата, но в Kubernetes он не нужен.

### Проверяем SAN в готовом сертификате

После выпуска сертификата рекомендуется проверить его содержимое:

```bash
openssl x509 -in tls.crt -noout -text | grep -A1 "Subject Alternative Name"
```

В выводе должен присутствовать адрес DNS указанный в `openssl.cnf`.

## Установка Root CA в доверенные на узлах k3s

Если в кластере используется одна виртуальная машина (наш случай), Root CA достаточно установить только на нее.

Root CA:
- обязателен для узлов k3s
- опционален для клиентских машин (браузеров)

Копируем Root CA в системное хранилище сертификатов и обновляем trust store:

```bash
sudo cp /k3s-1c-ci/tls/onecci-root-ca.crt /usr/local/share/ca-certificates/onecci-root-ca.crt
sudo update-ca-certificates
```

## Traefik - увеличенные таймауты (ошибка 504 на больших запросах)

```bash
nano traefik-timeouts.yaml
```

```yaml
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    additionalArguments:
      - "--entryPoints.websecure.transport.respondingTimeouts.readTimeout=600s"
      - "--entryPoints.websecure.transport.respondingTimeouts.writeTimeout=600s"
      - "--entryPoints.websecure.transport.respondingTimeouts.idleTimeout=600s"
```
Применяем
```bash
kubectl apply -f traefik-timeouts.yaml
kubectl -n kube-system rollout restart deploy/traefik
kubectl -n kube-system logs deploy/traefik --tail=50
```

## Общее описание настроек при установке сервисов

По мере установки сервисов мы будем настраивать использование сертификатов. Конкретные настройки описаны в соответствующих разделах инструкции, здесь представлено общее описание и общие команды.  
Конкретные команды представлены в отдельных инструкциях для каждого устанавливаемого сервиса.

### Добавляем CA-сертификат клиенстким сервисам (общее описание)

Корневой CA-сертификат хранится централизованно и используется всеми клиентами, которые обращаются к сервисам `*.onecci.lan` по HTTPS.

Мы будем создавать **ConfigMap** по мере необходимости **namespace**, где есть клиенты (Jenkins, CI-агенты и т.д.).

Общая команда выглядит так.  
Конкретные команды представлены в соответствующих разделах инструкции.
```bash
kubectl create configmap onecci-root-ca \
  --from-file=onecci-root-ca.crt=/k3s-1c-ci/tls/onecci-root-ca.crt \
  -n <namespace>
```

### Создаем Kubernetes TLS Secret (общее описание)

Kubernetes Secret привязан к namespace. Ingress может ссылаться на TLS Secret только внутри своего namespace.  
Мы используем один и тот же сертификат, но Secret создаем в каждом нужном namespace.

Это означает:
- если все сервисы находятся в одном namespace - Secret нужен только один;
- ⚠️ если сервисы разнесены по разным namespace (например jenkins, sonarqube, registry) - TLS Secret нужно создать в каждом таком namespace.

Сертификат и ключ необходимо загрузить в Kubernetes в виде TLS Secret.  
В Kubernetes загружается ТОЛЬКО серверный сертификат (leaf) и его приватный ключ.  
**Root CA** в Kubernetes Secret **не добавляется**.  

У нас сертификаты уже хранятся централизованно:
- `/k3s-1c-ci/tls/tls.crt`
- `/k3s-1c-ci/tls/tls.key`

Я использую одинаковое имя TLS секретов для всех сервисов по имени домена, например `onecci.lan.tls`. Secret является namespaced-ресурсом, поэтому одинаковое имя в разных namespace не конфликтует.

Команда создает Secret или обновляет, если, например, был перевыпущен сертификат.  
Конкретные команды представлены в соответствующих разделах инструкции.
```bash
kubectl create secret tls onecci.lan.tls \
  --cert=/k3s-1c-ci/tls/tls.crt \
  --key=/k3s-1c-ci/tls/tls.key \
  -n <namespace> \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Настройка Ingress (общее описание)

Для доступа по имени необходимо создать и применить Kubernetes-манифест Ingress в виде обычного YAML-файла (например `jenkins-ingress.yaml`).

Ingress-манифест это описание правил маршрутизации для Traefik: по какому имени или пути запрос должен быть направлен в какой сервис.

Пример манифеста с доступом по имени `servicename` и доступного по порту `8080`. :
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: <servicename>
  namespace: <servicename>
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  ingressClassName: traefik
  tls:
    - secretName: onecci.lan.tls
      hosts:
        - <servicename>.onecci.lan
  rules:
    - host: <servicename>.onecci.lan
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: <servicename>
                port:
                  number: <8080>
```

<details>
  <summary>Описание параметров</summary>

На что обратить внимание.

- **metadata.name** - Имя Ingress-ресурса внутри namespace. Используется Kubernetes для идентификации объекта.
- **metadata.namespace** - Namespace, в котором действует Ingress. Должен совпадать с namespace сервиса и TLS Secret.
- **spec.tls.secretName** - Имя Kubernetes Secret типа kubernetes.io/tls, содержащего сертификат и приватный ключ. Secret обязательно должен существовать в том же namespace, что и Ingress.
- **spec.tls.hosts** - определяет список доменных имен (хостов), к которым применяется указанный TLS-сертификат и ключ, хранящиеся в связанном секрете (secretName).
- **spec.rules.host** - Доменное имя, по которому Traefik принимает запросы, должно резолвиться в IP виртуальной машины (через DNS на роутере), присутствовать в SAN сертификата (или быть покрыто wildcard-сертификатом).
- **spec.rules.http.paths.path** - URL-путь, для которого действует правило маршрутизации. / означает весь сайт.
- **spec.rules.http.paths.pathType: Prefix** - Означает, что правило применяется ко всем путям, начинающимся с указанного префикса.
- **backend.service.name** - Имя Kubernetes Service, в который Traefik проксирует запрос.
- **backend.service.port.number** - Порт Service, на который направляется трафик (обычно HTTP-порт приложения внутри кластера).

</details>


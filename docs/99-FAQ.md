# FAQ

## Посмотреть список namespace

```bash
kubectl get ns
```

## Посмотреть список подов в namespace

```bash
kubectl get pods -n <namespace>
```
## Проверить статус пода

```bash
kubectl describe pod <pod-name> -n <namespace>
```

## Удалить под

```bash
kubectl delete pod <pod-name> -n <namespace>
```

# Удаляем Helm-приложение из k3s

Этот раздел универсальный. Подходит **для любого приложения в k3s**, установленного через Helm (GitLab, Jenkins, SonarQube и т.д.). Ниже приведены **два варианта удаления**.

## Вариант A. Быстрый reset (рекомендуется)

Используется вариант, если:

- данных в приложении нет или они не нужны;
- namespace используется **только** этим приложением;
- цель - полностью снести и поставить заново без отладки.

### Шаг A1. Удаляем namespace целиком

```bash
kubectl delete namespace <namespace>
```

Дождаться завершения.

Что сделает Kubernetes:

- удалит все pods;
- удалит все services;
- удалит все deployments / statefulsets / jobs;
- удалит все secrets и configmaps;
- удалит все PVC, связанные с этим namespace.

Это **самый быстрый** для homelab.

## Вариант B. Контролируемое удаление (shared / prod namespace)

Вариант используется при следующих условиях:

- namespace используется несколькими приложениями;
- нужно сохранить часть ресурсов;
- требуется корректное удаление Helm hooks.

### Удаляем Helm release

```bash
helm -n gitlab uninstall gitlab
```

Проверка:

```bash
helm -n gitlab list
```

Ожидаемо: пусто.

### Проверяем, что workload'ы исчезли

```bash
kubectl -n gitlab get pods
kubectl -n gitlab get deploy
kubectl -n gitlab get statefulset
kubectl -n gitlab get job
```

Если что-то осталось:

```bash
kubectl -n gitlab delete all --all
```

### Удаляем PVC (важно)

GitLab активно использует PersistentVolumeClaims. Они **не удаляются автоматически** при `helm uninstall`.

```bash
kubectl -n gitlab get pvc
```

Если список не пустой:

```bash
kubectl -n gitlab delete pvc --all
```

### Удаляем secrets и configmaps

```bash
kubectl -n gitlab delete secret --all
kubectl -n gitlab delete configmap --all
```

Сюда входят:

- root password secret;
- TLS / CA secrets;
- внутренние secrets GitLab.

### (Опционально) Удаляем namespace

Если после контролируемой чистки namespace больше не нужен:

```bash
kubectl delete namespace gitlab
```

## Проверка, что GitLab удален полностью

```bash
kubectl get all -A | grep -i gitlab || echo "GitLab полностью удален"
helm list -A | grep gitlab || echo "Helm release отсутствует"
```
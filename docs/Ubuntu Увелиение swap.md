# Увелиение swap

Скорее всего понадобится, т.к. сонар очень требовательный.

Проверяем файл подкачки
```
swapon --show
```

Консоль выдаст ответ
```
NAME      TYPE SIZE USED PRIO
/swapfile file   2G 1,9G   -2
```

Размер свободной оперативной памяти перед увеличением свопа должен быть больше занятого свопа, потому что при отключении, все данные из файла будут загружены в оперативную память.

Отключаем своп
```
sudo swapoff /swapfile
```

Указываем новый размер
```
sudo fallocate -l 10G /swapfile
```

Проверяем
```
sudo mkswap /swapfile
```

В консоли должен быть уже новый размер
```
mkswap: /swapfile: warning: wiping old swap signature.
Setting up swapspace version 1, size = 10 GiB (10737414144 bytes)
no label, UUID=43fbb832-6794-4650-9964-60ff9e7dd6b9
```

Включаем файл подкачки
```
sudo swapon /swapfile
```

Готово.
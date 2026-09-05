# Откат и восстановление

## Главное правило

До patch/flash сохраните собственный полный `vendor_b.img` и его SHA-256. Не
используйте vendor от другой ревизии X6515 или чужого build.

## Откат brightness fix

Если Android загружается:

```sh
adb reboot fastboot
```

Если Android не загружается, войдите в bootloader/recovery аппаратной комбинацией
и выберите fastbootd. Убедитесь, что виден правильный слот:

```sh
fastboot devices
fastboot getvar is-userspace
fastboot getvar current-slot
fastboot getvar partition-size:vendor_b
```

Размер backup обязан совпадать с размером раздела. Затем:

```sh
fastboot flash vendor_b backups/vendor_b.img
fastboot reboot
```

Для проверенного V1307 backup имел:

```text
size    500649984 bytes
SHA256  b0e44ada3b32e8d230f1863ee5e27d0225903765d9ae7e8f3ead857ac4c755e4
```

Это контрольное значение конкретного тестового телефона, а не разрешение
скачивать случайный образ с таким названием.

## Откат GSI

Сохраните исходный `bvS`/`bvN` system image. Его можно повторно прошить в
`system_b` из fastbootd. Если userdata несовместима или boot animation зациклен,
может потребоваться factory reset из recovery.

## dm-verity

После возврата полностью исходных system/vendor при желании:

```sh
adb root
adb enable-verity
adb reboot
```

Не включайте verity, пока раздел содержит modified HAL: исправление снова будет
отклонено или исправлено FEC.

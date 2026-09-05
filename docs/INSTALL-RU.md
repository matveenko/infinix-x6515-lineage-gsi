# Установка LineageOS 19.1 GSI на X6515

Документ описывает именно проверенный аппарат `Infinix X6515`, а не похожие по
названию Smart 7 с другим SoC или layout.

## Требования

- заряд не ниже 70%;
- резервная копия пользовательских данных;
- включённые OEM unlocking и USB debugging;
- качественный data-кабель; старый USB-хаб допустим, если ADB и fastboot видят
  устройство стабильно;
- Android Platform Tools;
- GSI `arm64_bvN` или `arm64_bvS` для A/B и system-as-root;
- понимание, что unlock полностью очищает userdata.

Проверенный GSI:

```text
lineage-19.1-20250606-UNOFFICIAL-arm64_bvN.img
SHA256 65ae1cc41d48c15bdf40d159ece55b473fafcdc8596e127ffab13cf0b36a0e5b

lineage-19.1-20250606-UNOFFICIAL-arm64_bvS.img
SHA256 49792f857b54c6c950bacc6e7c742b39a3dea672aa08072c70878743fb062f76
```

`bvN` — vanilla без встроенного root; `bvS` — PHH-SU/root variant. Не смешивайте
эти обозначения с `vndklite` или 32-bit binder builds.

## 1. Инвентаризация

`00-doctor.sh` — единственный скрипт репозитория, который нужен на этапе
подготовки к GSI. Он ничего не изменяет: только проверяет доступность `adb` и
`fastboot`, модель, MediaTek MT6761, Treble, ARM64, fingerprint и активный слот.

```sh
./scripts/00-doctor.sh
adb devices -l
adb shell getprop ro.product.model
adb shell getprop ro.treble.enabled
adb shell getprop ro.product.cpu.abilist
adb shell getprop ro.boot.slot_suffix
```

Ожидаются X6515, Treble `true`, `arm64-v8a` и A/B slot suffix.

## 2. Unlock

Разблокировка уничтожит userdata:

```sh
adb reboot bootloader
fastboot devices
fastboot flashing unlock
```

Подтвердите unlock аппаратными кнопками. После wipe снова включите USB debugging.

## 3. Fastbootd

Dynamic logical partitions прошиваются из userspace fastboot:

```sh
adb reboot fastboot
fastboot getvar is-userspace
fastboot getvar current-slot
```

Ожидается `is-userspace: yes`. В проверенной установке активным был слот B.
Ниже команды специально используют `_b`; не копируйте их, если ваш слот другой.

## 4. Освобождение места и system

На тестовом layout недостаточно свободного места для 2-ГБ system image. Был
удалён snapshot/COW логического `product_b`, а `system_b` увеличен до размера
образа. Это устройство-зависимая операция: сначала сохраните вывод
`fastboot getvar all` и убедитесь в именах разделов.

```sh
fastboot delete-logical-partition product_b-cow
fastboot resize-logical-partition system_b 2121457664
fastboot flash system_b lineage-19.1-20250606-UNOFFICIAL-arm64_bvS.img
fastboot reboot
```

Размер `2121457664` относится к указанному образу. Для другого GSI используйте
его фактический размер в байтах.

## 5. Первый старт и factory reset

На тестовом X6515 `fastboot -w` завершался ошибкой vendor fastboot wipe tasks, а
Lineage зависал из-за старого userdata. Решение:

1. загрузиться в recovery;
2. выполнить `Factory reset / Format data`;
3. перезагрузиться в System.

Первый старт может быть долгим. Не отключайте питание во время анимации без
диагностики ADB/logcat.

## 6. Root variant

Переход с `bvN` на соответствующий `bvS` того же релиза выполнялся повторной
прошивкой `system_b` без wipe. Перед этим убедитесь, что userdata уже корректно
создана и имеется рабочий путь в recovery/fastbootd.

После загрузки root-ADB включается в Developer options / PHH settings:

```sh
adb root
adb shell id
```

Ожидается `uid=0(root)`.

## 7. Базовая проверка

Проверьте Wi-Fi, SIM detection, звук, Bluetooth, fingerprint, rotation, power
button, камеру, звонки и мобильные данные до установки дополнительного софта.

## 8. Что делать со скриптами после установки

На этом установка GSI закончена. Остальные скрипты не нужны для самой прошивки
LineageOS — они образуют отдельный безопасный конвейер исправления яркости:

```text
00-doctor        убедиться, что подключён именно проверенный X6515/slot B
10-dump-vendor   снять и проверить собственный backup vendor_b
20-patch-vendor  собрать из backup изменённый vendor image на Mac
30-disable-verity отключить восстановление изменённого блока через verity/FEC
40-flash-vendor  проверить образ и прошить его только через fastbootd
50-verify        проверить HAL и аппаратный результат 4080/4095
```

Полные команды, необходимые перезагрузки и объяснение риска находятся в
[инструкции по исправлению яркости](BRIGHTNESS-FIX-RU.md#применение-готовых-скриптов).

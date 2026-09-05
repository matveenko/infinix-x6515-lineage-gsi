# Исправление яркости X6515

## Симптом

LineageOS 19.1 GSI загружалась и работала, но максимальная яркость была сильно
ниже XOS. Framework показывал `1.0`/`255`, а драйвер получал только `37`:

```sh
settings get system screen_brightness
# 255

cat /sys/class/leds/lcd-backlight/brightness
# 37

cat /sys/class/leds/lcd-backlight/max_brightness
# 4095
```

Прямая запись `4095` в sysfs доказала, что панель и kernel driver исправны.

## Ошибочный PHH workaround

Переключатель **Force alternative backlight scale** задаёт:

```text
persist.sys.phh.backlight.scale=1
persist.sys.qcom-brightness=4095
```

В PHH-патче `LightsService` этот режим передаёт масштабированное целое значение
не как ARGB, а напрямую в `LightState.color`. Это подходит отдельным Qualcomm
HAL, но MediaTek HAL X6515 интерпретирует `4095` как RGB `0x00000fff` и снова
вычисляет яркость из каналов. Результат — около `37/4095`.

Поэтому перед проверкой фикса нужно выключить alternative scale:

```sh
adb shell setprop persist.sys.phh.backlight.scale 0
```

PHH property handler после этого выставляет `persist.sys.qcom-brightness=-1`.

## Vendor HAL

Исполняемый файл:

```text
/vendor/bin/hw/android.hardware.lights-service.mediatek
```

Проверенный исходный SHA-256:

```text
798a48b2ecf51cdfc73017d01c2de748764cbcebaf4ab85bec83edb7747f316f
```

Бинарник вычисляет взвешенную яркость RGB:

```text
(29 * B + 150 * G + 77 * R) >> 8
```

Сумма коэффициентов равна 256, поэтому для серого `R=G=B=255` результатом
становится 255. Но панель X6515 имеет 4095 уровней.

Дизассемблирование проблемного участка:

```asm
3eb4: and   w9, w8, #0xff
3eb8: mul   w9, w9, w10
3ebc: ubfx  w10, w8, #8, #8
3ec0: ubfx  w8, w8, #16, #8
3ec4: madd  w9, w10, w11, w9
3ec8: madd  w8, w8, w12, w9
3ecc: lsr   w21, w8, #8
```

Патч меняет только последний сдвиг:

```diff
- 15 7d 08 53    lsr w21, w8, #8
+ 15 7d 04 53    lsr w21, w8, #4
```

Итоговая формула сохраняет форму штатной кривой и умножает результат на 16.
Максимум становится `4080/4095`; разница 0,37% визуально неразличима.

## Почему не daemon

Первый диагностический прототип читал Android setting и писал значение в sysfs
каждые 200 мс. Он подтвердил рабочий диапазон, но соревновался с Lights HAL,
вызывая скачки. Остановка HAL вызвала перезапуск Android framework watchdog'ом.

Финальный патч выполняется внутри штатного Binder HAL только при изменении
яркости. Нет polling, дополнительных wakeup и фонового расхода батареи.

## Transsion properties

В HAL найдены свойства:

```text
ro.vendor.transsion.backlight_hal.optimization
ro.vendor.transsion.hbm_mode_hal.support
```

Первое меняет vendor-логику идентификаторов lights. На этой GSI принудительное
включение привело к `Lights id 0 does not exist`, поэтому оно не является
решением и в patcher не используется.

## dm-verity и FEC

После первой прошивки modified `vendor_b` блочный раздел имел новый SHA, но
смонтированный `/vendor` всё ещё показывал исходный HAL. `vendor-verity`
обнаруживал изменённый блок и FEC прозрачно восстанавливал исходные данные.

На проверенной userdebug/root GSI использована штатная команда:

```sh
adb root
adb disable-verity
adb reboot
```

После этого `/vendor` монтируется непосредственно с `vendor_b`, и patched HAL
имеет ожидаемый SHA:

```text
619f0f16b5869a4d9ec4e234643258151b41471b8af8a941b4089e59bc9ab02a
```

## Применение готовых скриптов

Этот этап выполняется **после успешной установки и загрузки root-варианта
LineageOS**. На Mac должны быть Android Platform Tools, Python 3 и `e2fsprogs`:

```sh
brew install e2fsprogs
```

Запускайте команды из корня клонированного репозитория.

Сначала подключите загруженный Android с включённой root-отладкой. Проверьте
телефон и снимите собственный `vendor_b`:

```sh
./scripts/00-doctor.sh
./scripts/10-dump-vendor.sh
```

В результате появится `backups/vendor_b.img`. Скрипт продолжит работу только
при точном размере и SHA-256 проверенного V1307. Скопируйте этот исходный backup
ещё в одно безопасное место, затем соберите изменённый образ:

```sh
./scripts/20-patch-vendor.sh \
  backups/vendor_b.img \
  builds/vendor_b-x6515-brightness.img
```

Теперь отключите verity. Скрипт запросит буквальное подтверждение
`DISABLE-VERITY`:

```sh
./scripts/30-disable-verity.sh
adb reboot
```

Дождитесь полной загрузки Android, снова убедитесь, что ADB доступен, и войдите
в **fastbootd**, а не обычный bootloader fastboot:

```sh
adb reboot fastboot
fastboot getvar is-userspace
# ожидается: is-userspace: yes
```

Прошейте собранный образ. `40-flash-vendor.sh` повторно проверит размер,
патченный HAL, fastbootd, активный слот B и размер раздела, после чего запросит
`FLASH-VENDOR-B`:

```sh
./scripts/40-flash-vendor.sh builds/vendor_b-x6515-brightness.img
```

После полной загрузки Android выполните автоматическую проверку. Она выключает
PHH alternative scale, переводит яркость в ручной режим и временно выставляет
максимум:

```sh
./scripts/50-verify-brightness.sh
```

Успешный итог: patched HAL запущен, sysfs показывает `4080/4095`. Затем вручную
проверьте ползунок, минимум, середину, сон/пробуждение и touch. При проблемах
используйте [инструкцию восстановления](RECOVERY-RU.md).

## Проверка

```sh
adb root
adb shell settings put system screen_brightness_mode 0
adb shell settings put system screen_brightness 255
adb shell cat /sys/class/leds/lcd-backlight/brightness
# 4080
```

Также обязательно проверить минимум, середину, движение ползунка в обе стороны,
сон/пробуждение, touch и отсутствие рестартов `vendor.light-default`.

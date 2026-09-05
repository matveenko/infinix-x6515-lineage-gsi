# Infinix Smart 7 X6515: LineageOS GSI и исправление яркости

Экспериментальный, воспроизводимый набор для Infinix Smart 7 **X6515** на
MediaTek MT6761. Он документирует установку LineageOS 19.1 GSI и исправляет
ошибочный диапазон подсветки `0..255` при аппаратном диапазоне `0..4095`.

На тестовом устройстве после исправления работают Wi-Fi, звук, Bluetooth,
сканер отпечатка, автоповорот, сон/пробуждение и полный плавный диапазон
яркости. SIM определяется; мобильные данные требуют дополнительной проверки.

## С чего начать

Полная пошаговая установка находится в
**[docs/INSTALL-RU.md](docs/INSTALL-RU.md)**. Не начинайте с команд из краткого
примера ниже: сначала прочитайте инструкцию целиком, особенно разделы про
проверку модели, активный слот B, разблокировку, `fastbootd` и factory reset.

После первого успешного запуска LineageOS переходите к
**[исправлению яркости](docs/BRIGHTNESS-FIX-RU.md)**. Если телефон перестал
загружаться, используйте **[инструкцию по восстановлению](docs/RECOVERY-RU.md)**.

> [!CAUTION]
> Разблокировка загрузчика удаляет все пользовательские данные. Ошибка при
> прошивке dynamic partitions может оставить телефон без загрузки. Проект
> проверен только на X6515 с vendor fingerprint/build семейства V1307.

## Проверенная конфигурация

```text
Model:                 Infinix Smart 7 X6515
Stock build:           X6515-H6127JAk-S-RU-231117V1307
Vendor fingerprint:    Infinix/X6515-OP/Infinix-X6515:12/.../231117V1060:user/release-keys
SoC:                   MediaTek MT6761
Android / VNDK:        12 / 31
Architecture:          ARM64, Binder64
Partition layout:      A/B, dynamic partitions, system-as-root
Tested slot:           B
GSI:                   LineageOS 19.1 arm64_bvS / arm64_bvN
```

## Что лежит в репозитории

- [инструкция по установке](docs/INSTALL-RU.md) — путь от XOS до LineageOS GSI;
- [разбор исправления яркости](docs/BRIGHTNESS-FIX-RU.md) — диагностика,
  дизассемблирование и объяснение фикса;
- [инструкция по восстановлению](docs/RECOVERY-RU.md) — проверенный откат vendor;
- `scripts/` — безопасные dump/patch/flash/verify-скрипты;
- `tools/patch_hal.py` — строгий однобайтовый patcher.

English version: [README.en.md](README.en.md).

## Краткая памятка: исправление яркости

Требуется уже загруженная root/userdebug GSI, разблокированный bootloader,
официальные Android Platform Tools и `e2fsprogs`.

```sh
brew install e2fsprogs
./scripts/00-doctor.sh
./scripts/10-dump-vendor.sh
./scripts/20-patch-vendor.sh backups/vendor_b.img builds/vendor_b-x6515-brightness.img
./scripts/30-disable-verity.sh
adb reboot
# после полной загрузки Android:
adb reboot fastboot
./scripts/40-flash-vendor.sh builds/vendor_b-x6515-brightness.img
# после полной загрузки Android:
./scripts/50-verify-brightness.sh
```

Скрипты намеренно проверяют модель, fingerprint, слот, размер и SHA-256. Они
останавливаются при любом несовпадении.

## Почему здесь нет готового `vendor.img`

Vendor содержит проприетарные компоненты производителя. Проект не
распространяет их и не предлагает универсальный бинарник. Пользователь снимает
собственный `vendor_b`, а patcher принимает только известный SHA-256 и меняет
одну инструкцию в известном HAL.

## Результат фикса

```text
До PHH alternative scale:  Android 255 -> sysfs 37/4095
Без alternative scale:     Android 255 -> sysfs 255/4095
После HAL patch:            Android 255 -> sysfs 4080/4095
```

Инструкция ARM64 по адресу/смещению `0x3ecc`:

```diff
- 15 7d 08 53    lsr w21, w8, #8
+ 15 7d 04 53    lsr w21, w8, #4
```

Подробное объяснение — в [документе о яркости](docs/BRIGHTNESS-FIX-RU.md).

## Авторы и происхождение работы

Исследование выполнено совместно: Andrew Snow предоставил устройство, выполнял
аппаратные действия и тестировал поведение; OpenAI Codex помогал с диагностикой,
реверс-инжинирингом, автоматизацией и документацией. Все потенциально опасные
действия выполнялись под контролем владельца устройства.

Автор: [Andrew Snow](https://t.me/andrew_snoww). При использовании или
распространении проекта сохраняйте это указание авторства и ссылку.

LineageOS, PHH Treble, Android Platform Tools, MTKClient и остальные внешние
проекты принадлежат их авторам и не включаются в этот репозиторий.

## License

Собственные скрипты и документация проекта распространяются по разрешительной
лицензии с обязательным сохранением указанной атрибуции. Это не распространяется
на сторонние прошивки и проприетарные бинарники.

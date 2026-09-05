# Полная установка LineageOS 19.1 GSI и фикса яркости на Infinix X6515

Это последовательная инструкция от чистого Mac до работающего телефона. Она
проверена только на **Infinix Smart 7 X6515 / MT6761**, stock build
`X6515-H6127JAk-S-RU-231117V1307`, активном слоте B.

> [!CAUTION]
> Разблокировка bootloader полностью удалит данные. Ошибка в имени раздела
> способна оставить телефон без загрузки. Не продолжайте при несовпадении
> модели, fingerprint, SHA-256 или активного слота.

## 1. Что скачать

Создайте рабочую папку, откройте в ней Terminal и скачайте этот проект:

```sh
git clone https://github.com/matveenko/infinix-x6515-lineage-gsi.git
cd infinix-x6515-lineage-gsi
mkdir -p downloads
```

Если Git не установлен, репозиторий можно скачать кнопкой **Code → Download
ZIP** на [странице проекта](https://github.com/matveenko/infinix-x6515-lineage-gsi),
распаковать и открыть полученную папку в Terminal.

### 1.1 Android Platform Tools

Скачайте **SDK Platform-Tools for Mac** с
[официальной страницы Google](https://developer.android.com/tools/releases/platform-tools).
Android Studio не требуется. Переместите скачанный ZIP в `Downloads`, затем из
корня проекта выполните:

```sh
unzip ~/Downloads/platform-tools-latest-darwin.zip -d .
chmod +x platform-tools/adb platform-tools/fastboot
./platform-tools/adb version
./platform-tools/fastboot --version
```

Скрипты сами найдут `platform-tools/adb` и `platform-tools/fastboot` в папке
проекта. Если браузер переименовал ZIP, подставьте его настоящее имя.

### 1.2 LineageOS GSI

Для полного сценария, включая backup и фикс яркости, скачайте проверенный
root-вариант:

**[lineage-19.1-20250606-UNOFFICIAL-arm64_bvS.img.gz](https://sourceforge.net/projects/andyyan-gsi/files/lineage-19.x/lineage-19.1-20250606-UNOFFICIAL-arm64_bvS.img.gz/download)**

Нужен именно `arm64_bvS`, без `vndklite`:

- `arm64` — 64-битная архитектура;
- `b` — A/B, system-as-root;
- `v` — vanilla, без Google Apps;
- `S` — PHH Superuser, необходимый скрипту снятия `vendor_b`.

Переместите архив в `downloads`, распакуйте и проверьте **распакованный IMG**:

```sh
gunzip downloads/lineage-19.1-20250606-UNOFFICIAL-arm64_bvS.img.gz
shasum -a 256 downloads/lineage-19.1-20250606-UNOFFICIAL-arm64_bvS.img
```

Ожидаемый SHA-256 IMG:

```text
49792f857b54c6c950bacc6e7c742b39a3dea672aa08072c70878743fb062f76
```

Vanilla-вариант без root также загружался, но с ним нельзя выполнить
`10-dump-vendor.sh`:

**[lineage-19.1-20250606-UNOFFICIAL-arm64_bvN.img.gz](https://sourceforge.net/projects/andyyan-gsi/files/lineage-19.x/lineage-19.1-20250606-UNOFFICIAL-arm64_bvN.img.gz/download)**

SHA-256 распакованного `bvN` IMG:

```text
65ae1cc41d48c15bdf40d159ece55b473fafcdc8596e127ffab13cf0b36a0e5b
```

### 1.3 Инструменты для фикса яркости

Они понадобятся после первого запуска LineageOS:

```sh
brew install e2fsprogs
python3 --version
/opt/homebrew/opt/e2fsprogs/sbin/debugfs -V
```

Если команды `brew` нет, сначала установите Homebrew с
[официального сайта](https://brew.sh/). Скрипты учитывают стандартные пути
Homebrew как на Apple Silicon, так и на Intel Mac.

## 2. Подготовить телефон

1. Зарядите телефон минимум до 70% и сохраните все данные.
2. В XOS включите Developer options.
3. Включите **OEM unlocking** и **USB debugging**.
4. Подключите телефон data-кабелем и подтвердите RSA-диалог отладки.
5. Из корня проекта выполните:

```sh
./scripts/00-doctor.sh
```

### Что делает `00-doctor.sh`

Это только диагностика, она ничего не прошивает. Скрипт проверяет наличие ADB и
fastboot, подключение телефона, `MT6761`, Treble, ARM64, vendor fingerprint и
активный слот B. В конце должно быть:

```text
Device matches the tested X6515 family. No data was changed.
```

Если проверка остановилась, не переходите к следующим пунктам.

## 3. Разблокировать bootloader

Это действие полностью очистит userdata:

```sh
./platform-tools/adb reboot bootloader
./platform-tools/fastboot devices
./platform-tools/fastboot flashing unlock
```

Подтвердите разблокировку кнопками телефона. После wipe загрузите XOS, пройдите
первичную настройку и снова включите USB debugging.

## 4. Войти в fastbootd

```sh
./platform-tools/adb reboot fastboot
./platform-tools/fastboot getvar is-userspace
./platform-tools/fastboot getvar current-slot
```

Должно быть `is-userspace: yes` и `current-slot: b`. `fastbootd` — экран с
меню поверх recovery; обычный чёрный bootloader fastboot для logical partitions
не подходит.

## 5. Прошить LineageOS GSI

На проверенном layout для system image не хватало места. Был удалён только COW
snapshot `product_b`, затем `system_b` увеличен ровно до размера проверенного
образа:

```sh
./platform-tools/fastboot delete-logical-partition product_b-cow
./platform-tools/fastboot resize-logical-partition system_b 2121457664
./platform-tools/fastboot flash system_b downloads/lineage-19.1-20250606-UNOFFICIAL-arm64_bvS.img
./platform-tools/fastboot reboot
```

Число `2121457664` относится только к указанному распакованному `bvS` IMG.
Команды намеренно используют слот B и не являются универсальными для других
ревизий телефона.

## 6. Выполнить factory reset

На тестовом X6515 `fastboot -w` завершался ошибкой vendor wipe tasks, а старая
userdata мешала первому запуску. Если LineageOS не проходит boot animation:

1. войдите в recovery аппаратными кнопками;
2. на экране `No command` удерживайте Power и один раз нажмите Volume Up;
3. выберите **Factory reset / Wipe data**;
4. подтвердите форматирование и выберите **Reboot system now**.

Первый запуск может занять несколько минут.

## 7. Включить root ADB и проверить железо

В LineageOS включите Developer options, затем root debugging в PHH-настройках.
Проверьте:

```sh
./platform-tools/adb root
./platform-tools/adb shell id
```

Ожидается `uid=0(root)`. До фикса яркости проверьте touch, Wi-Fi, звук,
Bluetooth, fingerprint, автоповорот, сон/пробуждение, камеру и SIM.

## 8. Скрипт `10-dump-vendor.sh`: сохранить vendor

Состояние телефона: LineageOS полностью загружен, USB debugging и root ADB
включены.

```sh
./scripts/10-dump-vendor.sh
```

Скрипт снова запускает диагностику, получает root ADB, считывает
`/dev/block/mapper/vendor_b` и сохраняет его как `backups/vendor_b.img`. Затем
проверяет размер `500649984` и SHA-256:

```text
b0e44ada3b32e8d230f1863ee5e27d0225903765d9ae7e8f3ead857ac4c755e4
```

Скопируйте `backups/vendor_b.img` ещё на один надёжный носитель. Это ваш путь
отката; файл намеренно исключён из Git.

## 9. Скрипт `20-patch-vendor.sh`: собрать исправленный образ

Состояние телефона не важно: этот шаг выполняется только на Mac.

```sh
./scripts/20-patch-vendor.sh \
  backups/vendor_b.img \
  builds/vendor_b-x6515-brightness.img
```

Скрипт:

1. проверяет SHA-256 и размер исходного vendor;
2. извлекает MediaTek Lights HAL;
3. проверяет SHA-256 самого HAL;
4. меняет одну AArch64-инструкцию `lsr #8` на `lsr #4`;
5. возвращает executable mode, владельца и SELinux label;
6. проверяет файловую систему и повторно извлекает HAL для сверки.

Результат: `builds/vendor_b-x6515-brightness.img`. Исходный backup не меняется.

## 10. Скрипт `30-disable-verity.sh`: разрешить изменённый vendor

Состояние телефона: LineageOS полностью загружен и виден через ADB.

```sh
./scripts/30-disable-verity.sh
```

Введите `DISABLE-VERITY`, когда скрипт запросит подтверждение. Он выполняет
штатный `adb disable-verity`, чтобы FEC не подменял исправленный блок исходным.
После сообщения `Reboot required` выполните:

```sh
./platform-tools/adb reboot
```

Обязательно дождитесь полной загрузки Android.

## 11. Скрипт `40-flash-vendor.sh`: прошить фикс

Сначала переведите телефон из загруженного Android в fastbootd:

```sh
./platform-tools/adb reboot fastboot
./platform-tools/fastboot getvar is-userspace
```

При `is-userspace: yes` запустите:

```sh
./scripts/40-flash-vendor.sh builds/vendor_b-x6515-brightness.img
```

Скрипт проверяет размер образа, SHA-256 патченного HAL, fastbootd, активный слот
B и размер `vendor_b`. Только после этого он попросит ввести
`FLASH-VENDOR-B`, прошьёт раздел и перезагрузит телефон.

## 12. Скрипт `50-verify-brightness.sh`: проверить результат

Состояние телефона: LineageOS снова полностью загрузился и доступен по ADB.

```sh
./scripts/50-verify-brightness.sh
```

Скрипт выключает несовместимый PHH alternative scale, включает ручную яркость,
временно выставляет максимум и проверяет:

- SHA-256 смонтированного HAL;
- состояние `vendor.light-default`;
- аппаратное значение `4080/4095`.

Финальная строка успешной проверки:

```text
X6515 brightness patch verified.
```

После этого вручную проверьте минимум, середину, движение ползунка в обе
стороны, touch и сон/пробуждение. Техническое объяснение патча находится в
[BRIGHTNESS-FIX-RU.md](BRIGHTNESS-FIX-RU.md), откат — в
[RECOVERY-RU.md](RECOVERY-RU.md).

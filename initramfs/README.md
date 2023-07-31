initramfs для загрузочного образа с USB Mass Storage и USB ether
================================================================

Генерация образа initramfs
----------------

Для подготовки образа требуется rootfs, сгенерированная командой:

```
wirenboard$ rootfs/create_rootfs.sh 2-usbgadget
```

[FIXME](https://wirenboard.bitrix24.ru/workgroups/group/218/tasks/task/view/64680/):
Инициаллизации нужны mmc-utils с нашим [патчем](https://patchwork.kernel.org/project/linux-mmc/patch/7a2fd4e7-84b5-8e44-3789-e9ddffe30f64@gmail.com/).
Патч так и не доехал до bullseye => rootfs для initram-бутлета нужно собирать с `DEBIAN_RELEASE=stretch` и сопутствующими костылями (fdisk => util-linux; libnss v2.24)


(или `6-usbgadget` для WB6).

Используемые defconfig для ядра:

 * `mxs_usbgadget_ether_defconfig` для WB2;

дальше образ собирается скриптом `create_initramfs.sh` в этой директории:

`./create_initramfs.sh  ../output/rootfs_wb6-usbgadget/ ../output/initramfs/ wb6`

Сборка ядра c iniramfs
------------------------

Для загрузочного образа нужно собрать ядро Linux с особым конфигом и приделать к нему iniramfs.

1) Конфигурируем ядро. В директории с ядром, для WB6:

`make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- imx6_wirenboard_initramfs_defconfig`

в директории ядра. Для WB7:`wirenboard7_initramfs_defconfig`

2) Копируем iniramfs в директорию с ядром:

`mkdir initramfs`

`sudo cp -a ~/path/to//wirenboard/output/initramfs/* initramfs/`

3) Собираем и доустанавливаем модули ядра в директорию с iniramfs:

`make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_MOD_PATH=initramfs/  modules dtbs modules_install`

4) Собираем всё остальное ядро с встроенныой initramfs:

`make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- zImage`

Сборка .fit с iniramfs
------------------------

zImage с initramfs нужно положить в диркекторию contrib:

`cp ~/path/to/kernel/arch/arm/boot/zImage ~/path/to/wirenboard/contrib/usbupdate/zImage.wb6`

и собрать fit как обычно:

`sudo ./create_images.sh 67`


sudo cp -a ~/work/board/wirenboard/output/initramfs/* initramfs_newupdate/ && make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_MOD_PATH=initramfs_newupdate/  modules dtbs modules_install && make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- zImage

Порядок работы с образом
------------------------

После загрузки образа контроллер представляется как USB Mass Storage с
двумя LUN: первый - /dev/mmcblk0, второй - флаг окончания работы с Mass Storage.

 - Загружаем образ прошивки обычным способом (с помощью dd в первый LUN);
 - Записываем произвольный текст во второй LUN (echo '1' > /dev/sdc).

После этого на контроллере отключается USB Mass Storage и он переходит
в режим USB Ethernet. Хост получит IP 192.168.41.2 автоматически через DHCP,
IP контроллера - 192.168.41.1.

Далее с контроллером можно взаимодействовать через ssh, логин root, пароль wirenboard.

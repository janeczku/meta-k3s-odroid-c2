setenv console ttyAML0,115200
setenv fdtfile meson-gxbb-odroidc2.dtb
setenv bootpart 0:1
setenv bootdir /boot
setenv mmcroot /dev/mmcblk1p1 ro
setenv mmcrootfstype ext4 rootwait
setenv nographics "0"
load mmc ${bootpart} ${fdt_addr_r} ${bootdir}/${fdtfile}
load mmc ${bootpart} ${kernel_addr_r} ${bootdir}/Image
fdt addr ${fdt_addr_r}
if test "${nographics}" = "1"; then fdt rm /meson-fb; fdt rm /amhdmitx; fdt rm /picdec; fdt rm /ppmgr; fdt rm /meson-vout; fdt rm /mesonstream; fdt rm /deinterlace; fdt rm /codec_mm; fdt rm /reserved-memory; fdt rm /aocec; fi
setenv bootargs console=${console} root=${mmcroot} rootfstype=${mmcrootfstype}
booti ${kernel_addr_r} - ${fdt_addr_r}

require linux-stable.inc

KERNEL_CONFIG_COMMAND = "oe_runmake_call -C ${S} CC="${KERNEL_CC}" O=${B} olddefconfig"

COMPATIBLE_MACHINE = "odroid-c2"

KERNEL_DEVICETREE ?= "amlogic/meson-gxbb-odroidc2.dtb"

LINUX_VERSION = "5.1"
LINUX_VERSION_EXTENSION = "-k3s"

FILESEXTRAPATHS_prepend := "${THISDIR}/linux-stable-${LINUX_VERSION}:"

S = "${WORKDIR}/git"

PV = "5.1.17"
SRCREV = "4b886fa2b8f167b70af8a21340dfb3e24711e084"
SRC_URI = " \
    git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git;branch=linux-${LINUX_VERSION}.y \
    file://defconfig \
"

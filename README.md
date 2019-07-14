# meta-k3s-odroid-c2

This layer is used to build images for the Odroid C2 ARM board allowing it to run [k3s](https://k3s.io).

It is based on [meta-odroid-c2](https://github.com/jumpnow/meta-odroid-c2) and credits go to it's author for making the process of building custom firmware images for this board so seamless.

## Layer Dependencies

Layer depends on:

```
    URI: git://git.yoctoproject.org/poky.git
    branch: warrior

    URI: git://git.openembedded.org/meta-openembedded
    branch: warrior

    URI: https://github.com/janeczku/meta-k3s.git
    branch: master
```

## k3s-image

This layer ships with a single image recipe that creates a minimal image running only k3s and some core system services like OpenSSH and NTP. The image uses sysvinit as init manager but you should be able to switch to systemd if need be (see `local.conf`).

For details on the recipe used to install k3s and how to customize the configuration see [meta-k3s](https://github.com/janeczku/meta-k3s).

## Workspace Setup and Image Build

Create working directory:

```
$ mkdir ~/oe-workspace && cd ~/oe-workspace
```

Clone Poky layer:

```
$ git clone -b warrior git://git.yoctoproject.org/poky.git
```

Clone other dependency layers:

```
$ cd poky
$ git clone -b warrior git://git.openembedded.org/meta-openembedded
$ git clone git://github.com/janeczku/meta-k3s.git
```

Clone this layer:

```
$ cd ~/oe-workspace
$ git clone git://github.com/janeczku/meta-k3s-odroid-c2.git
```

Initialize the build directory:

```
$ source poky/oe-init-build-env ~/oe-workspace/build
```

Customize the configuration:

```
$ cd ~/oe-workspace
$ cp meta-k3s-odroid-c2/conf/local.conf-sample build/conf/local.conf
$ cp meta-k3s-odroid-c2/conf/bblayers.conf-sample build/conf/bblayers.conf
```

Check and if necessary edit the paths in `bblayers.conf` to match your local layer hierarchy.

Edit `local.conf` to configure settings like init system provider and initial root password.

Build the k3s image with:

```
$ cd ~/oe-workspace/build
$ bitbake k3s image
```

Once the image has been built, you may use `scripts/create_sdcard_image.sh` to create disk image for flashing to EMMC or SD cards. Review the script to see the available command line options.

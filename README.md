# Small-Linux-Bootloader

This is a small linux bootloader with initrd support. It support the X86-64 architecture. 

This is intended for educational only.

You should have these dependances installed on your system

Debian/ubuntu:

`sudo apt-get install bc build-essential libelf-dev libssl-dev bison flex`

This script will compile everything for you:

* The kernel
* The initrd 
* The bootloader 

And then it will pack them and lunch it with QEMU.
You should see this:
![](https://github.com/arnaudmeauzoone/Small-Linux-Bootloader/blob/master/kernel-boot.png)

To run it just run 

```shell
./build.sh
```

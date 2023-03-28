# Kernel Build Process & Booting

An OS like any other project needs to be built, and packaged in a special way in order to be "booted". 
This part will cover all the steps needed to have an initial set of building script for our os, and also explore some of the bootloader that can be used to load our kernel. 

- [General Overview](02_Overview.md) This chapter will a high level overview of the building process, introducing some of the basic concepts and tools that will be used in the following chapters and showing two possible compiler options
- [Boot Protocols & Bootloaders](03_Boot_Protocols.md) Here we will explore two possible solutions for booting our kernel: Multiboot2 and Stivale, explaining how they must be used and configured in order to boot our kernel
- [Makefiles](04_Gnu_Makefiles.md) The building script, we are going to use: Makefile. 
- [Linker Scripts](05_Linker_Scripts.md) Probably one of the most _obscure_ parts of the building process, especially for beginners, this chapter explains what are the linker scripts, why they are important, an how to write one.
- [Generating A Bootable Iso](06_Generating_Iso.md) After building our kernel we want to run it too (yeah like the cake...) but for doing that we need a bootable support, only the kernel file is not enough, this chapter will show how to create a bootable iso and start to test it on emulators/real hardware.

## Useful Links

- [Grub and grub.cfg documentation](https://www.gnu.org/software/grub/manual/grub/grub.html)
- [Multiboot 2 Specification.](https://www.gnu.org/software/grub/manual/multiboot2/multiboot.html)
- [Limine documentation.](https://github.com/limine-bootloader/limine)
- [Stivale 2 Specification.](https://github.com/stivale/stivale/blob/master/STIVALE2.md)
- [Stivale 2 Barebones.](https://github.com/stivale/stivale2-barebones/)
- [Sabaton - ARM Stivale 2 Bootloader.](https://github.com/FlorenceOS/Sabaton)
- [Xorisso Documentation.](https://linux.die.net/man/1/xorriso)
- [GNU Make Documenation.](https://www.gnu.org/software/make/manual/make.html)
- [Linker Scripts Documentation.](https://sourceware.org/binutils/docs/ld/Scripts.html#Scripts)
- [Bootlin Toolchains.](https://toolchains.bootlin.com/)
- [OS Dev Wiki - Building A Cross Compiler.](https://wiki.osdev.org/GCC_Cross-Compiler)

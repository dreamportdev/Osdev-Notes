# Kernel Build Process & Booting
This section covers some of the very first topics you'll need to know when building a kernel. Why you need a custom linker script, and how to write one, setting up a build system (we use make) and finally which boot protocol and bootloader to use.

- [General Overview](02_Overview.md)
- [Boot Protocols & Bootloaders](03_BootProtocols.md)
- [Makefiles](04_GNUMakefiles.md)
- [Linker Scripts](05_LinkerScripts.md)
- [Generating A Bootable Iso](06_GeneratingIso.md)

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

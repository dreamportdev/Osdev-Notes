# Kernel Build Process & Booting
This section covers some of the very first topics you'll need to know when building a kernel. Why you need a custom linker script, and how to write one, setting up a build system (we use make) and finally which boot protocol and bootloader to use.

- [General Overview](Overview.md)
- [Boot Protocols & Bootloaders](BootProtocols.md)
- [Makefiles](GNUMakefiles.md)
- [Linker Scripts](LinkerScripts.md)
- [Generating A Bootable Iso](GeneratingIso.md)

## Useful Links
- [Grub and grub.cfg documentation](https://www.gnu.org/software/grub/manual/grub/grub.html)
- [Multiboot 2 Specification.](https://www.gnu.org/software/grub/manual/multiboot2/multiboot.html)
- [Limine documentation.](https://github.com/limine-bootloader/limine)
- [Stivale 2 Specification.](https://github.com/stivale/stivale/blob/master/STIVALE2.md)
- [Xorisso Documentation.](https://linux.die.net/man/1/xorriso)
- [GNU Make Documenation.](https://www.gnu.org/software/make/manual/make.html)
- [Linker Scripts Documentation.](https://sourceware.org/binutils/docs/ld/Scripts.html#Scripts)

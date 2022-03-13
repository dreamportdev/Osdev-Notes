# Boot Protocols
A boot protocol defines the machine state when the kernel is given control by the bootloader. It also makes several services available to the kernel, like a memory map of the machine, a framebuffer and sometimes other utilities like uart or kernel debug symbols.

This section covers 2 protocols: multiboot 2 and stivale 2.

Multiboot 2 supercedes multiboot 1, both of which are the native protocols of grub. This means that anywhere grub is installed, a multiboot kernel can be loaded. This means testing will be easy on most linux machines. Multiboot 2 is quite an old, but very robust protocol.

Stivale 2 (also superceding stivale 1) is the native protocol of the limine bootloader. Limine and stivale were designed many years after multiboot 2 as an attempt to make hobbyist OS development easier. Stivale 2 is a more complex spec to read through, but it leaves the machine is a more known state prior to handing off to the kernel.

Both protocols have their earlier versions (multiboot 1 & stivale1), but these are not worth bothering with. Their newer versions are objectively better and available in all the same places.

### Why A Bootloader At All?
It's a fair question. In the world of testing on qemu/bochs/vmware/vbox, its easy to write a bootloader directly against UEFI or BIOS. Things get more complicated on real hardware though.

Unlike CPUs, where the manufacturers follow the spec exactly, and everything works as described, all the time, manufacturers of PCs follow *most* of the specs, but every machine has its minor caveats. Some assumptions can't be assumed everywhere, and some machines sometimes outright break spec. This leads to a few edge cases on some machines, and more or less on others. It's a big mess. 

This is where a bootloader comes in: a layer of abstraction between the kernel and the mess of PC hardware. It provides a boot protocol (often many you can choose from), and then ensures that everything in the hardware world is setup to allow that protocol to function. This is until the kernel has enough drivers set up to take full control of the hardware itself.

*Authors note: I would consider writing a good bootloader an advanced topic in the osdev world. If you're new, please use an existing bootloader. It's a fun project, but not at the same time as an os. Using an existing bootloader will save you many issues down the road. And no, an assembly stub to get into long mode is not a bootloader.*

## Multiboot 2
- mention grub2 supports loading elf64, but loads in pmode
- dont use mb1 when mb2 exists, and has been supported for so long
- explain how tags work -> linked list

## Stivale 2
Stivale 2 is a much newer protocol, designed for hobbyists. It sets up a number of things to make a new kernel developer's life easy.

It's spec it available [here](https://github.com/stivale/stivale/blob/master/STIVALE2.md), and there is a header available [here](https://github.com/stivale/stivale/blob/master/stivale2.h). You'll also need a copy of the limine bootloader to use it, available [here](https://github.com/limine-bootloader/limine).
For an example on how to get started, see the official barebones [here](https://github.com/stivale/stivale2-barebones/), and check out the limine discord.

It operates in a similar way to multiboot 2, by using a linked list of tags, although this time in both directions (kernel -> bootloader and bootloader -> kernel). Tags from the kernel to the bootloader are called `header_tag`s, and ones returned from the bootloader are called `struct_tag`s.
Stivale 2 has a number of major differences to multiboot 2 though:
- The kernel starts in 64-bit long mode, by default. No need for a protected mode stub to setup up some initial paging.
- The kernel starts with the first 4GB of memory and any usable regions of memory identity mapped.
- Stivale 2 also sets up a 'higher half direct map', or hhdm. This is the same identity map as the lower half, but it starts as the hhdm_offset returned in a struct tag when the kernel runs. The idea is that as long you ensure all your pointers are in the higher half, you can zero the bottom half of the page tables and easily be ready for userspace programs. No need to move code/data around.
- A well-defined GDT is provided.
- Unlike mb2, a distinction is made between usable memory and the memory used by the bootloader, kernel/modules, and framebuffer. These are separate types in the memory, and don't intersect. Meaning usable memory regions can be used immediately.

To get the next tag in the chain, it's as simple as:
```
stivale2_tag* next_tag = (stivale2_tag*)current_tag->next;
if (next_tag == NULL)
    //we reached the end of the list.
```

### Fancy Features
Stivale 2 also provides some more advanced features:
- It can enable 5 level paging, if requested.
- It boots up AP (all other) cores in the system, and provides an easy interface to run code on them.
- It supports KASLR, loading your kernel at a random offset each time.
- It can also provide things like EDID blobs, address of the PXE server (if booted this way), and a device tree blob on some platforms.

The limine bootloader not only supports x86, but also has tentative ARM (uefi required) support. There is also a stivale2-compatable bootloader called [sabaton](https://github.com/FlorenceOS/Sabaton), providing broader support for ARM platforms.

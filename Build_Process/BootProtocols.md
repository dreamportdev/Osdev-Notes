# Boot Protocols
A boot protocol defines the machine state when the kernel is given control by the bootloader. It also makes several services available to the kernel, like a memory map of the machine, a framebuffer and sometimes other utilities like uart or kernel debug symbols.

This section covers 2 protocols: multiboot 2 and stivale 2.

Multiboot 2 supercedes multiboot 1, both of which are the native protocols of grub. This means that anywhere grub is installed, a multiboot kernel can be loaded. This means testing will be easy on most linux machines. Multiboot 2 is quite an old, but very robust protocol.

Stivale 2 (also superceding stivale 1) is the native protocol of the limine bootloader. Limine and stivale were designed many years after multiboot 2 as an attempt to make hobbyist OS development easier. Stivale 2 is a more complex spec to read through, but it leaves the machine is a more known state prior to handing off to the kernel.

While this article was being written, limine has since added a new protocol (the limine boot protocol) which is not covered here. It's based on stivale2, with some major architectural changes. If you're familiar with the concepts of stivale2, the limine protocol is easy enough to understand.

### What about the earlier versions?
Both protocols have their earlier versions (multiboot 1 & stivale 1), but these are not worth bothering with. Their newer versions are objectively better and available in all the same places. Multiboot 1 is quite a simple protocol, and a lot of tutorials and articles online like to use it because of that: however its not worth the limited feature set you get for the short term gains. The only thing multiboot 1 is useful for is booting in qemu via the `-kernel` flag, as qemu can only process mb1 kernels like that. This option leaves a lot to be desired in the x86 emulation, so there are better ways to do that.

### Why A Bootloader At All?
It's a fair question. In the world of testing on qemu/bochs/vmware/vbox, its easy to write a bootloader directly against UEFI or BIOS. Things get more complicated on real hardware though.

Unlike CPUs, where the manufacturers follow the spec exactly and everything works as described, manufacturers of PCs generally follow *most* of the specs, with every machine having its minor caveats. Some assumptions can't be assumed everywhere, and some machines sometimes outright break spec. This leads to a few edge cases on some machines, and more or less on some others. It's a big mess. 

This is where a bootloader comes in: a layer of abstraction between the kernel and the mess of PC hardware. It provides a boot protocol (often many you can choose from), and then ensures that everything in the hardware world is setup to allow that protocol to function. This is until the kernel has enough drivers set up to take full control of the hardware itself.

*Authors note: I would consider writing a good bootloader an advanced topic in the osdev world. If you're new, please use an existing bootloader. It's a fun project, but not at the same time as an os. Using an existing bootloader will save you many issues down the road. And no, an assembly stub to get into long mode is not a bootloader.*

## Multiboot 2
For this section we'll mainly be talking about grub 2. There is a previous version of grub (called grub legacy), and if you have hardware that *must* run grub legacy, there are patches for legacy that add most of the version 2 features to it. This is highly recommended.

One such feature is the ability for grub to load 64-bit elf kernels. This greatly simplifies creating a 64-bit OS with multiboot 2, as previously you would have needed to load a 32-bit elf, and the 64-bit kernel as a module, and then load the 64-bit elf yourself. Effectively re-writing stage3 of the bootloader.

Regardless of what kind of elf is loaded, multiboot 2 is well defined and will always drop you into 32-bit protected mode, with the cpu in the state as described in the spec, [here](https://www.gnu.org/software/grub/manual/multiboot2/multiboot.html). If you're writing a 64-bit kernel this means that you will need a hand-crafted 32-bit assembly stub to set up and enter long mode.

The major difference between multiboot 1 and 2 is how data is communicated between the bootloader and kernel. In multiboot 2 a series of tags (it's a linked list of structs), each one with a pointer to the next tag in the chain.

### Creating a Boot Shim
The major caveat of multiboot when first getting started is that it drops you into 32-bit protected mode, meaning that you must set up long mode yourself. This also means you'll need to create a set of page tables to map the kernel into the higher half, since in pmode it'll be running with paging disabled, and therefore no translation.

Most implementations will use an assembly stub, linked at a lower address so it can be placed in physical memory properly. While the main kernel code is linked against the standard -2GB address (0xffff'ffff'8000'0000 and above). 

Entering long mode is fairly easy, it requires setting 3 flags:

- PAE (physical address extension), bit 5 in CR4.
- LME (long mode enable), bit 8 in EFER (this is an MSR).
- PG (paging enable), bit 31 in cr0. This MUST be enabled last.

Since we have enabled paging, we'll also need to populate cr3 with a valid paging structure. This needs to be done before setting the PG bit. Generally these initial page tables can be set up using 2mb pages with the present and writable flags set. Nothing else is needed for the initial pages.

Now you will be operating in compatability mode, a subset of long mode that pretends to be a protected mode cpu. This is to allow legacy programs to run in long mode. However we can enter full 64-bit long mode by reloading the CS register with a far jump or far return. See the [GDT notes](../GDT.md) for details on doing that.

It's worth noting that this boot shim will need it's own linker sections for code and data, since until you have entered long mode the higher half sections used by the rest of the kernel won't be available, as we have no memory at those addresses yet.

### Creating a Multiboot 2 Header
TODO: DT

## Stivale 2
Stivale 2 is a much newer protocol, designed for people making hobby operating systems. It sets up a number of things to make a new kernel developer's life easy.
While multiboot 2 is about providing just enough to get the kernel going, keeping things simple for the bootloader, stivale2 creates more work for the bootloader (like initializing other cores, launching kernels in long mode with a pre-defined page map), which leads to the kernel ending up in a more comfortable development environment. The downsides of this approach are that the bootloader may need to be more complex to handle the extra features, and certain restrictions are placed on the kernel. Like the alignment of sections, since the bootloader needs to set up paging for the kernel.

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

The limine bootloader not only supports x86, but also has tentative ARM (uefi required) support. There is also a stivale2-compatible bootloader called [sabaton](https://github.com/FlorenceOS/Sabaton), providing broader support for ARM platforms.

### Creating a Stivale2 Header
TODO: DT

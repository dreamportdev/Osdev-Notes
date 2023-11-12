# Boot Protocols

A boot protocol defines the machine state when the kernel is given control by the bootloader. It also makes several services available to the kernel, like a memory map of the machine, a framebuffer and sometimes other utilities like uart or kernel debug symbols.

This chapter covers 2 protocols _Sultiboot 2_ and _Stivale 2_:

* _Multiboot 2_ supercedes multiboot 1, both of which are the native protocols of grub. Meaning that anywhere grub is installed, a multiboot kernel can be loaded. making testing easy on most linux machines. _Multiboot 2_ is quite an old, but very robust protocol.

* _Stivale 2_ (also superceding stivale 1) is the native protocol of the limine bootloader. Limine and stivale were designed many years after multiboot 2 as an attempt to make hobbyist OS development easier. _Stivale 2_ is a more complex spec to read through, but it leaves the machine in a more known state prior to handing off to the kernel.

Recently limine has added a new protocol (the limine boot protocol) which is not covered here. It's based on stivale2, with mainly architectural architectural changes, but similar concepts behind it. If familiar with the concepts of stivale 2, the limine protocol is easy enough to understand.

All the referenced specifications and documents are provided as links at the start of this chapter/in the readme.

### What about the earlier versions?

Both protocols have their earlier versions (_multiboot 1 & stivale 1_), but these are not worth bothering with. Their newer versions are objectively better and available in all the same places. Multiboot 1 is quite a simple protocol, and a lot of tutorials and articles online like to use it because of that: however its not worth the limited feature set we get for the short term gains. The only thing multiboot 1 is useful for is booting in qemu via the `-kernel` flag, as qemu can only process mb1 kernels like that. This option leaves a lot to be desired in the `x86` emulation, so there are better ways to do that.

### Why A Bootloader At All?

It's a fair question. In the world of testing on qemu/bochs/vmware/vbox, its easy to write a bootloader directly against UEFI or BIOS. Things get more complicated on real hardware though.

Unlike CPUs, where the manufacturers follow the spec exactly and everything works as described, manufacturers of PCs generally follow *most* of the specs, with every machine having its minor caveats. Some assumptions can't be assumed everywhere, and some machines sometimes outright break spec. This leads to a few edge cases on some machines, and more or less on some others. It's a big mess.

This is where a bootloader comes in: a layer of abstraction between the kernel and the mess of PC hardware. It provides a boot protocol (often many we can choose from), and then ensures that everything in the hardware world is setup to allow that protocol to function. This is until the kernel has enough drivers set up to take full control of the hardware itself.

*Authors note: Writing a good bootloader is an advanced topic in the osdev world. If new, please use an existing bootloader. It's a fun project, but not at the same time as an os. Using an existing bootloader will save you many issues down the road. And no, an assembly stub to get into long mode is not a bootloader.*

## Multiboot 2

For this section we'll mainly be talking about grub 2. There is a previous version of grub (called grub legacy), and if we have hardware that *must* run grub legacy, there are patches for legacy that add most of the version 2 features to it. This is highly recommended.

One such feature is the ability for grub to load 64-bit elf kernels. This greatly simplifies creating a 64-bit OS with multiboot 2, as previously we would have needed to load a 32-bit elf, and the 64-bit kernel as a module, and then load the 64-bit elf manually. Effectively re-writing stage3 of the bootloader.

Regardless of what kind of elf is loaded, multiboot 2 is well defined and will always drop us into 32-bit protected mode, with the cpu in the state as described in the specification. If writing a 64-bit kernel this means that we will need a hand-crafted 32-bit assembly stub to set up and enter long mode.

One of the major differences between the two protocols is how info is passed between the kernel and bootloader:

- _Multiboot 1_ has a fixed size header within the kernel, that is read by the bootloader. This limits the number of options available, and wastes space if not all options are used.
- _Multiboot 2_ uses a fixed sized header that includes a `size` field, which contains the _number of bytes of the header + all of the following requests_. Each request contains an `identifier` field and then some request specific fields. This has slightly more overhead, but is more flexible. The requests are terminated with a special `null request` (see the specs on this).

- _Multiboot 1_ returns info to the kernel via a single large structure, with a bitmap indicating which sections of the structure are considered valid.
- _Multiboot 2_ returns a pointer to a series of tags. Each tag has an `identifier` field, used to determine its contents, and a size field that can be used to calculate the address of the next tag. This list is also terminated with a special `null` tag.

One important note about multiboot 2: the memory map is essentially the map given by the bios/uefi. The areas used by bootloader memory (like the current gdt/idt), kernel and info structure given to the kernel are all allocated in *free* regions of memory. The specification does not say that these regions must then be marked as *used* before giving the memory map to the kernel. This is actually how grub handles this, so should definitely do a sanity check on the memory map.

### Creating a Boot Shim

The major caveat of multiboot when first getting started is that it drops us into 32-bit protected mode, meaning that long mode needs to be manually set-up. This also means we'll need to create a set of page tables to map the kernel into the higher half, since in pmode it'll be running with paging disabled, and therefore no translation.

Most implementations will use an assembly stub, linked at a lower address so it can be placed in physical memory properly. While the main kernel code is linked against the standard address used for higher half kernels: `0xFFFFFFFF80000000`. This address is sometimes referred to as the -2GB region (yes that's a minus), as a catch-all term for the upper-most 2GB of any address space. Since the exact address will be different depending on the number of bits used for the address space (32-bit vs 64-bit for example), referring to it as an underflow value is more portable.

Entering long mode is fairly easy, it requires setting 3 flags:

- PAE (physical address extension), bit 5 in CR4.
- LME (long mode enable), bit 8 in EFER (this is an MSR).
- PG (paging enable), bit 31 in cr0. This MUST be enabled last.

If unfamiliar with paging, there is a chapter that goes into more detail in the memory management chapter.

Since we have enabled paging, we'll also need to populate `cr3` with a valid paging structure. This needs to be done before setting the PG bit. Generally these initial page tables can be set up using 2mb pages with the present and writable flags set. Nothing else is needed for the initial pages.

We will be operating in compatibility mode, a subset of long mode that pretends to be a protected mode cpu. This is to allow legacy programs to run in long mode. However we can enter full 64-bit long mode by reloading the CS register with a far jump or far return. See the [GDT notes](../GDT.md) for details on doing that.

It's worth noting that this boot shim will need its own linker sections for code and data, since until we have entered long mode the higher half sections used by the rest of the kernel won't be available, as we have no memory at those addresses yet.

### Creating a Multiboot 2 Header
Multiboot 2 has a header available at the bottom of its specification that we're going to use here.

We'll need to modify our linker script a little since we boot up in protected mode, with no virtual memory:

```
SECTIONS
{
    . = 1M;

    KERNEL_START = .;
    KERNEL_VIRT_BASE = 0xFFFFFFFF8000000;

    .mb2_hdr :
    {
        /* Be sure that the multiboot2 header is at the beginning */
        KEEP(*(.mb2_hdr))
    }

    .mb2_text :
    {
        /* Space for the assembly stub to get us into long mode */
        .mb2_text
    }

    . += KERNEL_VIRT_BASE

    .text ALIGN(4K) : AT(. - KERNEL_VIRT_BASE)
    {
        *(.text)
    }

    .rodata ALIGN(4K) : AT(. - KERNEL_VIRT_BASE)
    {
        *(.rodata)
    }

    .data ALIGN(4K) : AT(. - KERNEL_VIRT_BASE)
    {
        *(COMMON)
        *(.data)
        *(.bss)
    }
    KERNEL_END = .;
}
```

This is very similar to a default linker script, but we make use of the `AT()` directive to set the LMA (load memory address) of each section. What this does is allow us to have the kernel loaded at a lower memory address so we can boot (in this case we set `. = 1M`, so 1MiB), but still have most of our kernel linked as higher half. The higher half kernel will just be loaded at a physical memory address that is `0xFFFF'FFFF'8000'0000` lower than its virtual address.

However the first two sections are both loaded and linked at lower memory addresses. The first is our multiboot header, this is just static data, it doesn't really matter where it's loaded, as long as it's in the final file somewhere. The second section contains our protected mode boot shim: a small bit of code that sets up paging, and boots into long mode.

The next thing is to create our multiboot2 header and boot shim. Multiboot2 headers require some calculations that easier in assembly, so we'll be writing it in assembly for this example. It would look something like this:

```x86asm
.section .mb2_hdr

# multiboot2 header: magic number, mode, length, checksum
mb2_hdr_begin:
.long 0xE85250D6
.long 0
.long (mb2_hdr_end - mb2_hdr_begin)
.long -(0xE85250D6 + (mb2_hdr_end - mb2_hdr_begin))

# framebuffer tag: type = 5
mb2_framebuffer_req:
    .short 5
    .short 1
    .long (mb2_framebuffer_end - mb2_framebuffer_req)
    # preferred width, height, bpp.
    # leave as zero to indicate "don't care"
    .long 0
    .long 0
    .long 0
mb2_framebuffer_end:

# the end tag: type = 0, size = 8
.long 0
.long 8
mb2_hdr_end:
```

A full boot shim is left as an exercise to the reader, we may want to do extra things before moving into long mode. Or may not, but a skeleton of what's required is provided below.

```x86asm
.section .data
boot_stack_base:
    .byte 0x1000

# backup the address of mb2 info struct, since ebx may be clobbered
.section .mb_text
    mov %ebx, %edi

    # setup a stack, and reset flags
    mov $(boot_stack_base + 0x1000), %esp
    pushl $0x2
    popf

/* do protected mode stuff here */
/* set up your own gdt */
/* set up page tables for a higher half kernel */
/* don't forget to identity map all of physical memory */

    # load cr3
    mov pml4_addr, %eax
    mov %eax, %cr3

    # enable PAE
    mov $0x20, %eax
    mov %eax, %cr4

    # set LME (this is a good time to enable NX if supported)
    mov $0xC0000080, %ecx
    rdmsr
    orl $(1 << 8), %eax
    wrmsr

    # now we're ready to enable paging, and jump to long mode
    mov %cr0, %eax
    orl $(1 << 31)
    mov %eax, %cr0

    # now we're in compatability mode,
    # after a long-jump to a 64-bit CS we'll be
    # in long-mode proper.
    push $gdt_64bit_cs_selector
    push $target_function
    lret
```

After performing the long-return (`lret`) we'll be running `target_function` in full 64-bit long mode. It's worth noting that at this point we still have the lower-half stack, so it may be worth having some more assembly that changes that, before jumping directly to C.

Some of the things were glossed there, like paging and setting up a gdt, are explained in their own chapters.

We'll also want to pass the multiboot info structure to the kernel's main function.

The interface between a higher level language like C and assembly (or another high level language) is called the ABI (application binary interface). This is discussed more in the chapter about C, but for now to pass a single `uint64_t` (or a pointer of any kind, which the info structure is) simply move it to `rdi`, and it'll be available as the first argument in C.

*Authors Note: If you're unsure of why we load a stack before jumping to compiled code in the kernel, it's simply required by all modern languages and compilers. The stack (which operates like the data structure of the same name) is a place to store local data that doesn't in the registers of a platform. This means local variables in a function or parts of a complex calculation. It's become so universal that it has also adopted other uses over time, like passing function arguments (sometimes) and being used by hardware to inform the kernel of things (the iret frame on x86).*

## Stivale 2

Stivale 2 is a much newer protocol, designed for people making hobby operating systems. It sets up a number of things to make a new kernel developer's life easy.
While multiboot 2 is about providing just enough to get the kernel going, keeping things simple for the bootloader, stivale2 creates more work for the bootloader (like initializing other cores, launching kernels in long mode with a pre-defined page map), which leads to the kernel ending up in a more comfortable development environment. The downsides of this approach are that the bootloader may need to be more complex to handle the extra features, and certain restrictions are placed on the kernel. Like the alignment of sections, since the bootloader needs to set up paging for the kernel.

To use stivale2, we'll need a copy of the limine bootloader. A link to it and the stivale2 specification are available at the start of this chapter. There is also a C header file containing all the structs and magic numbers used by the protocol. A link to a barebones example is also provided.

It operates in a similar way to multiboot 2, by using a linked list of tags, although this time in both directions (kernel -> bootloader and bootloader -> kernel). Tags from the kernel to the bootloader are called `header_tag`s, and ones returned from the bootloader are called `struct_tag`s.
Stivale 2 has a number of major differences to multiboot 2 though:

- The kernel starts in 64-bit long mode, by default. No need for a protected mode stub to setup up some initial paging.
- The kernel starts with the first 4GB of memory and any usable regions of memory identity mapped.
- Stivale 2 also sets up a 'higher half direct map', or hhdm. This is the same identity map as the lower half, but it starts as the hhdm_offset returned in a struct tag when the kernel runs. The idea is that as long we ensure all the pointers are in the higher half, we can zero the bottom half of the page tables and easily be ready for userspace programs. No need to move code/data around.
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
- It supports KASLR, loading our kernel at a random offset each time.
- It can also provide things like EDID blobs, address of the PXE server (if booted this way), and a device tree blob on some platforms.
- A fully ANSI-compliant terminal is provided. This does require the kernel to make certain promises about memory layout and the GDT, but it's a very useful debug tool or basic shell in the early stages.

The limine bootloader not only supports x86, but tentatively supports aarch64 as well (uefi is required). There is also a stivale2-compatible bootloader called Sabaton, providing broader support for ARM platforms.

### Creating a Stivale2 Header
The limine bootloader provides a `stivale2.h` file which contains a number of nice definitions for us, otherwise everything else here can be placed inside of a c/c++ file.

*Authors Note: I like to place my limine header tags in a separate file, for organisation purposes, but as long as they appear in the final binary, they can be anywhere. You can also implement this in assembly if you really want.*

First of all, we'll need an extra section in our linker script, this is how the bootloader knows our kernel can be booted via stivale2:

```
.stivale2hdr :
{
    KEEP(*(.stivale2hdr))
}
```

If not familiar with the `KEEP()` command in linker scripts, it tells the linker to keep that section even if it's not referenced by anything. Useful in this case, since the only reference will be the bootloader, which the linker can't know about at link-time.

Next we'll need to create space for our stack (stivale2 requires us to provide our own) and define the stivale2 header, like so:

```c
#include <stivale2.h>

//8K for the initial stack, a reasonable default
static uint8_t init_stack[0x2000];

__attribute__((section(".stivale2hdr)))
static stivale2_header stivale2_hdr =
{
    .entry_point = 0,
    .stack = (uintptr_t)init_stack + 0x2000,
    .flags = (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4),
    .tags = (uintptr_t)&framebuffer_tag
};
```

If not familiar with the `__attribute__(())` syntax, it's a compiler extension (both clang and GCC support it) that allows us to do certain things our language wouldn't normally allow. This attribute specified that this variable should go into the `.stivale2hdr` section, as is required by the stivale2 spec.

Next we set some fields in the stivale2 header:

- `entry_point`: Is used to override the ELF's entry point address. Set this to zero to use the regular entry function we set in the linker script.
- `stack`: Self explanatory, used to set the stack the kernel code will start with.
- `flags`: A bitfield of flags. Bit 1 asks the bootloader to return higher half addresses to us for tags, modules and other things. Bit 2 asked the bootloader to make use of the nx-bit and write-enable bits in the page tables when loading the kernel. Bit 3 is recommended and enables the bootloader to load us at any physical address as long as the virtual address is the same. Bit 4 is required to be set, as it disables a legacy feature.
- `tags`: A pointer to the first stivale2 tag in the linked list of requests.

In the example above we actually set the first tag to a framebuffer request, so lets see what that would look like:

```c
static stivale2_header_tag_framebuffer framebuffer_tag =
{
    .tag =
    {
        .identifier = STIVALE2_HEADER_TAG_FRAMEBUFFER,
        .next = 0,
    },
    .framebuffer_width = 0,
    .framebuffer_height = 0,
    .framebuffer_bpp = 0
};
```

The `framebuffer_*` fields can be used to ask for a specific kind of framebuffer, but leaving them to zero tells the bootloader we want to best possible available. The `next` field can be used to point to the next header tag, if we had another one we wanted. The full list of tags is available in the stivale2 specification (see the useful links appendix).

The last detail is to change the signature of our kernel entry function to:

```c
void kernel_start(stivale2_struct* stivale2_data);
```

This struct points to a list of tags, each containing details about the machine we're booted on. These are called struct tags (bootloader -> kernel) as opposed to the tags we defined before (header tags: kernel -> bootloader). To get info about a specific feature, simply walk the linked list of tags, the next tag's address is available in the `tag->next` field. The end of the list is indicated by a nullptr.

## Finding Bootloader Tags
Since both multiboot 2 and stivale 2 return their info in linked lists, a brief example of how to traverse these lists is given below. These functions provide a nice abstraction to search the list for a specific tag, rather than manually searching each time.

### Multiboot 2
Multiboot 2 gives us a pointer to the multiboot info struct, which contains 2x 32-bit fields. These can be safely ignored, as the list is null-terminated (a tag with a type 0, and size of 8). The first tag is at 8 bytes after the start of the mbi. All the structures and defines used here are available in the header provided by the multiboot specification (check the bottom section, in the example kernel), including the `MULTIBOOT_TAG_TYPE_xyz` defines (where xyz is a feature described by a tag). For example the memory map is `MULTIBOOT_TAG_TYPE_MMAP`, and framebuffer is `MULTIBOOT_TAG_TYPE_FRAMEBUFFER`.

```c
//placed in ebx when the kernel is booted
multiboot_info* mbi;

void* multiboot2_find_tag(uint32_t type)
{
    multiboot_tag* tag = (multiboot_tag*)(uintptr_t)mbi + 8);
    while (1)
    {
        if (tag->type == 0 && size == 8)
            return NULL; //we've reached the terminating tag

        if (tag->type == type)
            return tag;

        uintptr_t next_addr = (uintptr_t)tag + tag->size;
        next_addr = (next_addr / 8 + 1) * 8;
        tag = (multiboot_tag*)next_addr;
    }
}
```

Lets talk about the last three lines of the loop, where we set the `tag` variable to the next value. The multiboot 2 spec says that tags should always be 8-byte aligned. While this is not a problem most of the time, it is *possible* we could get a misaligned pointer by simply adding `size` bytes to the current pointer. So to be on safe side, and spec-compliant, we'll align the value up to the nearest 8 bytes.

### Stivale 2
Stivale 2 gives us a pointer to a header at the start of the list, and then each item (including this header) contains a `next` pointer to the next item, and an `id` item with a unique 64-bit identifier for that tag. All the structures and defines are available in the standard `stivale2.h`. We'll know we've reached the end of the list when the `next` pointer is `NULL`.

```c
//given to the kernel entry function
stivale2_struct* s2_struct;

//returns null if tag could not be found
void* stivale2_find_tag(uint64_t id)
{
    stivale2_tag* tag = s2_struct->next;

    while (tag != NULL)
    {
        if (tag->id == id)
            return tag;
        tag = tag->next;
    }

    return NULL;
}
```

The above function can be used with the defines in `stivale2.h`, which follow the format `STIVALE2_STRUCT_TAG_xyz_ID`, where `xyz` represents the feature that is described in the tag. For example, the framebuffer would be `STIVALE2_STRUCT_TAG_FRAMEBUFFER_ID` and the memory map is `STIVALE2_STRUCT_TAG_MEMMAP_ID`. It's a little verbose, but easy to search for.

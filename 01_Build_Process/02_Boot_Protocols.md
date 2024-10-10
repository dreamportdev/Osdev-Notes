    # Boot Protocols

A boot protocol defines the machine state when the kernel is given control by the bootloader. It also makes several services available to the kernel, like a memory map of the machine, a framebuffer and sometimes other utilities like uart or kernel debug symbols.

This chapter covers 2 protocols _Multiboot 2_ and _Limine Protocol_:

* _Multiboot 2_ supercedes multiboot 1, both of which are the native protocols of grub. Meaning that anywhere grub is installed, a multiboot kernel can be loaded. making testing easy on most linux machines. _Multiboot 2_ is quite an old, but very robust protocol.

* _Limine Protocol_ (it was preceded by Stivale 1 and 2) is the native protocol of the Limine bootloader. Limine and Stivale protocols were designed many years after Multiboot 2 as an attempt to make hobbyist OS development easier. _Limine Protocol_ is a more complex spec to read through, but it leaves the machine in a more known state prior to handing off to the kernel.

The Limine protocol is based on Stivale2 (it was covered in earlier version of this book), with mainly architectural changes, but similar concepts behind it. If familiar with the concepts of stivale 2, the limine protocol is easy enough to understand.

All the referenced specifications and documents are provided as links at the start of this chapter/in the readme.

## What about the earlier versions?

Multiboot protocol has an earlier verison (_Multiboot 1_), while the limine prorocol was preceded by a different protocol, the _Stivale 1/2_. but in both cases. they are not worth bothering with. Their newer versions are objectively better and available in all the same places. Multiboot 1 is quite a simple protocol, and a lot of tutorials and articles online like to use it because of that: however its not worth the limited feature set we get for the short term gains. The only thing `multiboot 1` is useful for is booting in qemu via the `-kernel` flag, as qemu can only process mb1 kernels like that. This option leaves a lot to be desired in the `x86` emulation, so there are better ways to do that.

## Why A Bootloader At All?

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

We will be operating in compatibility mode, a subset of long mode that pretends to be a protected mode cpu. This is to allow legacy programs to run in long mode. However we can enter full 64-bit long mode by reloading the CS register with a far jump or far return. See the [GDT notes](../02_Architecture/04_GDT.md) for details on doing that.

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

## Limine Protocol

The _Limine Protocol_ that has replaced the _Stivale_  protocol, is following the same philosophy, and is designed for people making hobby operating systems, it sets up a number of things to make a new kernel developer's life easy.
While _Multiboot 2_ is about providing just enough to get the kernel going, keeping things simple for the bootloader, _Limine_ creates more work for the bootloader (like initializing other cores, launching kernels in long mode with a pre-defined page map), which leads to the kernel ending up in a more comfortable development environment. The downsides of this approach are that the bootloader may need to be more complex to handle the extra features, and certain restrictions are placed on the kernel. Like the alignment of sections, since the bootloader needs to set up paging for the kernel.

To use this protocol, we'll need a copy of the _Limine bootloader_. A link to it and the specification are available in the appendices. There is also a C header file containing all the structs and magic numbers used by the protocol. A link to a barebones example is also provided.

It is centered around the concept of `request/response`. For every information that we need from the bootloader, we provide a `request` structure, and it will return us with a `response`.

Limine has a number of major differences to multiboot 2 though:

- The kernel starts in 64-bit long mode, by default. No need for a protected mode stub to setup up some initial paging.
- The kernel starts with the first 4GB of memory and any usable regions of memory identity mapped.
- Limine protocol also sets up a _higher half direct map_, or _hhdm_. This is the same identity map as the lower half, but it starts at the `hhdm_offset` returned in a struct tag when the kernel runs. The idea is that as long we ensure all the pointers are in the higher half, we can zero the bottom half of the page tables and easily be ready for userspace programs. No need to move code/data around.
- A well-defined GDT is provided.
- Unlike _Multiboot2_, a distinction is made between usable memory and the memory used by the bootloader, kernel/modules, and framebuffer. These are separate types in the memory, and don't intersect. Meaning usable memory regions can be used immediately.

A `request` always has three members at the beginning of the structure:

```c
struct limine_example_request {
    uint64_t id[4];
    uint64_t revision;
    struct limine_example_response *response;
    // the members that follow depends on the request type
};
```
Where the fields are:

* `id` is a magic number that the bootloader uses to find and identify the requests within the executable. It is 8 byte aligned. For every type of request there can be only one. If there are multiple requests with the same id the bootloader will refuse to start.
* `revision` is the revision of the request that the kernel provides. This number is bumped each time a new member is added to it. It starts from 0. It's backward compatible, that means if the bootloader does not support the revision of the request, it will be processed as if were the highest revision supported.
* `response` this will contain the response by limine, this field is filled by the bootloader at load time. If there was an error processing the request, or the request was not supported, the field is left as it is, so for example if it was set to `NULL`, it will stay this way.

All the other fields depends on the type of the request.

The response instead, has only one mandatory field, it's the `revision` field, that like in the request, it marks the revision of the response field. Note that there is no coupling between response and request `revision` number.

### Fancy Features

Limine also provides some more advanced features:

- It can enable 5 level paging, if requested.
- It boots up AP (all other) cores in the system, and provides an easy interface to run code on them.
- It supports KASLR, loading our kernel at a random offset each time.
- It can also provide things like EDID blobs, address of the PXE server (if booted this way), and a device tree blob on some platforms.

The limine bootloader not only supports x86, but tentatively supports aarch64 as well (uefi is required). There is also a stivale2-compatible bootloader called Sabaton, providing broader support for ARM platforms.

### Creating a Limine Header

The limine bootloader provides a `limine.h` file which contains a number of nice definitions for us, otherwise everything else here can be placed inside of a c/c++ file.

*Authors Note: I like to place my limine header tags in a separate file, for organisation purposes, but as long as they appear in the final binary, they can be anywhere. You can also implement this in assembly if you really want.*

First of all, we'll need an extra section in our linker script, this is where all the limine requests will be placed:

```
.requests :
{
    KEEP(*(.requests_start_marker))
    KEEP(*(.requests))
    KEEP(*(.requests_end_marker))
} :requests
```

If not familiar with the `KEEP()` command in linker scripts, it tells the linker to keep that section even if it's not referenced by anything. Useful in this case, since the only reference will be the bootloader, which the linker can't know about at link-time.

First thing we want to do is set the base revision of the protocol. Latest version as time of writing is `2`, this can be done with the following line of code:

```c
__attribute__((used, section(".requests")))
static volatile LIMINE_BASE_REVISION(2);
```

If not familiar with the `__attribute__(())` syntax, it's a compiler extension (both clang and GCC support it) that allows us to do certain things our language wouldn't normally allow. This attribute specified that this variable should go into the `.requests` section, as is required by the Limine spec and it is marked as used.

The main requirement of any limine protocol variable, request is that, is that the compiler keep them as they are, without any optimization optimizing them, for this reason they are declared as `volatile` and they should be accessed at least once, or marked as `used`.

In this protocol, `requests` can be placed anywhere, and there is no need to use any type of list or place them in a specific memory area. For example, let's imagine that we want to get the framebuffer information from the bootloader. In this case we need to declare the `struct limine_framebuffer_request` type while creating a variable for our request:

```c
__attribute__((used, section(".requests")))
static volatile struct limine_framebuffer_request {
    .id = LIMINE_FRAMEBUFFER_REQUEST,
    .revision = 0
};
```

The requests types are all declared in the `limine.h` header.

For any other information that we need to get from the bootloader, we are going to create a similar request using the correct request type.

The last detail is to add the kernel start function (declared in the `ENTRY()` section in the linker script):

```c
void kernel_start(void);
```

Since all the bootloader information are provided via `static` variables, the kernel start function doesn't require any particular signature.


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

### Limine

Accessing the bootloader response is very simple, and it  doesn't require iterating any list. We just need to read the content of the `.response` field of the request structure:

```c
//somewhere in the code
if ( framebuffer_request->response != NULL) {
    // Do something with the response
}
```

Is important to note, for every type of request the `response` field have a different type, in this case it is a pointer to a `struct limine_framebuffer_response`, for more info on all the available requests, and repsonses refer to the protocl documentation.

The `framebuffer_*` fields can be used to ask for a specific kind of framebuffer, but leaving them to zero tells the bootloader we want to best possible available. The `next` field can be used to point to the next header tag, if we had another one we wanted. The full list of tags is available in the stivale2 specification (see the useful links appendix).

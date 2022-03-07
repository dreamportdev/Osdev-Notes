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

*Authors note: I would consider writing a good bootloader an advanced topic in the osdev world. If you're new, please use an existing bootloader. It's a fun project to write one, but not at the same time as an os. And no, an assembly stub to get into long mode is not a bootloader.*

## Multiboot 2
- mention grub2 supports loading elf64, but loads in pmode
- dont use mb1 when mb2 exists, and has been supported for so long
- explain how tags work -> linked list

## Stivale 2
Stivale 2 is a much newer protocol, designed for hobbyists. It sets up a number of things to make a new kernel developer's life easy.

It's spec it available [here](https://github.com/stivale/stivale/blob/master/STIVALE2.md), and there is a header available [here](https://github.com/stivale/stivale/blob/master/stivale2.h). You'll also need a copy of the limine bootloader to use it, available [here](https://github.com/limine-bootloader/limine).

It operates in a similar way to multiboot 2, by using a linked list of tags, although this time in both directions (kernel -> bootloader and bootloader -> kernel). Tags from the kernel to the bootloader are called `header_tag`s, and ones returned from the bootloader are called `struct_tag`s.

To get the next tag in the chain, it's as simple as:
```
stivale2_tag* next_tag = (stivale2_tag*)current_tag->next;
if (next_tag == NULL)
    //we reached the end of the list.
```

### Getting Started
First of all, you'll need a file to store the header tags. We'll use `stivale2_header_tags.c` for now. Notice this is a C file you're going to compile into your kernel binary.

Now inside of this file we'll the stivale2 header, and several example tags. A full list of tags is available in the stivale2 spec.
A simple example is described below.

```c
#include <stivale2.h>

uint8_t stivale_stack[0x2000];

//the terminal tag asks for a limine to provide a runtime terminal for us to use. It provides input and an easy way to get output on to the screen. Great for early debugging. It does impose some requires on to the OS (mainly paging and gdt layouts), check the spec for more details.
static struct stivale2_header_tag_terminal terminalTag = 
{
    .tag = 
    {
        .identifier = STIVALE2_HEADER_TAG_TERMINAL_ID,
        .next = 0,
    },
    //currently an unused flag, reserved for future expansion
    .flags = 0
};

//the framebuffer tags requests a framebuffer from the bootloader. 
//NOTE: this will fail to boot if a framebuffer is not available, that includes systems where only text-mode is available. To support both, you'll want to also include the 'any_video' tag, which will allow booting with text-mode.
static stivale2_header_tag_framebuffer framebufferTag
{
    .tag = 
    {
        //this is defined in stivale2.h
        .identifier = STIVALE2_HEADER_TAG_FRAMEBUFFER_ID,
        .next = (uint64_t)&terminalTag
    },

    //requested width/height/bpp of returned framebuffer. Zero means the best available.
    .framebuffer_width = 0,
    .framebuffer_height = 0,
    .framebuffer_bpp = 0,
    .unused = 0
};

//limine detects the presence of a stivale2 kernel by looking for the following elf section. We need to tell the compiler this section is used, since it's not referenced anywhere and may be removed by optimizations.
__attribute__((section(".stivale2hdr"), used))
static stivale2_header stivale2hdr
{
    //allows for setting a custom entry point for stivale2 only, instead of using the default elf entry point. Leaving at zero means this field is ignored.
    .entry_point = 0,

    //required: tells limine where we want our stack to be initialized to. 8K is a commong starting size. We add 8K as the stack grows downwards, so we want to pass address of the stack top.
    .stack = (uint64_t)stivale_stack + 0x2000;

    //collection of bit flags:
    // bit 1: if set tells the bootloader we want all pointers it gives us to be in the higher half. Useful for when we go to userspace later. Worth setting unless you know you dont need it.
    // bit 2: tells the bootloader to use PMRs (protected memory ranges). This means it will set the page tables priviledges to look like our elf section priviledges. I.e. code is marked as executable, read-only. Data is read/write, read-only data is read-only.
    // bit 3: fully virtual mappings. This allows the bootloader to load the kernel *anywhere* in physical memory, as long as the virtual addresses are correct. This means it will ignore AT() directives in linker scripts, if those are used.
    // bit 4: from a deprecated feature, required to be set.
    .flags = (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4)

    //address of the first tag
    .tags = (uint64_t)&framebufferTag;
};
```

Next we'll create a simple main function for the kernel to run when booted, and utility function to locate stivale struct tags (bootloader -> kernel).

```c
#include <stivale2.h>

//helper function for finding specific tags
void* get_stivale_tag(struct stivale2_struct* main_struct, uint64_t id)
{
    struct stivale2_tag* current = (struct stivale2_tag*)main_struct->tags;
    while (current != NULL)
    {
        if (current->identifier == id)
            break;
        current = (struct stivale2_tag*)current->next;
    }
    return current;
}

//stivale2 gives us a struct pointer as the first argument to our main function
void _start(struct stivale2_struct* stivale2_struct)
{
    //now we've booted, lets get the terminal details from the bootloader and print a hello message to the screen.

    struct stivale2_struct_tag_terminal* terminal = get_stivale_tag(stivale2_struct, STIVALE2_STRUCT_TAG_TERMINAL_ID);

    if (terminal == NULL)
        while (1); //sit in an infinite loop, terminal tag could not be found.

    //The way the terminal works is we are provided with a function pointer that lets us write to the screen. 
    //We'll construct a nice c-friendly function pointer around that pointer, and then use that as we would normally.

    void (*terminal_write)(const char* str, size_t length) = terminal->term_write;

    terminal_write("Hello world!, 12);

    while (1); //hang, make sure we dont start executing random memory as code.
}
```
-linker script
-building an iso
-barebones

### Fancy Features

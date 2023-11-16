# Architecture And Drivers

Before going beyond a basic "hello world" and implementing the first real parts of our kernel, there are some key concepts about how the CPU operates that we have to understand. What is an interrupt, and how do we handle it? What does it mean to mask them? What is the GDT and what is its purpose?

It's worth noting that we're going to focus exclusively on `x86_64` here, and some concepts are specific to this platform (the GDT, for example), while some concepts are transferable across most platforms (like a higher half kernels). Some, like interrupts and interrupt handlers, are only partially transferable to other platforms.

Similarly to the previous part, this chapter will be an high level introduction of the concept that will be explained later.

The [Hello World](02_Hello_World.md) chapter will guide through the implementation of some basic _serial i/o_ functions to be used mostly for debugging purpose (especially with an emulator), we will see how to send characters, strings and how to read them.

Many modern operating systems place their kernel in the _Higher Half_ of the virtual memory space, what it is, and how to place the kernel there is explained in the [Higher Half](03_Higher_Half.md) chapter.

In the [GDT](04_GDT.md) we will explain one of the `x86` structures used to _describe_ the memory to the CPU, although is a legacy structures its usage is still required in several part of the kernel (especially when dealing with userspace)

Then the chapters [Interrup Handling](05_InterruptHandling.md), [ACPI Tables](06_AcpiTables.md) and [APIC](07_APIC.md) will discuss how the `x86` cpu handle the exceptions and interrupts, and how the kernel should deal with them.

The [Timers](08_Timers.md) chapter will use one of the Interrupts handling routines to interrupt the kernel execution at regular intervals, this will be the ground for the implementation of the multitasking in our kernel.

The final three chapters of this part: [PS2 Keyboard Overview](09_Add_Keyboard_Support.md), [PS2 Keybord Interrupt Handling](10_Keyboard_Interrupt_Handling.md), [PS2 Keyboard Driver implementation](11_Keyboard_Driver_Implemenation.md) will explain how a keyboard work, what are the scancodes, how to translate them into character, and finally describe the steps to implement a basic keyboard driver.

## Address Spaces

If we've never programmed at a low level before, we'll likely only dealt with a single address space: the virtual address space the program lives in. However there are actually many other address spaces to be aware of!

This brings up the idea that an address is only useful in a particular address space. Most of the time we will be using virtual addresses, which is fine before our program lives in a virtual address space, but at times we will use *physical addresses* which, as we might have guessed, deal with the physical address space.

These are not the same, as we'll see later on we can convert virtual addresses to physical addresses (usually the cpu will do this for us), but they are actually separate things.

There are also other address spaces we may encounter in osdev, like:

- Port I/O: Some older devices on x86 are wired up to 'ports' on the cpu, with each port being given an address. These addresses are not virtual or physical memory addresses, so we can't access them like pointers. Instead special cpu instructions are used to move in and out of this address space.
- PCI Config Space: PCI has an entirely separate address that for configuring devices. This address space has a few different ways to access it.

Most of the time we won't have to worry about which address space to deal with: hardware will only deal with physical addresses, and the code will mostly deal with virtual addresses. As mentioned earlier we'll later look at how we use both of these so don't worry!

### Higher and Lower Halves

The concept of a higher half (and lower half) could be applied to any address space, but they are typically used to refer to the virtual address space. Since the virtual address space has a *non-canonical hole*, there are two distinct halves to it.

The non-canonical hole is the range of addresses in the middle of the virtual address space that the MMU (memory management unit) considers to be invalid. We'll look more at the MMU and why this exists in later chapters, but for now just know that the higher half refers to addresses above the hole, and the lower half is everything below it.

Of course like any convention we are free to ignore this and forge our own ways of dividing the address space between user programs and the kernel, but this is the recommended approach: the higher half is the for the kernel, the lower half is for userspace.

## The GDT

The global descriptor table has a lot of legacy on the `x86` architecture and has been used for a lot of things in the past. At its core we can think of it as a big array of descriptors, with each descriptor being a magic number that tells the cpu how to operate. Outside of long mode these descriptors can be used for memory segmentation on the CPU, but this is disabled in long mode. In long mode their only important fields are the DPL (privilege level) and their type (code, data or something else).

It's easy to be overwhelmed by the number of fields in the GDT, but most modern `x86_64` kernels only use a handful of static descriptors: 64-bit kernel code, 64-bit kernel data, 64-bit user code, 64-bit user data. Later on we'll add a TSS descriptor too, which is required when we try to handle an interrupt while the CPU is running user code.

The currently active descriptors tell the CPU what mode it is in: if a user code descriptor is loaded - it's running user-mode code. Data descriptors tell the CPU what privilege level to use when we access memory, which interacts with the user/supervisor bit in the page tables (as we'll see later).

If unsure where to start, we'll need a 64-bit kernel code descriptor and 64-bit kernel data descriptor at the bare mimimum.

## How The CPU Executes Code

Normally the CPU starts a program, and runs it until the program needs to wait for something. At a time in the future, the program may continue and even eventually exit. This is the typical life cycle of a userspace program.

On bare metal we have more things to deal with, like how do we run more than a single program at once? Or how do we keep track of the time to update a clock? What is the user presses a key or moves the mouse, how do we detect that efficiently? Maybe something we can't predict happens like a program trying to access memory it's not supposed to, or a new packet arrives over the network.

These things can happen at any time, and as the operating system kernel we would like to react to them and take some action. This is where interrupts come in.

### Interrupts

When an unexpected event happens, the cpu will immediately stop the current code it's running and start running a special function called an *interrupt handler*. The interrupt handler is something the kernel tells the cpu about, and the function can then work out what event happened, and then take some action. The interrupt handler then tells the cpu when it's done, and then cpu goes back to executing the previously running code.

The interrupted code is usually never aware that an interrupt even ocurred, and should continue on as normal.

## Drivers

Not device drivers for graphic cards, network interfaces, and other hardware, but on early stages of development we will need some basic drivers to implement some of the future features, for example we will need to have at least one supported Timer to implement the scheduler, we will most likely want to add a basic support for a keyboard in order to implement a cli, these topics will be covered in this section, along with other architecture specific drivers required by the CPU.


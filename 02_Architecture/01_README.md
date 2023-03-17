# Architecture

Before going beyond a basic "hello world" and implementing the first real parts of our kernel, there are some key concepts about how the CPU operates that we have to understand. What is an interrupt, and how do we handle it? What does it mean to mask them? What is the GDT and what is it's purpose?

It's worth noting that we're going to focus exclusively on x86_64 here, and some concepts are specific to this platform (the GDT, for example), while some concepts are transferable across most platforms (like a higher half kernels). Some concepts, like interrupts and interrupt handlers, are partially transferable to other platforms.

## Address Spaces

If you've never programmed at a low level before, you'll likely only dealt with a single address space: the virtual address space your program lives in. However there are actually many other address spaces to be aware of!

This brings up the idea that an address is only useful in a particular address space. Most of the time we will be using virtual addresses, which is fine before our program lives in a virtual address space, but at times we will use *physical addresses* which, as you might have guessed, deal with the physical address space. 

These are not the same, as we'll see later on we can convert virtual addresses to physical addresses (usually the cpu will do this for us), but they are actually separate things.

There are also other address spaces you may encounter in osdev, like:

- Port I/O: Some older devices on x86 are wired up to 'ports' on the cpu, with each port being given an address. These addresses are not virtual or physical memory addresses, so we can't access them like pointers. Instead special cpu instructions are used to move in and out of this address space.
- PCI Config Space: PCI has an entirely separate address that for configuring devices. This address space has a few different ways to access it.

Most of the time you won't have to worry about which address space to deal with: hardware will only deal with physical addresses, and your code will mostly deal with virtual addresses. As mentioned earlier we'll later look at how we use both of these so don't worry!

### Higher and Lower Halves

The concept of a higher half (and lower half) could be applied to any address space, but they are typically used to refer to the virtual address space. Since the virtual address space has a *non-canonical hole*, there are two distinct halves to it. 

The non-canonical hole is the range of addresses in the middle of the virtual address space that the MMU (memory management unit) considers to be invalid. We'll look more at the MMU and why this exists in later chapters, but for now just know that the higher half refers to addresses above the hole, and the lower half is everything below it.

Of course like any convention you are free to ignore this and forge your own ways of dividing the address space between user programs and the kernel, but this is the recommended approach: the higher half is the for the kernel, the lower half is for userspace.

## The GDT

The global descriptor table has a lot of legacy on the x86 architecture and has been used for a lot of things in the past. At it's core you can think of it as a big array of descriptors, with each descriptor being a magic number that tells the cpu how to operate. Outside of long mode these descriptors can be used for memory segmentation on the CPU, but this is disabled in long mode. In long mode their only important fields are the DPL (privilege level) and their type (code, data or something else).

It's easy to be overwhelmed by the number of fields in the GDT, but most modern x86_64 kernels only use a handful of static descriptors: 64-bit kernel code, 64-bit kernel data, 64-bit user code, 64-bit user data. Later on we'll add a TSS descriptor too, which is required when we try to handle an interrupt while the CPU is running user code.

The currently active descriptors tell the CPU what mode it is in: if a user code descriptor is loaded - it's running user-mode code. Data descriptors tell the CPU what privilege level to use when we access memory, which interacts with the user/supervisor bit in the page tables (as we'll see later).

If you're unsure where to start, you'll need a 64-bit kernel code descriptor and 64-bit kernel data descriptor at the bare mimimum.

## How The CPU Executes Code

Normally the CPU starts a program, and runs it until the program needs to wait for something. At a time in the future, the program may continue and even eventually exit. This is the typical life cycle of a userspace program.

On bare metal we have more things to deal with, like how do we run more than a single program at once? Or how do we keep track of the time to update a clock? What is the user presses a key or moves the mouse, how do we detect that efficiently? Maybe something we can't predict happens like a program trying to access memory it's not supposed to, or a new packet arrives over the network.

These things can happen at any time, and as the operating system kernel we would like to react to them and take some action. This is where interrupts come in.

### Interrupts

When an unexpected event happens, the cpu will immediately stop the current code it's running and start running a special function called an *interrupt handler*. The interrupt handler is something the kernel tells the cpu about, and the function can then work out what event happened, and then take some action. The interrupt handler then tells the cpu when it's done, and then cpu goes back to executing the previously running code.

The interrupted code is usually never aware that an interrupt even occured, and should continue on as normal.


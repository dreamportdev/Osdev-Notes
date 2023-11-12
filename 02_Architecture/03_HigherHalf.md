# Higher Half Kernel

Commonly kernels will place themselves in the higher half of the address space, as this allows the lower half to be used for userspace. It greatly simplifies writing new programs and porting existing ones. Of course this does make it slightly more complex for the kernel, but not by much!

Most architectures that support virtual addressing use an MMU (memory management unit), and for `x86` it's built into the CPU. Virtual memory (and paging - which is how the `x86` MMU is programmed) is discussed in more detail in the paging chapter, but for now think of it as allowing us to *map* what the code running on the CPU sees to a different location in physical memory. This allows us to put things anywhere we want in memory and at any address.

With a higher half kernel we take advantage of this, and place our kernel at a very high address, so that is it out of the way of any user programs that might be running. Commonly we typically claim the entire *higher half* of the virtual address space for use by the kernel, and leave the entire lower half alone for userspace.

## A Very Large Address

The address that the kernel is loaded at depends on the size of the address space. For example if it's a 32-bit address space we might load the kernel at `0xC0000000` (3GiB), or -1GiB (because it is 1GiB below the top of the address space). For a 64-bit address space this is typically `0xFFFFFFFF80000000` or -2GiB.

This doesn't mean the kernel will be physically loaded here, in fact it can be loaded anywhere. If using multiboot it will probably be around 1-2MiB, but with virtual memory we don't have to care about its physical address.

## Loading a Higher Half Kernel

Depending on the boot protocol used we may already be running in the higher half. If booted via multiboot2 we will need to enter long mode and set up paging before doing it. The steps to do this are outlined in the boot protocols chapter.

It's worth noting that when we compile and link code for the higher half we will need to use the `-mcmodel=large` parameter for the large code model in gcc, or better yet `-mcmodel=kernel` if the kernel is in the upper 2GiB of the address space, like we looked at earlier.

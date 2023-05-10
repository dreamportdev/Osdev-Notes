# All About Userspace

After this part our kernel will be able to switch between user and supervisor privilege levels, and we'll have a basic system call interface.

In the [Switching Modes](02_Switching_Modes.md) chapter we are going to explore how the `x86` architecture handles changing privilege levels, and how to switch back and forth between the _supervisor_ and _user_ mode.

In the [Handling Interrupts](03_Handling_Interrupts.md) chapter we will update our interrupt handling to be able to run in user mode too, and avoid kernel panics

Then in the [System Calls](04_System_Calls.md) we'll introduce the the concept of system calls. These are a controlled way to allow user programs to ask the kernel to perform certain tasks for it.

Finally in [Example ABI](05_Example_ABI.md) chapter we will implement an example system call interface for our kernel.

## Some Terminology

The `x86` architecture defines 4 rings of operation, with ring 0 having the most hardware access, and ring 3 having the least. The intent was for drivers to run in rings 1 and 2, with various permissions granted to those rings. However, overtime most programs were written to run with either full kernel permissions (ring 0) or as a user program (ring 3).

By the time paging was added to x86, rings 1 and 2 were essentially non-existent. That's why paging has a single bit to indicate whether a page is user or supervisor. Supervisor being the term used to refer to privileged ring 0 code and data. This trend carries across to other platforms too, where permissions are often binary. Just for curiosity, rings 1 and 2 do count as supervisor mode for page accesses.

We'll try to use the terms supervisor and user where possible, as this is the suggested approach to thinking about this, but will refer to protection rings where it's more accurate to do so.

## A Change in Perspective

Up until this point, we've just had kernel code running, maybe in multiple threads, maybe not. When we start running user code, it's a good idea to think about things from a different perspective. The kernel is not running a user program, rather the user program is running and the kernel is a library that provides some functions for the user program to call.

Of course there is only a single kernel, and it's the same kernel that runs alongside each user program.

These functions provided by the kernel are special, they're called *system calls*. This is code that runs in supervisor mode, but can be called by user mode. Meaning we must be extremely careful what system calls are allowed to do, how they accept arguments, and what data is returned. Every argument that is given to a system call should be scrutinized and validated anyway it can be.


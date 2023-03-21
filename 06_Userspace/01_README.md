# All About Userspace

This section is focused on x86, but a lot of high level concepts apply to other platforms. Details on getting to userspace and back for other platforms may come later.

## Some Terminology
The x86 architecture defines 4 rings of operation, with ring 0 having the most hardware access, and ring 3 having the least. The intent was for drivers to run in rings 1 and 2, with various permissions granted to those rings. However, overtime most programs were written to run with either full kernel permissions (ring 0) or as a user program (ring 3).

By the time paging was added to x86, rings 1 and 2 were essentially non-existent. That's why paging has a single bit to indicate whether a page is user or supervisor. Supervisor being the term used to refer to privileged ring 0 code and data. This trend carries across to other platforms too, where permissions are often binary. If you're curious, rings 1 and 2 do count as supervisor for page accesses.

For example, the risc-v platform has supervisor mode and user mode. Later ARM processors have PL0 and PL1, sound familiar?

We'll try to use the terms supervisor and user where possible, as this is the suggested approach to thinking about this, but will refer to protection rings where it's more accurate to do so.

## A Change in Perspective
Up until this point, we've just had kernel code running, maybe in multiple threads, maybe not. When we start running user code, it's a good idea to think about things from a different perspective. The kernel is not running a user program, rather the user program is running and the kernel is a library that provides some functions for the user program to call.

Of course there is only a single kernel, and it's the same kernel that runs alongside each user program. You might be starting to see the implications of this, and possibilities that go with it.

These functions provided by the kernel are special, they're called *system calls*. This is code that runs in supervisor mode, but can be called by user mode. Meaning you must be extremely careful what you allow system calls to do, how you accept arguments, and what data is returned. Every argument that is given to a system call should be scrutinized and validated anyway it can be.

* [Switching Modes](02_Switching_Modes.md)
* [Handling Interrupts](03_Handling_Interrupts.md)
* [System Calls](04_System_Calls.md)
* [An Example Syscall ABI](05_Example_ABI.md)

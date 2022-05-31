# All About Userspace

This section is focused on x86, but a lot of high level concepts apply to other platforms. Details on getting to userspace and back for other platforms may come later.

## Some Terminology
The x86 architecture defines 4 rings of operation, with ring 0 have full hardware access, and ring 3 having the least. The intent was for drivers to run in rings 1 and 2, with some permissions granted to those rings. However overtime most programs were written to run with either full kernel permissions (ring 0) or as a user program (ring 3).

By the time paging was added to x86, rings 1 & 2 were essentially non-existent. That's why paging has a single bit to indicate whether a page is user or supervisor. Supervisor being the term used to refer to privileged ring 0 code and data. This trend carries across to other platforms too, where permissions are often binary.

Risc-V for example, defines supervisor mode and user mode, as well as machine mode. Machine mode is analogous to system management mode on x86. Sounds familiar?

In summary, supervisor mode is the kernel and anything running in ring 0 (drivers, interrupt handlers, etc ...), user mode is anything else that dosn't need full hardware permissions.

## A Change in Perspective
Up until this point, we've just had kernel code running, maybe in multiple threads, maybe not. When we start running user code, it's a good idea to think about things from a different perspective. The kernel is not running a user program, rather the user program is running and the kernel is a library that provides some functions for the user program to call.

Of course there is only a single kernel, and it's the same kernel that runs alongside each user program. You might be starting to see the implications of this, and possibilities that go with it.

These functions that the kernel provides to user programs are special, they're called system calls. They're code that runs in supervisor mode, but can be called by user mode. This means you must be extremely careful what you allow system calls to do, and what data is returned. Every argument that is given to a system call should be scrutinized and validated anyway it can be.

* [Switching Modes](SwitchingModes.md)
* [Handling Interrupts](HandlingInterrupts.md)
* [System Calls](SystemCalls.md)

# Useful Links
TODO(DT):

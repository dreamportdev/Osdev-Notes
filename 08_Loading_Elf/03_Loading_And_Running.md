# Loading and Running an ELF

Before we start, we're going to apply a few restrictions to our program loader. These are things you can easily add later, but they only serve to complicate the process.

For a program to be compatible with our loader:

- It cannot contain any relocations. We don't care about static linking or position independent code (PIC) however, as that doesn't affect the loader.
- All libraries must be statically linked, we won't support dynamic linking for now. This feature isn't too hard to implement, but we will leave this as an exercise to the reader.
- The program must be freestanding! As of right now we don't have a libc that targets our kernel. It can be worth porting (or writing) a libc later on.

# Overview

In the previous chapter we looked at the details of loading program headers, but we glossed over a lot of the high level details of loading a program. Assuming we want to start running a new program (we're ignoring `fork()` and `exec()` for the moment), we'll need to perform the following:

- Create a new address space for the program. The specifics may depend on your design, but this usually results in a new VMM being instanced for the new program. Of course the kernel must live in the higher half of this new address space.
- Inside this address space we're going to load the program headers, like we did perviously. Remember that the phdrs expect to be loaded at certain virtual addresses.
- Now we'll need to create a new thread that uses this address space, this thread will serve as our main thread. In our design this involves first creating a new process, attaching the address space and then creating the thread. You will also need create a stack for this thread to run on.
- We'll want this thread to execute the entry function of the 

## Caveats

- running user thread requires ring switch

- dont forgot to exit()!

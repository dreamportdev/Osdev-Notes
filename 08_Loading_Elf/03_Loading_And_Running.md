# Loading and Running an ELF

Before we start, we're going to apply a few restrictions to our program loader. These are things you can easily add later, but they only serve to complicate the process.

For a program to be compatible with our loader:

- It cannot contain any relocations. We don't care about static linking or position independent code (PIC) however, as that doesn't affect the loader.
- All libraries must be statically linked, we won't support dynamic linking for now. This feature isn't too hard to implement, but we will leave this as an exercise to the reader.
- The program must be freestanding! As of right now we don't have a libc that targets our kernel. It can be worth porting (or writing) a libc later on.

# Overview

In the previous chapter we looked at the details of loading program headers, but we glossed over a lot of the high level details of loading a program. Assuming we want to start running a new program (we're ignoring `fork()` and `exec()` for the moment), we'll need to perform the following:

- Create a new address space for the program. The specifics may depend on your design, but this usually results in a new VMM being instanced for the new program. Of course the kernel must live in the higher half of this new address space.
- Inside this address space we're going to load the program headers, like we did perviously. Remember that the phdrs expect to be loaded at certain virtual addresses with certain permissions.
- Now we'll need to create a new thread that uses this address space, this thread will serve as our main thread. In our design this involves first creating a new process, attaching the address space and then creating the thread. You will also need create a stack for this thread to run on (if this is not already part of your thread-creation process).
- We'll want this thread to execute the entry function of the ELF file, this is available in the ELF header as the field `e_entry`.

If you've done all of this then the program is ready to run! You should be able to queue the main thread in your scheduler and let it run.

## Caveats

As you can already see from the restrictions we made above there is plenty of room for improvement. There are also some other things to keep in mind:

- If you're loading a program into *userspace* (rather than in the kernel) you will need to map all the memory you want to allow the program to use as user-accessible. This means not just the program headers but also the stack.
- Again if you're loading a user program your scheduler will need to handle switching between different privilege levels on the cpu. On x86_64 these are called rings (ring 0 = kernel, ring 3 = user), other platforms may use different names. See the userspace chapter for more detail.
- As was mentioned in the scheduling chapter, don't forget to call a function when exiting the main thread of the program! In a typical userspace program the standard library does this for us, but our programs are freedstanding so you'll need to do this manually. If coming from userspace this will require a syscall.

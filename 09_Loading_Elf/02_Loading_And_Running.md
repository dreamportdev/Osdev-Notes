# Loading and Running an ELF

Before we start, we're going to apply a few restrictions to our program loader. These are things you can easily add later, but they only serve to complicate the process.

For a program to be compatible with our loader:

- It cannot contain any relocations. We don't care about static linking or position independent code (PIC) however, as that doesn't affect the loader.
- All libraries must be statically linked, we won't support dynamic linking for now. This feature isn't too hard to implement, but we will leave this as an exercise to the reader.
- The program must be freestanding! As of right now we don't have a libc that targets our kernel. It can be worth porting (or writing) a libc later on.

## Steps Required

In the previous chapter we looked at the details of loading program headers, but we glossed over a lot of the high level details of loading a program. Assuming we want to start running a new program (we're ignoring `fork()` and `exec()` for the moment), we'll need to do a few things. Most of this was covered in previous chapters, and now it's a matter of putting it all together.

- First a copy of the ELF file to be loaded is needed. The recommended way is to load a file via the VFS, but it could be a bootloader module or even embedded into the kernel.
- Then once the ELF is loaded, we need verify that its header is correct. Also check the architecture (machine type) matches the current machine, and that the bit-ness is correct (dont try to run a 32-bit program if you dont support it!).
- Find all the loadable program headers for the ELF, we'll need those in a moment.
- Create a new address space for the program to live in. This usually involves creating a new VMM instance, but the specifics will vary depending on your design. Don't forget to keep the kernel mappings in the higher half!
- Copy the loadable program headers into this new address space. Take care when writing this code, as the program headers may not be page-aligned:. Don't forget to zero the extra bytes between `memsz` and `filesz`.
- Once loaded, set the appropriate permission on the memory each program header lives in: the write, execute (or no-execute) and user flags.
- Now we'll need to create a new thread to act as the main thread for this program, and set its entry point to the `e_entry` field in the ELF header. This field is the start function of the program. You'll also need to create a stack in the memory space of this program for the thread to use, if this wasnt already done as part of your thread creation.

If all of the above are done,  then the program is ready to run! We now should be able to enqueue the main thread in the scheduler and let it run.

## Caveats

As we can already see from the above restrictions there is plenty of room for improvement. There are also some other things to keep in mind:

- If the program is going to be loaded into *userspace* (rather than in the kernel) we will need to map all the memory we want to allow the program to use as user-accessible. This means not just the program headers but also the stack. We'll  want to mark all this memory as user-accessible *after* copying the program data in there though.
- Again if the program being loaded is a user program the scheduler will need to handle switching between different privilege levels on the cpu. On `x86_64` these are called rings (__ring 0__ = kernel, __ring 3__ = user), other platforms may use different names. See the userspace chapter for more detail.
- As mentioned earlier in the scheduling chapter, don't forget to call a function when exiting the main thread of the program! In a typical userspace program the standard library does this for us, but our programs are freestanding so it needs to be done manually. If coming from userspace this will require a syscall.

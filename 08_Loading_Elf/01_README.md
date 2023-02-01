# Loading An ELF

This chapter won't be too heavy on new concepts, besides the ELF specification itself, but will focus on bringing everything together. We're going to load a program in a new process, and run it in userspace. This is typically how most programs run, and then from there we can execute a few example system calls.

It should be noted that the original ELF specification is for 32-bit programs, but a *64-bit extensions* was created later on called ELF64. We'll be focusing on ELF64.

## Restrictions

To simplify our program loader we're going to put a few restrictions in place for now. Later on you can expand the loader yourself as you come across features you might want to support.

For a program to be compatible with our loader:

- It cannot contain any relocations. We don't care if it's statically linked or uses PIC (position independent code) however.
- All libraries must be statically linked, we won't support dynamic linking for now. This feature can be implemented over a weekend, but greatly increases the complexity of your loader.
- The program must be freestanding, since we haven't ported (or written) a libc we can't use any standard functions. Porting a libc is worthwhile, but it's outside the scope of this chapter.

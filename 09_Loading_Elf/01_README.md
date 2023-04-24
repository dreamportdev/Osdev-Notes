# Loading An ELF

The *executable and linker file* (ELF) is an open standard for programs, libraries and shards of code and data that are waiting to linked. It's the most common format used by linux and BSD operating systems, and sees some use elsewhere. It's also the most common format for programs in hobby as it's quite simple to implement and it's public specification is feature-complete.

That's not to say ELF is the *only* format for these kinds of files (there are others like PE/portable execute, a.out or even mach-o), but the ELF format is the best for our purposes. A majority of operating systems have come to a similar to conclusion. We could also use our own format, but be aware this requires a compiler capable of outputting it (meaning either write our own compiler, or modify an existing one - a lot of work!).

This chapter won't be too heavy on new concepts, besides the ELF specification itself, but will focus on bringing everything together. We're going to load a program in a new process, and run it in userspace. This is typically how most programs run, and then from there we can execute a few example system calls.

It should be noted that the original ELF specification is for 32-bit programs, but a *64-bit extension* was created later on called ELF64. We'll be focusing on ELF64.

It's worth having a copy of the ELF specification as a reference for this chapter as we won't define every structure required. The specification doesn't use fixed width types in it's definiton, instead using `words` and `half words`, which are based on the word size of the cpu. For the exact definition of these terms we will need the platform-specific part of the ELF spec, which gives concrete types for these.

For `x86_64` these types are defined as follows:

```c
typedef uint64_t Elf64_Addr;
typedef uint64_t Elf64_Off;
typedef uint16_t Elf64_Half;
typedef uint32_t Elf64_Word;
typedef int32_t Elf64_Sword;
typedef uint64_t Elf64_Xword;
typedef int64_t Elf64_Sxword;
typedef uint8_t Elf64_UnsignedChar;
```

All structs in the base ELF spec are defined using these types, and so we will use them too. Note that their exact definitions *will* change depending on the target platform.

In this chapter we're going to look at the following topics:

- [General ELF Theory](02_Elf_Theory.md)
- [Loading A Program](03_Loading_And_Running.md)

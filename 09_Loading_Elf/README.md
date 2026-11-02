# Loading ELFs

In this part we're going to look at the executable and linker file (ELF) format, and how we can write a loader for it. This will let us load programs along the kernel (like hardware drivers we detect at runtime), or load programs into userspace!

This part is organised as follows:

- [High-level Overview](01_Overview.md) A high level look at how the ELF specifications are structured, how to approach them and get the info we need.
- [Theory](02_Elf_Theory.md) We'll look at what the pieces of an ELF file are, which ones are important to us, and how they fit together.
- [Simple Loader](03_Simple_Loader.md) In this chapter we'll implement a simple loader for fixed-position executables.
- [Position Independent Loader])(04_Position_Independent_Loader.md) Here we'll look at extending our loader to handle position-independent executables and shared objects.


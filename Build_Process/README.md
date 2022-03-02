# Building A Kernel from C/C++ Source Files.

Basic knowledge of compiling these languages is assumed, but kernel specific notes are detailed below. This article goes over how and why to build a freestanding program.

## Freestanding Environment
If you build a C file with no extra flags, you'll end up with an executable that starts running code at the function `void main(int argc, char** argv, char** envp)`.
However, this is actually not where your program starts executing! A bunch of libraries from your host os, compiler and sometimes specific to your language will be added to your program automatically. This eases development for regular applications, but complicates life a little for developing a kernel.

A userspace program normally begins at `void _start()`, which is part of the c standard library, and will setup things like some global state, and parts of the environment. It will also call `_init()` which calls global constructors for languages like C++. Things like environment variables dont automatically exist in a program's memory space, they have to be fetched from somewhere, same with the command line. This all happens in `_start()`.

Since we will be writing the operating system, we can't depend on any functionality that requires our *host operating system*, like these libraries. This is called a freestanding program. It has no external dependencies.

*Authors note: techincally your kernel can depend on some utility libraries, or sections of the compiler runtime. However the idea is you should build your code with nothing extra added by default, and only add things back in that are also freestanding.*

In a freestanding environment, you should assume nothing. That includes the standard library (as it requires os support to work). Your program will also need a special linker script in order to run properly, since the linker wont know where to start your program, since the usual main function means nothing here. See below for this.

Both C and C++ have several freestanding headers. The common ones are `stdint.h`, `stddef.h` for C/C++, and `utility` and `type_traits` for C++. There are a few others, and compiler vendors will often supply extra freestanding headers. GCC and Clang provide ones like `cpuid.h` as a helper for x86 cpuid functions, for example.

## Cross Compilation
Often this is not necessary for hobby os projects, as we are running our code on the same cpu architecture that we're compiling on. However it's still recommended to use one as you have can configure the cross compiler to the specs you want, rather than relying on the one provided by your host os. 

A cross compiler is always required when building your os for a different isa to your host. Building code for an risc-v cpu, while running on an x86 cpu would require a cross compiler for example.

The two main compiler toolchains used are gcc and clang. They differ a lot in philosophy, but are comparable in a lot of the ways we care about. GCC is much older and so it established a lot of the conventions used, such as the majority ofs compiler flags, inline assembly and some language extensions. Clang honours most (if not all) of these, and the two seem to be feature equivilent, with the exception of some experimental features.

## Differences Between GCC and Clang

The main difference is that GCC requires a completely separate set of bianries (mean ing a separate build) for each target architecture, while clang is designed in a modular fashion and will swap out the parts for each target architecture as needed. This ultimately means you will need to build (or download) a separate gcc toolchain for each target platform, while clang only needs a single toolchain setup.

However, each GCC toolchain will use the platform-specific headers by default, where as clang seems to have insane defaults in this area. You'll generally always want to have the platform-specific headers GCC supplies regardless of which toolchain you build with.

Compiling GCC from source dosnt take too long on a modern CPU (~10 minutes for a complete build on a 7th gen intel mobile cpu, 4 cores), however there are also prebuilt binaries online from places like [bootlin](https://toolchains.bootlin.com/).

## Building C Source Files
- disabling cpu extensions (x87, sse/sse2)
- useful flags to enable (always emit frame pointers)

### Building C++ Source Files
- rtti, exceptions and no removing unwind tables

## Linking Object Files Together
- Ref to linker scripts explanation. @Ivan.

[LinkerScripts](Build_Process/LinkerScripts.md)

## Quick Addendum: Easily Generating a Bootable ISO
- Depends on bootloader, assume grub for now (grub-mkrescue). Also make reference to limine-install.
- Talk about xorisso.

## Building and Using Debugging Symbols
- -g flag, quick mention of different symbol formats (defaults to host, fine if debugging on host).

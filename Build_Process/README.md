# Building A Kernel from C/C++ Source Files.

Basic knowledge of compiling these languages is assumed, but kernel specific notes are detailed below. This article goes over how and why to build a freestanding program.

## Freestanding Environment
If you build a C file with no extra flags, you'll end up with an executable that starts running code at the function `void main(int argc, char** argv, char** envp)`.
However, this is actually not where your program starts executing! A number of libraries from your host os, compiler and sometimes specific to your language will be added to your program automatically. This eases development for regular applications, but complicates life a little for developing a kernel.

A userspace program normally begins at `void _start()`, which is part of the c standard library, and will setup things like some global state, and parts of the environment. It will also call `_init()` which calls global constructors for languages like C++. Things like environment variables dont automatically exist in a program's memory space, they have to be fetched from somewhere, same with the command line. This all happens in `_start()`.

Since we will be writing the operating system, we can't depend on any functionality that requires our *host operating system*, like these libraries. This is called a freestanding program. It has no external dependencies.

*Authors note: techincally your kernel can depend on some utility libraries, or sections of the compiler runtime. However the idea is you should build your code with nothing extra added by default, and only add things back in that are also freestanding.*

In a freestanding environment, you should assume nothing. That includes the standard library (as it requires os support to work). Your program will also need a special linker script in order to run properly, since the linker wont know where to start your program, since the usual main function means nothing here. See below for this.

Both C and C++ have several freestanding headers. The common ones are `stdint.h`, `stddef.h` for C/C++, and `utility` and `type_traits` for C++. There are a few others, and compiler vendors will often supply extra freestanding headers. GCC and Clang provide ones like `cpuid.h` as a helper for x86 cpuid functions, for example.

## Cross Compilation
Often this is not necessary for hobby os projects, as we are running our code on the same cpu architecture that we're compiling on. However it's still recommended to use one as you have can configure the cross compiler to the specs you want, rather than relying on the one provided by your host os. 

A cross compiler is always required when building your os for a different cpu architecture to your host. Building code for an risc-v cpu, while running on an x86 cpu would require a cross compiler for example.

The two main compiler toolchains used are gcc and clang. They differ a lot in philosophy, but are comparable for a lot of the things we care about. GCC is much older and so it established a lot of the conventions used, such as the majority ofs compiler flags, inline assembly and some language extensions. Clang honours most (if not all) of these, and the two seem to be feature equivilent, with the exception of some experimental features.

## Differences Between GCC and Clang

The main difference is that GCC requires a completely separate set of bianries (mean ing a separate build) for each target architecture, while clang is designed in a modular fashion and will swap out the parts for each target architecture as needed. This ultimately means you will need to build (or download) a separate gcc toolchain for each target platform, while clang only needs a single toolchain setup.

However, each GCC toolchain will use the platform-specific headers by default, where as clang seems to have insane defaults in this area. You'll generally always want to have the platform-specific headers GCC supplies regardless of which toolchain you build with.

Compiling GCC from source doesn't take too long on a modern CPU (~10 minutes for a complete build on a 7th gen intel mobile cpu, 4 cores), however there are also prebuilt binaries online from places like [bootlin](https://toolchains.bootlin.com/).

## Setting up a build environment
Setting up a proper build environment can be broken down into a few steps:
- Setup a cross compilation toolchain.
- Install an emulator.
- Install any additional tools.
- Setup your bootloader of choice.
- Run a hello world to check everything works.

### Getting a Cross Compiler
The easiest approach here is to simply use clang. Clang is designed to be a cross compiler, and so any install of clang can compile to any supported platform.
To compile for another platform simply invoke clang as you normally would, additonally passing `--target=xyz`, where xyz is the target triplet for your target platform.

For x86_64 you would pass `--target=x86_64-elf`. Target triplets describe the hardware instruction set + operating system + file format of what you want to compile for. In this case we are the operating system so that part can be omitted.

Setting up a GCC cross compiler is a little more hands on, but still very simple. The first approach is to simply download a pre-compiled toolchain (see the link above). This is super simple, with the only major disavantage being that you may not be getting the latest version.

The other approach is to compile GCC yourself. This takes more time, but it's worth understanding the process, [described here](CompilingGCC.md).

The following sections will use the common shorthands to kepe things simple:
| Shorthand | Meaning                   |
|-----------|---------------------------|
| $(CC) | C Compiler (cross compiler version we just setup) |
| $(CXX) | C++ compiler (cross-compiler version) |
| $(LD) | Linker (again, cross compiler version) |
| $(C_SRCS) | All the C source files to compile |
| $(OBJS) | All the object files to link |

If you're using clang be sure to remember to pass `--target=xyz` with each command. This is not necessary with GCC.

### Building C Source Files
Now that we have a toolchain setup we can test it all works by compiling a C file.
Create a C source file, it's contents dont matter here as we wont be running it, just telling it compiles.

Run the following to compile the file into an object file, and then to link that into the final executable.
```sh
$(CC) hello_world.c -c -o hello_world.o -ffreestanding
$(LD) hello_world.o -o hello_world.elf -nostdlib
```

If all goes well, there should be no errors. At this point you can try running your executable, which will likely result in a segfault if its for your native platform, or it wont run if you've compiled it for another platform.
You can optionally use `readelf` or `objdump` to inspect the compiled elf.

Regarding the flags used above, `-ffreestanding` tells the compiler that this code is freestanding and should not reference outside code. `-nostdlib` tells the linker a similar thing, and tells it not to link against any of the standard libraries. The only code in the final executable now is yours.

Now there are still several things to be aware of: for example the compiler will make the assumption that all of the cpu's features are available. On x86_64 it'll assume that the FPU and sse(2) are available. This is true in userspace, but not so for the kernel, as we have to set them up before they work!

Telling the compiler to not use these features can be done by passing some extra flags:
- `-mno-red-zone`: disables the red-zone, a 128 byte region reserved on the stack for optimizations. Hardware interrupts are not aware of the red-zone, and will clobber it. So we ned to disable it in the kernel or we'll loose data.
- `-mno-80387`: Not strictly necessary, but tells the compiler that the FPU is not available, and to process floating point calculations in software instead of hardware, and to not use the FPU registers.
- `-mno-mmx`: Disables using the FPU registers for 64-bit integer calculations.
- `-mno-3dnow`: Disables 3dnow! extensions, similar to MMX.
- `-mno-sse -mno-sse2`: Disables SSE and SSE2, which use the 128-bit xmm registers, and require setup before use.

There are also a few other compiler flags that are useful, but not necessary:
- `-fno-stack-protector`: Disables stack protector checks, which use the compiler library to check for stack smashing attacks. Since we're not including the standard libaries, we cant use this unless we implement the functions ourselves. Not really worth it.
- `-fno-omit-frame-pointer`: Sometimes the compiler will skip creating a new stack frame for optimization reasons. This will mess with stack traces, and only increases the memory usage by a few bytes here and there. Well worth having.
- `-Wall` and `-Wextra`: These flags need no introduction, they just enable all default warnings, and then extra warnings on top of that. Some people like to use `-Wpedantic` as well, but it can cause some false positives.

### Building C++ Source Files
This section should be seen as an extension to the section above on compiling C files, compiler flags included.

When compiling C++ for a freestanding environment, there are a few extra flags that are required:
- `-fno-rtti`: Tells the compiler not to generate **R**un**t**ime **t**ype **i**nformation. This requires runtime support from the compiler libaries, and the os. Neither of which we have in a freestanding environment.
- `-fno-exceptions`: Requires the compiler libraries to work, again which we dont have. Means you can't use C++ exceptions in your code. Some standard functions (like the `delete` operator) will still required you to declare them `noexcept` so the correct symbols are generated.

And a few flags that are not required, but can be nice to have:
- `-fno-unwind-tables` and `-fno-asynchronous-unwind-tables`: tells the compiler not to generate unwind tables. These are mainly used by exceptions and runtime type info (rtti - dynamic_cast and friends). Disabling them just cleans up the resulting binary, and reduces its file size.

## Linking Object Files Together
The GCC Linker (ld) and the compatable clang linker (lld.ld) can accept linker scripts.
These describe the layout of the final executable to the linker: what things go where, with what alignment and permissions.
Ultimately this file is what's loaded by the bootloader, so these details can be important.

These are their own topic, and have a file dedicated to them [here](Build_Process/LinkerScripts.md). You likely havent used these when building userspace programs, as your compiler/os installation provides a default one. However since we're building a freestanding program (the kernel) we need to be explicit about these things. 

To use a linker script you add `-T script_name_here.ld` to the linker command.

Outside of linker scripts, the linking process goes as you'd expect:
```sh
$(LD) $(OBJS) -o output_filename_here.elf -nostdlib -static -pie --no-dynamic-linker
```

For an explanation of the above linker flags used:
- `-nostdlib`: this is crucial for building a freestanding program, as it stops the linker automatically including the default libraries for the host platform. Otherwise your program will contain a bunch of code that wants to make syscalls to your host OS.
- `-static`: A safeguard for linking against other libarires. The linker will error if you try to dynamically link with anything (i.e static linking only). Because again there is not runtime, there is no dynamic linker. 
- `-pie` and `--no-dynamic-linker`: Not strictly necessary, but forces the linker to output a relocatable program with a very narrow set of relocations. This is useful as it allows some bootloaders to perform relocations on the kernel.

### Building with Makefiles
Now compiling and building one file isn't so bad, but the same process for muliple files can quickly get out of hand. This is especially true when you only want to build files that have been modified, and use previously compiled versions of other files.

For an example using makefiles, [check here](GNUMakefiles.md). Makefiles are a common tool used for building many pieces of software due to how how easy and commmon `make` is. Specifically GNU make. GNU make is also chosen as it comes installed by default in many linux distros, and is almost always available if it's not already installed.

There are other make-like tools out there (xmake, nmake) but these are less popular, and therefore less standardized. For the lowest common denominator we'll stick with the original GNU make.

This section may expand to include other build systems (meson, cmake) soon.

## Quick Addendum: Easily Generating a Bootable ISO
There are more details to this, however most bootloaders will provide a tool that lets you create a bootable iso, with the kernel, the bootloader itself and any other files you might want. For grub this is `grub-mkrescue` and limine provides `limine-install` for version 2.x or `limine-desploy` for version 3.x.

- Depends on bootloader, assume grub for now (grub-mkrescue). Also make reference to limine-install.
- Talk about xorisso.
- Maybe a separate file on the different boot protocols? how they differ, whats required to support them, and how to generate an iso using their tools.
[here](GeneratingISO.md)

## Building and Using Debugging Symbols
- -g flag, quick mention of different symbol formats (defaults to host, fine if debugging on host).
- how to get these symbols: mb2 has a tag for sections, stivale2 provides the entire elf file.

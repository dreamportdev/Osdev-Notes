# Build Process

An OS like any other project needs to be built and packaged, but it is different from any other programs, we don't only need it to be compiled, but  it needs different tools and steps in order to have an image that can be loaded by a bootloader. And booting it requires another step.

In this part we are going to explore all the tools and steps that are needed in order to have an initial set of building scripts for our os, and also will explore some options for the compilers and the bootloader that can be used for our kernel.

In this chapter we will have a global overview of the build process, touching briefly what are the steps involved, and the tools that are going to be used.

Then in the [Boots Protocols and Bootloaders](02_Boot_Protocols.md) chapter we will explore in detail how to boot a kernel, and describe two options that can be used for the boot process: Multiboot and Stivale.

The [Makefiles](04_Gnu_Makefiles.md) chapter will explain how to build a process, even if initially is just a bunch of file and it can be done manually, it soon grow more complex, and having the process automated will be more than useful, we will use _Makefile_ for our build script.

One of the most _obscure_, that is always present while building any software, but is hidden to us until we start to roll up our own kernel is the _linking process_. The [Linker Scripts](05_Linker_Scripts.md) chapter will introduce us to the world of _linking_ files and explain how to write a linker script.

Finally the kernel is built but not ready to run yet, we need to copy it into a bootable media, the [Generating A Bootable Iso](06_Generating_Iso.md) chapter will show how to create a bootalbe iso of our kernel, and finally being able to launch it and see the results of our hard work.


For the rest of this part a basic knowledge of compiling these languages is assumed.

## Freestanding Environment

If we build a C file with no extra flags, we'll end up with an executable that starts running code at the function `void main(int argc, char** argv, char** envp)`.
However, this is actually not where our program starts executing! A number of libraries from the host os, compiler and sometimes specific to the language will be added to our program automatically. This eases development for regular applications, but complicates life a little for developing a kernel.

A userspace program actually begins executing at `void _start()`, which is part of the c standard library, and will setup things like some global state, and parts of the environment. It will also call `_init()` which calls global constructors for languages like C++. Things like environment variables don't automatically exist in a program's memory space, they have to be fetched from somewhere. Same with the command line. This all happens in `_start()`.

Since we will be writing the operating system, we can't depend on any functionality that requires our *host operating system*, like these libraries. A program like this is called a *freestanding* program. It has no external dependencies.

*Authors note: technically your kernel can depend on some utility libraries, or sections of the compiler runtime. However the idea is you should build your code with nothing extra added by default, and only add things back in that are also freestanding.*

In a freestanding environment, we should assume nothing. That includes the standard library (as it requires os support to work). Our program will also need a special linker script in order to run properly, since the linker wont know where to start the program. Linker scripts are expanded on below, as well as in their own chapter.

Both C and C++ have several freestanding headers. The common ones are `stdint.h`, `stddef.h` for C/C++, and `utility` and `type_traits` for C++. There are a few others, and compiler vendors will often supply extra freestanding headers. GCC and Clang provide ones like `cpuid.h` as a helper for x86 cpuid functions, for example.

## Cross Compilation

Often this is not necessary for hobby os projects, as we are running our code on the same cpu architecture that we're compiling on. However it's still recommended to use one as we can configure the cross compiler to the specs we want, rather than relying on the one provided by the host os.

A cross compiler is always required when building the os for a different cpu architecture. Building code for a `risc-v` cpu, while running on an `x86` cpu would require a cross compiler for example.

The two main compiler toolchains used are _gcc_ and _clang_. They differ a lot in philosophy, but are comparable for a lot of the things we care about. GCC is much older and so it established a lot of the conventions used, such as the majority of compiler flags, inline assembly and some language extensions. Clang honours most (if not all) of these, and the two seem to be feature equivalent, with the exception of some experimental features.

## Differences Between GCC and Clang

The main difference is that GCC requires a completely separate set of binaries (meaning a separate build) for each target architecture, while clang is designed in a modular fashion and will swap out the parts for each target architecture as needed. This ultimately means we will need to build (or download) a separate gcc toolchain for each target platform, while clang only needs a single toolchain setup.

However, each GCC toolchain will use the platform-specific headers by default, where as clang seems to have insane defaults in this area. We'll generally always want to have the platform-specific headers GCC supplies regardless of which toolchain we build with.

Compiling GCC from source doesn't take too long on a modern CPU (~10 minutes for a complete build on a 7th gen intel mobile cpu, 4 cores), however there are also prebuilt binaries online from places like bootlin, see the useful links appendix for .

## Setting up a build environment
Setting up a proper build environment can be broken down into a few steps:

- Setup a cross compilation toolchain.
- Install an emulator.
- Install any additional tools.
- Setup the bootloader of choice.
- Run a hello world to check everything works.

### Getting a Cross Compiler
The easiest approach here is to simply use clang. Clang is designed to be a cross compiler, and so any install of clang can compile to any supported platform.
To compile for another platform simply invoke clang as normally would, additionally passing `--target=xyz`, where xyz is the target triplet for the target platform.

For `x86_64` the target triplet  would be `--target=x86_64-elf`. Target triplets describe the _hardware instruction set + operating system + file format_ of what we want to compile for. In this case we are the operating system so that part can be omitted.

Setting up a GCC cross compiler is a little more hands on, but still very simple. The first approach is to simply download a pre-compiled toolchain (see the link above). This is super simple, with the only major disadvantage being that we may not be getting the latest version.

The other approach is to compile GCC. This takes more time, but it's worth understanding the process (it is explained in the appendices section). The osdev wiki has a great guide on this, a link is available in the appendices section.

The following sections will use the common shorthands to keep things simple:

| Shorthand | Meaning                   |
|-----------|---------------------------|
| $(CC) | C Compiler (cross compiler version we just setup) |
| $(CXX) | C++ compiler (cross-compiler version) |
| $(LD) | Linker (again, cross compiler version) |
| $(C_SRCS) | All the C source files to compile |
| $(OBJS) | All the object files to link |

If using clang be sure to remember to pass `--target=xyz` with each command. This is not necessary with GCC.

### Building C Source Files
Now that we have a toolchain setup we can test it all works by compiling a C file.
Create a C source file, its contents don't matter here as we wont be running it, just telling it compiles.

Run the following to compile the file into an object file, and then to link that into the final executable.

```sh
$(CC) hello_world.c -c -o hello_world.o -ffreestanding
$(LD) hello_world.o -o hello_world.elf -nostdlib
```

If all goes well, there should be no errors. At this point we can try running the executable, which will likely result in a segfault if its for our native platform, or it wont run if it has been compiled for another platform.
The commands `readelf` or `objdump` can be used to inspect the compiled elf.

Regarding the flags used above, `-ffreestanding` tells the compiler that this code is freestanding and should not reference outside code. The option `-nostdlib` tells the linker a similar thing, and tells it not to link against any of the standard libraries. The only code in the final executable now is ours.

Now there are still several things to be aware of: for example the compiler will make the assumption that all of the cpu's features are available. On `x86_64` it'll assume that the FPU and sse(2) are available. This is true in userspace, but not so for the kernel, as we have to initialize parts of the cpu hardware for those features to be available.

Telling the compiler to not use these features can be done by passing some extra flags:

- `-mno-red-zone`: disables the red-zone, a 128 byte region reserved on the stack for optimizations. Hardware interrupts are not aware of the red-zone, and will clobber it. So we need to disable it in the kernel or we'll lose data.
- `-mno-80387`: Not strictly necessary, but tells the compiler that the FPU is not available, and to process floating point calculations in software instead of hardware, and to not use the FPU registers.
- `-mno-mmx`: Disables using the FPU registers for 64-bit integer calculations.
- `-mno-3dnow`: Disables 3dnow! extensions, similar to MMX.
- `-mno-sse -mno-sse2`: Disables SSE and SSE2, which use the 128-bit xmm registers, and require setup before use.
- `-mcmodel=kernel`: The compiler uses 'code models' to help optimize code generation depending on where in memory the code might run. The `medium` cmodel runs in the lower 2GiB, while the `large` runs anywhere in the 64-bit address space. We could use `large` for our kernel, but if the kernel is being loaded loading in the top-most 2GiB `kernel` valuie can be used which allows similar optimizations to `medium`.

There are also a few other compiler flags that are useful, but not necessary:

- `-fno-stack-protector`: Disables stack protector checks, which use the compiler library to check for stack smashing attacks. Since we're not including the standard libraries, we can't use this unless we implement the functions ourselves. Not really worth it.
- `-fno-omit-frame-pointer`: Sometimes the compiler will skip creating a new stack frame for optimization reasons. This will mess with stack traces, and only increases the memory usage by a few bytes here and there. Well worth having.
- `-Wall` and `-Wextra`: These flags need no introduction, they just enable all default warnings, and then extra warnings on top of that. Some people like to use `-Wpedantic` as well, but it can cause some false positives.

### Building C++ Source Files

This section should be seen as an extension to the section above on compiling C files, compiler flags included.

When compiling C++ for a freestanding environment, there are a few extra flags that are required:

- `-fno-rtti`: Tells the compiler not to generate runtime type information. This requires runtime support from the compiler libaries, and the os. Neither of which we have in a freestanding environment.
- `-fno-exceptions`: Requires the compiler libraries to work, again which we don't have. Means we can't use C++ exceptions in your code. Some standard functions (like the `delete` operator) still require you to declare them `noexcept` so the correct symbols are generated.

And a few flags that are not required, but can be nice to have:

- `-fno-unwind-tables` and `-fno-asynchronous-unwind-tables`: tells the compiler not to generate unwind tables. These are mainly used by exceptions and runtime type info (_rtti, dynamic_cast_ and friends). Disabling them just cleans up the resulting binary, and reduces its file size.

## Linking Object Files Together

The GCC Linker (`ld`) and the compatible clang linker (`lld.ld`) can accept linker scripts.
These describe the layout of the final executable to the linker: what things go where, with what alignment and permissions.
This is incredibly important for a kernel, as it's the file that will be loaded by the bootloader, which may impose certain restrictions or provide certain features.

These are their own topic, and have a full chapter  dedicated to them later in this chapter. We likely haven't used these when building userspace programs, as our compiler/os installation provides a default one. However since we're building a freestanding program (the kernel) now we need to be explicit about these things.

A linker script can be simply added appending the `-T script_name_here.ld` to the linker command.

Outside of linker scripts, the linking process goes as following:

```sh
$(LD) $(OBJS) -o output_filename_here.elf
    -nostdlib -static -pie --no-dynamic-linker
```

For an explanation of the above linker flags used:

- `-nostdlib`: this is crucial for building a freestanding program, as it stops the linker automatically including the default libraries for the host platform. Otherwise the program will contain a bunch of code that wants to make syscalls to the host OS.
- `-static`: A safeguard for linking against other libraries. The linker will error if we try to dynamically link with anything (i.e static linking only). Because again there is no runtime, there is no dynamic linker.
- `-pie` and `--no-dynamic-linker`: Not strictly necessary, but forces the linker to output a relocatable program with a very narrow set of relocations. This is useful as it allows some bootloaders to perform relocations on the kernel.

One other linker option to keep in mind is `-M`, which displays the link map that was generated. This is a description of how and where the linker allocated everything in the final file. It can be seen as a manual symbol table.

### Building with Makefiles

Now compiling and building one file isn't so bad, but the same process for multiple files can quickly get out of hand. This is especially true when we only want to build files that have been modified, and use previously compiled versions of other files.

_Make_ is a common tool used for building many pieces of software due to how easy and common `make` is. Specifically GNU make. GNU make is also chosen as it comes installed by default in many linux distros, and is almost always available if it's not already installed.

There are other make-like tools out there (xmake, nmake) but these are less popular, and therefore less standardized. For the lowest common denominator we'll stick with the original GNU make, which is discussed later on in its chapter.

## Quick Addendum: Easily Generating a Bootable Iso

There are more details to this, however most bootloaders will provide a tool that lets us create a bootable iso, with the kernel, the bootloader itself and any other files we might want. For grub this is `grub-mkrescue` and limine provides `limine-install` for version 2.x or `limine-deploy` for version 3.x.

While the process of generating an iso is straightforward enough when using something like xorisso, the process of installing a bootloader into that iso is usually bootloader dependent. This is covered more in detail in its own chapter.

If just here for a quick reference, grub uses `grub-mkrescue` and a `grub.cfg` file, limine reqiures us to build the iso by yourselves with a `limine.cfg` on it, and then run `limine-deploy`.

## Testing with An Emulator

Now we have an iso with our bootloader and kernel installed onto it, how do we test this? Well there's a number of emulators out there, with varying levels of performance and debug utility. Generally the more debug functionality an emulator provides, the slower it will run. A brief comparison of some common x86 emulators is provided below.

- _Qemu_ is great middle ground between debugging and speed. By default our OS will run using software virtualization (qemu's implementation is called tcg), but we can optionally enable kvm with the `--enable-kvm` flag for hardware-assisted virtualization. Qemu also provides a wide range of supported platforms.
- _Bochs_ is x86 only at the time of writing, and can be quite slow. Very useful for figuring things out at the early stages, or for testing very specific hardware combinations though, as we get the most control over the emulated machine.
- _VirtualBox/VMWare_. These are grouped together as they're more industrial virtualization software. They aim to be as fast as possible, and provide little to no debug functionality. Useful for testing compatibility, but not day-to-day development.

We'll be using qemu for this example, and assuming the output filename of the iso is contained in the makefile variable `ISO_FILENAME`.

```makefile
# runs our kernel
run:
    qemu-system-x86_64 -cdrom $(ISO_FILENAME)
run-with-kvm:
    qemu-system-x86_64 -cdrom $(ISO_FILENAME) --enable-kvm
```

There are a few other qemu flags we might want to be aware of:

- `-machine xyz` changes the machine that qemu emulates to xyz. To get a list of supported machines, use `-machine help`. Recommended is to use `-machine -q35` as it provides some modern features like the mcfg for accessing pci over mmio instead of over IO ports.
- `-smp` used to configure how many processors and their layout. If wanting to support smp, it's recommended to enable this early on as it's easier to fix smp bugs as they are added, rather than fixing them all at once if we add smp support later. To emulate a simple quad-core cpu use `-smp cores=4`.
- `-monitor` qemu provides a built in monitor for debugging. Super useful! It's always available in it's own tab (under view->monitor) but we can move the monitor to terminal that was used to launch qemu using `-monitor stdio`. The built in terminal is fairly basic, so this is recommended.
- `-m xyz` is used to set the amount of ram given to the VM. It supports common suffixes like 'M' for MiB, 'G' for GiB and so on.
- `-cpu xyz` sets the cpu model to emulate, like `-machine` and list can be viewed by running qemu with `-cpu help`. There are some special options like 'host' which will try to emulate the host's cpu, or 'qemu64' which provides a generic cpu with as many host-supported features. There is also 'max' which provides every feature possible either through kvm or software implementations.
- `-d` for enable debug traces of certain things. `-d int` is the most useful, for logging the output of any interrupts that occur. If running with uefi instead of bios we may get a lot of SMM enter/exit interrupts during boot, these can be disabled (in the log) by using `-d int -M smm=off`.
- `-D` sets the output for the debug log. If not specified this is stdout, but we can redirect it to anywhere.
- `-S` pauses the emulator before actually running any code. Useful for attaching a debugger early on.
- `-s` creates a gdb server on port 1234. Inside of gdb we can attach to this server and debug our kernel/bootloader using `target remote :1234`.
- `-no-reboot` when qemu encounters a triple fault, it will reset the machine (meaning it restarts, and runs from the bootloader again). This flag tells qemu to pause the virtual machine immediately after the faulting instruction. Very useful for debugging!
- `-no-shutdown` some configurations of qemu will shutdown if `-no-reboot` is specified, instead of pausing the VM. This flag forces qemu to stay open, but paused.

## Building and Using Debugging Symbols

We'll never know when we need to debug your kernel, especially when running in a virtualized environment. Having debug symbols included in the kernel will increase the file size, but can be useful. If we want to remove them from an already compiled kernel the `strip` program can be used to strip excess info from a file.

Including debug info in the kernel is the same as any other program, simply compile with the `-g` flag.

There are different versions of DWARF (the debugging format used by elf files), and by default the compiler will use the most recent one for our target platform. However this can be overridden and the compiler can be forced to use a different debug format (if needed). Sometimes there can be issues if the debugger is from a different vendor to our compiler, or is much older.

Getting access to these debug symbols is dependent on the boot protocol used:

### Multiboot 2

Multiboot 2 provides the Elf-Symbols (section 3.6.7 of the spec) tag to the kernel which provides the elf section headers and the location of the string table. Using these is described below in the stivale section.

### Stivale 2

Stivale2 uses a similar and slightly more complex (but more powerful) mechanism of providing the entire kernel file in memory. This means we're not limited to just using elf files, and can access debug symbols from a kernel in any format. This is because we have the file base address and length and have to do the parsing by ourselves.

### ELFs Ahead, Beware!

This section is included to show how elf symbols could be loaded and parsed, but it is not a tutorial on the elf format itself. If unfamiliar with the format, give the _elf64_ specification a read! It's quite straightforward, and written very plainly. This section makes reference to a number a of structures and fields from the specification.

With that warning out of the way, let's look at the two fields from the elf header we're interested in. If using the multiboot 2 info, we will be given these fields directly. For stivale 2, we will need to parse the elf header. We're interested in `e_shoff` (the section header offset) and `e_shstrndx` (the section header string index).

The elf section headers share a common format describing their contents. They can be thought of as an array of `Elf64_Shdr` structs.

This array is `e_shoff` bytes from the start of the elf file. If we're coming from multiboot 2, we're simply given the section header array.

One particular elf section is the string table (called `.strtab` usually), which contains a series of null-terminated c style strings. Anytime a something in the elf file has a name, it will store an offset. This offset can be used as a byte index into the string table's data, giving the first character of the name we're after. These strings are all null-terminated.
This applies to section names as well, which presents a problem: how do we find the `.strtab` section header if we need the string table to determine the name a section header is using?

The minds behind the elf format thought of that, and give us the field in the elf header `e_shstrndx`, which is the index of the string table section header. Then we can use that to determine the names of other section headers, and debug symbols too.

Next we'll want to find the `.symtab` section header, who's contents are an array of `Elf64_Sym`. These symbols describe various parts of the program, some source file names, to linker symbols or even local variables. There is also other debug info stored in other sections (see the `.debug` section), but again that is beyond the scope of this section.

Now to get the name of a section, we'll need to find the matching symbol entry, which will give us the offset of the associated string in the string table. With that we can now access mostly human-readable names for our kernel.

Languages built around the C model will usually perform some kind of name mangling to enable features like function overloading, namespaces and so on. This is a whole topic on its own. Name mangling can be through of as a translation that takes place, to allow things like function overloading and templates to work in the C naming model.

### Locating The Symbol Table

We'll need to access the data stored in the string table quite frequently for looking up symbols, so let's calculate that and store it in the variable `char* strtab_data`. For both protocols it's assumed that we have found the tag returned by the bootloader that contains the location of the elf file/elf symbols.

```c
//multiboot 2
multiboot_tag_elf_sections* sym_tag;
const char* strtab_data = sym_tag->sections[sym_tag->shndx].sh_offset;

//stivale 2
stivale2_struct_tag_kernel_file* file_tag;
Elf64_Ehdr* hdr = (Elf64_Ehdr*)file_tag->kernel_file;
Elf64_Shdr* shdrs = (Elf64_Shdr*)(file_tag->kernel_file + hdr->shoff);
const char* strtab_data = shdrs[hdr->e_shstrndx].sh_offset;
```

To find the symbol table, iterate through the section headers until one with the name `.symtab` is found.
As a reminder, the name of a section header is stored as an offset into the string table data. For example:

```c
Elf64_Shdr* example_shdr;
const char* name = strtab_data[example_shdr->sh_name];
```

Now all that's left is a function that parses the symbol table. It's important to note that some symbols only occupy a single address, like a label or a variable, while others will occupy a range of addresses. Fortunately symbols have a size field.

An example function is included below, showing how a symbol can be looked up by its address. The name of this symbol is then printed, using a fictional `print` function.

```c
Elf64_Shdr* sym_tab;
const char* strtab_data;

void print_symbol(uint64_t addr)
{
    Elf64_Sym* syms = sym_tab->sh_offset;

    const size_t syms_count = sym_tab->sh_size / sym_tab->e_entsize;
    for (size_t i = 0; i < syms_count; i++)
    {
        const uint64_t sym_top = syms[i].st_value + syms[i].st_size;

        if (addr < syms[i].st_value || addr > sym_top)
            continue;

        //addr is inside of syms[i], let's print the symbol name
        print(strtab_data[syms[i].st_name]);
        return;
    }
}
```

A quick note about getting the symbol table data address: On multiboot `sym_tab->sh_offset` will be the physical address of the data, while stivale2 will return the original value, which is an offset from the beginning of the file. This means for stivale 2 we would add `file_tag->kernel_base` to this address to get its location in memory.

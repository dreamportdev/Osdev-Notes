# Makefiles

There's a million and one excellent resources on makefiles out there, so this chapter is less of a tutorial and more of a collection of interesting things.

## GNUMakefile vs Makefile

There's multiple different make-like programs out there, a lot of them share a common base, usually the one specified in posix. GNU make also has a bunch of custom extensions it adds, which can be quite useful. These will render our Makefiles only usable for gnu make, which is the most common version. So this is fine, but if we care about being fully portable between make versions, we'll have to avoid these.

If we want to use gnu make extensions, we now have a makefile that wont run under every version of make. Fortunately the folks at gnu allow us to name our makefile `GNUMakefile` instead, and this will run as normal. However other versions of make won't see this file, meaning they wont try to run it.

## Simple Makefile Example

Below is an example of a basic Makefile.

```makefile
#toolchain
CC = x86_64-elf-gcc
CXX = x86_64-elf-g++
AS = x86_64-elf-as
LD = x86_64_elf-ld

#inputs
C_SRCS = kernel_main.c util.c
ASM_SRCS = boot.S
TARGET = build/kernel.elf

#flags
CC_FLAGS = -g -ffreestanding
LD_FLAGS = -T linker_script.lds -ffreestanding

#auto populated variables
OBJS = $(patsubst %.c, build/%.c.o, $(C_SRCS))
OBJS += $(patsubst %.S, build/%.S.o, %(ASM_SRCS))

.PHONY: all clean

all: $(OBJS)
    @echo "Linking program ..."
    $(LD) $(LD_FLAGS) $(OBJS) -o $(TARGET)
    @echo "Program linked, placed @ $(TARGET)"

clean:
    @echo "Cleaning build files ..."
    -rm -r build/
    @echo "Cleaning done!"

build/%.c.o: %.c
    @echo "Compiling C file: $<"
    @mkdir -p $(@D)
    $(CC) $(CC_FLAGS) $< -c -o $@

build/%.S.o: %.S
    @echo "Assembling file: $<"
    @mkdir -p $(@D)
    $(AS) $< -c -o $@
```

Okay! So there's a lot going on there. This is just a way to organise makefiles, and by no means a definitive guide.
Since we may be using a cross compiler or changing compilers (it's a good idea to test with both gcc and clang) we've declared some variables representing the various programs we'll call when compiling. `CXX` is not used here, but if using c++ it's the common name for the compiler.

Following that we have our inputs, `C_SRCS` is a list of our source files. Anytime we want to compile a new file, we'll add it here. The same goes for `ASM_SRCS`. Why do we have two lists of sources? Because they're going to be processed by different tools (c files -> c compiler, assembly files -> assembly compiler/assembler). `TARGET` is the output location and name of the file we're going to compile.

*Authors Note: In this example I've declared each input file in C_SRCS manually, but you could also make use the builtin function `$(shell)` to use a program like find to search for you source files automatically, based on their file extension. Another level of automation! An example of what this might look like, when searching for all files with the extension '.c', is given below:*

```makefile
C_SRCS = $(shell find -name "*.c")
```

Next up we have flags for the c compiler (`CC_FLAGS`) and the linker (`LD_FLAGS`). If we wanted flags for the assembler, we could create a variable here for those too. After the flags we have our first example of where make can be really useful.

The linker wants a list of compiled object files, from the c compiler or assembler, not a list of the source files they came from. We already maintain a list of source files as inputs, but we don't have a list of the produced object files that the linker needs to know what to link in the final binary. We could create a second list, and keep that up to date, but that's more things to keep track off. More room for error as well.
Make has built in search and replace functionality, in the form of the `patsubst` (pattern substitution) function. `patsubst` uses the wildcard (`%`) symbol to indicate the section of text we want to keep. Anything specified outside of the wildcard is used for pattern matching. It takes the following arguments:

- Pattern used to select items from the input variable.
- Pattern used to transform selected items into the output.
- Input variable.

Using `patsubst` we can transform the list of source files into a list of object files, that we can give to the linker. The second line `OBJS += ...` functions in the same way as the first, but we use the append operator instead of assign. Similar to how they work in other languages, here we *append* to the end of the variable, instead of overwriting it.

Next up is an important line: `.PHONY: `. Make targets are presumed to output a file of the same name by default. By adding a target as a dependency of the .PHONY target, we tell make that this target is more of a command, and not a real file it should look for. In simple scenarios it serves little purpose, but it's an issue that can catch us by surprise later on. Since `phony` targets don't have a time associated with them, they are assumed to be always out of date and thus are run everytime they are called.


The `all` and `clean` targets work as we'd expect, building the final output or cleaning the build files. It's worth noting the '@' symbol in front of echo. When at the start of a line, it tells make not to echo the rest of the line to the shell. In this case we're using echo because we want to output text without the shell trying to run it. Therefore we tell make not to output the echo line itself, since echo will already write the following text to the shell.

The line `-rm -r build/` begins with a minus/hyphen. Normally if a command fails (returns a non-zero exit code), make will abort the sequence of commands and display an error. Beginning a line with a hyphen tells make to ignore the error code. Make will still tell if an error ocurred, but it won't stop the executing the make file. In this case this is what we want.

The last two rules tell make how it should create a `*.c.o` or `*.S.o` file if it needs them. They have a dependency on a file of the same name, but with a different extension (`*.c` or `*.S`). This means make will fail with an error if the source file does not exist, or if we forget to add it to the `SRCS` variables above. We do a protective mkdir, to ensure that the filepath used for output actually exists.

Make has a few built-in symbols that are used through the above example makefile. These are called automatic variables, and are described in the makefile manual.

That's a lot of text! But here we can see an example of a number of make functions being used. This provides a simple, but very flexible build system for a project, even allowing the tools to be swapped out by editing a few lines.

There are other built in functions and symbols that have useful meanings, however discovering them is left as an exercise to the reader.

## Built In Variables
Make includes a few special built in variables (make calls them *automatic variables*). This list is not complete, but is most of the common ones, with the rest being available in the documentation. Remember variables are evaluated, and then replaced by their contents before the actual command containing them is run.

The following group use the following as their example:

```makefile
output.o: input.c build_dir
    @echo "doing stuff"
```

- `$@`: Evaluates to the target name of the current rule, in the example this would be `output.o`.
- `$<`: Evaluates to the first prerequisite, in the example this would be `input.c`.
- `$^`: Evaluates to a list of the all the prerequisites, in the example this would be `input.c build_dir`.

For the following, the example used is a file path:

```
/project/build/file.o
```

- `$(@D)`: Contains the directory path, in this case `/project/build`. Note the trailing slash is not present.
- `$(@F)`: Contains the filename in the path, in this case `file.o`.

## Complex Makefile Example (with recursion!)

What about bigger projects? Well we aren't limited to a single makefile, one makefile can include another one (essentially copy-pasting it into the current file) using the `include` keyword.
For example, to include `extras.mk` (.mk is a common extension for non-primary makefiles) into `Makefile` we would add the line somewhere:

```makefile
include extras.mk
```

This would place the contents of the included file (extras.mk) *at the line where it was included*. This means the usual top to bottom reading of a makefile is followed as well. You can think of this as how `#define` works in C/C++, it's a glorified copy-and-paste mechanism.

One *import*ant note about using `import` is to remember that the included file will run with the current working directory of the file that used the import, not the directly of the where the included file is.

You can also run `make` itself as part of a command to build a target. This opens the door to a whole new world of makefiles calling further makefiles and including others.

### Think Bigger!
*__Authors Note:__ This chapter is written using a personal project as a reference, there are definitely other ways to approach this, but I thought it would be an interesting example to look at how I approached this for my kernel/OS. - DT.*

Now what about managing a large project with many sub-projects, custom and external libraries that all interact? As an example lets look at the northport os, it features the following structure of makefiles:

```
northport/
    | - initdisk/
    |   \ - Makefile
    |
    | - kernel/
    |   | - arch/x86_64/
    |   |   \ - Local.mk
    |   | - arch/rv64/
    |   |   \ - Local.mk
    |   \ - Makefile
    |
    | - libs/
    |   | - Makefile
    |   |
    |   | - np-syslib/
    |   |   \ - Makefile
    |   |
    |   | - np-graphics/
    |   |   \ - Makefile
    [ ... other northport libs here]
    |
    | - userland/
    |   | - Makefile
    |   |
    |   | - startup/
    |   |   \ - Makefile
    |   |
    |   | - window-server/
    |   |   \ - Makefile
    [ ... other northport apps here]
    |
    | - misc/
    |   | - UserlandCommon.mk
    |   \ - LibCommon.mk
    |
    | - BuildPrep.mk
    | - Run.mk
    \ - Makefile
```

Whew, there's a lot going on there! Let's look at why the various parts exist:

- When the user runs `make` in the shell, the root makefile is run. This file is mostly configuration, specifying the toolchain and the options it'll use.

- This makefile then recursively calls make on each of the sub-projects.
    - For example, the kernel makefile will be run, and it will have all of the make variables specified in the root makefile in its environment.
    - This means if we decide to change the toolchain, or want to add debug symbols to *all* projects, we can do it in a single change.
    - Libraries and userland apps work in a similar way, but there is an extra layer. What I've called the glue makefile. It's very simple, it just passes through the make commands from above to each sub project.
    - This means we don't need to update the root makefile every time a new userland app is updated, or a new library.
    - It also allows us to override some variables for every library or every userspace app, instead of globally. Useful!

- There are a few extra makefiles:
    - Run.mk is totally optional if we just want to build the system. It contains anything to do with qemu or gdb, so it can easily be removed if the end user only wants to build the project, and not run it.
    - LibCommon.mk and UserlandCommon.mk contain common definitions that most userland apps/libraries would want. Like a `make clean` target, automatically copying the output to a global 'apps' directory, rules for building c++ object files from source, etc. This saves having to write those rules per project. They can instead be written once, and then included into each makefile.

- The kernel/arch dir contains several local.mk files. Only one of these is included at a time, and they include any platform-specific source files. These are also contained in the same directory. This is a nice way to automate what gets built.
    - The root makefile contains a variable `CPU_ARCH` which contains either `x86_64` or `rv64g`. If using the gcc toolchain, the tools are selected by using the `CPU_ARCH` variable (g++ is actually named `$(CPU_ARCH)-elf-g++`, or `x86_64-elf-g++`), and for the clang toolchain it's passed to the `--target=` argument.

- This allows us to piggy-back on the variable, and place `include arch/$(CPU_ARCH)/local.mk` inside the kernel makefile. Now the kernel changes what is built based on the same rule, ensuring we're always using the correct files. Cool!

# Cross Platform Building

This appendix looks at how and why we might want to build a cross compilation toolchain, and how to build some other tools like gdb and qemu. These tools include:

- binary utils like a linker, readelf, objdump, addr2line.
- a compiler for our chosen language.
- a debugger, like gdb.
- an emulator for testing, like qemu.

For most of these tools (except clang/LLVM) we'll need to build them specifically for the target architecture we want to support. The building processes covered below are intended to be done on a unix-style system, if developing in a windows environment this will likely be different and is not covered here.

For the binary utils and compiler there are two main vendors: the GNU toolchain consisting of GCC and binutils, and the LLVM toolchain of the same name which uses clang as a frontend for the compiler.

## Why Use A Cross Compiler?

A fair question to ask! If we're building our kernel for x86_64 and our host is the same architecture, why not use our host compiler and linker? Well it's very doable, but your distribution may ship modified versions of these tools (that have been optimized to target this distribution or architecture). Our compiler may also choose the wrong file if conflicting names are chosen: if we create our own `stdint.h` (not recommended) the host compiler may keep including the ones for the host system. This could be fine, until we move to another system or target a different architecture - at which point things may break in unexpected ways.

It's also considered good practice to take a `clean room` approach to building software for bare metal environments.

## Binutils and Compilers

### Prerequisites

In order to build GNU binutils and GCC there are a few dependencies that need to be satisfied. The exact names of these packages depend on the distribution we're using. The minimal set of dependencies is listed below:

- autotools and make. Often these are provided via the build-essential package for debian based distros.
- bison.
- flex.
- libgmp3-dev, sometimes called libgmp3-devel depending on distro. Same applies to other libraries below.
- libmpc-dev.
- libmpfr-dev.
- texinfo.
- libcloog.

There's three environment variables we're going to use during the build process:

```
export PREFIX="/your/path/to/cross/compiler"
export TARGET="riscv64-elf"
export PATH="$PREFIX/bin:$PATH"
```

The `PREFIX` environment variable stores the directory we want to install the toolchain into after building, `TARGET` is the target triplet of our target and we also modify the shell `PATH` variable  to include the prefix directory. To permantly add the cross compiler to your path, you may want to add this last line (where we updated `PATH`) to your shell's configuration. If you're unsure what shell you use, it's probably bash and you will want to edit your `.bashrc`. As for where to install this up to personal preference, but if unsure a 'tools' directory under our home folder should work. This is nice because the install process doesn't require root permissons. If we want all users on the system to be able to access it, we could install somewhere under `/usr/` too.

The process of building binutils and GCC follows a pattern:

- first we'll create a directory to hold all the temporary build files and change into it.
- next is to generate the build system files using a script.
- then we can build the targets we want, before installing them.

### Binutils

These are a set of tools to create and manage programs, including the linker (`ld`), the GNU assembler (`as`, referred to as GAS), objcopy (useful for inserting non-code files into binaries) and readelf.

The flags we'll need to pass to the configure script are:

- `--prefix=$PREFIX`: this tells the script where we want to install programs after building. If omitted this will use a default value, but this is not recommended.
- `--target=$TARGET`: tells the script which target triplet we want to use.
- `--with-sysroot`: the build process needs a system root to include any system headers from. We don't want it to use the host headers so by just using the flag we point the system root to an empty directory, disabling this functionality - which is what we want for a freestanding toolchain.
- `--disable-nls`: this helps reduce the size of the generated binaries by disabling native language support. If you want these tools to support non-english languages you may want to omit this option (and keep nls enabled).
- `--disable-werror`: tells the configure script not to add `-Werror` to the compile commands generated. This option may be needed depending on if you have any missing dependencies.

Before we can do this however we'll need to obtain a copy of the source code for GNU binutils. This should be available on their website or can be downloaded from the ftp mirror: https://ftp.gnu.org/gnu/binutils/.

Once downloaded extract the source into a directory, then create a new directory for holding the temporary build files and enter it. If unsure of where to put this, a sibling directory to where the source code was extracted works well. An example might be:

```bash
mkdir binutils_build
cd binutils_build
```

From this temporary directory we can use the configure script to generate the build files, like so:

```bash
/path/to/binutils_src/configure --target=$TARGET --with-sysroot --disable-nls --disable-werror
```

At this point the configure script has generated a makefile for us with our requested options, now we can do the usual series of commands:

```bash
make
make install
```

That's it! Now all the binutils tools are installed in the `PREFIX` directory and ready to be used.

### GCC

The process for building GCC is very similar to binutils. Note that we need to have a version of binutils for our target triplet before trying to build GCC. These binaries must also be in the path, which we did before. Let's create a new folder for the build files (`build_gcc`) and move into it.

Now we can use the configure script like before:

```bash
/path/to/gcc_sources/configure --target=$TARGET --prefix=$PREFIX --disable-nls --enable-languages=c,c++ --without-headers
```

For brevity we'll only explain the new flags:

- `--enable-languages=c,c++`: select which language frontends to enable, these two are the default. We can disable c++ but if we plan to cross compile more things than our kernel this can be nice to have.
- `--without-headers`: tells the compiler not to rely on any headers from the host and instead generate its own.

Once the script is finished we can run a few make targets to build the compiler and its support libraries. By default running `make`/`make all` is not recommended as this builds everything for a full userspace compiler. We don't need all that and it can take a lot of time. For a freestanding program like a kernel we only need the compiler and libgcc.

```bash
make all-gcc
make all-target-libgcc
make install-gcc
make install-target-libgcc
```

Libgcc contains code the compiler might add calls to for certain operations. This happens mainly when an operation the compiler tries to perform isn't supported by the target hardware and has to be emulated in software. GCC states that it can emit calls to libgcc functions anywhere and that we should *always* link to it. The linker can remove the unused parts of the code if they're not called. This set up is specific to GCC.

In practice we can get away with not linking to libgcc, but this can result in unexpected linker errors. Best practice here is to build and link with libgcc.

### Clang and LLVM

Building LLVM from source is a much more significant task than building the gcc/binutils toolchain. It takes a fair amount more time to build all the required tools from scratch. However there is an upside to this, LLVM (which clang is just one frontend to) is designed to be modular and ships with backend modules for most supported architectures. This means a default install of clang (from your distribution's package manager) can be used as a cross compiler.

To tell clang to cross compile, there is a special flag you'll need to pass it: `--target`. It takes the target triplet for the target. Most LLVM tools like lld (the llvm linker) support it and will switch their modules to use ones that match the target triplet.

As an example lets say you wanted to use clang as a cross compiler for `x86_64-elf` triplet or `x86_64-unknown-elf` you would invoke clang like `clang --target=x86_64-elf` or `--target=x86_64-unknown-elf`. Let's say you wanted to build your kernel for riscv64 you would do something like `clang --target=riscv64`.

Since `clang` and `lld` are compatible with the `gcc/binutils` versions of these tools you can pass the same flags and compilation should go as exepected.

## Emulator (QEmu)

Of course we can use any emulator we want, but in our example we rely on qemu. This tool to be compiled requires some extra dependencies:

* ninja-build
* python3-sphinx
* sphinx-rtd-theme
* If we want to use the gtk ui, we also need libgtk3-dev

As usual let's create a new folder called `build_qemu` and move into it. The confiure command is:

```bash
/path/qemu_src/configure --prefix=$PREFIX --target-list=riscv64-softmmu --enable-gtk --enable-gtk-clipboard --enable-tools --enable-vhost-net
```
where:

* `--target-list=riscv64-softmmu,x86_64`: is a comma separated list of platforms we want to support.
* `--enable-tools`: will build support utilities that comes with qemu
* `--enable-gtk`: it will enable the gtk+ interface
* `--enable-vhost-net` : it will enable the vhost-net kernel acceleration support

After the configuration has finished, to build qemu the commands to install it:

```bash
make -j $(nproc)
make install
```

Qemu is quite a large program, so it's recommended to make use of all cores when building it.

## GDB

The steps for building GDB are similar to binutils and GCC. We'll create a temporary working directory and move into it. Gdb has a few extra dependencies we'll need:

* libncurses-dev
* libsource-highligh-dev

```bash
path/to/gdb_sources/configure --target=$TARGET  --host=x86_64-linux-gnu  --prefix="$PREFIX" --disable-werror --enable-tui --enable-source-highlight
```

The last two options enable compiling the text-user-interface (`--enable-tui`) and source code highlighting (`--enable-source-highlight) which are nice-to-haves. These flags can be safely omitted if these aren't features we want.

The `--target=` flag is special here in that it can also take an option `all` which builds gdb with support for every single architecture it can support. If we're going to develop on one machine but test on multiple architectures (via qemu or real hardware) this is nice. It allows a single instance of gdb to debug multiple architectures without needing different versions of gdb. Often this is how the 'gdb-multiarch' package is created for distros that have it.

After running the configure script, we can build and install our custom gdb like so:

```bash
make all-gdb
make install-gdb
```

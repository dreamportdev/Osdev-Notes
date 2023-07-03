# Cross Compilation Build

Even if it is not our purpose to go in depth with the building of a cross-compiler toolchain, it can be useful to know what we need to build and what are  the minimum necessary build flags required for them. 

Usually when building a  cros-compiler for every architecture we want to support we need the following: 

* binutils 
* a compiler (we will focus on gcc and clang)
* a debugger (gdb in our case)
* an emulator

they need to be buit with the support for the target architecture. The next sections will explain what are some configuration flags that we want to enable.

## Prerequisites

In order to build the cross-compiler and the other tools, there is also a set of dependencies that needs to be satisfied,  this depends on the linux distribution/operating system we are using. So they may be already installed. 

The list below is the common dependencies that are needed, but again it is not complete and depends highly on the host operating systems: 

* configure
* make
* build-essential (on debian derivatives)
* bison
* flex
* libgmp3-dev
* libmpc-dev
* libmpfr-dev
* texinfo
* libcloog

This appendix built process is  focused on a unix-like operating system.

## Where To Put The Cross-compiler

We can let them be installed it in the default location, somewhere in `/usr` probably. But it could be useful to wrap all of them in a custom folder, so in case we decide to remove one, we just need to delete the folder. To do that we can define the following three env variables for the build process: 

```
export PREFIX="/your/path/to/cross/compiler"
export TARGET="riscv64-elf"
export PATH="$PREFIX/bin:$PATH"
```

replace the `TARGET` variable with the architecture needed to support. Now to install all the tools in the same folder (declared in the env variable `PREFIX`) we just need to add the following flag during the `configure` command: `--prefix=$PREFIX`

## Binutils

They are a set of tool to create and manage binary programs, they include a lof of commands like the most importants are `ld` (the linker0, `as` (an assembly compiler, unless we are using nasm), `objcopy`(useful if we need to include other binaries to our kernel), `readelf` (to read the content off an elf file), etc. 

For the binutils the flags that we need to pass to the configure command are: 

* `--prefix=$PREFIX` :  this flags indicate the folder where we want the binaries to be installed. If omitted it will use the default path (in which case we also need to be authenticated as root to finish it)
*`--target=$TARGET`: this is the target platform we want to build for, for example `x86_64-elf`for supporting the `x86_64` architecture, or `riscv64-elf` if we want to support  the riscv64 architecture.
* `--with-sysroot`: tells binutils to enable sysroot support in the cross-compile by pointing it to a default empty directory.
* `--disable-nls` : this is added more to reduce the size of the binaries generated, since it disable the national  language support. 
* `--disable-werror`: explanation to add 

The first thing to do is obtain a copy of the binutils sources (wheter we are cloning their source repository or just downloading latest version from the official site)

Before starting the build process let's create a an empty folder where to put the binaries and move into it: 

```bash
mkdir binutils_build
cd binutils_build
```

Now form there we can launch the configure command with the flags above: 

```bash
/path/to/binutils_src/configure --target=$TARGET --with-sysroot --disable-nls --disable-werror
```

After the command is complete we just need to build them using the "usual" make commands

```bash
make
make install
```

And that's it, now `binutils`are installed in `$PREFIX` and ready to be used  if we have added it to our path.

## Compilers

This step depends on the compiler used

### Gcc

The process is very similar, once we obtained the sources downloaded , let's create a new folder for the built files (i.e. `build_gcc`), and move into it. 

Now we can launch the configure command similar to the above one: 

```bash
/path/gcc_sources/configure --target=$TARGET --prefix="$PREFIX" --disable-nls --enable-languages=c,c++ --without-headers 
```

Some of the flags are the same as above with the same purpose. The other two are: 

* `--enable-languages=c,c++` : specify the languages we want to be enabled by the compiler
* `--without-headers`: is telling to not rely on any headers or library present on the target machine. 

Once the configure has been completed, the `make` commands are slightly different from the standard ones: 

```bash
make all-gcc
make all-target-libgcc
make install-gcc
make install-target-libgcc
```

Again the two install steps, will install the compiler in the `$PREFIX` folder.

### Clang

@DT
  
## Emulator (QEmu)

Of course we can use any emultaro we want, but in our example we rely on qemu. This tool to be compiled requires some extra dependencies: 

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
* `--enable-vhos-net` : it will enable the vhost-net kernel acceleration support

@DT: what other parameters can we add? 

After the configuration has finished, to build qemu the commands to install it: 

```bash
make -j $(nproc)
make install
```
 
## GDB

Let's create a build folder for it too, i.e. `build_gdb` and move into it. 

GDB can require extra dependencies: 

* libncurses-dev
* libsource-highligh-dev

if we want to enable the `tui`(Text User Interface) 

```bash
../gdb.x.y.z/configure --target=$TARGET  --host=x86_64-linux-gnu  --prefix="$PREFIX" --disable-werror --enable-tui --enable-source-highlight
```

where: 

* `--enable-tui`: will enable the Text User Interface (it's useful to navigate through the sources while debugging)
* `--enable-source-highlight` : it enables source highlight
As usual `TARGET` and `PREFIX` are the same used for the previous tools.  be already set from the previous steps (if not make sure to have them set, if we don't want to risk to overwrite the default installation of gdb).

Now we can build and install it:

```bash
make all-gdb
make install-gdb
```

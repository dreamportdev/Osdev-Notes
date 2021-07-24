# Environment Setup

## Tools needed

These are the tools that you need to start to write your own kernel:

* gcc
* nasm
* binutils
* grub-mkrescue
* xorriso

In addition if you want to write a 64 bit kernel you nened a cross-compiler toolchain. 
You need to recompile the following packages:

* gcc
* binutils

It will be covered in another document. 

To emulate your operating system you can use any virtualization software, like qemu, bochs, virtualbox, vmware, etc.

## The compilation

## The makefile

The makefile needs to: 

* Compile all the c files in all the folders
* Compile all the assembly files
* Convert any eventual font if present
* Link all together 
* Create a iso (optional)
* Rund the os with an emulator (optional)

Some symbols often used in our makefile: 

* $@ is the name of the target being generated
* $< the first prerequisite

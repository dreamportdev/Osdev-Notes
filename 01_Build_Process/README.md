# Kernel Build Process & Booting

An OS like any other project needs to be built and packaged, but it is different from any other programs, we don't only need it to be compiled, but  it needs different tools and steps in order to have an image that can be loaded by a bootloader. And booting it requires another step.

This part is going to cover all the tools and steps that are needed in order to have an initial set of building scripts for our os, and also will explore some options for the compilers and the bootloader that can be used for our kernel. 

The next chapters will cover the following topics:

- [General Overview](02_Overview.md): This chapter will serve as a high level overview of the overall building process, explaining why some steps are needed, and what is thier purpose. It also give an introduction to many of the concepts that will be developed in the in the following chapters.
- [Boot Protocols & Bootloaders](03_Boot_Protocols.md): This chapter will explore two different solutions for booting our kernel: _Multiboot2_ and _Stivale_, explaining how they should be used and configured in order to boot our kernel, and what are their difference. 
- [Makefiles](04_Gnu_Makefiles.md): The building script, we are going to use to build our kernel: Makefile. 
- [Linker Scripts](05_Linker_Scripts.md): This chapter will introduce one of the probably  most _obscure_ part of the building process, especially for beginners, it will explain what are the linker scripts, why they are important, and how to write one.
- [Generating A Bootable Iso](06_Generating_Iso.md): After building our kernel we want to run it too (yeah like the cake...). In order to do that we need a bootable iso, as only the kernel file is not enough. This chapter will show how to create a bootable iso and start to test it on emulators/real hardware.

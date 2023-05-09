# Kernel Build Process & Booting

This part is going to cover all the tools and steps that are needed in order to have an initial set of building scripts for our os, and also will explore some options for the compilers and the bootloader that can be used for our kernel.

Below the list of chapters for this part:

- [General Overview](01_Overview.md): This chapter will serve as a high level overview of the overall building process, explaining why some steps are needed, and what is thier purpose. It also give an introduction to many of the concepts that will be developed in the in the following chapters.
- [Boot Protocols & Bootloaders](02_Boot_Protocols.md): This chapter will explore two different solutions for booting our kernel: _Multiboot2_ and _Stivale_, explaining how they should be used and configured in order to boot our kernel, and what are their difference.
- [Makefiles](03_Gnu_Makefiles.md): The building script, we are going to use to build our kernel: Makefile.
- [Linker Scripts](04_Linker_Scripts.md): This chapter will introduce one of the probably  most _obscure_ part of the building process, especially for beginners, it will explain what are the linker scripts, why they are important, and how to write one.
- [Generating A Bootable Iso](05_Generating_Iso.md): After building our kernel we want to run it too (yeah like the cake...). In order to do that we need a bootable iso, as only the kernel file is not enough. This chapter will show how to create a bootable iso and start to test it on emulators/real hardware.

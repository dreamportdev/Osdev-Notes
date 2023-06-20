# Useful Resources

This appendix is a collection of links we found useful developing our own kernels and these notes.

## Build Process

- Grub and grub.cfg documentation: [https://www.gnu.org/software/grub/manual/grub/grub.html](https://www.gnu.org/software/grub/manual/grub/grub.html)
- Multiboot 2 Specification: [https://www.gnu.org/software/grub/manual/multiboot2/multiboot.html](https://www.gnu.org/software/grub/manual/multiboot2/multiboot.html)
- Limine documentation:[https://github.com/limine-bootloader/limine](https://github.com/limine-bootloader/limine)
- Stivale 2 Specification: [https://github.com/stivale/stivale/blob/master/STIVALE2.md](https://github.com/stivale/stivale/blob/master/STIVALE2.md)
- Stivale 2 Barebones: [https://github.com/stivale/stivale2-barebones/](https://github.com/stivale/stivale2-barebones/)
- Sabaton - ARM Stivale 2 Bootloader: [https://github.com/FlorenceOS/Sabaton](https://github.com/FlorenceOS/Sabaton)
- Xorisso Documentation: [https://linux.die.net/man/1/xorriso](https://linux.die.net/man/1/xorriso)
- GNU Make Documenation: [https://www.gnu.org/software/make/manual/make.html](https://www.gnu.org/software/make/manual/make.html)
- Linker Scripts Documentation : [https://sourceware.org/binutils/docs/ld/Scripts.html#Scripts](https://sourceware.org/binutils/docs/ld/Scripts.html#Scripts)
- Bootlin Toolchains : [https://toolchains.bootlin.com/](https://toolchains.bootlin.com/)
- OS Dev Wiki - Building A Cross Compiler: [https://wiki.osdev.org/GCC_Cross-Compiler](https://wiki.osdev.org/GCC_Cross-Compiler)

## Architecture

- Intel Software developer's manual Vol 3A APIC Chapter
- IOAPIC Datasheet: [https://pdos.csail.mit.edu/6.828/2016/readings/ia32/ioapic.pdf](https://pdos.csail.mit.edu/6.828/2016/readings/ia32/ioapic.pdf)
- Broken Thorn Osdev Book Series, The PIC: [http://www.brokenthorn.com/Resources/OSDevPic.html](http://www.brokenthorn.com/Resources/OSDevPic.html)
- Osdev wiki page for RSDP: [https://wiki.osdev.org/RSDP](https://wiki.osdev.org/RSDP)
- Osdev wiki page for RSDT[https://wiki.osdev.org/RSDT](https://wiki.osdev.org/RSDT)
- OSdev Wiki - Pit page: [https://wiki.osdev.org/Programmable_Interval_Timer](https://wiki.osdev.org/Programmable_Interval_Timer)
- Broken Thron Osdev Book Series Chapter 16 PIC, PIT and Exceptions: [http://www.brokenthorn.com/Resources/OSDev16.htm](http://www.brokenthorn.com/Resources/OSDev16.html)
- Osdev Wiki Ps2 Keyboard page: [https://wiki.osdev.org/PS/2_Keyboard](https://wiki.osdev.org/PS/2_Keyboard)
- Osdev Wiki Interrupts page: [https://wiki.osdev.org/IRQ#From_the_keyboard.27s_perspective](https://wiki.osdev.org/IRQ#From_the_keyboard.27s_perspective)
- Osdev Wiki 8042 Controller pagepage: [https://wiki.osdev.org/"8042"_PS/2_Controller#Translation](https://wiki.osdev.org/%228042%22_PS/2_Controller#Translation)
- Scancode sets page: [https://www.win.tue.nl/~aeb/linux/kbd/scancodes-10.html#scancodesets](https://www.win.tue.nl/~aeb/linux/kbd/scancodes-10.html#scancodesets)
- Brokenthorn Book Series Chapter 19 Keyboard programming: [http://www.brokenthorn.com/Resources/OSDev19.html](http://www.brokenthorn.com/Resources/OSDev19.html)

## Video Output

- JMNL.xyz blog post about creating a ui: [https://jmnl.xyz/window-manager/](https://jmnl.xyz/window-manager/]
- Osdev wiki page for PSF format: [https://wiki.osdev.org/PC_Screen_Font](https://wiki.osdev.org/PC_Screen_Font)
- gbdfed - Tool to inspect PSF files: [https://github.com/andrewshadura/gbdfed](https://github.com/andrewshadura/gbdfed)
- PSF Formats: [https://www.win.tue.nl/~aeb/linux/kbd/font-formats-1.html](https://www.win.tue.nl/~aeb/linux/kbd/font-formats-1.html)
- Osdev Forum PSF problem post: [https://forum.osdev.org/viewtopic.php?f=1&t=41549](https://forum.osdev.org/viewtopic.php?f=1&t=41549)


## Memory Management

- Intel Software developer's manual Vol 3A Paging Chapter
- Osdev Wiki page for  Page Frame Allocation: [https://wiki.osdev.org/Page_Frame_Allocation](https://wiki.osdev.org/Page_Frame_Allocation)
- Writing an Os in Rust by Philipp Oppermann Memory management: [https://os.phil-opp.com/paging-introduction/](https://os.phil-opp.com/paging-introduction/)
- Broken Thorn Osdev Book Series, Chapter 18: The VMM [http://www.brokenthorn.com/Resources/OSDev18.html](http://www.brokenthorn.com/Resources/OSDev18.html)

## Scheduling

- Osdev Wiki page for Scheduling Algirthm: [https://wiki.osdev.org/Scheduling_Algorithms](https://wiki.osdev.org/Scheduling_Algorithms)
- Operating System Three Easy Pieces (Book): [https://pages.cs.wisc.edu/~remzi/OSTEP/](https://pages.cs.wisc.edu/~remzi/OSTEP/)
- Broken Thorn Osdev Book Series: [http://www.brokenthorn.com/Resources/OSDev25.html](http://www.brokenthorn.com/Resources/OSDev25.html)
- Writing an Os in Rust by Philip Opperman Multitasking: [https://os.phil-opp.com/async-await/](https://os.phil-opp.com/async-await/)

## Userspace

- Intel Software developer's manual Vol 3A Protection Chapter
- Wiki Osdev Page for Ring 3: [https://wiki.osdev.org/Getting_to_Ring_3](https://wiki.osdev.org/Getting_to_Ring_3)
- JamesMolloy User mode chapter: [http://www.jamesmolloy.co.uk/tutorial_html/10.-User Mode.html](http://www.jamesmolloy.co.uk/tutorial_html/10.-User%20Mode.html)
- Default calling conventions for different compilers: [https://www.agner.org/optimize/#manuals](https://www.agner.org/optimize/#manuals)

## IPC

- Wiki Osdev Page for IPC Data Copying: [https://wiki.osdev.org/IPC_Data_Copying_methods](https://wiki.osdev.org/IPC_Data_Copying_methods)
- Wiki Osdev Page Message Passing Tutorial: [https://wiki.osdev.org/Message_Passing_Tutorial](https://wiki.osdev.org/Message_Passing_Tutorial)
- Wikipedia IPC page: [https://en.wikipedia.org/wiki/Inter-process_communication](https://en.wikipedia.org/wiki/Inter-process_communication)
- InterProcess communication by GeeksForGeeks: [https://www.geeksforgeeks.org/inter-process-communication-ipc/](https://www.geeksforgeeks.org/inter-process-communication-ipc/)

## Virtual File System

- JamesMolloy VFS chapter: [http://www.jamesmolloy.co.uk/tutorial_html/8.-The VFS and the initrd.html](http://www.jamesmolloy.co.uk/tutorial_html/8.-The%20VFS%20and%20the%20initrd.html)
- Wiki Osdev page for USTAR: [https://wiki.osdev.org/USTAR](https://wiki.osdev.org/USTAR)
- Tar (Wikipedia): [https://en.wikipedia.org/wiki/Tar_(computing)](https://en.wikipedia.org/wiki/Tar_\(computing\))
- Osdev Wiki page for VFS: [https://wiki.osdev.org/VFS](https://wiki.osdev.org/VFS)
- Vnodes: An Architecture for Multiple File System Types in Sun Unix: [https://www.cs.fsu.edu/~awang/courses/cop5611_s2004/vnode.pd](https://www.cs.fsu.edu/~awang/courses/cop5611_s2004/vnode.pdf)

## Loading Elfs

- The ELF Specification: [https://refspecs.linuxbase.org/LSB_3.0.0/LSB-PDA/LSB-PDA/generic-elf.html](https://refspecs.linuxbase.org/LSB_3.0.0/LSB-PDA/LSB-PDA/generic-elf.html)
- Osdev Wiki Page for ELF: [https://wiki.osdev.org/ELF](https://wiki.osdev.org/ELF)
- Osdev Wiki Page ELF Tutorial: [https://wiki.osdev.org/ELF_Tutorial](https://wiki.osdev.org/ELF_Tutorial)
- x86-64 psABI: [https://gitlab.com/x86-psABIs/x86-64-ABI](https://gitlab.com/x86-psABIs/x86-64-ABI)

## Nasm

* Nasm Struct Section: [https://www.nasm.us/xdoc/2.15/html/nasmdoc5.html#section-5.9.1](https://www.nasm.us/xdoc/2.15/html/nasmdoc5.html#section-5.9.1)
* Nasm String section: [https://www.nasm.us/xdoc/2.15/html/nasmdoc3.html#section-3.4.2](https://www.nasm.us/xdoc/2.15/html/nasmdoc3.html#section-3.4.2)

## Debugging

* Osdev Wiki Page for kernel debugging: [https://wiki.osdev.org/Kernel_Debugging](https://wiki.osdev.org/Kernel_Debugging)
* Osdev Wiki Page for Serial ports: [https://wiki.osdev.org/Serial_Ports](https://wiki.osdev.org/Serial_Ports)
* Debugging with Qemu at Wikibooks: [https://en.wikibooks.org/wiki/QEMU/Debugging_with_QEMU](https://en.wikibooks.org/wiki/QEMU/Debugging_with_QEMU)
    

## Communities

- Osdev Fourm: [https://forum.osdev.org/](https://forum.osdev.org/)
- Operating System Developmen on Reddit: [https://www.reddit.com/r/osdev/](https://www.reddit.com/r/osdev/)
- Osdev Discord server: [https://discord.gg/osdev](https://discord.gg/osdev)

## Books and Manuals

- Gnu.org TAR manual page: [https://www.gnu.org/software/tar/manual/html_node/Standard.html](https://www.gnu.org/software/tar/manual/html_node/Standard.html)
- Broken Thorne Osdev Book Series Chapter 22 VFS: [http://www.brokenthorn.com/Resources/OSDev22.html](http://www.brokenthorn.com/Resources/OSDev22.html)
- Operating System Three Easy Pieces (Book): [https://pages.cs.wisc.edu/~remzi/OSTEP/](https://pages.cs.wisc.edu/~remzi/OSTEP/)
- Operating Systems Design And Implementation by Andres S. Tanenbaum. Difficult to find as of today, but if you can it's an excellent resource on the minix kernel.
- Thinks Os By Allen B. Downey: [https://greenteapress.com/thinkos/](https://greenteapress.com/thinkos/)
- Xv6 is a modern rewrite of v6 unix, for teaching purposes. It comes with an accompanying book which walks through each part of the source code. It was later ported to risc-v, but the x86 version is still available (but no longer actively maintained). [https://pdos.csail.mit.edu/6.S081/2020/xv6/book-riscv-rev1.pdf](https://pdos.csail.mit.edu/6.S081/2020/xv6/book-riscv-rev1.pdf)

An interesting github repository with a lot of resources about operating systems, like guides, tutorials, hobby kernels, interesting project is the `awesome-os` rpository by @jubalh available here: [https://github.com/jubalh/awesome-os](https://github.com/jubalh/awesome-os)

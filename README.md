# Osdev Notes

[![Discord Chat](https://img.shields.io/discord/578193015433330698.svg?style=flat)](https://discordapp.com/channels/578193015433330698/578193713340219392)
<span class="badge-buymeacoffee">
<a href="https://buymeacoffee.com/dreamos82" title="Donate to this project using Buy Me A Coffee"><img src="https://img.shields.io/badge/buy%20me%20a%20coffee-donate-yellow.svg" alt="Buy Me A Coffee donate button" /></a>
</span>
![](https://tokei.rs/b1/github/dreamos82/osdev-notes)

This repository is a collection of notes about operating systems development. Written by the authors while writing (and re-writing) our own operating systems. The notes are organised like a book, with the intent of guiding the reader through the various stages of building an operating system kernel from scratch.

Currently these notes are a work in progress, but many chapters are functionally complete and available to read below. We'll keep updating old chapters and adding new ones over time so be sure to check back occasionally.

We hope you enjoy, and find something interesting here!

## Current Chapters:

* [Part 0: Introduction](00_Introduction/01_README.md)
    * [Assumed Knowledge](00_Introduction/02_AssumedKnowledge.md)
    * [About The Authors](00_Introduction/03_AboutTheAuthors.md)
* [Part 1: Building & Boot Protocols](01_Build_Process/01_README.md)
    * [Building a Kernel](01_Build_Process/02_Overview.md)
    * [Bootloaders and Boot Protocols](01_Build_Process/03_Boot_Protocols.md)
    * [Makefiles](01_Build_Process/04_Gnu_Makefiles.md)
    * [Linker Scripts](01_Build_Process/05_Linker_Scripts.md)
    * [Generating a Bootable Iso](01_Build_Process/06_Generating_Iso.md)
* [Part 2: Architecture and Basic Drivers](02_Architecture/01_README.md)
    * [Hello World](02_Architecture/02_Hello_World.md)
    * [A Higher Higher Kernel](02_Architecture/03_HigherHalf.md)
    * [Global Descriptor Table](02_Architecture/04_GDT.md)
    * [Interrupts](02_Architecture/05_InterruptHandling.md)
    * [ACPI Tables](02_Architecture/06_ACPITables.md)
    * [APIC](02_Architecture/07_APIC.md)
    * [Timers](02_Architecture/08_Timers.md)
    * [Adding Keyboard support](02_Architecture/PS2_Keyboard/01_README.md)
    * [Handling the keyboard interrupt](02_Architecture/PS2_Keyboard/02_Interrupt_Handling.md)
    * [Keyboard Driver Implementation](02_Interrupt_Handling/PS2_Keyboard/03_Driver_Implementation.md)
* [Part 3: Video Output](/03_Video_Output/01_README.md)
    * [The Framebuffer](/03_Video_Output/01_Framebuffer.md)
    * [Drawing Text on Framebuffer](03_Video_Output/02_DrawingTextOnFB.md)
* [Part 4: Memory Management](04_Memory_Management/01_README.md)
    * [Physical Memory](04_Memory_Management/02_Physical_Memory.md)
    * [Paging](04_Memory_Management/03_Paging.md)
    * [Virtual Memory Manager](04_Memory_Management/04_Virtual_Memory_Manager.md)
    * [Heap Allocation](04_Memory_Management/05_Heap_Allocation.md)
    * [Memory Protection](04_Memory_Management/06_Memory_Protection.md)
* [Part 5: Scheduling](05_Scheduling/01_README.md)
    * [The Scheduler](05_Scheduling/02_Scheduler.md)
    * [Processes and Threads](05_Scheduling/03_Processes_And_Threads.md)
    * [Locks](05_Scheduling/04_Locks.md)
* [Part 6: Getting to Userspace](06_Userspace/01_README.md)
    * [Switching Modes](06_Userspace/02_Switching_Modes.md)
    * [Updated Interrupt Handling](06_Userspace/03_Handling_Interrupts.md)
    * [System Calls](06_Userspace/04_System_Calls.md)
    * [Example Syscall ABI](06_Userspace/05_Example_ABI.md)
* [Part 7: Inter-Process Communication](07_IPC/01_README.md)
    * [Shared Memory](07_IPC/02_Shared_Memory.md)
    * [Message Passing](07_IPC/03_Message_Passing.md)
* [Part 8: File System](08_VirtualFileSystem/01_README.md)
    * [The Virtual File System](08_VirtualFileSystem/02_VirtualFileSystem.md)
* [Part 9: Loading & Executing ELFs](09_Loading_Elf/01_README.md)
    * [Theory](09_Loading_Elf/02_Elf_Theory.md)
    * [Loading and Running](09_Loading_Elf/03_Loading_And_Running.md)
* [Part 10: Going Beyond](10_Going_Beyond/01_README.md)
* [Extras: Appendices](99_Appendices/0_README.md)
    * [General Troubleshooting](99_Appendices/A_Troubleshooting.md)
    * [Tips and Tricks](99_Appendices/B_Tips_And_Tricks.md)
    * [C Language](99_Appendices/C_Language_Info.md)
    * [Working With NASM](99_Appendices/D_Nasm.md)

## Useful Links

* [DreamOs64](https://github.com/dreamos82/Dreamos64): 64-bit OS written from scratch by [Ivan G](https://github.com/dreamos82).
* [Northport](https://github.com/DeanoBurrito/northport): Another 64-bit OS with SMP, and riscv support! by [Dean T](https://github.com/DeanoBurrito/).
* [DreamOs](https://github.com/dreamos82/Dreamos): 32-bit OS written from scratch. This project is discontinued, but it still worth mentioning. Also by [Ivan G](https://github.com/dreamos82).

## Authors

* [Ivan G](https://github.com/dreamos82) (dreamos82) - Author and creator of these notes.
* [Dean T](https://github.com/DeanoBurrito/) (DeanoBurrito) - Author.

## License

The contents (code, text and other assets) of this repository are licensed under the Creative Commons Attribution-NonCommercial 4.0 Public License, see the [LICENSE](LICENSE.md) file for the full text.

While not legal advice, this license can be summed up as:
- You are free to share (copy and redistribute) this material in any medium or format.
- Adapt (remix, transform and build upon) the material.

Under the following restrictions:
- You must give appropriate credit, provide a link to the license, and indicate if changes were made.
- You cannot use the material for commercial uses.

Note that no warranties of any kind are provided.

<a rel="license" href="http://creativecommons.org/licenses/by-nc/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc/4.0/88x31.png" /></a>

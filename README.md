# Osdev Notes

[![Discord Chat](https://img.shields.io/discord/578193015433330698.svg?style=flat)](https://discordapp.com/channels/578193015433330698/578193713340219392)
<span class="badge-buymeacoffee">
<a href="https://buymeacoffee.com/dreamos82" title="Donate to this project using Buy Me A Coffee"><img src="https://img.shields.io/badge/buy%20me%20a%20coffee-donate-yellow.svg" alt="Buy Me A Coffee donate button" /></a>
</span>

This repository is a collection of small documents, notes and articles about various osdev topics.

They are not meant to be exhaustive, just  personal notes. I will keep updating them while developing the OS.

They are divided by topic, and usually in addition to information widely available on internet. I also try to add information based on personal experience, advice received, or mistakes made. 

I hope that someone will find them useful. 

Topics covered so far: 

* [Building & Boot Protocols](01_Build_Process/01_README.md)
    * [Bootloaders and Boot Protocols](01_Build_Process/02_Boot_Protocols.md)
    * [Building a Kernel](01_Build_Process/03_Overview.md)
    * [Linker Scripts](01_Build_Process/04_Linker_Scripts.md)
    * [Makefiles](01_Build_Process/05_Ggnu_Makefiles.md)
    * [Generating a Bootable Iso](01_Build_Process/06_Generating_Iso.md)
* [Memory Management](02_Memory_Management/01_README.md)
    * [Physical Memory](02_Memory_Management/02_Physical_Memory.md)
    * [Paging](02_Memory_Management/03_Paging.md)
    * [Virtual Memory Manager](02_Memory_Management/04_Virtual_Memory_Manager.md)
    * [Heap Allocation](02_Memory_Management/05_Heap_Allocation.md)
    * [Memory Protection](02_Memory_Management/06_Memory_Protection.md)
* [Keyboard](03_PS2_Keyboard/01_README.md)
    * [Interrupt Handling](03_PS2_Keyboard/02_Interrupt_Handling.md)
    * [Driver Implementation](03_PS2_Keyboard/03_Driver_Implementation.md)
* [Scheduling](04_Scheduling/01_README.md)
    * [The Scheduler](04_Scheduling/02_Scheduler.md)
    * [Processes and Threads](04_Scheduling/03_Processes_And_Threads.md)
    * [Locks](04_Scheduling/04_Locks.md)
* [Getting to Userspace](05_Userspace/01_README.md)
    * [Switching Modes](05_Userspace/02_Switching_Modes.md)
    * [Updated Interrupt Handling](05_Userspace/03_Handling_Interrupts.md)
    * [System Calls](05_Userspace/04_System_Calls.md)
    * [Example Syscall ABI](05_Userspace/05_Example_ABI.md)
* [Inter-Process Communication](06_IPC/01_README.md)
    * [Shared Memory](06_IPC/02_Shared_Memory.md)
    * [Message Passing](06_IPC/03_Message_Passing.md)
* [Extras](99_Appendices/0_README.md)
    * [General Troubleshooting](99_Appendices/A_Troubleshooting.md)
    * [Tips and Tricks](99_Appendices/B_Tips_And_Tricks.md)
    * [C Language](99_Appendices/C_Language_Info.md)
    * [Working With NASM](99_Appendices/D_Nasm.md)

* [APIC](APIC.md)
* [Debugging](Debug.md)
* [Drawing text on framebuffer](DrawingTextOnFB.md)
* [Framebuffer](Framebuffer.md)
* [Global Descriptor Table](GDT.md)
* [Moving the kernel in the higher half](HigherHalf.md)
* [Interrupt handling (64 bit)](InterruptHandling.md)
* [RSDP_and_RSDT](RSDP_and_RSDT.md)
* [Timer](Timer.md)

## Useful links

* [DreamOs64](https://github.com/dreamos82/Dreamos64) 64 bit Os written from scratch by [Dreamos82](https://github.com/dreamos82).
* [Northport](https://github.com/DeanoBurrito/northport) Another 64 bit Os written from scratch with SMP! by [DeanoBurrito](https://github.com/DeanoBurrito/).
* [DreamOs](https://github.com/dreamos82/Dreamos) 32 Bits Os written from scratch, the project is discontinued but I think it was worth mentioning. By [Dreamos82]([Dreamos82](https://github.com/dreamos82)).

## Authors
* [Ivan G](https://github.com/dreamos82) - Main author and creator of these notes.
* [Dean T](https://github.com/DeanoBurrito/) - Co-Author.

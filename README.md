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

* [Drawing text on framebuffer](DrawingTextOnFB.md)
* [Environment setup (for a 64bit os)](Environment_Setup.md)
* [Multiboot](Multiboot.md)
* [Framebuffer](Framebuffer.md)
* [Moving the kernel in the higher half](HigherHalf.md)
* [Interrupt handling (64 bit)](InterruptHandling.md)
* [Nasm tips](Nasm.md)
* [Memory Management](Memory_Management/README.md)
    * [Paging](Memory_Management/Paging.md)
    * [Memory Allocation](Memory_Management/Heap_Allocation.md)
    * [Physical Memory](Memory_Management/PhysicalMemory.md)
* [Building & Boot Protocols](Build_Process/README.md)
    * [Bootloaders and Boot Protocols](Build_Process/BootProtocols.md)
    * [Building a Kernel](Build_Process/Overview.md)
    * [Linker Scripts](Build_Process/LinkerScripts.md)
    * [Makefiles](Build_Process/GNUMakefiles.md)
    * [Generating a Bootable Iso](Build_Process/GeneratingISO.md)
* [Global Descriptor Table](GDT.md)
* [APIC](APIC.md)
* [Keyboard](PS2_Keyboard/)
    * [Interrupt Handling](PS2_Keyboard/InterruptHandling.md)
    * [Driver Implementation](PS2_Keyboard/DriverImplementation.md)
* [Timer](Timer.md)
* [Debugging](Debug.md)
* [RSDP_and_RSDT](RSDP_and_RSDT.md)
* [C Language tips and tricks](C_Language_Info.md)
* [TroubleShooting](Troubleshooting.md)
* [Misc tips and tricks](TipsAndTricks.md)

# Useful links

* [DreamOs64](https://github.com/dreamos82/Dreamos64) 64 bit Os written from scratch by [Dreamos82](https://github.com/dreamos82).
* [Northport](https://github.com/DeanoBurrito/northport) Another 64 bit Os written from scratch with SMP! by [DeanoBurrito](https://github.com/DeanoBurrito/).
* [DreamOs](https://github.com/dreamos82/Dreamos) 32 Bits Os written from scratch, the project is discontinued but I think it was worth mentioning. By [Dreamos82]([Dreamos82](https://github.com/dreamos82)).

# Authors
* [Ivan G](https://github.com/dreamos82) - Main author and creator of these notes.
* [Dean T](https://github.com/DeanoBurrito/) - Co-Author.

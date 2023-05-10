# Memory Management 

This part will cover all the topic related on how to build a memory management mechanism, from scratch, all layers will be covered.

Below the list of chapters: 

* [Overview](01_Overview.md) It introduces the basic concepts of memory management, and provide an high level overview of all the layers that are part of it.
* [Physical Memory Manager](02_Physical_Memory.md) The lowest layer, the physical memory manager, it deals with "real memory".
* [Paging](03_Paging.md) Paging will provide a separation between a physical memory address and a virtual address. This mean that the kernel we will be able to access much more addresses than the ones available.
* [Virtual Memory Manager](04_Virtual_Memory_Manager.md) It sits between the heap and the physical memory manager, it is similar to the Physical Memory Manager, but for the virtual space.
* [Heap Allocation](05_Heap_Allocation.md) Allocating memory, aka _malloc_ and friends. What is behind it and how it works.

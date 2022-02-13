# Memory Allocation 

When we are talking about memory allocation we are talking about a broad topic that covers at least two or three differen types of allocators: 

* Phsical Memory Allocation (you can check the [Physical Memory](PhysicalMemory.md) Chapter
* Virtual Memory Allocation usually split in User Space Memory Allocation and Kernel Space memor allocation

Not all OS needs a distinction between user space and kernel space (this depends on how the operating system is designed). 

In this page we will try to cover some basics about a memory allocator, try to detail an algorithm that can be used to allocate memory.

And try to cover some gray areas that are between the phyisical memory manager and the memory allocator. 

## From physical to virtual... (The link between...) 

Before going to see some real  allocation algorithm, let's try to explain first how all things are connected together. 

So when talking about Memory Management we are talking about several topics, here is a short and not complete list of the topics
(probably those are the one you will find covered by these notes): 

* [Physical memory](PhysicalMemory.md) Management
* [Paging](Paging.md)
* Virtual Memory Management
* Memory Allocation
 
Now one of the biggest problem while writing a memory manager for our os  is to understand how all these topics are connected between each other.

And probably this guide will not be enough to understand this topic, but i hope it will help. 

Before proceeding a quick recap of some of the basic concepts: 

1. The Physical memory manager is managing the physical memory, the RAM itself (or whatever it is called on your device), when requested it will mark the used area of the physical memory as free/used depending on their status, 
2. Paging is introducing the concept of Virtual Memory and Virtual Addresses. It basically provide the OS with a much broader address space (how big it depends on the architecture). It basically map a physical address to a virtual one wherever the os wants. So for example *Phys:0x123456 = Virt:0xF0B12345*. And that's not all in a multitasking environment since it is just based on tables, we can have every taks using it's own address space, so the same virtual address for *task1* is different from the virtual address of *task2*
3. Memory Allocation (explained in this section) it returns addresses, virtual! It basically looks for an area of contiguous addresses big enough to contain the requested size. It doesn't care about physical addresses, it will only search for the area we need in the virtual world. It doesn't care if the physical memory it will be all contigous or not. To the requester it will look contiguous (another cool feature of the paging). More details will be given in the paragraphs below.
4. Virtual Memory manager 

__Probably an image could be used here?__
__Continue...__

### When the virtual address will become physical?

Well it's up to you.. there are two possible way:

* On demand
* On first use..

__Continue__



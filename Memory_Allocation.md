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

What is the difference? The first method involve that we allocate the physical space as soon as we fouund the virtual memory address. Depending on the size we will map directly the virtual addresses onto their physical parts (usually they are blocks/pages of a fixed size), there is no need for the phyisical blocks to be contiguos, as long as the virtual ones are.

Otherwise the other way is to map the virtual address only when it will be accessed, so what happen basically is that we search a suitable virtual memory block for the required space, mark it as used and return the address. And forget about it. 

Then at some point in the future the program that requested the block will try to access the address returned, at this point since it is not mapped yet an exception (called Page Fault) and here our handler will do the job, finding a suitable physical address to map to the current virtual address that caused  the exception, and resuming the normal execution. All of that will be transparent to the user.

What is the pros of the second approach? Well for sure we don't waste memory, and we allocate it only when is really needed, so if a program allocate lot of memory for it's worst case scenario, but uses usually only 10% of it, in this way we will just use that 10% instead of preallocate everything. On the other hand in this way we can have fragmentation for the data that is related to the same process (be careful we are talking about physical memory not virtual), and also to allocate the n-physical pages of physical memory we will have to pass through n-page faults.
__Continue__



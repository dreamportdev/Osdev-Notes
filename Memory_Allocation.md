# Memory Allocation 

When we are talking about memory allocation we are talking about a broad and complex topic (is also one of the first hard challenges when developing an OS, and i find it personally boring)  that covers at least two or three different types of allocators: 

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

1. The Physical memory manager is managing the physical memory, the RAM itself (or whatever it is called on your device), when requested it will mark the used area of the physical memory as free/used depending on their status, it usually allocate memory in block/pages of a fixed size.
2. Paging is introducing the concept of Virtual Memory and Virtual Addresses. It basically provide the OS with a much broader address space (how big it depends on the architecture). It basically map a physical address to a virtual one wherever the os wants. So for example *Phys:0x123456 = Virt:0xF0B12345*. And that's not all in a multitasking environment since it is just based on tables, we can have every taks using it's own address space, so the same virtual address for *task1* is different from the virtual address of *task2*
3. Memory Allocation (explained in this section) it returns addresses, virtual! It basically looks for an area of contiguous addresses big enough to contain the requested size. It doesn't care about physical addresses, it will only search for the area we need in the virtual world. It doesn't care if the physical memory it will be all contigous or not. To the requester it will look contiguous (another cool feature of the paging). More details will be given in the paragraphs below.
4. Virtual Memory manager 

__Probably an image could be used here?__
__Continue...__

### When the virtual address will become physical?

Well it's up to you.. there are two possible way (maybe more, but i don't want to overcomplicate stuff):

* On demand
* On first use..

What is the difference? The first method involve that we allocate the physical space as soon as we fouund the virtual memory address (if needed). Depending on the size we will map directly the virtual addresses onto their physical parts (usually they are blocks/pages of a fixed size), there is no need for the phyisical blocks to be contiguos, as long as the virtual ones are.

Otherwise the other way is to map the virtual address only when it will be accessed, so what happen basically is that we search a suitable virtual memory block for the required space, mark it as used and return the address. And forget about it. 

Then at some point in the future the program that requested the block will try to access the address returned, at this point since it is not mapped yet an exception (called Page Fault) and here our handler will do the job, finding a suitable physical address to map to the current virtual address that caused  the exception, and resuming the normal execution. All of that will be transparent to the user.

What are the pros of the second approach? Well for sure we don't waste memory, and we allocate it only when is really needed, so if a program allocate lot of memory for it's worst case scenario, but uses usually only 10% of it, in this way we will just use that 10% instead of preallocate everything. On the other hand in this way we can have fragmentation for the data that is related to the same process (be careful we are talking about physical memory not virtual), and also to allocate the n-physical pages of physical memory we will have to pass through n-page faults.

Before proceeding is important probably to clarify a concept: when mapping a physical address into a virtual one, we are usually mapping pages of fixed sizes (4k, 2M, 1gb, mixed) while the allocator is allocating bytes/megabytes/whatever. So let's show that with an example in both cases, on-demand and on-first-use. 

Aassume that we have a set of alloc calls like the following (consecutives):

```C
char *a = alloc(5);
char *b = alloc(10);
char *c = alloc(100);
```

Let's make few assumptions: our allocator hasn't mapped any virtual address into physical memory yet, we are using 4k pages and we don't consider the data structures overhead. So this is what will happen when we allocate memory on-demand: 

1. The first alloc will find the address A, and check if it is already mapped, since it isn't will ask the virtual memory manager to map it into a physical address, the pmm find a suitable page (remember they are 4k) and map the virtual address A to the pyhsical address P. So VA(P) = A and Phys(A) = P
2. Now we make the second alloc of 10, the allocator check for a suitable address and find a hole just at B=A+5 (let's ignore overhead caused by headers/structures around), so it check if it is alreqady mapped, but the paging works in blocks of 4k size, so it does the check and find that the address of B is within the range of A - A+4k so it doesn't do any mapping. So VA(P+5) = Phys(A+5)
3. Third alloc, the heap founds the suitable address at A + B, it needs 100bytes it is still in the range of: A - A+4k, so no need for mapping... we are still good to go. 

Now an edge case is if the next alloc will go over the boundaries of the current page, but well this is what we will discuss in this chapter later.

Now what happens if we are using on first-use mapping? Well things here are more tricky and they depends on who rise the PF first. but the reasoning is similar, if for example the address are accessed in the same order of the previous example, we apply the same reasoning. But what happens if we access them in a different order? Well it will most likely be the same, in fact, if we access for example *b* first, it will cause a #PF, now the pf handler will map a page for the address, but remember Pages have a fixed size, so this means that we map and address space that is a multiple of PAGE_SIZE (that is the page size used by your kernel), so this means that when we will map the page for the address obtained by *b*, what we are really mapping is the tha Page containing B. For example: 

* The alloc for *b* return the address 0x10010
* We try to access *b* but it isn't mapped yet, we cause a #PF tha fire our #PF handler
* THe handler get the address and decompose in it's PDirs/PTables (what suits your kernel/architecture chosen) and ask for a physical page. But here is the trick when computing entries for the paging structure the last X bits (again: it depends if you are using 32/64 bits architecture, 4k/2m/1g pages, but let's say is a number between 11 and 21) are considered the offset, so they don't take part in the mapping process, they are "skipped". For example let's assume we are use 4 level paging for 64bit long mode, so according to the specs we know that the last 11 bits of the address are considered the offset, so the meaningful part of the address are the last 53 bits, in binary: 

```
ADDRESS        : 0b00000000000000000000000000000000000000000000000010000000000010000 AND
MEANINGFUL_MASK: 0b11111111111111111111111111111111111111111111111111111000000000000 =
PAGE_BASE_ADDR : 0b00000000000000000000000000000000000000000000000010000000000000000
HEX_BASE_ADDR  : 0x10000
```

That means that although we wanted to map 0x10010 what we are really allocating is the page containing that address. 
What does it mean? That if we will try to access *a* later, well most likely the allocator would have returned 10005 (remember we don't take into account any header information), so the #PF for *b* has already mapped the page for *a*, so there is no need for another #PF or another mapping. Now the same will happen for when *c* will be accessed. 

Of course things could have been different if we assumed that the addressed returned by the allocator were at a page boundary (i.e. *a* was starting at 0x10985 and *b* at 0x10990, this would have caused to have *c* be outside the current page boundary, so it would have caused a page fault, but we will talk more about it later). 
__Continue__


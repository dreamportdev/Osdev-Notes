# Memory Allocation 

*Authors note: Memory allocation is one of the first hard challenges you will face when developing an os, and I find it personally boring.*

When we are talking about memory allocation we are talking about a broad and complex topic that covers at least two or three different types of allocators: 

* Phsical Memory Allocation (see the [Physical Memory](PhysicalMemory.md) chapter)
* Virtual Memory Allocation usually split in a user side (the heap) and kernel side (paging, virtual memory manager).

Not all OS needs a distinction between user space and kernel space (this depends on how the operating system is designed). 

In this page we will cover some basics about a memory allocator, detail an algorithm that can be used to allocate memory, and try to cover some gray areas that are between the phyisical memory manager and the memory allocator. 

## From Physical to Virtual... (The Link Between...) 

Before going to see some real allocation algorithms, let's first explain how it's all connected together. 

So when talking about memory management, we are actually talking about several topic. Here is a short but not exhaustive list of the topics (the ones we cover in these notes): 

* [Physical memory](PhysicalMemory.md) Management
* [Paging](Paging.md)
* Virtual Memory Management
* Memory Allocation
 
Now one of the biggest problems while writing a memory manager for our os is to understand how all these topics are connected to each other. This guide will probably not be enough to understand this topic completely, but it should help!

Before proceeding a quick recap of some of the basic concepts: 

1. The Physical memory manager manages physical memory: the RAM itself (or whatever it is called on your device). When requested it will mark the used area of the physical memory as free/used depending on their status, it usually allocate memory in block/pages of a fixed size.
2. Paging is introducing the concept of virtual memory and virtual addresses. It basically provides the OS with a much broader address space (how big it depends on the architecture). It basically map a physical address to a virtual one wherever the os wants. So for example *Phys:0x123456 = Virt:0xF0B12345*. And that's not all: since paging is just based on tables that we can swap out at any time, in a multi-tasking environment we can have every task using it's own address space, so the same virtual address for *task1* is different from the virtual address of *task2*
3. Memory Allocation (explained in this section) it returns addresses, virtual! It basically looks for an area of contiguous addresses big enough to contain the requested size. It doesn't care about physical addresses, it will only search for the area we need in the virtual world. It doesn't care if the physical memory it will be all contigous or not. To the requester it will look contiguous (another cool feature of the paging). More details will be given in the paragraphs below.
4. Virtual Memory Manager: for smaller projects this will be paging, but the vmm is the over-arching manager of a tasks memory. Letting you map virtual addresses to physical ones, sharing memory between multiple tasks, ensuring memory is available when needed (stealing from other vmms).

__Probably an image could be used here?__
__Continue...__

## Backing Virtual Memory with Physical Memory

When does virtual memory become physical? Well it's up to you. There are two main ways this is done:

* The *immediate* method: This means that we allocate the physical memory as soon as we map the virtual memory. Depending on the size we will map directly the virtual addresses onto their physical parts (usually they are blocks/pages of a fixed size), there is no need for the physical blocks to be continuous, as long as the virtual ones are. Another win for virtual memory!

* The *demand* method: the vmm just maps the virtual address when requested, but does not put any physical memory behind it. Then at some point in the future the program that requested the memory will try to access the returned virtual address, and since it is not mapped yet an exception (called Page Fault, or #PF) will be fired. The handler will check CR2 and the provided error code to find out that the address allocated is not mapped, and will take care of mapping it for us. All of that will be transparent to the user. This does not always have to be the full virtual address region that was initially mapped! There is also a version used by some operating systems where new memory is always mapped to a read-only page of zeroes, and is only allocated on the first *write* rather than first use.

The table below shows the pros and cons of both appraoches: 

| Paging allocation type | Pros                             | Cons                                                    |
|------------------------|----------------------------------|---------------------------------------------------------|
| Immediate              | No need for a page fault handler | Allocates physical memory that may not be needed (potentially wasting physical memory) |
| Demand                 | Only allocates physical memory that is used | Complex page fault handler required |

Before proceeding is probably important to clarify a concept: when mapping a physical address into a virtual one, we are usually mapping pages of fixed sizes (4k, 2M, 1gb, mixed) while the allocator is allocating bytes/megabytes/whatever. So let's show that with an example in both cases, on-demand and on-first-use. 

Aassume that we have a set of alloc calls like the following:

```C
char *a = alloc(5);
char *b = alloc(10);
char *c = alloc(100);
```

Let's make few assumptions: our allocator hasn't mapped any virtual address to physical memory yet, we are using 4k pages, and we don't consider the data structure's overhead. So when we allocate memory on-demand, this is what will happen:

1. The first alloc will find the address A, and check if it is already mapped, since it isn't will ask the virtual memory manager to map it into a physical address, the pmm find a suitable page (remember they are 4k) and map the virtual address A to the pyhsical address P. So VA(P) = A and Phys(A) = P
2. Now we make the second alloc of 10, the allocator checks for a suitable address and finds a hole just at B=A+5. So it checks if it is already mapped, but since paging works in blocks of 4k size, it finds that the address of B is within the range of A - A+4k so it doesn't do any mapping. So VA(P+5) = Phys(A+5)
3. Third alloc, the heap finds a suitable address at A + B. It needs 100 bytes, and this is still in the range of: A - A+4k, so no need for mapping! We are still good to go. 

Now an edge case is if the next alloc will go over the boundaries of the current page, but this is what we will discuss in this chapter later.

Now what happens if we are using on first-use mapping? Well things here are more tricky and they depends on who causes the PF first, but the reasoning is similar. If for example the address are accessed in the same order of the previous example, we apply the same reasoning. But what happens if we access them in a different order? Well it will most likely be the same, in fact, if we access for example *b* first, it will cause a #PF. Now the pf handler will map a page for that address, but remember pages have a fixed size, so this means that we map and address space that is a multiple of PAGE_SIZE (that is the page size used by your kernel), this means that when we map the page for the address obtained by *alloc b*, what we are really mapping is the tha page *containing* B. 

For example: 

* The alloc for *b* return the address 0x10010
* We try to access *b* but it isn't mapped yet, we cause a #PF tha fire our #PF handler
* The handler gets the address and decomposes through its PDirs/PTables (what suits your kernel/architecture chosen), and asks for a physical page. Here is the trick when computing entries for the paging structure: the last X bits (again: it depends on what page size you're using, whether it's 4kb/2mm/1gb pages. For 4K pages it's the last 12 bits) are considered the offset, so they don't take part in the mapping process. They are "skipped". Now for let's assume we are using 4 level paging for 64bit long mode, according to the specs we know that the last 12 bits of the address are considered the offset, so the meaningful part of the address are the last 52 bits, in binary: 

```
ADDRESS        : 0b00000000000000000000000000000000000000000000000010000000000010000 AND
MEANINGFUL_MASK: 0b11111111111111111111111111111111111111111111111111111000000000000 =
PAGE_BASE_ADDR : 0b00000000000000000000000000000000000000000000000010000000000000000
HEX_BASE_ADDR  : 0x10000
```

Again, although we wanted to map 0x10010 what we are really allocating is the page containing that address. 
What does this mean? That if we try to access *a* later, when the allocator has returned the address 0x10005, the #PF for *b* has already mapped the page for *a*, so there is no need for another #PF or another mapping. Now the same will happen for when *c* will be accessed. 

Of course things could have been different if we assumed that the addressed returned by the allocator were at a page boundary (i.e. *a* was starting at 0x10985 and *b* at 0x10990, this would have caused to have *c* be outside the current page boundary, so it would have caused a page fault, but we will talk more about it later). 

__Continue__


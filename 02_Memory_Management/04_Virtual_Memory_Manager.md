# Virtual Memory Manager

## An Overview

At first a virtual memory manager might not seem like a necessary component since we have paging, but the VMM serves as an abstraction over the hardware used for memory translation (the MMU - memory management unit, the piece of hardware that processes our page tables), as well as abstracting away other things like memory mapping files or even devices.

As mentioned, if your kernel is simple your VMM may only interact with paging, but as your kernel grows more complex, your vmm will also grow too.

### Virtual Memory

What exactly does the virtual memory manager *manage*? The PMM manages the physical memory installed in a computer, so it would make sense that the VMM manages the virtual memory. What do we mean by virtual memory?

Once paging is enabled, any memory we access is virtual memory. Meaning that anytime we access memory it must first be translated by the MMU (memory management unit, which contains the TLB that we interact with) from a virtual address to a physical address. This is what paging does, and should be nothing new. 
To access physical memory like we did before, we have to first map it into the virtual address space, either via an identity map or at an offset somewhere else. If we do this we can now access physical memory like before, but it's accessed via virtual memory. It's a subtle difference, but a very important one.

Now that we have a layer between how the kernel and other programs see memory, we can do some interesting things. Mapping physical memory into the virtual address space is the most common use (we'll need this to access the page tables, or for drivers to communicate with hardware), but we can also place things anywhere in virtual memory that we like. 
For example, a higher half kernel is commonly placed at -2GB (0xFFFF'FFFF'8000'0000 in a 64-bit virtual address space) which would be near-impossible to do with physical memory. We can also arrange things in virtual memory to our liking: some kernels will have the heap start at a known address (0xFFFF'D555'5555'0000 for example) to help with debugging, since you can easily tell what a virtual address corresponds too.  

Using virtual memory also allows us to protect parts of memory. Once we reach userspace we will still need the kernel loaded, in order to provide system calls and handle interrupts, but we don't want the user program to be able to arbitrarily access this memory. 

We can also add more advanced features later on, like demand paging. Typically when a program (including the kernel) asks the VMM for memory, and the VMM can successfully allocate it, physical memory is mapped there right away. *Immediately backing* like this has advantages in that it's very simple to implement, and can be very fast. The major downside is that we trust the program to only allocate what it needs, and if it allocates more (which is very common) that extra physical memory is wasted. In contrast, *demand paging* does not back memory right away, instead relying on the program to cause a page fault when it accesses the virtual memory it just allocated. At this point the VMM now backs that virtual memory with some physical memory, usually a few pages at a time (to save overhead on page-faults). The benefits of demand-paging are that it can reduce physical memory usage, but it can slow down programs if not implemented carefully. It also requires a more complex VMM, and the ability to handle page faults properly.

On the topic of advanced VMM features, you can also do other things like caching files in memory, and then mapping those files into the virtual address space somewhere (this is what the `mmap` system call does).

A lot of these features are not needed in the beginning, but hopefully the uses of a VMM are clear. To answer the original question of what a VMM does: it's really a manager of the virtual address space.

## Concepts

As you might expect, there are many VMM designs out there. We're going to look at a simple one that should provide all the functionality needed for now.
First we'll need to introduce a new concept: a virtual memory object. This is just a struct that represents part of the virtual address space, so it will need a base address and length, both of these are in bytes and will be page-aligned. We'll also want to store some flags that describe the memory the object represents: is it writable? is it user accessible?

These flags seem like the flags we store in the page tables, so you could just store them there, but storing them as part of the object makes looking them up faster, since you don't need to manually traverse the paging structure. Later on we will add more flags.

Here's what our example virtual memory object looks like:

```c
typedef struct {
    uintptr_t base;
    size_t length;
    size_t flags;
    vm_object* next;
} vm_object;

#define VM_FLAG_NONE 0
#define VM_FLAG_WRITE (1 << 0)
#define VM_FLAG_EXEC (1 << 1)
#define VM_FLAG_USER (1 << 2)
```

The `flags` field is actually a bitfield, and we've defined some macros to use with it. These don't correspond to the bits in the page table, but having them separate like this means they are platform-agnostic. We can port our kernel to cpu architecture and most of the code won't need to change, we'll just a short function that converts the vm flags into page table flags. This is especially convinient for oddities like x86 and it's nx-bit, where all memory is executable by default, and you must specify if you *don't* want it to be executable. 

Having it like this allows that to be abstracted away from the rest of our kernel. For x86_64 our translation function would look like the following:

```c
uint64_t convert_x86_64_vm_flags(size_t flags) {
    uint64_t value = 0;
    if (flags & VM_FLAG_WRITE)
        value |= PT_FLAG_WRITE;
    if (flags & VM_FLAG_USER)
        value |= PT_FLAG_USER;
    if ((flags & VM_FLAG_EXEC) == 0)
        value |= PT_FLAG_NX;
    return value;
};
```

The `PT_xyz` macros are just setting the bits in the page table entry, for specifics see the paging chapter. Notice how we set the NX-bit if `VM_FLAG_EXEC` is not set because of a quirk on x86.

We're going to store these vm objects as a linked list, which is the purpose of the `next` field.

## Allocating Objects

`void* vmm_alloc(size_t length, size_t flags)` for general allocations
`void* vmm_map(uintptr_t phys_addr, size_t length, size_t flags)` for mmio or pre-allocated memory.

## Freeing Objects

`void vmm_free(void* addr)`

## Workflow

- unless you specifically need *physical memory*, you use `vmm_alloc`/`vmm_free` for stuff.

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


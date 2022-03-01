# Memory Management

Welcome to one of the first big challenges of your osdev adventure. It is the first "complex" component that you have to implement, and in my opinion one of the most boring too!! 

So let's get started...

The shortest way to define a memory manager is that is a system that manage computer memory, and provide ways to dinamically allocate and free portions of it. 

The design and complexity of a memory manger can vary greatly, a lot depends on what the operating system will do and how it will be designed. For example if what we want is a single task os, with Paging not enabled, and no memory protection, probably it will be failry simple to implement. 

In this section we will try to cover a more common use case that is probably what nearly all modern operating system does, that is a 32/64 operating system with paging enabled, and a memory allocator for the kernel and one for the user space, in this way we will be able to cover more or less all the following topics: 

* Physical Memory Manager
* Paging 
* Virtual Memory Manager
* Heap Allocation

Don't worry we will try to keep it as simple as possible, using basic algorithms and try to explain all the grey areas... But stil it will be sometime hard to follow, you will prob

For every of the steps above there will be a dedicated section, while in this one we will try to explain the global picture. Before proceeding let's define briefly the concepts above (for in detail explanation please refer to their own sections): 

| Memory Management Layer | Description |
|-|-------------|
| Physical Memory Manager | Responsible for keeping track of which parts of the available hardware memory (usually ram) are free/in-use. It allocates in fixed size blocks, the native page size. This is 4096 bytes on x86.|
| Paging | It introduces the concepts of *virtual memory* and *virtual addresses*, providing the OS with a bigger address space, protection to the data and code in its pages, and isolation between programs. | 
| Virtual memory manager | For a lot of projects, the VMM and paging will be the same thing. However the VMM should be seen as the virtual memory *manager*, and paging is just one tool that it uses to accomplish its job: ensuring that a program has memory where it needs it, when it needs it. Often this is just mapping physical ram to the requested virtual address (via paging or segmentaiton), but it can evolve into stealing pages from other processes. |
| Heap Allocator | The VMM can handle page-sized allocations just fine, but that is not always useful. A heap allocator allows for allocations of any size, big or small. | 

## PMM - Physical Memory Manager

- Exists at a system-level, there is only a single PMM per running os, and it manages all of the available memory. 
  - There are implemenations that use a co-operative pmm per cpu core design, which move excess free pages to other pmms, or request pages from other pmms if needed. These can be extremely problematic if not designed properly, and should be considered an advanced topic.
- Keeps track of whether a page is currently in use, or free.
- Is responsible for protecting non-usable memory regions from being used as general memory (mmio, acpi or bootloader memory).

## VMM - Virtual Memory Manager
- Exists per process/running program.
- Sets up an environment where the program can happily run code at whatever addresses it needs, and access data where it needs too.
- The VMM can be thought of a black-box to user programs, you ask it for an address and it 'just works', returning memory where needed. It can use several tools to accomplish this job:
   - Segmentation: Mostly obsolete in long mode, replaced by paging.
   - Paging: Can be used to map virtual pages (what the running code sees) to physical pages (where it exists in real memory).
   - Swapping: Can ask other VMMs to swap their in-use memory to storage, and handover any freed pages for us to use.
- A simple implementaion often only involves paging.
- If using a higher half kernel, the upper half of every VMM will be identical, and contain the protected kernel code and data.

## Heap Allocator
- At last one per process/running program. 
- Can be chained! Some designs are faster for specific tasks, and often will operate on top of each other.
- Can exist in kernel or user space.
- Can manage memory of any size, unlike the VMM which often operates in page-sized chunks (for simplicity). Often splitting the page-aligned chunks given by the VMM into whatever the program requests via `malloc(xyz)`.
- There are many different ways to implement one, the common choices are:
  - Using a doubly linked list of nodes, with each tracking their size and whether they are free or in use. Relatively simple to implement, great for getting started. Prone to sublte bugs, and can start to slow down after some time.
  - Buddy allocator. These are more complex to understand initially, but are generally much faster to allocate/free. They can lead to more fragmentation that a linked list style. 
  - Slab allocator. These work in fixed sized chunks, memory can simply be viewed as a single array of these chunks, and the allocator simply needs a bitmap to keep track of which chunks are free or not.

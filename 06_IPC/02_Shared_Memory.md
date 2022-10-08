# IPC via Shared Memory

Shared memory is the easiest form of IPC to implement. It's also the fastest form as the data is just written by one process, and then read by another. No copying involved. Note that speed here does not necessarily mean low-latency.

The principle behind shared memory is simple: we're going to map the same physical pages into two different virtual address spaces. Now this memory is visible to both processes, and they can pass data back and forth.

## Overall Design

As always there are many ways to design something to manage this. You could have a program ask the virtual memory manager for memory, but with a special 'shared memory' flag. If you've ever used the `mmap()` syscall, this should sound familiar. In this design the program interacts with the VMM, which then transparently deals with the ipc subsystem.

Alternatively, you could have programs deal with the ipc subsystem directly, which would then deal with the VMM for allocating a region of virtual memory to map the shared memory into. There are pros and cons to both approaches, but either way these components will need to interact with each other.

Your virtual memory manager will also need to keep track of whether it allocated the pages for a particular virtual memory range, or it borrowed them from the ipc subsytem. We need this distinction because of how shared memory works: if two VMMs map the same physical memory, and then one VMM exits and frees any physical memory it had mapped, it will free the physical memory used for the shared memory. This leaves the other VMM with physical memory that the physical memory manager thinks is *free*, but it's actually still in use.

The solution we're going to use is *reference counting*. Everytime a VMM maps shared memory into it's page tables, we increase the count by 1. Whenever a VMM exits and goes to free physical memory, it will first check if it's shared memory or not. If it's not, it can be freed as normal, but if it's shared memory we simply decrease the reference count by 1. Whenever decrementing the reference count, we check if it's zero, and only then do we free the physical memory. The reference count can be thought of as a number that represents how many people are using a particular shared memory instance, with zero meaning no-one is using it. If no-one is using it, we can safely free it.

## IPC Manager

We're going to implement an *IPC manager* to keep track of shared memory.

At it's heart, our IPC manager is going to be a list of physical memory ranges, with a name attached to each range. When we say physical memory *range*, this just refers to a number of physical pages located one after the other (i.e. contiguous). Attaching a name to a range lets us identity it, and we can even give some of these names special meanings, like `/dev/stdout` for example. In reality this is not how stdout is usually implemented, but it serves to get the point across. 

We're going to use a struct to keep track of all the information we need for shared memory, and store them in a linked list so we can keep track of multiple shared memory instances.

```c
struct ipc_shared_memory {
    uintptr_t physical_base;
    size_t length;
    size_t ref_count;
    const char* name;
    ipc_shared_memory* next;
}
```

The `ipc_shared_memory` struct holds everything we'll need. The `physical_base` and `length` fields describe the physical memory (read: pages allocated from your physical memory manager) used by this shared memory instance. It's important to note that the address is a *physical* one, since virtual addresses are useless outside of their virtual address space. Since each process is isolated in it's own address space, we cannot store a virtual address here.

The `ref_count` field is how many processes are currently using this physical memory, if this drops to zero we can safely free the physical memory used and consider the shared memory instance finished. The `name` field holds a string used to identify this shared memory instance, and the `next` pointer is used for the linked list.

### Creating Shared Memory

Let's look at what could happen if a program wants to create some shared memory, in order to communicate with other programs:

- The program asks the virtual memory manager to allocate some memory, and says it should be shared.
- The VMM finds a suitible virtual address for this memory to appear at (where it'll be mapped).
- Instead of the VMM allocating physical memory to map at this virtual address, the VMM asks the ipc manager to create a new shared memory instance.
- The ipc manager adds a new `ipc_shared_memory` entry to the list, gives it the name the program requested, and sets the `ref_count` to 1 (since there is one program accessing it).
- The ipc manager asks the physical memory manager for enough physical memory to satify the original request, and stores the address and length.
- The ipc manager returns the address of the physical memory it just allocated to the VMM.
- The VMM maps this physical memory at the virtual address it selected earlier.
- The VMM can now return this virtual address to the program, and the program can access the shared memory at this address.

```c
spinlock_t* list_lock;
ipc_shared_memory* list;

void* create_shared_memory(size_t length, const char* name) {
    ipc_shared_memory* shared_mem = malloc(sizeof(ipc_shared_memory));
    shared_mem->next = NULL;
    shared_mem->ref_count = 1;
    shared_mem->length = length;

    const size_t name_length = strlen(name);
    shared_mem->name = malloc(name_length + 1);
    strcpy(shared_mem->name, name);

    shared_mem->physical_base = pmm_alloc_pages(length / PAGE_SIZE);

    acquire(list_lock);
    ipc_shared_memory* tail = list;
    while (tail->next != NULL)
        tail = list->next;
    
    tail->next = shared_mem;
    release(list_lock);
}
```

Notice the use of the lock around when we access the linked list. Since this single list is shared by any process that interacts with the ipc manager, we need to protect it from entering a corrupted state. The lock should be allocated and initialized by some earlier code.

-- pmm_alloc_pages() and PAGE_SIZE

### Accessing Shared Memory

-- dont passing pointers through shared memory. Use base + offsets.

### Cleaning Up

-- ref count in practice

## Interesting Applications

-- circular buffer to immitate a stream of data.
-- mention io_uring, how this approach allows for IPC with zero intervention from the kernel.
-- Hybrid designs with occasional signals being sent by kernel.

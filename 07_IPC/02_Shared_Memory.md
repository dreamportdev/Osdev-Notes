# IPC via Shared Memory

Shared memory is the easiest form of IPC to implement. It's also the fastest form as the data is just written by one process, and then read by another. No copying involved. Note that speed here does not necessarily mean low-latency.

The principle behind shared memory is simple: we're going to map the same physical pages into two different virtual address spaces. Now this memory is visible to both processes, and they can pass data back and forth.

## Overall Design

As always there are many ways to design something to manage this. You could have a program ask the virtual memory manager for memory, but with a special 'shared memory' flag. If you've ever used the `mmap()` syscall, this should sound familiar. In this design the program interacts with the VMM, which then transparen'tly deals with the ipc subsystem.

Alternatively, you could have programs deal with the ipc subsystem directly, which would then deal with the VMM for allocating a region of virtual memory to map the shared memory into. There are pros and cons to both approaches, but either way these components will need to interact with each other.

Your virtual memory manager will also need to keep track of whether it allocated the pages for a particular virtual memory range, or it borrowed them from the ipc subsytem. We need this distinction because of how shared memory works: if two VMMs map the same physical memory, and then one VMM exits and frees any physical memory it had mapped, it will free the physical memory used for the shared memory. This leaves the other VMM with physical memory that the physical memory manager thinks is *free*, but it's actually still in use.

The solution we're going to use is *reference counting*. Everytime a VMM maps shared memory into its page tables, we increase the count by 1. Whenever a VMM exits and goes to free physical memory, it will first check if it's shared memory or not. If it's not, it can be freed as normal, but if it's shared memory we simply decrease the reference count by 1. Whenever decrementing the reference count, we check if it's zero, and only then we free the physical memory. The reference count can be thought of as a number that represents how many people are using a particular shared memory instance, with zero meaning no-one is using it. If no-one is using it, we can safely free it.

## IPC Manager

We're going to implement an *IPC manager* to keep track of shared memory.

At its heart, our IPC manager is going to be a list of physical memory ranges, with a name attached to each range. When we say physical memory *range*, this just refers to a number of physical pages located one after the other (i.e. contiguous). Attaching a name to a range lets us identify it, and we can even give some of these names special meanings, like `/dev/stdout` for example. In reality this is not how stdout is usually implemented, but it serves to get the point across.

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

The `ipc_shared_memory` struct holds everything we'll need. The `physical_base` and `length` fields describe the physical memory (read: pages allocated from your physical memory manager) used by this shared memory instance. It's important to note that the address is a *physical* one, since virtual addresses are useless outside of their virtual address space. Since each process is isolated in its own address space, we cannot store a virtual address here.

The `ref_count` field is how many processes are currently using this physical memory. If this ever reaches zero, it means no-one is using this memory, and we can safely free the physical pages. The `name` field holds a string used to identify this shared memory instance, and the `next` pointer is used for the linked list.

### Creating Shared Memory

Let's look at what could happen if a program wants to create some shared memory, in order to communicate with other programs:

- The program asks the virtual memory manager to allocate some memory, and says it should be shared.
- The VMM finds a suitable virtual address for this memory to appear at (where it'll be mapped).
- Instead of the VMM allocating physical memory to map at this virtual address, the VMM asks the ipc manager to create a new shared memory instance.
- The ipc manager adds a new `ipc_shared_memory` entry to the list, gives it the name the program requested, and sets the `ref_count` to 1 (since there is one program accessing it).
- The ipc manager asks the physical memory manager for enough physical memory to satisfy the original request, and stores the address and length.
- The ipc manager returns the address of the physical memory it just allocated to the VMM.
- The VMM maps this physical memory at the virtual address it selected earlier.
- The VMM can now return this virtual address to the program, and the program can access the shared memory at this address.

We're going to focus on the three steps involving the ipc manager. Our function for creating a new shared memory region will look like the following:

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

    shared_mem->physical_base = pmm_alloc(length / PAGE_SIZE);

    acquire(list_lock);
    ipc_shared_memory* tail = list;
    while (tail->next != NULL)
        tail = list->next;

    tail->next = shared_mem;
    release(list_lock);

    return shared_mem->physical_base;
}
```

This code is the core to implementing shared memory, it allows us to create a new shared memory region and gives us its physical address. The VMM can then map this physical address into the memory space of the process like it would do with any other memory.

Notice the use of the lock functions (`acquire` and `release`) when we access the linked list. Since this single list is shared between all processes that use shared memory, we have to protect it so we don't accidentally corrupt it. This is discussed further in the chapter on scheduling.

### Accessing Shared Memory

We've successfully created shared memory in one process, now the next step is allowing another process to access it. Since each instance of shared memory has a name, we can search for an instance this way. Once we've found the correct instance it's a matter of returning the physical address and length, so the VMM can map it. We're going to return a pointer to the `ipc_shared_memory` struct itself, but in reality you only need the base and length fields.

Here's our example function:

```c
ipc_shared_memory* access_shared_memory(const char* name) {
    ipc_shared_memory* found = list;
    acquire(list_lock);

    while (found != NULL) {
        if (strcmp(name, found->name) == 0) {
            release(list_lock);
            return found;
        }
        found = found->next;
    }
    release(list_lock);
    return NULL;
}
```

At this point all that's left is to modify the virtual memory manager to support shared memory. This is usually done by allowing certain flags to be passed when calling `vmm_alloc` or equivalent functions.

An example of how that might look:

```c
#define VM_FLAG_SHARED  (1 << 0)

void* vmm_alloc(size_t length, size_t flags) {
    uintptr_t phys_base = 0;
    if (flags & VM_FLAG_SHARED)
        phys_base = access_shared_memory("examplename")->physical_base;
    else
        phys_base = pmm_alloc(length / PAGE_SIZE);

    //the rest of the this function can look as per normal.
}
```

We've glossed over a lot of the implementation details here, like how you pass the name of the shared memory to the ipc manager. You could add an extra argument to `vmm_alloc`, or have a separate function entirely. The choice is yours. Traditionally functions like this accept a file descriptor, and the filename associated with that descriptor is used, but feel free to come up with your own solution.

If you're following the VMM design explained in the memory management chapter, you can use the extra argument to pass this information.

### Potential Issues

There's a few potential issues to be aware of with shared memory. The biggest one is to be careful when writing data that contains pointers. Since each process interacting with shared memory may see the shared physical memory at a different virtual address, any pointers you write here may not be valid.

Best practice is to store data *relative to the base*, this way each process can read the pointer from the shared memory, and add its own virtual offset. Alternatively it can be better to not use pointers inside of shared memory at all, and instead use opaque objects like resource handles or file descriptors.

Another problem that may arise is your compiler optimizing away reads and writes to the shared memory. This can happen because the compiler sees these memory accesses are having no effect on the rest of the program. This is the same issue you might have experienced with MMIO (memory mapped io) devices, and the solution is the same: make any reads or write `volatile`.

### Cleaning Up

At some point our programs are going to exit, and when they do we'll want to reclaim any memory they were using. We mentioned using reference counting to prevent use-after-free bugs with shared memory, so let's take a look at that in practice.

Again, this assumes your vmm has some way of knowing which regions of allocated virtual memory it owns, and which regions are shared memory. For our example we've stored the `flags` field used with `vmm_alloc`.

```c
void vmm_free(void* addr) {
    size_t flags = vmm_get_flags(addr);
    uintptr_t phys_addr = get_phys_addr(addr);

    if (flags & VMM_FLAG_SHARED_MEMORY)
        free_shared_memory(phys_addr);
    else
        pmm_free(phys_addr, length / PAGE_SIZE);

    //do other vmm free stuff, like adjusting page tables.
}
```

The `vmm_get_flags` is a made up function, it just returns the flags used for a particular virtual memory allocation, we also use a function to manually walk the page tables and get the physical address mapped to this virtual address (`get_phys_addr`). For details on how to get the physical address mapped to a virtual one, see the section on paging.

That's the VMM modified, but what does `free_shared_memory` do? As mentioned before, it will decrement the reference count by 1, and if the count is set to 0, we free the physical pages.

```c
void free_shared_memory(void* phys_addr) {
    ipc_shared_memory* found = list;
    ipc_shared_memory* prev = NULL;
    acquire(list_lock);

    while (found != NULL) {
        if (strcmp(name, found->name) == 0) {
            release(list_lock);
            found = list;
        }
        prev = found;
        found = next;
    }

    found->ref_count--;
    if (found->ref_count == 0) {
        pmm_free(found->physical_base, found->length / PAGE_SIZE);
        free(found->name);
        if (prev == NULL)
            list = found->next;
        else
            prev->next = found->next;
        free(found);
    }
    release(list_lock);
}
```

Again we've omitted error handling and checking for `NULL` to keep the examples concise, but you should handle these cases in your code. The first part of the function should look similar, it's the same code used in `access_shared_memory`. The interesting part happens when the reference count reaches zero: we free the physical pages used, and free any memory we previously allocated. We also remove the shared memory instance from the linked list.

## Interesting Applications

Most applications will default to using message passing (in the form of a pipe) for their IPC, but shared memory is a very simple and powerful alternative. Its biggest advantage is that no intervention from the kernel is required during runtime: multiple processes can exchange data at their own pace, quite often faster than you could with message passing, as there are less context switches to the kernel.

More commonly a hybrid approach is taken, where processes will write into shared memory, and if a receiving process doesn't check it for long enough, the sending process will invoke the kernel to send a message to the receiving process.

## Access Protection

It's important to keep in mind that we have no access protection in this example. Any process can view any shared memory if it knows the correct name. This is quite unsafe, especially if you're exchanging sensitive information this way. Commonly shared memory is presented to user processes through the virtual file system (we'll look at this more later), this has the benefit of being able to use the access controls of the VFS for protecting shared memory as well.

If you choose not to use the VFS, you will want to implement your own access control.

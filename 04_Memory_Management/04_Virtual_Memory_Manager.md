# Virtual Memory Manager

## An Overview

At first a virtual memory manager might not seem like necessary when we have paging, but the VMM serves as an abstraction on top of paging (or whatever memory management hardware our platform has), as well as abstracting away other things like memory mapping files or even devices.

As mentioned before, a simple kernel only requires a simple VMM which may end up being a glorified page-table manager. However as our kernel grows more complex, so will the VMM.

### Virtual Memory

What exactly does the virtual memory manager *manage*? The PMM manages the physical memory installed in a computer, so it would make sense that the VMM manages the virtual memory. What do we mean by virtual memory?

Once we have some kind of address translation enabled, all memory we can access is now virtual memory. This address translation is usually performed by the MMU (memory management unit) which we can program in someway. On `x86_64` the MMU parses the page tables we provide to determine what should happen during this translation.

Even if we create an identity map of physical memory (meaning virtual address = physical address) we're still accessing physical memory *through* virtual memory. This is subtle, but important difference.

Virtual memory can be imagined as how the program views memory, as opposed to physical memory which is how the rest of the hardware sees memory.

Now that we have a layer between how a program views memory and how memory is actually laid out, we can do some interesting things:

- Making all of physical memory available as virtual memory somewhere is a common use. You'll need this to be able to modify page tables. The common ways are to create an identity map, or to create an identity map but shift it into the higher half (so the lower half is free for userspace later on).
- Place things in memory at near-impossible addresses. Higher half kernels are commonly placed at -2GB as this allows for certain compiler optimizations. On a 64-bit machine -2GB is `0xFFFF'FFFF'8000'0000`. Placing the kernel at that address without virtual memory would require an insane amount of physical memory to be present. This can also be extended to do things like place MMIO at more convinient locations.
- We can protect regions of memory. Later on once we reach userspace, we'll still need the kernel loaded in virtual memory to handle interrupts and provide system calls, but we don't want the user program to arbitarily access kernel memory.

We can also add more advanced features later on, like demand paging. Typically when a program (including the kernel) asks the VMM for memory, and the VMM can successfully allocate it, physical memory is mapped there right away. *Immediately backing* like this has advantages in that it's very simple to implement, and can be very fast. The major downside is that we trust the program to only allocate what it needs, and if it allocates more (which is very common) that extra physical memory is wasted. In contrast, *demand paging* does not back memory right away, instead relying on the program to cause a page fault when it accesses the virtual memory it just allocated. At this point the VMM now backs that virtual memory with some physical memory, usually a few pages at a time (to save overhead on page-faults). The benefits of demand-paging are that it can reduce physical memory usage, but it can slow down programs if not implemented carefully. It also requires a more complex VMM, and the ability to handle page faults properly.

On the topic of advanced VMM features, it can also do other things like caching files in memory, and then mapping those files into the virtual address space somewhere (this is what the `mmap` system call does).

A lot of these features are not needed in the beginning, but hopefully the uses of a VMM are clear. To answer the original question of what a VMM does: it's a virtual address space manager and allocator.

## Concepts

As it might be expected, there are many VMM designs out there. We're going to look at a simple one that should provide all the functionality needed for now.
First we'll need to introduce a new concept: a *virtual memory object*, sometimes called a *virtual memory range*. This is just a struct that represents part of the virtual address space, so it will need a base address and length, both of these are measured in bytes and will be page-aligned. This requirement to be page-aligned comes from the mechanism used to manage virtual memory: paging. On `x86` the smallest page we can manage is `4K`, meaning that all of our VM objects must be aligned to this.

In addition we might want to store some flags in the *vm object*, they are like the flags used in the page tables, we could technically just store them there, but having them as part of the object makes looking them up faster, since we don't need to manually traverse the paging structure. It also allows us to store flags that the are not relevant to paging.

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

The `flags` field is actually a bitfield, and we've defined some macros to use with it.

These don't correspond to the bits in the page table, but having them separate like this means they are platform-agnostic. We can port our kernel to any cpu architecture that supports some kind of MMU and most of the code won't need to change, we'll just need a short function that converts our vm flags into page table flags. This is especially convenient for oddities like `x86` and its ` nx-bit`, where all memory is executable by default, and it must specified if the memory *don't* want to be executable.

Having it like this allows that to be abstracted away from the rest of our kernel. For `x86_64` our translation function would look like the following:

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

The `PT_xyz` macros are just setting the bits in the page table entry, for specifics see the *paging chapter*. Notice how we set the NX-bit if `VM_FLAG_EXEC` is not set because of a quirk on `x86`.

We're going to store these *vm objects* as a linked list, which is the purpose of the `next` field.

### How Many VMMs Is Enough?

Since a virtual memory manager only handles a single address space, we'll need one per address space we wish to have. This roughly translates to one VMM per running program, since each program should live in its own address space. Later on when we implement scheduling we'll see how this works.

The kernel is a special case since it should be in all address spaces, as it always needs to be loaded to manage the underlying hardware of the system.

There are many ways of handling this, one example is to have a special kernel VMM that manages all higher half memory, and have other VMMs only manage the lower memory for their respective program. In this design we have a single higher half VMM (for the kernel), and many lower-half VMMs. Only one lower half VMM is active at a time, the one corresponding to the running program.

### Managing An Address Space

This is where design and reality collide, because our high level VMM needs to program the MMU. The exact details of this vary by platform, but for `x86(_64)` we have paging! See the previous chapter on how x86 paging works. Each virtual memory manager will need to store the appropriate data to manage the address space it controls: for paging we just need the address of the root table.

```c
void* vmm_pt_root;
```

This variable can be placed anywhere, this depend on our design decisions, there is not correct answer, but a good idea is to reserve some space in the VM space to be used by the VMM to store its data. Usually a good idea is to place this space somewhere in the higher half area probably anywhere below the kernel.

Once we got the address, this needs to be mapped to an existing physical address, so we will need to do two things:

* Allocate a physical page for the `vmm_pt_root` pointer (at this point a function to do that should be present)
* Map the phyiscal address into the virtual address `vmm_pt_root`.

It is important to keep in mind that the all the addresses must be page aligned.

## Allocating Objects

Now we know what a VM object is, let's look at how we're going to create them.

We know that a VM object represents an area of the address space, so in order to create a new one we'll need to search through any existing VM objects and find enough space to hold our new object. In order to find this space we'll need to know how many bytes to allocate, and what flags the new VM object should have.

We're going to create a new function for this. Our example function is going to have the following prototype:

```c
void* vmm_alloc(size_t length, size_t flags, void* arg);
```

The `length` field is how many bytes we want. Internally we will round this **up** to the nearest page size, since everything must be page-aligned. The `flags` field is the same bitfield we store in a VM object, it contains a description of the type of memory we want to allocate.

The final argument is unused for the moment, but will be used to pass data for more exotic allocations. We'll look at an example of this later on.

The function will return a virtual address, it doesn't have necessarily to be already mapped and present, it just need to be an available address. Again the question is: where is that address? The answer again is that it depends on the design decisions. So we need to decide where we want the virtual memory range to be returned is, and use it as starting address. It can be the same space used for the vmm data strutctures, or another area, that is up to us, of course this decision will have an impact on the design of the algorithm.

For the example code we're going to assume we have a function to modify page tables that looks like the following:

```c
void map_memory(void* root_table, void* phys, void* virt, size_t flags);
```

And that there is a variable to keep track of the head of the linked list of objects:

```c
vm_object* vm_objs = NULL;
```

Now onto our alloc function. The first thing it will need to do is align the length up to the nearest page. This should look familiar.

```c
length = ((length + PAGE_SIZE - 1) / PAGE_SIZE) * PAGE_SIZE;
```

The next step is to find a space between two VM objects big enough to hold `length` bytes. We'll also want to handle the edge cases of allocating before the first object, after the last object, or if there are no VM objects in the list at all (not covered in the example below, they are left as exercise).

```c
vm_object* current = vm_objs;
vm_object* prev = NULL;
uintptr_t found = 0;

while (current != NULL) {
    if (current == NULL)
        break;

    uintptr_t base = (prev == NULL ? 0 : prev->base);
    if (base + length < current->base) {
        found = base;
        break;
    }

    prev = current;
    current = current->next;
}
```

This is where the bulk of our time allocating virtual address space will be spent, so it could probably be wise in giving some thought  designing this function for the VMM. We could keep allocating after the last item until address space becomes limited, and only then try allocating between objects, or perhaps another allocation strategy.

The example code above focuses on being simple and will try to allocate at the lowest address it can first.

Now that a place for the new VM object has been found, the new object should be stored in the list.

```c
vm_object* latest = malloc(sizeof(vm_object));

if (prev == NULL)
    vm_objs = latest;
else
    prev->next = latest;
latest->next = current;
```

What happens next depends on the design of the VMM. We're going to use immediate backing to keep things simple, meaning we will immedately map some physical memory to the virtual memory we've allocated.

```c
    //immediate backing: map physical pages right away.
    void* pages = pmm_alloc(length / PAGE_SIZE);
    map_memory(vmm_pt_root, pages, (void*)obj->base, convert_x86_64_vm_flags(flags));

    return obj->base;
}
```

We're not handling errors here to keep the focus on the core code, but they should be handled in a real implementation. There is also the caveat of using `malloc()` in the VMM. It  may run before the heap is initialized, in which case another way to allocate memory for the VM objects is needed. Alternatively if the heap exists outside of the VMM, and is already set up at this point this is fine.

### The Extra Argument

What about that extra argument that's gone unused? Right now it serves no purpose, but we've only looked at one use of the VMM: allocating working memory.

Working memory is called anonymous memory in the unix world and refers to what most programs think of as just 'memory'. It's a temporary data store for while the program is running, it's not persistent between runs and only the current program can access it. Currently this is all our VMM supports.

The next thing we should add support for is mapping MMIO (memory mapped I/O). Plenty of modern devices will expose their interfaces via mmio, like the APICs, PCI config space or NVMe controllers. MMIO is usually some physical addresses we can interact with, that are redirected to the internal registers of the device. The trick is that MMIO requires us to access *specific* physical addresses, see the issue with our current design?

This is easily solved however! We can add a new `VM_FLAG` that specifies we're allocating a virtual object for MMIO, and pass the physical address in the extra argument. If the VMM sees this flag, it will know not to allocate (and later on, not to free) the mapped physical address. This is important because there's not any physical memory there, so we don't want to try free it.

Let's add our new flag:

```c
#define VM_FLAG_MMIO (1 << 3)
```

Now we'll need to modify `vmm_alloc` to handle this flag. We're going to modify where we would normally back the object with physical memory:

```c
//immedate backing: map physical pages right away.
void* phys = NULL;
if (flags & VM_FLAG_MMIO)
    phys = (void*)arg;
else
    phys = pmm_alloc(length / PAGE_SIZE);
map_memory(vmm_pt_root, phys, (void*)obj->base, convert_x86_64_vm_flags(flags));
```

Now we have check for whether an object is MMIO or not. If it is, we don't allocate physical memory to back it. Instead we just modify the page tables to point to the physical address we want it too.

At this point our VMM can allocate any object types we'll need for now, and hopefully we can start to see the purpose of the VMM.

As mentioned previously a more advanced design could allow for memory mapping files: by adding another flag, and passing the file name (as a `char*`) in the extra argument, or perhaps a file descriptor (like `mmap` does).

## Freeing Objects

We've looked at allocating virtual memory, how about freeing it? This is quite simple! To start with, we'll need to find the VM object that represents the memory we want to free: this can be done by searching through the list of objects until we find the one we want.

If we don't find a VM object with a matching base address, something has gone wrong and error for debugging should be emitted. Otherwise the VM object can be safely removed from the linked list.

At this point the object's flags need to be inspected to determine how to handle the physical addresses that are mapped. If the object represents MMIO, it will only need to remove the mappings from the page tables. If the object is working (anonymous) memory, which is indicated by the `VM_FLAG_MMIO` bit being cleared, the physical addresses in the page tables are page frames. The physical memory manager should be informed that these frames are now free after removing the mappings.

We're leaving the implementation of this function up to the reader, but it's prototype would like something like:

```c
void vmm_free(void* addr);
```

## Workflow

Now that we have a virtual memory manager, let's take a look at how we might use it:

### Example 1: Allocating A Temporary Buffer

Traditionally `malloc()` or a variable-length array for something like this should be used. However there isn't a heap yet (see the next chapter), and allocating from the VMM directly like this gives few guarentees, we might want, like the memory always being page-aligned.

```c
void* buffer = vmm_alloc(buffer_length, VM_FLAG_WRITE, NULL);
//buffer now points to valid memory we can use.

//... sometime later on, we free the virtual memory.
vmm_free(buffer);
buffer = NULL;
```

Usually this is used by the heap allocator to get the memory it needs, and it will take care of allocating more appropriately sized chunks.

### Example 2: Accessing MMIO

The local APIC is a device accessed via MMIO. Its registers are *usually* located at the physical address `0xFEE00000`, and that's what we're going to use for this example. **In the real world this address should be obtained from the model specific register (MSR) instead of hardcoding it (in x86 architectures).**

If not familiar with what the local APIC is, it's a device for handling interrupts on x86, see the relevant chapter for more detail. All needed to know for this example  is that it has a 4K register space at the specified physical address.

Since we know the physical address of the MMIO, we want to map this into virtual memory to access it. We could do this by directly modifying the page tables, but we're going to use the VMM.

```c
const size_t flags = VM_FLAG_WRITE | VM_FLAG_MMIO;
void* lapic_regs = vmm_alloc(0x1000, flags, (void*)0xFEE0'0000);
//now we can access the lapic registers at this virtual address
```

## Next Steps

We've looked a basic VMM implementation, and discussed some advanced concepts too, but there are some good things that should be implemented sooner rather than later:

- A function to get the physical address (if any) of a virtual address. This is essentially just walking the page tables in software, with extra logic to ensure a VM object exists at that address. We could add the ability to check if a VM object has specific flags as well.
- A way to copy data between separate VMMs (with separate address spaces). There are a number of ways to do this, it can be an interesting problem to solve. We'll actually look at some roundabout ways of doing this later on when we look at IPC.
- Cleaning up a VMM that is no longer in use. When a program exits, we'll want to destroy the VMM associated with it to reclaim some memory.
- Adding upper and lower bounds to where `vmm_alloc` will search. This can be useful for debugging, or it want to a split higher half VMM/lower half VMM design like mentioned previously.

## Final Notes

As mentioned above all the memory accessed is virtual memory at this point, so unless there is a specific reason to interact with the PMM it can be best to deal with the VMM instead. Then let the VMM manage the physical memory it may or may not need.

Of course there will be cases where this is not possible, and there are valid reasons to allocate physical memory directory (DMA buffers for device drivers, for example), but for the most part the VMM should be the interface to interact with memory.

This VMM design that was explained here is based on a stripped-down version of the Solaris VMM. It's very well understood and there is plenty of more in depth material out there if interested in exploring further. The original authors have also published several papers on the topic.

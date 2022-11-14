# Virtual Memory Manager

## An Overview

At first a virtual memory manager might not seem like necessary when we have paging, but the VMM serves as an abstraction on top of paging (or whatever memory management hardware your platform has), as well as abstracting away other things like memory mapping files or even devices.

As mentioned before, a simple kernel only requires a simple VMM which may end up being a glorified page-table manager. However as your kernel grows more complex, so will your VMM.

### Virtual Memory

What exactly does the virtual memory manager *manage*? The PMM manages the physical memory installed in a computer, so it would make sense that the VMM manages the virtual memory. What do we mean by virtual memory?

Once we have some kind of address translation enabled, all memory we can access is now virtual memory. This address translation is usually performed by the MMU (memory management unit) which we can program in someway. On x86_64 the MMU parses the page tables we provide to determine what should happen during this translation.

Even if you create an identity map of physical memory (meaning virtual address = physical address) you're still accessing physical memory *through* virtual memory. This is subtle, but important difference.

You can think of virtual memory as how the program views memory, as opposed to physical memory which is how the rest of the hardware sees memory.

Now that we have a layer between how a program views memory, we can do some interesting things:

- Making all of physical memory available as virtual memory somewhere is a common use. You'll need this to be able to modify page tables. The common ways are to create an identity map, or to create an identity map but shift it into the higher half (so the lower half is free for userspace later on).
- Place things in memory at near-impossible addresses. Higher half kernels are commonly placed at -2GB as this allows for certain compiler optimizations. On a 64-bit machine -2GB is `0xFFFF'FFFF'8000'0000`. Placing the kernel at that address without virtual memory would require an insane amount of physical memory to be present. This can also be extended to do things like place MMIO at more convinient locations.
- We can protect regions of memory. Later on once we reach userspace, we'll still need the kernel loaded in virtual memory to handle interrupts and provide system calls, but we don't want the user program to arbitarily access kernel memory.

We can also add more advanced features later on, like demand paging. Typically when a program (including the kernel) asks the VMM for memory, and the VMM can successfully allocate it, physical memory is mapped there right away. *Immediately backing* like this has advantages in that it's very simple to implement, and can be very fast. The major downside is that we trust the program to only allocate what it needs, and if it allocates more (which is very common) that extra physical memory is wasted. In contrast, *demand paging* does not back memory right away, instead relying on the program to cause a page fault when it accesses the virtual memory it just allocated. At this point the VMM now backs that virtual memory with some physical memory, usually a few pages at a time (to save overhead on page-faults). The benefits of demand-paging are that it can reduce physical memory usage, but it can slow down programs if not implemented carefully. It also requires a more complex VMM, and the ability to handle page faults properly.

On the topic of advanced VMM features, you can also do other things like caching files in memory, and then mapping those files into the virtual address space somewhere (this is what the `mmap` system call does).

A lot of these features are not needed in the beginning, but hopefully the uses of a VMM are clear. To answer the original question of what a VMM does: it's a virtual address space manager and allocator.

## Concepts

As you might expect, there are many VMM designs out there. We're going to look at a simple one that should provide all the functionality needed for now.
First we'll need to introduce a new concept: a *virtual memory object*, sometimes called a *virtual memory range*. This is just a struct that represents part of the virtual address space, so it will need a base address and length, both of these are measured in bytes and will be page-aligned. This requirement to be page-aligned comes from the mechanism used to manage virtual memory: paging. On x86 the smallest page we can manage is 4K, meaning that all of our VM objects must be aligned to this.

We'll also want to store some flags that describe the memory the object represents: is it writable? is it user accessible? is it an ipc buffer?

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

The `flags` field is actually a bitfield, and we've defined some macros to use with it. 

These don't correspond to the bits in the page table, but having them separate like this means they are platform-agnostic. We can port our kernel to any cpu architecture that supports some kind of MMU and most of the code won't need to change, we'll just need a short function that converts our vm flags into page table flags. This is especially convinient for oddities like x86 and it's nx-bit, where all memory is executable by default, and you must specify if you *don't* want it to be executable. 

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

### How Many VMMs Is Enough?

Since a virtual memory manager only handles a single address space, you'll need one per address space you wish to have. This roughly translates to one VMM per running program, since each program should live in it's own address space. Later on when we implement scheduling you'll see how this works. 

The kernel is a special case since it should be in all address spaces, as it always needs to be loaded to manage the underlying hardware of the system.

There are many ways of handling this, one example is to have a special kernel VMM that manages all higher half memory, and have other VMMs only manage the lower memory for their respective program. In this design you have a single higher half VMM (for the kernel), and many lower-half VMMs. Only one lower half VMM is active at a time, the one corresponding to the running program.

### Managing An Address Space

This is where design and reality collide, because our high level VMM needs to program the MMU. The exact details of this vary by platform, but for x86(_64) we have paging! See the previous chapter on how x86 paging works. Each virtual memory manager will need to store the appropriate data to manage the address space it controls: for paging we just need the address of the root table.

```c
void* vmm_pt_root;
```

## Allocating Objects

Now we know what a VM object is, let's look at how we're going to create them.

We know that a VM object represents an area of the address space, so in order to create a new one we'll need to search through any existing VM objects and find enough space to hold our new object. In order to find this space we'll need to know how many bytes to allocate, and what flags the new VM object should have.

As you might have expected, we're going to create a new function for this. Our example function is going to have the following prototype:

```c
void* vmm_alloc(size_t length, size_t flags, void* arg);
```

The `length` field is how many bytes we want. Internally we will round this **up** to the nearest page size, since everything must be page-aligned. The `flags` field is the same bitfield we store in a VM object, it contains a description of the type of memory we want to allocate.

The final argument is unused for the moment, but will be used to pass data for more exotic allocations. We'll look at an example of this later on.

For the example code we're going to assume you have a function to modify page tables that looks like the following:

```c
void map_memory(void* root_table, void* phys, void* virt, size_t flags);
```

And that you have a variable to keep track of the head of our linked list of objects:

```c
vm_object* vm_objs = NULL;
```

Now onto our alloc function. The first thing it will need to do is align the length up to the nearest page. This should look familiar.

```c
length = (length + (PAGE_SIZE - 1)) / PAGE_SIZE * PAGE_SIZE;
```

The next step is to find a space between two VM objects big enough to hold `length` bytes. We'll also want to handle the edge cases of allocating before the first object, after the last object, or if there are no VM objects in the list at all.

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

This is where the bulk of your time allocating virtual address space will be spent, so you may want to give some thought to designing this function for your own VMM. You could keep allocating after the last item until address space becomes limited, and only then try allocating between objects, or perhaps another allocation strategy.

The example code above focuses on being simple and will try to allocate at the lowest address it can first. 

Now we have found a place for the new VM object, we'll want to store the new object in the list.

```c
vm_object* latest = malloc(sizeof(vm_object));

if (prev == NULL)
    vm_objs = latest;
else
    prev->next = latest;
latest->next = current;
```

What happens next depends on your the design of your VMM. We're going to use immediate backing to keep things simple, meaning we will immedately map some physical memory to the virtual memory we've allocated.

```c
    //immedate backing: map physical pages right away.
    void* pages = pmm_alloc(length / PAGE_SIZE);
    map_memory(vmm_pt_root, pages, (void*)obj->base, convert_x86_64_vm_flags(flags));
    
    return obj->base;
}
```

We're not handling errors here to keep the focus on the core code, but you should handle those in your implementation. There is also the caveat of using `malloc()` in your VMM. Your VMM may run before your heap is initialized, in which case you will need another way to allocate memory for your VM objects. Alternatively if your heap exists outside of your VMM, and is already set up at this point this is fine.

### The Extra Argument

What about that extra argument that's gone unused? Right now it serves no purpose, but we've only looked at one use of the VMM: allocating working memory. 

Working memory is called anonymous memory in the unix world and refers to what most programs think of as just 'memory'. It's a temporary data store for while the program is running, it's not persistent between runs and only the current program can access it. Currently this is all our VMM supports.

The next thing we should add support for is mapping MMIO (memory mapped I/O). Plenty of modern devices will expose their interfaces via mmio, like the APICs, PCI config space or NVMe controllers. MMIO is usually some physical addresses we can interact with, that are redirected to the internal registers of the device. The trick is that MMIO requires us to access *specific* physical addresses, see the issue with our current design?

This is easily solved however! We can add a new `VM_FLAG` that specifies we're allocating a virtual object for MMIO, and pass the physical address in the extra argument. If the VMM sees this flag, it will know not to allocate (and later on, not to free) the mapped physical address. This is important because there's not any physical memory there, so we dont want to try free it.

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

At this point our VMM can allocate any object types we'll need for now, and hopefully you can start to see the purpose of the VMM.

As mentioned previously a more advanced design could allow for memory mapping files: by adding another another flag, and passing the file name (as a `char*`) in the extra argument.

## Freeing Objects

Let's looking at how we would free a VM object, and what would happen.

`void vmm_free(void* addr)`

## Workflow

Now that we have a virtual memory manager, let's take a look at how we might use it:

### Example 1: Allocating A Temporary Buffer

Traditionally you would use `malloc()` or a variable-length array for something like this. However we don't have a heap yet (see the next chapter), and allocating from the VMM directly like this gives us a few guarentees we might want, like the memory always being page-aligned.

```c
void* buffer = vmm_alloc(buffer_length, VM_FLAG_WRITE, NULL);
//buffer now points to valid memory we can use.

//... sometime later on, we free the virtual memory.
vmm_free(buffer);
buffer = NULL;
```

Usually this is used by the heap allocator to get the memory it needs, and it will take care of allocating more appropriately sized chunks.

### Example 2: Accessing MMIO

The local APIC is a device accessed via MMIO. It's registers are *usually* located at the physical address `0xFEE0'0000`, and that's what we're going to use for this example. **In the real world you should get this address from the model specific register (MSR) instead of hardcoding it.**

If you're not familiar with what the local APIC is, it's a device for handling interrupts on x86, see the relevant chapter for more detail. All you need to know is that it has a 4K register space at the specified physical address.

Since we know the physical address of the MMIO, we want to map this into virtual memory to access it. We could do this by directly modifying the page tables, but we're going to use the VMM. 

```c
const size_t flags = VM_FLAG_WRITE | VM_FLAG_MMIO;
void* lapic_regs = vmm_alloc(0x1000, flags, (void*)0xFEE0'0000);
//now we can access the lapic registers at this virtual address
```

## Next Steps

We've looked a basic VMM implementation, and discussed some advanced concepts too, but there are some good things you could implement sooner rather than later:

- A function to get the physical address (if any) of a virtual address. This is essentially just walking the page tables yourself in software, with extra logic to ensure a VM object exists at that address. You could add the ability to check if a VM object has specific flags as well.
- A way to copy data between separate VMMs (with separate address spaces). There are a number of ways to do this, it can be an interesting problem to solve. We'll actually look at some roundabout ways of doing this later on when we look at IPC.
- Cleaning up a VMM that is no longer in use. When a program exits, you'll want to destroy the VMM associated with it to reclaim some memory. It's very easy to run into issues here as you will want to free the pages used by the VMM management structures, and the page tables. How would you do this?
- Adding upper and lower bounds to where `vmm_alloc` will search. This can be useful for debugging, or it want to a split higher half VMM/lower half VMM design like mentioned previously.

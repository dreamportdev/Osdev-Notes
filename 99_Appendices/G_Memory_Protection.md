# Memory Protection

This appendix is a collection of useful strategies for memory protection. This mainly serves as a reminder that these features exist, and are worth looking into!

## WP bit

On `x86_*` platforms, we have the R/W bit in our page tables. This flag must be enabled in order for a page to be written to, otherwise the page is read-only (assuming the page is present at all).

However this is not actually true! Supervisor accesses (rings 0/1/2 - not ring 3) *can* write to readonly pages by default. This is not as bad as it might seem, as the kernel is usually carefully crafted to only access the memory it needs. However when we allow user code to access the kernel (via system calls for example), the kernel can be 'tricked' into writing into areas it wouldn't normally, via software or hardware bugs.

One helpful mitigation for this is to set the WP bit, which is bit 16 of cr0. Once written to cr0, *any* attempts to write to a read-only page will generate a page fault, like a user access would.

## SMAP and SMEP

Two separate features that serve similar enough purposes, that they're often grouped together.

SMEP (Supervisor Memory Execute Protection) checks that while in a supervisor ring the next instruction isn't being fetched from a user page. If the cpu sees that the cpl < 3 and the instruction comes from a user page, it will generate a page fault, allowing the kernel to take action.

SMAP (Supervisor Memory Access Protection) will generate a page fault if the supervisor attempts to read or write to a user page. This is quite useful, but it brings up an interesting problem: how do the kernel and userspace programs communicate now? Well the engineers at Intel thought of this, and have repurposed the AC (alignment check) bit in the flags register. When AC is cleared, SMAP is active and will generate faults. When AC is set SMAP is temporarily disabled and supervisor rings can access user pages until AC is cleared again. Like most of the other flag bits, AC has dedicated instructions to set (`stac`) and clear (`clac`) it.

Support for SMEP can be checked via cpuid, specifically leaf 7 (sub-leaf 0) bit 7 of the ebx register. SMAP can be checked for via leaf 7 (sub-leaf 0) bit 20 of ebx.
These features were not introduced at the same time, so it's possible to find a cpu that supports one and not the other. Futhermore, they were introduced relatively recently (2014-2015), so unlike other features (NX for example) they can't safely be assumed to be supported.

*Authors Note: Some leaves of cpuid have multiple subleaves, and the subleaf must be explicitly specified. I ran into a bug while testing this where I didn't specify that the subleaf was 0, and instead the last value in rax was used. The old phrase 'garbage in, garbage out' holds true here, and cpuid returned junk data. Be sure to set the subleaf!*

Once these features are known to be supported, they can be enabled like so:

- SMAP: set bit 21 in CR4.
- SMEP: set bit 20 in CR4.

## Page Heap

Unlike the previous features which are simple feature flags, this is a more advanced solution. It's really focused on detecting buffer overruns: when too much data is written to a buffer, and the data ends up writing into the next area of memory. This section assumes we're comfortable writing memory allocators, and familiar with how virtual memory works. It's definitely an intermediate topic, one worth being aware of though!

Now while this technique is useful for tracking down a rogue memcpy or memset, it does waste quite a lot of physical memory and virtual address space, as will be shown. Because of this it's useful to be able to swap this with a more traditional allocator for when debugging featuresi are not needed.

A page heap (named after the original Microsoft tool), is a heap where each allocator is rounded up to the nearest page. This entire memory region is dedicated to this allocation, and the two pages either side of the allocation are unmapped. The memory region is padded at the beginning, so that the last byte of the allocated buffer is the last byte of the last mapped page.

This means that when we attempt to read or write beyond the end of the array, we cause a page fault! Now is possible to track any buffer overruns from inside the page fault handler. If the kernel doesn't have any page fault handling logic yet, it can simply panic and print the faulting address, and using this information to track down the overrun.

What about buffer underruns? This is even easier!

Instead of padding the memory region at the beginning, pad it at the end. The code will just end up returning the first byte of the first page, and now any attempts to access data before the buffer will trigger a page fault like before. Unfortunately underruns and overruns cannot be detected with a single page heap.

Now that's a lot of words, let's have a look at a quick example of how it might work:

- A program wants to allocate 3500 bytes.
- The heap gets called (via `malloc` or similar), and rounds this up to the nearest page: 4096 bytes.
- Now we map these pages at an address of our choosing, selecting this address is outside the scope of this section.
- If we're wanting to detect buffer underruns, simply return the base of the first page. Otherwise keep going.
- To detect buffer overruns we need to pad at the beginning, so we could return the address of the first page + the difference from before.

An example in c might look like (note these functions are made up for the example, and must be implemented yourself):

```c
void* page_heap_alloc(size_t size, bool detect_overrun) {
    const size_t pages_required = (size / PAGE_SIZE_IN_BYTES) + 1;
    void* pages = pmm_alloc_pages(pages_required);
    uint64_t next_alloc_address = get_next_addr();

    //unmap either side of region
    vmm_ensure_unmapped(next_alloc_address - PAGE_SIZE_IN_BYTES);
    vmm_ensure_unmapped(next_alloc_address + pages_required);
    vmm_map(next_alloc_address, pages);

    //if we don't want to detect overruns, detect underruns instead.
    if (!detect_overrun)
        return pages;

    return (void*)((uint64_t)pages + (pages_required * PAGE_SIZE_IN_BYTES - size));
}
```

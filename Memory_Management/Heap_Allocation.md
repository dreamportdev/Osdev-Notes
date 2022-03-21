# Heap Allocation 

## Introduction

Welcome to the last layer of memory allocation, the heap, this is where usually the vaorious alloc functions are implemented. This layer usually is built on top of the other memory levels/services (the physical memory, virtual memory, paging). 

Depending how the operating system is designed, this layer can return either physical or virtual addresses, for our purposes we will assume that the operating system has paging enabled and a basic virtual memory support, this means that our heap allocator will work with virtual addresses. 

What we are going to see in  this section is how to create an alloc and a free function, how to keep track of allocated address, and reetrieve them when it's time to release it.

### To avoid confusion

Heap is a term that has several meanings, so probably if coming from some computer science courses the first thing that will come to mind is the **Heap Data Structure**, that is a special tree with some special features, but that is a different heap. This term when used in a Memory Management/Osdev environment has a different meaning and it usually refers to the portion of memory where the _dynamically allocated_ memory resides (malloc...).

Of course this section will refer to the Osdev Heap...

## A quick recap of what allocating memory means

Again how a memory manager allocate memory deeply depends on its design and what it supports, for this section what we assume is that the operating system has a Physical Memory Manager, with Paging Enabled, and a heap to allocate memory, this design choice is good because it prepare the ground for when processes will be implemented to let them have their own address space. 

Under the assumptions above, what happens under the hood when we want to allocate some memory from the heap?

* The heap search for a suitable address if found returns it (in this case it stops there), and if it can't find any it will ask the VMM for more space
* The VMM will receive eventually the heap request and ask the PMM a suitable physical page to be allocated to the heap
* The PMM search for a suitable physical page to fullfill the VMM request, and if found return it to the VMM
* Once the VMM get the physical page it map it into the program virtual address space
* The heap will now return the required address to the program




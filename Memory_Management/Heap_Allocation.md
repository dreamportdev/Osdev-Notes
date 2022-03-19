# Heap Allocation 

## Introduction

Welcome to the last layer of memory allocation, the heap, this is where usually the vaorious alloc functions are implemented. This layer usually is built on top of the other memory levels/services (the physical memory, virtual memory, paging). 

Depending how the operating system is designed, this layer can return either physical or virtual addresses, for our purposes we will assume that the operating system has paging enabled and a basic virtual memory support, this means that our heap allocator will work with virtual addresses. 

What we are going to see in  this section is how to create an alloc and a free function, how to keep track of allocated address, and reetrieve them when it's time to release it.

### To avoid confusion

Heap is a term that has several meanings, so probably if coming from some computer science courses the first thing that will come to mind is the **Heap Data Structure**, that is a special tree with some special features, but that is a different heap. This term when used in a Memory Management/Osdev environment has a different meaning and it usually refers to the portion of memory where the _dynamically allocated_ memory resides (malloc...).

Of course this section will refer to the Osdev Heap...





# Memory Management

Welcome to one of the first big challenges of your osdev adventure. It is the first "complex" component that you have to implement, and in my opinion one of the most boring too!! 

So let's get started...

The shortest way to define a memory manager is that is a system that manage computer memory, and provide ways to dinamically allocate and free portions of it. 

The design and complexity of a memory manger can vary greatly, a lot depends on what the operating system will do and how it will be designed. For example if what we want is a single task os, with Paging not enabled, and no memory protection, probably it will be failry simple to implement. 

In this section we will try to cover a more common use case that is probably what nearly all modern operating system does, that is a 32/64 operating system with paging enabled, and a memory allocator for the kernel and one for the user space, in this way we will be able to cover more or less all the following topics: 

* Physical Memory manager
* Paging 
* Virtual Memory
* Memory Allocation

Don't worry we will try to keep it as simple as possible, using basic algorithms and try to explain all the grey areas... But stil it will be sometime hard to follow, you will prob

For every of the steps above there will be a dedicated section, while in this one we will try to explain the global picture. Before proceeding let's define briefly the concepts above (for in detail explanation please refer to their own sections): 

| | Description |
|-|-------------|
| Physical Memory Manager | The physical memory manager is repsonsible of allocating and freeing  the hardware memory available (usually ram) it usually allocate fixed size blocks of it|
| Paging | it introduce the concept of *Virtual memory* and *virtual addresses*, provides the OS with a bigger address space, it provide protection to the pages, and isolation | 
| Virtual memory manager | TBD |
| Memory allocator | it handles alloc/free request, in our scenario will handle virtual addresses usually we have a kernel allocator and a user allocator | 

Again the explanation above is just a short introduction to the concepts that will be implemented in their relevant sections. 

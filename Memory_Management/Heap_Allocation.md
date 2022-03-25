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

## Allocating and freeing memory

As many other OS component there are many different algorithm that are designed and implement to manage memory, everyone of them has it pros and cons, here we try to explain a simple and efficient algorithm based on linked lists. 

### Overview

A heap allocator usually exposes two main functions: 

* `void *alloc(size_t size);` To request memory of size bytes
* `void free(void *ptr);` To free previously allocated memory

In user space alloc and free are the well known `malloc()/free()` function. But an OS usueally doesn't have only a user space heap, but it has also a kernel space one many os call those functions `kmalloc()/kfree()`. 

So let's get started with describing the allocation algorithm. 

### Allocating memory

To start describing our allocation algorithm  let's start answering this question: "What does the heap allocator do?". 

Well the answer is, as we already know: it allocates memory, in bytes. If the program ask _X_ byte, the allocator will return an address point to an area of memory exactly of _X_ byts (well that is not exactly true, it can be little bit more, since there could be some minimum allocatable size). 

If we are writing an OS, we already know that the ram can be viewed as a very long array, where the index is the Memory Location Address. The allocator is returning this indexes. So the first thing we can see so far, is that we need to be able to keep track of the next available address. 

Let's start with a very simple example, assume that we have an address space of 100 bytes, nothing is allocated yet, and the program makes thhree consecutive alloc calls: 

```c
alloc(10);
alloc(3);
alloc(5);
```
Let's assume also that there is no minimum allocatable space. The initial situation of our ram is the following:

| 0000 | 0001| 0002 | ... | 0099 | 00100 |
|------|-----|------|-----|------|-------|
| cur  |     |      |     |      |       |

cur is the variable keeping track of the next address that can be returned and is initialized to 0, for this example.
Now when the `alloc(10)` is called, it is asking for a memory location of 10 bytes, since `cur = 0`, the address to return is 0, and the next available address will become: `cur + 10`. So now we have the following situation: 

| 0000 | 0001 | 0002 | ... |  0010  |  ... | 00100 |
|------|------|------|-----|--------|------|-------|
|  X   |  X   |  X   |     |  cur   |      |       |

Where `X` is just a marker to say that the addresses above are used now. Calling `alloc(3)`, the allocator will return the address currently pointed by ` cur = 10` and then move cur 3 bytes forward...

| 0000 | 0001 | 0002 | ... |  0010  | ... | 0013  | ... | 00100 |
|------|------|------|-----|--------|-----|-------|-----|-------|
|  X   |  X   |  X   |     |   X    |     | cur   |     |       |

Now the third alloc call is easy to imagine what is going to do, it can be done as an exercise.

Well what we have seen so far is already an Allocation algorithm, that we can easily implement: 

```c 
uint64_t cur_heap_position = 0; //This is just pseudocode in real word this will be a memory location 
void *first_alloc(size_t size) {
  uint64_t *addr_to_return = cur_heap_position;
  cur_heap_position+=size;
  return (void*) addr_to_return;
}
```

Congratulations! We have written our first allocator! It is called the **bump allocator**, but what about the free? That one is even easier, let's have a look at it: 

```c
void first_free(void *ptr) {
    return;
}
```

Yeah... that's right it's not an error. it is just doing nothing. Why? Because we are not keeping track of the allocated memory, so we can't just update the `cur_heap_position` variable with the address of ptr, because we don't know who is using the memory after ptr. So we are forced just to do nothing. 

Even if probably useless let's see what are the pros and cons of this approach: 

Pros:

* Is very time-efficient allocating memory is O(1), as well as "freeing" it. 
* It is also memory efficient, in fact there is no overhead at all, we just need a variable to keep track of the next free address. 
* It is very easy to implement, and probably it could be a good placeholder when we haven't developed a full memory manager yet, but we need some *malloc* like functions.
* Actually there is no fragmentation since there is no freeing! 

Of course the cons are probably pretty clear and make this algorithm pretty useless in most cases: 

* We don't free memory
* There is no way to traverse the heap, because we don't keep track of the allocations
* It will "eventually" finish the RAM sooner or later

But again it was a first good step into writing a memory allocator. 

The main problem of this algorithm is that we don't keep track of what we have allocated in the past so we are not able to free that memory when no longer used. 

Now let's try to build the new allocator starting from the one just implemented. The first thing to do is try to figure out what are the information we need to keep track of the previous allocations:

* Whenever we make an allocation we require x bytes of memory, so when we return the address, we know that the next free one will be at least at: `returned_address + x`  so we need to keep track of the allocation size
* Then we need a way to traversate the previously allocated addresses, for this we need just a pointer to the start of the heap, if we decide to keep track of the sizes. 

The problem is now: how to keep track of this information, for this example let's keep things extermely simple, and place the size just before the pointer, so whenever we make an allocation  we write the size to the address pointed by `cur_heap_position` and return the next address, so the code should look like this now:  

```c
uint8_t heap_start = 0;
uint8_t cur_heap_position = heap_start; //This is just pseudocode in real word this will be a memory location 

void *first_alloc(size_t size) {
  *cur_heap_position++=size;
  uint8_t *addr_to_return = cur_heap_position;
  cur_heap_position+=size;
  return (void*) addr_to_return;
}
```

This new function potentially fix one of the item we listed above, it can now let us to traversate the heap because we know that the heap has the following structure: 

| 0000 | 0001 | 0002 | 0003  | ... |  0010  | 0011 | 0013 | ... | 00100 |
|------|------|------|-------|-----|--------|------|------|-----|-------|
|  2   |  X   |  X   |   7   | ... |   X    | cur  |      | ... |       |

Where the number indicates the size of the allocated block. So  now if we want to iterate from the first to the last item allocated the code will looks like: 

```c
uint8_t *cur_pointer = start_pointer;
while(cur_pointer < cur_heap_pointer) {
  printf("Allocated address: size: %%d - 0x%x\n", *cur_pointer, cur_pointer+1);
  cur_pointer = cur_pointer + (*cur_pointer) + 1;
}
```

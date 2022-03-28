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
We assume also that there is no minimum allocatable space. The initial situation of our ram is the following:

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

Well what we have seen so far is already an Allocation algorithm, that we can easily implement (in all the following examples we use uint8_t for all the pointer, in a real executin scenario probably will be better to use a bigger size for that variable): 

```c 
uint8_t *cur_heap_position = 0; //This is just pseudocode in real word this will be a memory location 
void *first_alloc(size_t size) {
  uint8_t *addr_to_return = cur_heap_position;
  cur_heap_position= cur_heap_position + size;
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
uint8_t *heap_start = 0;
uint8_t *cur_heap_position = heap_start; //This is just pseudocode in real word this will be a memory location 

void *second_alloc(size_t size) {
  *cur_heap_position=size;
  cur_heap_position = cur_heap_position + 1;
  uint8_t *addr_to_return = cur_heap_position;
  cur_heap_position+=size;
  return (void*) addr_to_return;
}
```

This new function potentially fix one of the problems we listed above, it can now let us to traversate the heap because we know that the heap has the following structure: 

| 0000 | 0001 | 0002 | 0003  | ... |  0010  | 0011 | 0013 | ... | 00100 |
|------|------|------|-------|-----|--------|------|------|-----|-------|
|  2   |  X   |  X   |   7   | ... |   X    | cur  |      | ... |       |

> **_NOTE:_**  just to remind that the pointer is a uint8_t pointer, so when we are storing the size, the memeory cell pointed by cur_heap_position will be of type *uint8_t*, that means that in this example and the followings, the size stored can be maximum 255.

Where the number indicates the size of the allocated block, so in the example above there have been 2 memory allocations the first of 2 bytes and the second of 7 bytes. Now if we want to iterate from the first to the last item allocated the code will looks like: 

```c
uint8_t *cur_pointer = start_pointer;
while(cur_pointer < cur_heap_pointer) {
  printf("Allocated address: size: %%d - 0x%x\n", *cur_pointer, cur_pointer+1);
  cur_pointer = cur_pointer + (*cur_pointer) + 1;
}
```

But are we able to reclaim unused memory with this approach? The answer is no, because even if traversing we know the size of the area to reclaim, and we can reach it everytime from the start of the heap, there is no mechanism to mark this area as available, and if we set the size field to 0, we break the heap (all areas after the one we are trying to free will become unreachable).

So to solve this issue we need to keep track of a new information: the status of the block is it used or free? So now everytime we will make an allocation we will keep track of: 

* the allocated size 
* the status (free or used)

At this poin our new heap allocation will looks like: 
| 0000 | 0001 | 0002 | 0003  |  0004 | ... |  0011 | 0011 | 0013 | ... | 00100 |
|------|------|------|-------|-------|-----|-------|------|------|-----|-------|
|  2   |  U   |  X   |   7   |   U   | ... |   X   | cur  |      | ... |       |

Where U is just a label for a boolean-like variable (U = used = false, F = true = free). 

At this point we the first change we can do to our allocation function is add the new status variable just after the size: 

```c
#define USED 0
#define FREE 1

uint8_t *heap_start = 0;
uint8_t *cur_heap_position = heap_start; //This is just pseudocode in real word this will be a memory location 

void *third_alloc(size_t size) {
  *cur_heap_position=size;  
  cur_heap_position = cur_heap_position + 1;
  *cur_heap_position = USED;
  cur_heap_position = cur_heap_position + 1;
  uint8_t *addr_to_return = cur_heap_position;
  cur_heap_position+=size;
  return (void*) addr_to_return;
}
```

One thing that we should have noticed so far, is that for keep track of all those new information we are adding an overhead to our allocator, how big the overhead is depends on the variable type, but even if wee keep things small, using only `uint8_t` we have already added 2 bytes of overhead for every single allocation. 

The implementation above is not completed yet, since we don't have implemented a mechanism to reused the freed location but before adding this last piece let's talk about the free. 

Now we know that given a pointer `ptr` (previously allocated of course...) we know that `ptr - 1` is the status (and should be USED) and `ptr - 2` is the size, so the free is pretty easy so far: 

```c
void third_free(void *ptr) {
  if( *(ptr - 1) == USED ) {
    *(ptr - 1) = FREE;
  }
}
```

Yeah, that's it... we just need to change the status, and the allocator will be able to know whether the memory location is used or not.

To finish the new allocator, we need now to implement the mechanism to reuse the freed memory location, so how the new algorihtm works is when an allocation request is made: 

* First the alloc function will start from the start of the heap and traverse the heap from the start until the latest address allocated (the current end of the heap) looking for a chunk where it's size is greather than the requested size
* if found let's mark the size field as USED, the size doesn't need to be updated since it's not changing, so assuming that cur_pointer is pointing to the first medatata byte of the location to be returned (the size in our example) the code to update and return the current block will be pretty simple: 
```c
cur_pointer = cur_pointer + 1; //remember cur_pointer is pointing to the size byte, and is different from current_heap end
*cur_pointer = USED;
cur_pointer = cur_pointer + 1;
return cur_pointer;
```
there is no need to update the cur_heap_end, since it has not been touched. 

* In case nothing has been found this means that the current end of the heap has been reached so in this case it will first add the two metadata bytes with the requested size, and the status (set to USED) then return the next address. Assuming that in this case `cur_pointer == cur_heap_position`:

```c
*cur_pointer = size;
cur_pointer = cur_pointer + 1;
*cur_pointer = USED;
cur_pointer = cur_pointer + 1;
cur_heap_position = cur_pointer + size;
return cur_pointer;
```

We already seen how to traverse the heap when explaining the second version of the alloc function, so we just need to adjust that example to this newer scenario where we have now two extra bytes with information about the allocation instead of one,

```c

```
> **_NOTE:_**  ...



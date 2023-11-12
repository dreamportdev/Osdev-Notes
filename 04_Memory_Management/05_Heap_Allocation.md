# Heap Allocation

## Introduction

Welcome to the last layer of memory allocation, the heap, this is where usually the various alloc functions are implemented. This layer is usually built on top of the other layers of memory management (PMM and VMM), but a heap can be built on top of anything, even another heap! Since different imeplementations have different charactistics, they may be favoured for certain things. We will describe a way of building a heap allocator that is easy to understand, piece by piece. The final form will be a linked list.

We'll focus on three things: allocating memory (`alloc()`), freeing memory (`free()`) and the data structure needed for those to work.


### To Avoid Confusion

The term 'heap' has a few meanings, and if coming from a computer science course the first though might be the data structure (specialized tree). That can be used to implement a heap allocator (hence the name), but its not what we're talking about here.

This term when used in a memory management/osdev environment has a different meaning, and it usually refers to the code where memory is _dynamically allocated_ (`malloc()` and friends).

## A Quick Recap: Allocating Memory

There are many kinds of memory allocators in the osdev world (physical, virtual, and others) with various subtypes (page frame, bitmap, etc ...). For the next section we assume the following components are present:

- a physical memory allocator.
- a virtual memory allocator (using paging).

If some of these terms need more explanation, they have chapters of their own to explain their purpose and function!

With the above assumptions, what happens under the hood when we want to allocate some memory from the heap?

* The heap searches for a suitable address. If one is found returns that address is returned and the algorithm stops there. If it can't find any it will ask the VMM for more space.
* The VMM will receive the heap's request and ask the PMM a suitable physical page to be allocated to fulfill the heap's request.
* The PMM search for a suitable physical page to fulfill the VMM's request, returning that address to the VMM.
* Once the VMM has the physical memory, that memory is mapped into the program's virtual address space, at the address the heap requested (usually at the end).
* The heap will now return an address with the requested amount of space to the program.

## Allocating and Freeing

As with other OS components there are many different algorithms out there for managing memory, each with its pros and cons. Here we'll explain a simple and efficient algorithm based on linked lists. Another common algorithm used for a heap is the slab allocator. This is a very fast, but potentially more wasteful algorithm. This is not covered here and exploring slab allocators is left as an exercise for the reader.

### Overview

A heap allocator exposes two main functions:

* `void *alloc(size_t size);` To request memory of size bytes.
* `void free(void *ptr);` To free previously allocated memory.

In user space these are the well known `malloc()/free()` functions. However the kernel will also need its own heap (we don't want to put data where user programs can access it!). The kernel heap usually exposes functions called `kmalloc()/kfree()`. Functionally these heaps can be the same.

So let's get started with describing the allocation algorithm.

### Part 1: Allocating Memory

*Authors note: In the following examples we will use `uint8_t` for all the pointers, but in a real scenario it will be better to use a bigger size for the variable keeping track of the allocated region sizes (so we're not limited to 255 bytes).*

The easiest way to start with creating our allocator is to ask: "What do a heap allocator do?".

Well the answer is, as we already know: it allocates memory, specifically in bytes. The bytes part is important, because as kernel developers we're probably used to dealing with pages and page-sized things. If the program asks for _X_ bytes, the allocator will return an address pointing to an area of memory that is at least _X_ bytes. The VMM is allocating memory, but the biggest difference is that the Heap is allocating bytes, while the VMM is allocating Pages.

If we are writing an OS, we already know that RAM can be viewed as a very long array, where the index into this array is the memory address. The allocator is returning these indices. So we can already see the first detail we'll need to keep track of: next available address.

Let's start with a simple example, assume that we have an address space of 100 bytes, nothing has allocated yet, and the program makes the following consecutive `alloc()` calls:

```c
alloc(10);
alloc(3);
alloc(5);
```

Initially our ram looks like the following:

| 0000 | 0001| 0002 | ... | 0099 | 00100 |
|------|-----|------|-----|------|-------|
| cur  |     |      |     |      |       |

`cur` is the variable keeping track of the next address that can be returned and is initialized to 0, in this example.
Now when the `alloc(10)` is called, the program is asking for a memory location of 10 bytes. Since `cur = 0`, the address to return is 0, and the next available address will become: `cur + 10`.

So now we have the following situation:

| 0000 | 0001 | 0002 | ... |  0010  |  ... | 00100 |
|------|------|------|-----|--------|------|-------|
|  X   |  X   |  X   |     |  cur   |      |       |

`X` is just used as marker to convey that memory has been allocated already. Now when calling `alloc(3)`, the allocator will return the address currently pointed by ` cur = 10` and then move `cur` 3 bytes forward.

| 0000 | 0001 | 0002 | ... |  0010  | ... | 0013  | ... | 00100 |
|------|------|------|-----|--------|-----|-------|-----|-------|
|  X   |  X   |  X   |     |   X    |     | cur   |     |       |

Now the third `alloc()` call will work similarly to the others, and we can imagine the results. `

What we have so far is already an allocation algorithm, that's easy to implement and very fast!
Its implementation is very simple:

```c
uint8_t *cur_heap_position = 0; //Just an example, in the real world you would use
                                //a virtual address allocated from the VMM.
void *first_alloc(size_t size) {
  uint8_t *addr_to_return = cur_heap_position;
  cur_heap_position= cur_heap_position + size;
  return (void*) addr_to_return;
}
```

Congratulations! We have written our first allocator! It is called the **bump allocator**, because each allocation just *bumps* the next address pointer forward.

But what about `free()`? That's even easier, let's have a look at it:

```c
void first_free(void *ptr) {
    return;
}
```

Yeah... that's right, it's not an error. A bump allocator does not have `free()`.

Why? Because we are not keeping track of the allocated memory, so we can't just update the `cur_heap_position` variable with the address of ptr, because we don't know who is using the memory after ptr. So we are forced just to do nothing.

Even if probably useless let's see what are the pros and cons of this approach:

Pros:

* Is very time-efficient allocating memory is O(1), as well as "freeing" it.
* It is also memory efficient, in fact there is no overhead at all, we just need a variable to keep track of the next free address.
* It is very easy to implement, and probably it could be a good placeholder when we haven't developed a full memory manager yet, but we need some *malloc* like functions.
* Actually there is no fragmentation since there is no freeing!

Of course the cons are probably pretty clear and make this algorithm pretty useless in most cases:

* We don't free memory.
* There is no way to traverse the heap, because we don't keep track of the allocations.
* We will eventually run out of memory (OOM - out of memory).

### Part 2: Adding Free()

The main problem with this algorithm is that we don't keep track of what we have allocated in the past, so we are not able to free that memory in the future, when it's no longer used.

Now we're going to build a new allocator based on the one we just implemented. The first thing to do is try to figure out what are the information we need to keep track of from the previous allocations:

* Whenever we make an allocation we require `x` bytes of memory, so when we return the address, we know that the next free one will be at least at: `returned_address + x`  so we need to keep track of the allocation size.
* Then we need a way to traverse to the previously allocated addresses, for this we need just a pointer to the start of the heap, if we decide to keep track of the sizes.

Now the problem is: how do we keep track of this information?

For this example let's keep things extermely simple: place the size just before the pointer. Whenever we make an allocation we write the size to the address pointed by `cur_heap_position`, increment the pointer and return that address. The updated code should look like the following:

```c
uint8_t *heap_start = 0;
uint8_t *cur_heap_position = heap_start; //This is just pseudocode in real word this will be a memory location

void *second_alloc(size_t size) {
  *cur_heap_position = size;
  cur_heap_position = cur_heap_position + 1;
  uint8_t *addr_to_return = cur_heap_position;
  cur_heap_position += size;
  return (void*) addr_to_return;
}
```

This new function potentially fixes one of the problems we listed above: it can now let us traverse the heap because we know that the heap has the following structure:

| 0000 | 0001 | 0002 | 0003  | ... |  0010  | 0011 | 0013 | ... | 00100 |
|------|------|------|-------|-----|--------|------|------|-----|-------|
|  2   |  X   |  X   |   7   | ... |   X    | cur  |      | ... |       |

*Authors note: just a reminder that the pointer is a uint8_t pointer, so when we are storing the size, the memory cell pointed by cur_heap_position will be of type *uint8_t*, that means that in this example and the followings, the size stored can be maximum 255. In a real allocator we want to support bigger allocations, so using at least a `uint32_t` or even `size_t` is recommended.*

In this example, the number indicates the size of the allocated block. There have already been 2 memory allocations, with the first of 2 bytes and the second of 7 bytes. Now if we want to iterate from the first to the last item allocated the code will looks like:

```c
uint8_t *cur_pointer = start_pointer;
while(cur_pointer < cur_heap_pointer) {
  printf("Allocated address: size: %d - 0x%x\n", *cur_pointer, cur_pointer+1);
  cur_pointer = cur_pointer + (*cur_pointer) + 1;
}
```

But are we able to reclaim unused memory with this approach? The answer is no. You may think so, but even if we know the size of the area to reclaim, and we can reach it everytime from the start of the heap, there is no mechanism to mark this area as available or not. If we set the size field to 0, we break the heap (all areas after the one we are trying to free will become unreachable).

### Part 3: Actually Adding Free()

So to solve this issue we need to keep track of a new information: whether a chunk of memory is used or free.

So now everytime we will make an allocation we will keep track of:

* the allocated size
* the status (free or used)

At this point our new heap allocation will looks like:

| 0000 | 0001 | 0002 | 0003  |  0004 | ... |  0011 | 0011 | 0013 | ... | 00100 |
|------|------|------|-------|-------|-----|-------|------|------|-----|-------|
|  2   |  U   |  X   |   7   |   U   | ... |   X   | cur  |      | ... |       |

Where U is just a label for a boolean-like variable (U = used = false, F = true = free).

At this point we the first change we can do to our allocation function is add the new status variable just after the size:

```c
#define USED 1
#define FREE 0

uint8_t *heap_start = 0;
uint8_t *cur_heap_position = heap_start; //This is just pseudocode in real word this will be a memory location

void *third_alloc(size_t size) {
  *cur_heap_position = size;
  cur_heap_position = cur_heap_position + 1;
  *cur_heap_position = USED;
  cur_heap_position = cur_heap_position + 1;
  uint8_t *addr_to_return = cur_heap_position;
  cur_heap_position += size;
  return (void*) addr_to_return;
}
```

One thing that might have been noticed so far is that for keep track of all those new information we are adding an overhead to our allocator. How big this overhead is depends on the size of the variables we use in the chunk headers (where we store the alloc size and status). Even if we keep things small by only using `uint8_t`, we have already added 2 bytes of overhead for every single allocation.
The implementation above is not completed yet, since we haven't implemented a mechanism to re-use the freed location but before adding this last piece let's talk about the free.

Now we know that given a pointer `ptr` (previously allocated from our heap, of course) `ptr - 1` is the status (and should be USED) and `ptr - 2` is the size.

Using this our free can be pretty simple:

```c
void third_free(void *ptr) {
  if( *(ptr - 1) == USED ) {
    *(ptr - 1) = FREE;
  }
}
```

Yeah, that's it! We just need to change the status, and the allocator will be able to know whether the memory location is used or not.

### Part 4: Re-Using Freed Memory

Now that we can free, we should add support for returning from this freed memory. How the new `alloc()` works is as follows:

* Alloc will start from the beginning of the heap, traversing it until the latest address allocated (the current end of the heap) looking for a chunk who's size is bigger than the requested size.
* If found mark that chunk as USED. The size doesn't need to be updated since it's not changing, so assuming that `cur_pointer` is pointing to the first metatata byte of the location to be returned (the size in our example) the code to update and return the current block will be pretty simple:

```c
cur_pointer = cur_pointer + 1; //remember cur_pointer is pointing to the size byte, and is different from current_heap end
*cur_pointer = USED;
cur_pointer = cur_pointer + 1;
return cur_pointer;
```

There is also no need to update the cur_heap_end, since it has not been touched.

* In case nothing has been found this means that the current end of the heap has been reached so in this case it will first add the two metadata bytes with the requested size, and the status (set to USED) then return the next address. Assuming that in this case `cur_pointer == cur_heap_position`:

```c
*cur_pointer = size;
cur_pointer = cur_pointer + 1;
*cur_pointer = USED;
cur_pointer = cur_pointer + 1;
cur_heap_position = cur_pointer + size;
return cur_pointer;
```

We have already seen how to traverse the heap when explaining the second version of the alloc function. Now we just need to adjust that example to this newer scenario where we have now two extra bytes with information about the allocation instead of one. The code for alloc will now look like:

```c
#define USED 1
#define FREE 0

uint8_t *heap_start = 0;
uint8_t *cur_heap_position = heap_start; //This is just pseudocode in real word this will be a memory location

void *third_alloc(size_t size) {
  cur_pointer = heap_start;

  while(cur_pointer < cur_heap_position) {
    cur_size = *cur_pointer;
    status = *(cur_pointer + 1);

    if(cur_size >= size && status == FREE) {
       status = USED;
       return cur_pointer + 2;
    }
    cur_pointer = cur_pointer + (size + 2);
  }

  *cur_heap_position=size;
  cur_heap_position = cur_heap_position + 1;
  *cur_heap_position = USED;
  cur_heap_position = cur_heap_position + 1;
  uint8_t *addr_to_return = cur_heap_position;
  cur_heap_position+=size;
  return (void*) addr_to_return;
}
```

If we are returning a previously allocated address, we don't need move `cur_heap_position`, since we are reusing an area of memory that is before the end of the heap.

Now we have a decent and working function that can free previously allocated memory, and is able to reuse it. It is still not perfect and there are several major problems:

* There is a lot of potential waste of space, for example if we are allocating 10 bytes, and the heap has two holes big enough the first is 40 bytes, the second 14, the algorithm will pick the first one free so the bigger one with a waste of 26 bytes. There can be different solution to this issue, but is out of the purpose of this tutorial (and eventually left as an exercise)
* It can suffer of fragmentation. Basically there can be a lot of small freed areas that the allocator will not be able to use because of their size. A partial solution to this problem is described in the next paragraph.

Another thing worth doing to improve readability of the code is replace the direct pointer access with a more elegant data structure. This lets us add more fields (as we will in the next paragraph) as needed.

So far our allocator needs to keep track of just the size of the block returned and its status The data structure for this could look like the following:

```c
struct {
    size_t size;
    uint8_t status;
} Heap_Node;
```

That's it! That's what we need to clean up the code and replace the pointers in the latest with the new struct reference. Since it is just matter of replacing few variables, implementing this part is left to the reader.

### Part 5: Merging

So now we have a basic memory allocator (woo hoo), and we are nearing the end of our memory journey.

In this part we'll see how to help mitigate the *fragmentation* problem. It is not a definitive solution, but this let us to reuse memory in a more efficient way. Before proceeding let's recap what we've done so far.
We started from a simple pointer to the latest allocated location, and added information in order to keep track of what was previously allocated and how big it was, needed to reuse the freed memory.

We've basically created a list of memory regions that we can traverse to find the next/prev region.

Lets look at fragmentation a little more closely, in the following example. We assume that we have a heap limited to 25 bytes:

```c
a = third_alloc(6);
b = third_alloc(6);
c = third_alloc(6)
free(c);
free(b);
free(a);
```

What the heap will look like after the code above?

| 00 | 01 | 02 |  ..  |  07 | 08 | 09 | 10 | .. | 15 | 16 | 17 | .. | 23 | 24 | 25 |
|----|----|----|------|-----|----|----|----|----|----|----|----|----|----|----|----|
|  6 | F  | X  |  ..  |  X  | 6  | F  |  X | .. | X  | 6  | F  | .. | X  |    |    |


Now, all of the memory in the heap is available to allocate (except for the overhead used to store the status of each chunk), and everything looks perfectly fine. But now the code keeps executing and it will arrive at the following instruction:

```c
alloc(7);
```

Pretty small allocation and we have plenty of space... no wait. The heap is mostly empty but we can't allocate just 7 bytes because all the free blocks are too small. That is _fragmentation_ in a nutshell.

How do we solve this issue? The idea is pretty straightforward, every time a memory location is being freed, we do the following:

* First check if it is adjacent to to other free locations (both directions: previous and next)
    * If `ptr_to_free + ptr_to_free_size == next_node` then merge the two nodes and create a single node of `ptr_to_free_size + next_node_size` (notice we don't ned to add the size of `Heap_node` because `ptr` should be the address immediately after the struct).
    * If `prev_node_address + prev_node_size + sizeof(Heap_Node) == ptr_to_free` then merge the two nodes and create a single node of `prev_node_size + ptr_to_free_size`
* If not just mark this location as free.

There are different ways to implement this:

* Adding a `next` and `prev` pointer to the node structure. This is the way we'll use in the rest of this chapter. This makes checking the next and previous nodes for mergability very easy. It does dramatically increase the memeory overhead. Checking if a node can be merged can be done via `(cur_node->prev).status = FREE` and `(next_node->next).status = FREE`.
* Otherwise without adding the next and prev pointer to the node, we can scan the heap from the start until the node before `ptr_to_free`, and if is free we can merge. For the next node instead things are easier: we just need to check if the node starting at `ptr_to_free + ptr_size` if it is free is possible to merge. By comparison this increases the runtime overhead of `free()`.

Both solutions have their own pros and cons, like previously mentioned we'll go with the first one for these examples. Adding the `prev` and `next` pointers to the heap node struct leaves us with:

```c
typedef struct {
    size_t size;
    uint8_t status;
    Heap_Node *prev;
    Heap_Node *next;
} Heap_Node;

```

So now our heap node will look like the following in memory:

| 00 | 01   | 02    | 10   |  18 |
|----|------|-------|------|-----|
|  6 | F/U  | PREV  | NEXT |  X  |

As mentioned earlier using the double linked list the check for mergeability is more straightforward. For example to check if we can merge with the left node we just need to check the status of the node pointed by the prev field, if it is free than they can be merged. To merge with the previous node would apply the logic below to `node->prev`:

* Update the `size` its, adding to it the size of cur_node
* Update the `next` pointer to point to cur_node->next

Referring to the next node:

* Update its `prev` pointer to point to the previous node above (cur_node->prev)

Of course merging with the right node is the opposite (update the size and the prev pointer of cur_node->next and update the next pointer of cur_node->next).

**Important note:** We always want to merge in the order of `current + next` and then `prev + current` as if the prev node absorbs current, what happens to the memory owned by the next node when merged with it? Nothing, it's simply lost. It can be avoided with clever and careful logic, but the simpler solution is to simply merge in the right order.

Below a pseudo-code example of how to merge left:

```c
Heap_Node *prev_node = cur_node->prev //cur_pointer is the node we want to check if can be merged
if (prev_node != NULL && prev_node->status == FREE) {
    // The prev node is free, and cur node is going to be freed so we can merge them
    Heap_Node next_node = cur_pointer->next;
    prev_node->size = prev_node->size + cur_node->size + sizeof(Heap_Node);
    prev_node->next = cur_pointer->next;
    if (next_node != NULL) {
        next_node->prev = prev_node;
    }
}
```
What we're describing here is the left node being "swallowed" by the right one, and growing in size. The memory that the left node owns and is responsible for is now part of the right oneTo make it easier to understand, consider the portion of a hypothetical heap in the picture below:

![Heap initial status](/Images/heapexample.png)


Basically the heap starts from address 0, the first node is marked as free and the next two nodes are both used. Now imagine that `free()` is called on the second address (for this exammple we consider size of the heap node structure to be just of 2 bytes):

```c
free(0x27); //Remember the overhead
```


This means that the allocator (before marking this location as free and returning) will check if it is possible to merge first to the left (YES) and then to the right (NO since the next node is still in use) and then will proceed with a merge only on the left side. The final result will be:

![The heap status after the merge](/Images/heap_example_after_merge.png)

The fields in bold are the fields that are changed. The exact implementation of this code is left to the reader.

### Part 6: Splitting

Now we have a way to help reduce fragmentation, on to the next major issue: wasted memory from allocating chunks that are too big. In this part we will see how to mitigate this.

Imagine our memory manager is allocating and freeing memory for a while and we arrive at a moment in time where we have just three nodes:

* The first node Free, size of 150 bytes (the heap start).
* The second node Used size of 50 bytes.
* The third node Free size of 1024 bytes (the heap end).

Now `alloc()` is called again, like so:

```c
alloc(10);
```
The allocator is going to look for the first node it can return that is at least 10 bytes. Using the example from above, this will be the first node. Everything looks fine, except that we've just returned 150 bytes for a 10 byte allocation (i.e. ~140 bytes of memory is wasted). There are a few ways to approach this problem:
- The first solution that comes to mind if to scan the entire heap each time and use the smallest (but still big enough for the requested size) node. This is better, but the downside (speed) should be obvious. This will also still not work as well as the second solution because in the above the example it would still return 150 bytes.
- What we're going to do is 'cut' the space that we need from the node, splitting it into 2 new nodes. The first node will be the request allocation size, and is used to fulfill that. The other will be kept as a free node, inserted into the linked list.

The workflow will be the following:

* Find the first node that is big enough to contain the incoming request.
* Create a new node at the address `(uintptr_t)cur_node + requested_bytes`. Set this node's size to `cur_node->size - requested_bytes - sizeof(Heap_Node)`, we're substracting the size of the Heap_Node struct here because we're going to use some memory in the heap to store this new node. This is the process of inserting into the heap.
* `cut_node->size` should now be the requested size.
* In our example we're using a doubly-linked list (i.e. both forward and back), so we'll need to update the current node and the next node's pointers to include this new node (update its pointers too).
* One edge case to be aware of here is if node that was split was the last node of the heap, The `heap_tail` variable should be updated as well, if it is being used (this depend on design decisions).


After that the allocator can compute the address to return using `(uintptr_t)cur_node + sizeof(Heap_node)`, since we want to return the memory *after* the node, not the node itself (otherwise the program would put data there and overwrite what we've stored there!).

Before wrapping up there's a few things worth pointing out about implementing splitting:

* Remember that every node has some overhead, so when splitting we shouldn't have nodes smaller (or equal to) than `sizeof(Heap_Node)`, because otherwise they will never be allocated.
* It's a good idea to have a minimum size for the memory a chunk can contain, to avoid having a large number of nodes and for easy alignment later on. For example if the minimum_allocable_size is 0x20 bytes, and we want to allocate 5 bytes, we will still receive a memory block of `0x20` bytes. The program may not know it was returned `0x20` bytes, but that is okay. What exactly value should be used for it is implementatin specific, values of `0x10` and `0x20` are popular.
* Always remember that there is the memory footprint of `sizeof(Heap_Node)` bytes while computing sizes that involve multiple nodes. If we decide to include the overhead size in the node's size, remember to also subtract it when checking for suitable nodes.

And that's it!

### Part 7: Heap Initialization

Each heap will likely have different requires for how it's initialized, depending on whether it's a heap for a user program, or it's running as part of a kernel. For a userspace program heap we may want to allocate a bigger initial size if we know the program will need it. As the operating system grows there will be more instances of the heap (usually at least one per program + global kernel heap), and it becomes important to keep track of all the memory used by these heaps. This is often a job that the VMM for a process will take on.

What is really needed to initialize a heap is an initial size (for example 8k), and to create a single starting node:

```c

Heap_Node *heap_start;
Heap_Node *heap_end;
void initialize_heap() {
  heap_start = INITIAL_HEAP_ADDRESS //Remember is a virtual address;
  heap_start->next = NULL;
  heap_start->next = NULL; // Just make sure that prev and next are not going anywhere
  heap_start->status = free;
  heap_start->size = INITIAL_HEAP_SIZE // 8096 = 8k;
  heap_end = heap_start
}
```

Now the question is, how do we choose the starting address? This really is arbitrary. We can pick any address that we like, but there are a few  constraints that we should follow:

* Some memory is used by the kernel, we don't want to overwrite anything with our heap, so let's keep sure that the area we are going is free.
* Usually when paging is enabled, in many case the kernel is moved to one half of the memory space (usually referred as to HIGHER_HALF and LOWER_HALF) so when deciding the initial address we should place it in the correct half, so if the kernel is placed in the HIGHER and we are implementing the kernel heap it should go on the HIGHER Half and if it is for the user space heap it will goes on the LOWER half.

For the kernel heap, a good place for it to start is immediately following the kernel binary in memory. If the kernel is loaded at `0xFFFFFFFF80000000` as is common for higher half kernels, and the kernel is `0x4321` bytes long. It round up to the nearest page and then add another page (`0x4321` gets rounded to `0x5000`, add `0x1000` now we're at `0x6000`). Therefore our kernel heap would start at `0xFFFFFFFF80006000`.

The reason for the empty page is that it can be left unmapped, and then any buggy code that attempts to access memory *before* the heap will likely cause a page fault, rather then returning bits of the kernel.

And that's it, that is how the heap is initialized with a single node. The first allocation will trigger a split from that node... and so on...

### Part 8: Heap Expansion

One final part that we will explained briefly, is what happens when we reach the end of the heap. Imagine the following scenario we have done a lot of allocations, most of the heap nodes are used and the few usable nodes are small. The next allocation request will fail to find a suitable node because the requested size is bigger than any free node available. Now the allocator has searched through the heap, and reached the end without success. What happens next? Time to expand the heap by adding more memory to the end of it.

Here is where the virtual memory manager will join the game. Roughly what will  is:

* The heap allocator will first check if we have reached the end of the address space available (unlikely).
* If not it will ask to the VMMmanager to map a number of pages (exact number depends on implementation) at the address starting from `heap_end + heap_end->size + sizeof(heap_node)`.
* If the mapping fail, the allocation will fail as well (i.e. out of memory/OOM. This is an issue to solve in its own right).
* If the mapping is succesfull, then we have just created a new node to be appended to the current end of the heap. Once this is done we can proceed with the split if needed.

And with that we're just written a fairly complete heap allocator.

A final note: in these examples we're not zeroing the memory returned by the heap, which languages like C++ may expect when `new` and `delete` operators are used. This can lead to non-deterministic bugs where objects may be initialized with left over values from previous allocations (if the memory has been used before), and suddenly default construction is not doing what is expected.
Doing a `memset()` on each block of memory returned does cost cpu time, so its a trade off, a decision to be made for your specific implementation.

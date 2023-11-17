# Physical Memory Manager

The physical memory manager is responsible for tracking which parts of physical memory are in use, or free for use. The PMM doesn't manage individual bytes of memory, rather it keeps track of *pages*. A page is a fixed size determined by the MMU: in the case of x86 this is 4096 (0x1000) bytes.

There are different ways on how to handle a PMM, one of them is using a bitmap. Where every bit represent a page, if the bit is a 0 the page is available, if is 1 is taken. 

What the physical memory manager has to take care of as its bare minimum is:

1. Initialize the data structures marking unavailable memory as "used"
2. Check if given an address it is already used or not
3. Allocate/free a page

In this chapter we will explain the bitmap method, because is probably the simplest to understand for a beginner. To keep the explanation simple, we will assume that the kernel will support only one page size.

## The Bitmap

Now let's start with a simple example, imagine that we have a very tiny amount of ram like 256kb of ram, and we want to use 4kb pages, and assume that we have the kernel that takes the first 3 pages. As said above using the bitmap method assign 1 bit to every page, this means that every bytes can keep track of $8*4k=32kb$ of memory, if the page is taken the bit is set to 1, if is free the bit is clear (=0)

This means that a single *unsigned char* variable can hold the status of 32kb of ram, to keep track of 256kb of ram we then need 8bytes (They can stay in a single `uint64_t` variable, but for this example let's stick with the char type), this means that with an array of 8 elements of *unsigned char* we can represent the whole amount of memory, so we are going to have something like this: 


|           | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |  
|-----------|---|---|---|---|---|---|---|---|
| bitmap[0] | 0 | 0 | 0 | 0 | 0 | 1 | 1 | 1 | 
| bitmap[1] | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 
| bitmap[2] | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 
| bitmap[3] | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 
| bitmap[4] | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 
| bitmap[5] | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 
| bitmap[6] | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 
| bitmap[7] | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 

So marking a memory location as free or used is just matter of setting clearing a bit in this bitmap. 

### Returning An Address

But how do we mark a page as taken or free? We need to translate row/column in an address, or the address in row/column. Let's assume that we asked fro a free page and we found the first available bit at row 0 and column 3, how we translate it to address, well for that we need few extra info: 

* The page size (we should know what is the size of the page we are using), Let's call it `PAGE_SIZE`
* How many bits are in a row (it's up to us to decide it, in this example we are using an unsigned char, but most probably in real life it is going to be a `uint32_t` for 32bit OS or `uint64_t` for 64bit os) let's call it `BITS_PER_ROW`

To get the address we just need to do: 

* `bit_number = (row * BITS_PER_ROW) + column`
* `address = bit_number * PAGE_SIZE`

Let's pause for a second, and have a look at `bit_number`, what it represent? Maybe it is not straightforward what it is, but consider that the memory is just a linear space of consecutive addresses (just like a long tape of bits grouped in bytes), so when we declare an array we just reserve *NxSizeof(chosendatatype)* contiguous addresses of this space, so the reality is that our array is just something like: 

 | bit_number | 0 | 1 | 2 | ... | *8* | ... | 31 | *32* | ... | 63 |
 |------------|---|---|---|-----|-----|-----|----|------|-----|----|
 | \*bitmap   | 1 | 1 | 1 | ... | *0* | ... |  0 |  *0* | ... |  0 |
  
It just represent the offset in bit from `&bitmap` (the starting address of the bitmap). 

In our example with *row=0 column=3* (and page size of 4k) we get:

* `bit_number = (0 * 8) + 3 = 3`
* `address = bit_number * 4k = 3 * 4096 = 3 * 0x1000 = 0x3000`

Another example: *row = 1 column = 4* we will get: 

* `bit_number = (1 * 8) + 4 = 12`
* `address = bit_number * 4k = 0xC000`

But what about the opposite way? Given an address compute the bitmap location? Still pretty easy: 

$$bitmap_{location}=\frac{address}{4096}$$

In this way we know the "page" index into an hypoteteical array of Pages. But we need row and columns, how do we compute them? That depends on the variable size used for the bitmap, let's stick to 8 bits, in this case:

* The row is given by `bitmap_location / 8`
* The column is given by: `bitmap_location % 8`

### Freeing A Page

So now knowing how the bitmap works, let's see how to update/test it. We need basically three very simple functions:

* A function to test if a given frame location (in this case `bit_number` will be used) is clear or set
* A function to mark a location as set
* A function to mark a location as clear 

For all the above functions we are going to use bitwise operators, and all of them will take one argument that is the `bit_number` location (as seen in the previous paragraph), the implementation is left as exercise.

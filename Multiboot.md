# Grub and Multiboot 2 info
To load your kernel using grub, it has to be multiboot2 compliant (check your grub version older versions only support multiboot1). 

## Grub

First thing that you need is a config file for grub where you specify the entry for your kernel: 
```grub
set timeout=10
set default=0

menuentry "Your os" {
    multiboot2 /boot/kernel.bin                  // Path to the loader executable
    boot
     // More modules may be added here in the form 'module <path> "<cmdline>"'
}
```


## Multiboot2
This document refers to Multiboot 2 Specs!

### The Header

The minimum structure is: 

|Offset |  Name               | Description              | 
|-------|---------------------|--------------------------|
|  0    | Magic number        | Magic number used by grub must be 0xE85250D6|
|  4    | Architecture        | This specify the cpu instruction set architecture. 0=Protected mode x86 4=32-bit MIPS.|
|  8    | Header length       | Length of this header |
|  12   | Checksum			  | The checksum value, this number if added to Magic+architecture+Header length must be 0|
| 16-XX | Tags                | Will be specified in the next section |


### Kernel loading

When the kernel is loaded: 

* EAX contains the magic number 0x36d76289 
* EBX contains the addres of multiboot header structure (to check) 

In order to pass this information to the kernel C main function if we are running in 64bit mode, they have to be saved first where they can be read by the C function. 
To do that they must be saved  into edi and esi register:

```asm
mov edi, eax
mov esi, ebx
```

otherwiseif you are in 32 bit mode, then you just need to place them on the stack:

```asm
push ebx,
push eax
```

And then your C function will be something like that: 

```C
void _kernel_start(unsigned long magic, unsigned long address);
```


The first parameter is the magic number, the second one the address of the multiboot header. 

You should save *eax*  and *ebx* before starting to load any data structure like paging, gdt, to avoid the risk of having them overwritten 

Consider that x86_64 registers when calling C functions from asm the parameters are passed first on rdi,rsi, ..., and then they are passed on the stack, while 
if you are on 32bit mode you just need to pass it on the stack. 

### Parsing the multiboot header

So after the kernel is loaded, and assuming that we have passed the multiboot header information to it (see previous chapter), then we have a pointer to all the informataion 
that are contained in the multiboot header. 

Keep in mind that reading multiboot information is not mandatory, but sometime it can be useful. This guide explaing the basic of how to handle it, and few examples
What we found in it? 

### First 8 bytes

The first 8 bytes have a fixed structure: 

| bytes | Content                                                                                    | 
|-------|--------------------------------------------------------------------------------------------|
|  0-4  | Total size of the boot information in bytes (it include this field and the terminating tag)| 
|  4-8  | Reserved                                                                                   | 

and then they are followed by the tags. 

If we want to get the size of the multiboot header then we can just do the following:

```C
unsigned size = *(unsigned*)addr;
```
We don't need a specific structure for the first 8 bytes, half of them are reserved, and what we need is just the size of the header. 


### The tags 

Every tag begins in the same way: 

| size  |  Content                                         |
|-------|--------------------------------------------------|
|   4   | Type of information provided                     | 
|   4   | Size of the current tag including this header    | 

Instead of recreating the same structures from scratch for every tag, you can use the multiboot2 header example provided by the documentation.
Just add it to your kernel (you can find it here: https://www.gnu.org/software/grub/manual/multiboot2/html_node/multiboot2_002eh.html#multiboot2_002eh). 

So to access the first tag, starting from the address in *addr*: 

```C
struct multiboot_tag *tag = (struct multiboot_tag*) (addr+8);
```

And the first 4 bytes will be the type of tag, the second 4 will be the size of it. 
For a detailed list of tags is better to look at the multiboot specs: https://www.gnu.org/software/grub/manual/multiboot2/multiboot.html#Header-tags 

The easier way to read these information is to use the multiboot header mentioned above, it has a data structure for each tag and much more. 

The memory layout of the multiboot2 information provided by the bootloader starting from addr is: 

| offset | Description                    |
|--------|--------------------------------|
|   0    | Size of multiboot header infos |
|   4    | Reserved						  |
|   8	 | Header tags                    |

Tags follow one another padded when necessary in order for each tag to start at 8-bytes aligned address. 
So when iterating through tags we need always to align the address to 8byte, this explain the for loop in the multiboot2 example: 
```gcc
  for (tag = (struct multiboot_tag *) (addr + 8);
       tag->type != MULTIBOOT_TAG_TYPE_END;
       tag = (struct multiboot_tag *) ((multiboot_uint8_t *) tag 
                                       + ((tag->size + 7) & ~7)))
```                                       
To get to the next tag, we always need to add the size of the current tag (that is in tag->size) and align it to 8bytes.
this is done by adding 7 to the current tag size, and then AND the result with negation of 7. 

Tags are terminated by a tag of type ‘0’ and size ‘8’.

## Useful resources

* https://wiki.osdev.org/Calling_Conventions - Calling conventions from ASM to C function on different architectures
* https://www.gnu.org/software/grub/manual/multiboot2/multiboot.html#Header-tags Multiboot headers
* https://stackoverflow.com/questions/33308421/what-does-size-7-7-mean/33308592

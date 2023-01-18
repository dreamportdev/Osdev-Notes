# Higher Half

Loading a kernel in higher half it means that  the addres space of the kernel is in the higher-half. 
For example for a 32 bit kernel the kernel can start from 0xC0000000 (3Gb) or for a 64bit it can start at 0xffffffff80000000. 

It doesn't mean that the kernel will be phyisically placed there, in fact most probably it is placed somewhere around 0x100000 (2mb), but it means that after having enabled virtual memory (see the Paging chapter), the virtuall addresses of the kernel are at 0xC0000000 (or 0xffffffff80000000 for 64 bit example). 	

The steps to move the kernel in the higher half are: 

* Update the linker script to instruct it about the new addressing layout
* Prepare paging dir/tables, map the kernel initially in both the lower half and higher half
* Enable paging
* Enable PAE 
* Jump into 64 bit mode
* Load gdt 
* Far jump in the higher half

For example: we want to map it starting from address: 0xffffffff80000000 (even if it is physically a 0x100000), let's assume that the paging mode used is 2mb pages (it is the same with 4kb pages, but just one table more), the kernel starting address is then composed by


Let's assume we are in 64 bit mode. The address is 0xffffffff80000000, if we are using 2Mb pages: 

| 63 .... 48 | 47 ... 39 | 38   ... 32  31  30 | 29  ..  21 | 20 19 ...  0 |
|------------|-----------|---------------------|------------|--------------|
| 1   ...  1 | 1  ...  1 | 1    ... 1   1   0  | 0   ... 0  | 0  0  ...  0 |
|  Sgn. ext  |    PML4   |      PDPR           |   Page dir |    Offset    |

the address is composed as follows:

* Sgn ext: bits from 63 to 48 can be ignored
* PML4: (bits 47..39) is 511
* PDPR: (bits 38..30) is 510
* PD: (bits 29..21) is 0
* Offset is the offset within the page dir base address. That means that it will be within the 0th page of the Page dir.

So to map the kernel we need to create a PDPR for 511th entry of PML4, and then the 510th entry of the PDPR has to be linked to a pagedir, where we will map the kernel there as it is.

Before proceeding with updating the code, first important thing to be done is to update our linker script, we want to inform it where there resources have to be loaded. What we are going to changes are the address references.


```
ENTRY(start)

SECTIONS {
    . = 1M;

    _kernel_start =.;
    _kern_virtual_offset = 0xffffffff80000000;
    .multiboot_header :
    {
        /* Be sure that multiboot header is at the beginning */
        *(.multiboot_header)
    }

    .multiboot.text :
    {
        *(.multiboot.text)
    }

    . += _kern_virtual_offset;
	/* Add a symbol that indicates the start address of the kernel. */
	.text ALIGN (4K) : AT (ADDR (.text) - _kern_virtual_offset)
	{
		*(.text)
	}
	.rodata ALIGN (4K) : AT (ADDR (.rodata) - _kern_virtual_offset)
	{
		*(.rodata)
	}
	.data ALIGN (4K) : AT (ADDR (.data) - _kern_virtual_offset)
	{
		*(.data)
	}
	.bss ALIGN (4K) : AT (ADDR (.bss) - _kern_virtual_offset)
	{
		*(.bss)
	}

    _kernel_end = .;
}
```


As you can see we specified a new variable in the script, called *_kern_virtual_offset* and just before declaring the sections *.text .rodata .data .bss* we instruct the linker that the starting address is going to be *1M + 0xffffffff80000000*, and with the AT keyword in every section we are just telling the linker what the real address of the section is. 
For example the following section: 

```
	.text ALIGN (4K) : AT (ADDR (.text) - _kern_virtual_offset)
	{
		*(.text)
	}
```

Since it is after the instruction * .+=_kern_virtual_offset*  without the AT ( ... ) part it means that it will be placed at an address that starts somewhere above _kern_virtual_offset. But of course this probably is not going to exist physically, so with the AT part we are just telling that the real address is the current minus the _kern_virtual_offset, that is somewhere above 1MB.

So if you arrived that far, you already have you 64 bit kernel loaded, and the paging is already enabled, that means also that you have your kernel already mapped in the page dir, with it being somewhere around 1MB. 

What we are going to do now: 

* Map the kernel also in the new address
* Update all the references to memory location to reflect the new memory layout
 



To compile the kernel in the higher half, you need to add the *-mcmodel=large* to the C Compilation flags.

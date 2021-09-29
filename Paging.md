# Paging

In 64 bit mode we have up to 4 Levels of page table. The number depends on the size we want to assign to each page. 

There are 3 possible scenarios: 

* 4kib Pages: We are going to use all levels, so the address will be composed of all the 4 table entries 
* 2Mib Pages: in the case we only need 3 page levels
* 1Gib Pages: Only 2 levels are needed

To implement paging, is strongly reccomended to have implemented exceptions too. 

The 4 levels of page directories/tables are: 

* the Page-Map Level-4 Table (PML4),
* the Page-Directory Pointer Table (PDP),
* the Page-Directory Table (PD),
* and the Page Table (PT).

The number of levels depend on the size of the pages chosen. 
If we are using 4kb pages then we will have: PML4, PDPR, PD, PT, while if we go for 2mb Pages we have only PML4, PDPR, PD. 

## Address translation 

### Address translation using 2mb pages

If we are using 2MB pages this is how the address will be handled by the paging mechanism:

|            |           |                     |            |              |
|------------|-----------|---------------------|------------|--------------|
| 63 .... 48 | 47 ... 39 | 38   ... 32  31  30 | 29  ..  21 | 20 19 ...  0 |
|  1 ...  1  | 1  ...  1 | 1    ... 1   1   0  | 0   ... 0  | 0  0  ...  0 |
|  Sgn. ext  |    PML4   |      PDPR           |   Page dir |    Offset    |

* Bits 63 to 48, not used in address composition
* Bits 47 ... 39 are the PML4 Entry 
* Bits 38 ... 30 are the PDPR entry 
* Bits 29 ... 21 are the PD entry
* Offset in the Page dir 

Every table has 512 elements, so we have an address space of 2^512 * 2^512 * 2^512 * 0x200000 (that is the page size) :w

### Address translation using 4kb pages
   
If we are using 4kB pages this is how the address will be handled by the paging mechanism:

|            |           |                     |            |             |              |
|------------|-----------|---------------------|------------|-------------|--------------|
| 63 .... 48 | 47 ... 39 | 38   ... 32  31  30 | 29  ..  21 | 20  ...  12 | 11 10 ...  0 |
| 1   ...  1 | 1  ...  1 | 1    ... 1   1   0  | 0   ... 0  | 0   ...  0  | 0 ...  ... 0 |
|  Sgn. ext  |    PML4   |      PDPR           |   Page dir |  Page Table |   Offset     |

* Bits 63 to 48, not used in address composition
* Bits 47 ... 39 are the PML4 Entry 
* Bits 38 ... 30 are the PDPR entry 
* Bits 29 ... 21 are the PD entry
* Bits 20 ... 12 are the PT entry
* Offset in the Page table 

Same as above: 
Every table has 512 elements, so we have an address space of 2^512 * 2^512 * 2^512 * 2^512 * 0x1000 (that is the page size)


## Page fault 

Page fault is exception number 14, when it is raised, it contains two information: 

* an error code on the stack
* The address that caused the failure stored in the CR2 register. 

The idea of the page fault handler is that when #PF is raised, it look at the address requested, ask a physical memory location to the phyisical memory handler, and then map it into the virtual memory. 

The error code has the following structure: 

|           |       |        |      |       |     |
|-----------|-------|--------|------|-------|-----|
| 31 .... 4 |   4   |    3   |   2  |   1   |  0  |
|  Reserved |  I/D  |  RSVD  |  U/S |  W/R  |  P  |

Where: 
* Bits 31...4 Are reserved
* Bit 4 if 1 means tha t the fault is caused by an instruction fetch
* Bit 3 if 1 means that the violation was caused by a reserved bit set to 1 in a page directory
* Bit 2 if 1 the fault was caused by an access when the processor was executing in user moder
* Bit 1 if 1 the fault was caused by a write access (read if 0)
* Bit 0 if 1 the fault was caused by a page level protection violtaion, if 0 instead is a non present page. 

## Recursion

There are few things to take in account when trying to access paging structures using recursion technique for x86_64 architecture:

* When specifying entries using constant numbers (not stored in variables) during conversion, always use the long version appending the "l" letter (i.e. 510th entry became: 510l)
* Always remember to add the sign extension part (otherwise you will obtain a #G)

Few examples of recursive addresses: 

* PML4: 511 (hex: 1ff) - PDPR: 510 (hex: 1fe) - PD 0 (hex: 0) using 2mb pages translates to: ffffffff80000000
* Let's assume we mapped PML4 into itself at entry 510, 
    - if we want to access the content of the PML4 page itself, using the recursion we need to build a special address using the entries: PML4: 510, PDPR: 510, PD: 510, PT: 510, now keep in mind that the 510th entry of PML4 is PML4 itself, so this means that when the processor loads that entry, it loads PML4 itself instead of PDPR, but now the value for the PDPR entry is still 510, that is still PML4 then, the table loaded is PML4 again, repat this process for PD and PT wit page number equals to 510, and we obtain access to the PML4 page itself.
    - Now using a similar approach we can get acces to other tables, for example the following values: PML4: 510, PDPR:510, PD: 1, PT: 256, will give access at the Page Directory PD at  entry number 256 in PDPR that is  contained in the first PML4 entry 

## Virtual Memory Manager

The virtual memory manager is a layer between the physical memory manager and the allocation function (slab/heap/whatever), it basically has to do only two things: 

* Given a virtual address in input it has to be mapped in the page table
* And also given a virtual address in input it has to be unmapped it from the physical location. 

The workflow should be the similar to the following: 

Allcoation function return an address --> This address is mapped to it's own page table (eventually allocating intermediate page dirs) -> Physical memory is requested

Is not necessary to allocate physical memory immediately, but it can be handled also during the page fault. 

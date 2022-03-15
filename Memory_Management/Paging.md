# Paging

## What is Paging?

Paging is a memory management scheme that introduce the concept of **_logical address_** (virtual address) and **_Virtual Memory_** to the operating system. On x86_* architectures it is achieved via hardware. Using this tecnique we create a new layer of addressing above the memory space (the physical address space), that introduce a mapping between a physical address and a logical one, and few more features (like access protection, level protection, etc.)

Paging introduce few new concepts that are explained below

### Page
A _page_ is a contiguous block of physical  memory of fixed size, and it represent the smallest unit of data for a virtal memory management unit, and usually is described by a single entry in a Page Table

### Page Directories and Tables

Those are the basics blocks of paging. Depending on the architectures, and page size there can be a different number of them (for example if we are running in 32 bits mode with 4k pages we have Page Directory and Page Table,  if we are running in 64 bits with 4k pages we have four level of those tables, 3 directories and 3 tables.

What are those directories and tables? Let's start from the tables: 

* **Page Table** contains the information about a single pages of memory, an entry in a page table represents the starting physical memory addresss for this page.
* **Page Directory** an entry in a page directory can point to: another page directory (depending on what type of paging we have enabled) or a page table. 

A special register contains the address of the Root Page Directory. 

### Logical Address

A Virtual Address, is and address where the application/data appears to reside from an application/user level perspective. That address could or could not be the same of th physical address, depending of operating system design. 

A virtual address is usually a composition of entry numbers for each level of tables. The picture below shows how address translation works: 

![address_translation drawio](https://user-images.githubusercontent.com/59960116/157250312-1175dbd1-87ca-47d7-b7cf-6b07394af4ce.png)


Using logical address and paging, we can introduce a new address space that can be much bigger of the available physical memory.


So for example: 

```
phys#0x123456 = virt#0xffff2345235
```

This mapping, in x86 architectures, is achieved trhough the usage of several hierarchical tables each item in one level is pointing to the next level table. 
A virtual address is a composition of entry number for each level of the tables. So for example assume that we have 3 levels, and 32 bits a address:

```
virtaddress = 0xff880120
```

Now we know that the bits: 

* 0 to 10 are the offset
* 11 to 21 are the page table entry
* 20 to 32 are the page directory entry

We can translate the abbove address to: 
* Offset:  0x120 bytes into page
* Page Table entry: number 0x80 (it points to the memory page)
* Page Dir entry: 0x3FE (it points to a page table)


In this section we will see the X86_64 paging.

## Paging in Long Mode 

In 64 bit mode we have up to 4 Levels of page tables. The number depends on the size we want to assign to each page. 

There are 3 possible scenarios: 

* 4kib Pages: We are going to use all levels, so the address will be composed of all the 4 table entries 
* 2Mib Pages: in the case we only need 3 page levels
* 1Gib Pages: Only 2 levels are needed

To implement paging, is strongly reccomended to have implemented exceptions too. 

The 4 levels of page directories/tables are: 

* the Page-Map Level-4 Table (PML4),
* the Page-Directory Pointer Table (PDPR),
* the Page-Directory Table (PD),
* and the Page Table (PT).

The number of levels depend on the size of the pages chosen. 
If we are using 4kb pages then we will have: PML4, PDPR, PD, PT, while if we go for 2mb Pages we have only PML4, PDPR, PD. 

## Page Directories and Table structure

As we have seen earlier in this section, when paging is enabled, a virtual address is translated into a set of entry number in different tables. In this paragraph we will see the different types available for them

But before proceeding with the details let's see some of the characteristics common between all table/directory types: 

* The size of all table type is fixed and is 4k
* Every table has exactly 512 entries
* Every entry has the size of 64 bits
* The tables have a hierarchy, and every item in a table higher in the hierachy point to a lower hierachy one (with some exceptions explained later). The page table points to a memory area. 

The hierarchy of the tables is: 

* PML4 is the Root table, is the one that is contained in the PDBR register, and that is loaded for the actual address translation (see the next paragraph). Every entry in the page table points to a PDPR table
* PDPR every entry of this table points to a Page Directory
* Page Directory (PD): depending of the value of the PS bit (Page Size) an entry in this table can point to:
   * a Page Table if the PS bit is clear (this means we are using 4k pages)
   * 2 MB memory area if the PS bit is set 
* Page Table (PT) Every entry in the page Table points to a 4k memory page.

Is important to note that the x86_64 architecture support mixing page size.

Let's see first the structure of all entries type, and then explain the bits

### PML4 & PDPR & PD

PML4 and PDPR entry structure are identical, while the PD one has few differences. Let's start seeing the structure of the first two types: 

|63     | 62        | 51                   | 39                     | 11  ...  9 |
|-------|-----------|----------------------|------------------------|------------|
|**EXB**| Available | _Reserved must be 0_ | **Table Base Address** | Available  |


|8   ...   6 | 5     |  4      |  3      |  2      |  1      | 0     |
|------------|-------|---------|---------|---------|---------|-------|
| _Reserved_ | **A** | **PCD** | **PWT** | **U/S** | **R/W** | **P** |

Where **Table Base Address** is PDPR Table base address if the table is PML4 or the PD base address if the table is the PDPR.

Now the Page directory has few differences: 
* Bits 39 to 12 are the Page Table base address when using 4k pages, or 2 MB Memory area if the PS bit is set.
* Bits 6 and 8 must be 0
* Bit 7 (the PS) must be 1
* If we are using 2MB Pages bit 12 to 20 are reserved and must be 0. If not it will cause a #PF

### Page Table 
A page table entry structure is still similar to the one above, but it contains few more bits that can be set: 

|63     | 62    | 51         | 39                    | 11  ... 9 |
|-------|-------|------------|-----------------------|-----------|
|**EXB**| Avail | _Reserved must be 0_ | **Page Base Address** | Available |


| 8     | 7       | 6      | 5     |  4      |  3      |  2      |  1      | 0     |
|-------|---------|--------|-------|---------|---------|---------|---------|-------|
| **G** | **PAT** | **D**  | **A** | **PCD** | **PWT** | **U/S** | **R/W** | **P** |


In this table there are 3 new bits (D, PAT, G) and the Page Base Address as already explained is not pointing to a table but to a memory area. 

In the next section we will se all the fields of an entry.

### Page Table entries fields

Below is a list of all the fields present in the table entries, with an explanation of the most commonly used.

* **P** (Present): If set this tells the CPU that the current page or page table pointed by this entry is currently loaded in physical memory, so when accessed the address translation can be carried out. If is 0 this means that the page is not loaded into memory so a virtual address that contains this entry will cause a Page Fault.
* **R/W** (Read/Write): If set the page can be both read and written, if clear is in read only mode. When this bit is set in a page Directory it tells the cpu that all its entries will share that setting
* **User/Supervisor** It describe the privilege level, if clear the page has the Supervisor level, while if it is set the level is Supervisor.
* **PWT** (Page Level Write Through): controls the caching policy (writhe through or write back), i usually leave it to 0, for more information refer to the Intel Developer Manuals
* **PCD** (Page Level Cache Disable): controls the caching of individual pages or tables, i usually leave it to 0, for more information refer to the Intel Developer Manuals
* **A** (Accessed): This value is set by the CPU, if is 0 it means the page hasn't  been accessed yet. Is set when the page (or page teable) have been accessed at least once
* **D** (Dirty): Indicates if a page has been writtent to when set. This flag applies only to Page Tables. This flag and the accessed flag are provided for being use by the memory management software, the CPU only set it when it's value is 0. Otherwise is up to the Memory Maanger to decide if it has to be cleared or not.
* **PS** (Page Size): Used only on Page Directory Level, if set it indicates that the current entry point to a 2MB Page, if it is clear it means that the current entry is a 4kb page
* **PAT** (Page Attribute Table Index): It selects the PAT entry, refer to the Intel Manual for a more detailed explanation
* **G** (Global) it requires the PGE bit set in in CR4, if set it indicates that when CR3 is loaded or a task switch occurs that page-table or page directory is not invalidated.
* **EXB** is the Execute Disable bit, available only if supported by the CPU, otherwise is reserved. Refer to the intel manual for this bit.

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

Every table has 512 elements, so we have an address space of 2^512 * 2^512 * 2^512 * 0x200000 (that is the page size)

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

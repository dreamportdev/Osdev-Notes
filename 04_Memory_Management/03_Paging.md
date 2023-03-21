# Paging

## What is Paging?

Paging is a memory management scheme that introduces the concept of **_logical addresses_** (virtual address) and **_virtual memory_**. On x86_\* architectures this is achieved via hardware. Paging enables a layer of translation between virtual and physical address, and virtual and physical address spaces, as well as adding a few extra features (like access protection, priviledge level protection).

Paging introduces a few new concepts that are explained below.

### Page
A _page_ is a contiguous block of memory, of fixed size. On x86 a page is 0x1000 bytes. It represents the smallest unit the hardware memory management unit can work with, and therefore the smallest unit we can work with! Each entry in a page table describes one page.

### Page Directories and Tables

These are the basic blocks of paging. Depending on the architecture (and requested page size) there can be a different number of them. 

- For example if we are running in 32 bit mode with 4k pages we have page directory and page table. 
- If we are running in 64 bits with 4k pages we have four levels of page tables, 3 directories and 3 tables.

What are those directories and tables? Let's start from the tables: 

* **Page Table** contains the information about a single page of memory, an entry in a page table represents the starting physical memory addresss for this page. 
* **Page Directory** an entry in a page directory can point to: another page directory (depending on what type of paging we have enabled) or a page table. 

A special register, `CR3` contains the address of the root page directory. This register has the following format:

* bits from 12 to 63 (31 if we are in running a 32 bit kernel) are the address of the root page directory.
* bits 0 to 12 change their meaning depending on the value of bit 14 in CR4, but in this section and for our purpose are not relevant anyway, so they can be left as 0.

Sometimes CR3 (although technically it's just the data from bits 12+) are referred to as the PDBR, short for page directory base address.

### Virtual (or Logical) Address

A virtual address is what a running program sees. Thats any program: a driver, user application or the kernel itself. In the kernel, often a virtual address will map to the same physical address. This is called identity mapping. This is not always the case though.

A virtual address is usually a composition of entry numbers for each level of tables. The picture below shows how address translation works: 

![address_translation drawio](/Images/addrtranslation.png)


Using logical address and paging, we can introduce a new address space that can be much bigger of the available physical memory.


For example: 

```c
phys(0x12'3456) = virt(0xFFF'F234'5235)
```

In x86 this mapping is achieved through the usage of several hierarchical tables, with  each item in one level pointing to the next level table. 
A virtual address is a composition of entry number for each level of the tables. So for example assume that we have 3 levels, and 32 bits a address assuming address translation used in the picture above:

```c
virtaddress = 0x2F88'0120
```

Now we know that the bits: 

* 0 to 5 are the offset.
* 6 to 13 are the page table entry.
* 14 to 21 are the page directory level 1 entry.
* 21 to 31 are the page directory level 2 entry.

We can translate the abbove address to: 

* Offset:  0x20 bytes into page.
* Page Table entry: number 0x4 (it points to the memory page).
* Page Dir 1 entry: 0x20 (it points to a page table).
* Page Dir 2 entry: 0xBE (it points to a page dir 1).

The above example is just an imaginary translation mechanism, we'll discuss the actual x86_64 4-level paging below.

## Paging in Long Mode 

In 64 bit mode we have up to 4 levels of page tables. The number depends on the size we want to assign to each page. 
It's worth noting that newer cpus do support a feature called la57 (large addressing using 57-bits), this just adds another layer of page tables on top the existing 4 to allow for a larger address space. It's a cool feature, but not really required unless you're using crazy amounts of memory.

There are 3 possible scenarios: 

* 4kib Pages: We are going to use all 4 levels, so the address will be composed of all the 4 table entries.
* 2Mib Pages: in the case we only need 3 page levels.
* 1Gib Pages: Only 2 levels are needed.

To implement paging, is strongly reccomended to have implemented interrupts too, specifically handling #PF (vcetor 0xd).

The 4 levels of page directories/tables are: 

* the Page-Map Level-4 Table (PML4),
* the Page-Directory Pointer Table (PDPR),
* the Page-Directory Table (PD),
* and the Page Table (PT).

The number of levels depend on the size of the pages chosen. 
If we are using 4kb pages then we will have: PML4, PDPR, PD, PT, while if we go for 2mb Pages we have only PML4, PDPR, PD. 1gb pages would only use the PML4 and PDPR.

## Page Directories and Table Structure

As we have seen earlier in this section, when paging is enabled, a virtual address is translated into a set of entry numbers in different tables. In this paragraph we will see the different types available for them.

But before proceeding with the details let's see some of the characteristics common between all table/directory types: 

* The size of all table type is fixed and is 4k.
* Every table has exactly 512 entries.
* Every entry has the size of 64 bits.
* The tables have a hierarchy, and every item in a table higher in the hierachy point to a lower hierachy one (with some exceptions explained later). The page table points to a memory area. 

The hierarchy of the tables is: 

* PML4 is the root table (this is the one that is contained in the PDBR register) and is loaded for the actual address translation (see the next paragraph). Each of it's entries point a PDPR table.
* PDPR, the next level down. Each entry points to a single page directory.
* Page directory (PD): depending of the value of the PS bit (page size) an entry in this table can point to:
   * a page table if the PS bit is clear (this means we are using 4k pages)
   * 2 MB memory area if the PS bit is set 
* Page table (PT): every entry in the page table points to a 4k memory page.

Is important to note that the x86_64 architecture support mixing page sizes.
Let's have a look at the common parts between all of the entries in these tables, and look at what they mean.

### PML4 & PDPR & PD

PML4 and PDPR entry structure are identical, while the PD one has few differences. Let's begin by looking at the structure of the first two types: 

|63     | 62        | 51 ... 40            | 39 ... 12              | 11  ...  9 |
|-------|-----------|----------------------|------------------------|------------|
|**XD**| Available | _Reserved must be 0_ | **Table base address** | Available  |


|8   ...   6 | 5     |  4      |  3      |  2      |  1      | 0     |
|------------|-------|---------|---------|---------|---------|-------|
| _Reserved_ | **A** | **PCD** | **PWT** | **U/S** | **R/W** | **P** |

Where **Table base address** is a PDPR table base address if the table is PML4 or the PD base address if the table is the PDPR.

Now the page directory has few differences: 

* Bits 39 to 12 are the page table's base address when using 4k pages, or 2mb area of physical memory if the PS bit is set.
* Bits 6 and 8 must be 0.
* Bit 7 (the PS) must be 1.
* If we are using 2mb pages bit 12 to 20 are reserved and must be 0. If not, accessing address within this range will cause a #PF.

### Page Table

A page table entry structure is still similar to the one above, but it contains few more bits that can be set: 

|63     | 62    | 51 ... 40  | 39 ... 12             | 11  ... 9 |
|-------|-------|------------|-----------------------|-----------|
|**XD**| Avail | _Reserved must be 0_ | **Page Base Address** | Available |


| 8     | 7       | 6      | 5     |  4      |  3      |  2      |  1      | 0     |
|-------|---------|--------|-------|---------|---------|---------|---------|-------|
| **G** | **PAT** | **D**  | **A** | **PCD** | **PWT** | **U/S** | **R/W** | **P** |


In this table there are 3 new bits (D, PAT, G) and the page base address, as already explained, is not pointing to a table but to the physical memory this page represents.

In the next section we will go through the fields of an entry.

### Page Table Entry Fields

Below is a list of all the fields present in the table entries, with an explanation of the most commonly used.

* **P** (Present): If set this tells the CPU that this entry is valid, and can be used for translation. Otherwise translation stops here, and results in a page fault. 
* **R/W** (Read/Write): Pages are always readable, setting this flag allows writing to memory via this virtual address. Otherwise an attempt to write to memory while this bit is cleared results in a page fault. Reminder that these bits also affect the child tables. So if you mark a pml4 entry as read-only, any address that gets translated through that will be read only, even if the entries in the tables below it have this bit set.
* **User/Supervisor**: It describes the privilege level required to access this address. If clear the page has the supervisor level, while if it is set the level is user. The cpu identifies supervisor/user level by checking the CPL (current protection level, set by the segment registers). If it is less than 3 then the accesses are made in supervisor mode, if it's equal to 3 they are made in user mode.
* **PWT** (Page Level Write Through): Controls the caching policy (write-through or write-back). I usually leave it to 0, for more information refer to the Intel Developer Manuals.
* **PCD** (Page Level Cache Disable): Controls the caching of individual pages or tables. I usually leave it to 0, for more information refer to the Intel Developer Manuals.
* **A** (Accessed): This value is set by the CPU, if is 0 it means the page hasn't been accessed yet. It's set when the page (or page teble) has been accessed since this bit was last cleared.
* **D** (Dirty): If set, indicates that a page has been written to since last cleared. This flag is supposed to only apply to page tables, but some emulators will set it on other levels as well. This flag and the accessed flag are provided for being use by the memory management software, the CPU only set it when it's value is 0. Otherwise is up to the operating system's memory manager to decide if it has to be cleared or not. Ignoring them is also fine.
* **PS** (Page Size): Reserved in the pml4, if set on the PDPR it means address translation stops at this level and is mapping a 1GB page. Check for 1gb page support before using this. More commonly this can be set on the PD entry to stop translation at that level, and map a 2MB page.
* **PAT** (Page Attribute Table Index): It selects the PAT entry (in combination with the PWT and PCD bits above), refer to the Intel Manual for a more detailed explanation.
* **G** (Global): If set it indicates that when CR3 is loaded or a task switch occurs that this particular entry should not be ejected. This feature is not architectural, and should be checked for before using.
* **XD**: Also known as NX, the execute disable bit is only available if supported by the CPU (can be checked wit CPUID), otherwise reserved. If supported, and after enabling this feature in EFER (see the intel manual for this), attempting to execute code from a page with this bit set will result in a page fault.

Note about PWT and PCD, the definiton of those bits depends on whether PAT (page attribute tables) are in use or not. For a better understanding of those two bits please refer to the most updated intel documentation (is in the Paging section of the intel Software Developer Manual vol.3) 

## Address translation 

### Address Translation Using 2MB Pages

If we are using 2MB pages this is how the address will be handled by the paging mechanism:

|            |           |                     |            |              |
|------------|-----------|---------------------|------------|--------------|
| 63 .... 48 | 47 ... 39 | 38   ... 32  31  30 | 29  ..  21 | 20 19 ...  0 |
|  1 ...  1  | 1  ...  1 | 1    ... 1   1   0  | 0   ... 0  | 0  0  ...  0 |
|  Sgn. ext  |    PML4   |      PDPR           |   Page dir |    Offset    |

* Bits 63 to 48, not used in address translation.
* Bits 47 ... 39 are the PML4 entry.
* Bits 38 ... 30 are the PDPR entry.
* Bits 29 ... 21 are the PD entry.
* Offset in the page directory.

Every table has 512 elements, so we have an address space of $2^{512} * 2^{512} * 2^{512} * 0x200000$ (that is the page size)

### Address translation Using 4KB Pages
   
If we are using 4kB pages this is how the address will be handled by the paging mechanism:

|            |           |                     |            |             |              |
|------------|-----------|---------------------|------------|-------------|--------------|
| 63 .... 48 | 47 ... 39 | 38   ... 32  31  30 | 29  ..  21 | 20  ...  12 | 11 10 ...  0 |
| 1   ...  1 | 1  ...  1 | 1    ... 1   1   0  | 0   ... 0  | 0   ...  0  | 0 ...  ... 0 |
|  Sgn. ext  |    PML4   |      PDPR           |   Page dir |  Page Table |   Offset     |

* Bits 63 to 48, not used in address translation.
* Bits 47 ... 39 are the PML4 entry.
* Bits 38 ... 30 are the PDPR entry.
* Bits 29 ... 21 are the PD entry.
* Bits 20 ... 12 are the PT entry.
* Offset in the page table.

Same as above: 
Every table has 512 elements, so we have an address space of: $2^{512} * 2^{512} * 2^{512} * 2^{512} * 0x1000$ (that is the page size)

## Page Fault

A page fault (exception 14, triggers the interrupt of the same number) is raised when address translation fails for any reason. An error code is pushed on to the stack before calling the interrupt handler describing the situation when the fault occured. Note that these bits describe was what was happening, not why the fault occured. If the user bit is set, it does not necessarily mean it was a priviledge violation. The `CR2` register also contains the address that caused the fault.

The idea of the page fault handler is to look at the error code and faulting address, and do one of several things:
- If the program is accessing memory that it should have, but hasnt been mapped: map that memory as initially requested.
- If the program is attempting to access memory it should not, terminate the program. 

The error code has the following structure: 

|           |       |        |      |       |     |
|-----------|-------|--------|------|-------|-----|
| 31 .... 4 |   4   |    3   |   2  |   1   |  0  |
|  Reserved |  I/D  |  RSVD  |  U/S |  W/R  |  P  |

The meanings of these bits are expanded below:

* Bits 31...4 are reserved.
* Bit 4: set if the fault was an instruction fetch.
* Bit 3: set if the attempted translation encuntered a reserved bit being set to 1 (at *some* level in the paging structure).
* Bit 2: set if the access was a user mode access, otherwise it was supervisor mode. 
* Bit 1: set if the false was caused by a write, otherwise it was a read. 
* Bit 0: set if a protection violation caused the fault, otherwise it means translation failed due to a non present page.

## Recursion

There are few things to take in account when trying to access paging structures using the recursion technique for x86_64 architecture:

* When specifying entries using constant numbers (not stored in variables) during conversion, always use the long version appending the "l" letter (i.e. 510th entry became: 510l).
* Always remember to add the sign extension part (otherwise you will obtain a #GP).

A few examples of recursive addresses: 

* PML4: 511 (hex: 1ff) - PDPR: 510 (hex: 1fe) - PD 0 (hex: 0) using 2mb pages translates to: `0xFFFF'FFFF'8000'0000`.
* Let's assume we mapped PML4 into itself at entry 510, 
    - If we want to access the content of the PML4 page itself, using the recursion we need to build a special address using the entries: PML4: 510, PDPR: 510, PD: 510, PT: 510, now keep in mind that the 510th entry of PML4 is PML4 itself, so this means that when the processor loads that entry, it loads PML4 itself instead of PDPR, but now the value for the PDPR entry is still 510, that is still PML4 then, the table loaded is PML4 again, repat this process for PD and PT wit page number equals to 510, and we obtain access to the PML4 page itself.
    - Now using a similar approach we can get acces to other tables, for example the following values: PML4: 510, PDPR:510, PD: 1, PT: 256, will give access at the Page Directory PD at  entry number 256 in PDPR that is  contained in the first PML4 entry .

## Virtual Memory Manager

The virtual memory manager is a layer between the physical memory manager and the allocation function (slab/heap/whatever), it basically has to do only two things: 

* Given a virtual address in input it has to be mapped in the page table
* And also given a virtual address in input it has to be unmapped it from the physical location. 

The workflow should be the similar to the following: 

Allcoation function return an address --> This address is mapped to it's own page table (eventually allocating intermediate page dirs) -> Physical memory is requested.

Is not necessary to allocate physical memory immediately, but it can be handled also during the page fault. 

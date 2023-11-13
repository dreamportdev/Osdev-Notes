# Paging

## What is Paging?

Paging is a memory management scheme that introduces the concept of **_logical addresses_** (virtual address) and **_virtual memory_**. On x86_\* architectures this is achieved via hardware. Paging enables a layer of translation between virtual and physical addresses, and virtual and physical address spaces, as well as adding a few extra features (like access protection, priviledge level protection).

It introduces a few new concepts that are explained below.

### Page
A page is a contiguous block of memory, with the exact size depending on what the architecture supports. On x86_64 we have page sizes of 4K, 2M and optionally 1G. The smallest page size is also called a page frame as it represents the smallest unit the memory management unit can work with, and therefore the smallest unit we can work with! Each entry in a page table describes one page.

### Page Directories and Tables

These are the basic blocks of paging. Depending on the architecture (and requested page size) there can be a different number of them.

- For example if we are running in 32 bit mode with 4k pages we have page directory and page table.
- If we are running in 64 bits with 4k pages we have four levels of page tables, 3 directories and 1 table.

What are those directories and tables? Let's start from the tables:

* **Page Table** contains the information about a single page of memory, an entry in a page table represents the starting physical memory addresss for this page.
* **Page Directory** an entry in a page directory can point to depending on the page size selected:
    - another page directory
    - a page table
    - or memory

A special register, `CR3` contains the address of the root page directory. This register has the following format:

* bits from 12 to 63 (31 if we are in running a 32 bit kernel) are the address of the root page directory.
* bits 0 to 12 change their meaning depending on the value of bit 14 in CR4, but in this chapter and for our purpose are not relevant anyway, so they can be left as 0.

Sometimes CR3 (although technically it's just the data from bits 12+) is referred to as the PDBR, short for Page Directory Base address.

### Virtual (or Logical) Address

A virtual address is what a running program sees. Thats any program: a driver, user application or the kernel itself.

Sometime in the kernel, a virtual address will map to the same physical address, this scenario it is called `identity mapping`, but this is not always the case though, we can also have the same physical address that maps to different virtual addresses.

A virtual address is usually a composition of entry numbers for each level of tables. The picture below shows, with an example, how address translation works:

![Address Translation](/Images/addrtranslation.png)

The _memory page_ in the picture refers to a physical memory page (the picture above doesn't refer to any existing hardware paging, is just an example scenario). Using logical address and paging, we can introduce a whole new address space that can be much bigger of the available physical memory.


For example we can have that:

```c
phys(0x123'456) = virt(0xFFF'F234'5235)
```

Meaning that the virtual address `0xFFFF2345235` refers to the phyisical address `0x123456`.

This mapping is usually achieved through the usage of several hierarchical tables, with each item in one level pointing to the next level table. As already mentioned above a virtual address is a composition of _entry numbers_ for each level of the tables. Now let's assume for example that we have 3 levels paging, 32 bits addressing and the address translation mechanism used is the one in the picture above, and we have the virtual address below:

```c
virtaddress = 0x2F880120
```

Looking at the picture above we know that the bits:

* _0 to 5_ represent the offset (for offset we mean what location we want to access within the physical memory page).
* _6 to 13_ are the page table entry.
* _14 to 21_ are the page directory level 1 entry.
* _21 to 31_ are the page directory level 2 entry.

We can translate the above address to:

* Offset:  0x20 bytes into page.
* Page Table entry: number 0x4 (it points to the memory page).
* Page Dir 1 entry: 0x20 (it points to a page table).
* Page Dir 2 entry: 0xBE (it points to a page dir 1).

The above example is just an imaginary translation mechanism, we'll discuss the actual `x86_64` 4-level paging below. If we are wondering how the first page directory can be accessed, this will be clear later, but the answer is that there is usually a special register that contains the base address of the root page directory (in this example page dir 1).

## Paging in Long Mode

In 64 bit mode we have up to 4 levels of page tables. The number depends on the size we want to assign to each page.
It's worth noting that newer cpus do support a feature called _la57_ (large addressing using 57-bits), this just adds another layer of page tables on top the existing 4 to allow for a larger address space. It's a cool feature, but not really required unless we're using crazy amounts of memory.

There are 3 possible scenarios:

* 4kib Pages: We are going to use all 4 levels, so the address will be composed of all the 4 table entries.
* 2Mib Pages: in this case we only need 3 page levels.
* 1Gib Pages: Only 2 levels are needed.

To implement paging, is strongly reccomended to have already implemented interrupts too, specifically handling #PF (vector 0xd).

The 4 levels of page directories/tables are:

* the Page-Map Level-4 Table (PML4),
* the Page-Directory Pointer Table (PDPR),
* the Page-Directory Table (PD),
* and the Page Table (PT).

The number of levels depend on the size of the pages chosen.
If we are using `4Kib` pages then we will have: PML4, PDPR, PD, PT, while if we go for `2Mib` Pages we have only PML4, PDPR, PD, and finally `1Gib` pages would only use the PML4 and PDPR.

## Page Directories and Table Structure

As we have seen earlier in this chapter, when paging is enabled, a virtual address is translated into a set of entry numbers in different tables. In this paragraph we will see the different types available for them on the `x86_64` architecture.

But before proceeding with the details let's see some of the characteristics common between all table/directory types:

* The size of all table type is fixed and is 4k.
* Every table has exactly 512 entries.
* Every entry has the size of 64 bits.
* The tables have a hierarchy, and every item in a table higher in the hierachy point to a lower hierachy one (with some exceptions explained later). The page table points to a memory area.

The hierarchy of the tables is:

* PML4 is the root table (this is the one that is contained in the PDBR register) and is loaded for the actual address translation (see the next paragraph). Each of its entries point a PDPR table.
* PDPR, the next level down. Each entry points to a single page directory.
* Page directory (PD): depending of the value of the PS bit (page size) an entry in this table can point to:
   * a page table if the PS bit is clear (this means we are using 4k pages)
   * 2 MB memory area if the PS bit is set
* Page table (PT): every entry in the page table points to a 4k memory page.

Is important to note that the x86_64 architecture support mixing page sizes.

In the following paragraphs we will have a look with more detail at how the paging is enabled and the common parts between all of the entries in these tables, and look at what they mean.

### Loading the root table and enable paging

Until now we have explained how address translation works now let's see how the Root Table is loaded (in `x86_64` is PML4), this is done by loading the special register `CR3`, also known as `PDBR`, we introduced it at the beginning of the chapter, and is contents is basically the base address of our PML4 table. This can be easily done with two lines of assembly:

```x86asm
   mov eax, PML4_BASE_ADDRESS
   mov cr3, eax
```

The first `mov` is needed because `cr3` can be loaded only from another register. Keep in mind that in order to enter long mode we should have already paging enabled, so the first page tables should be loaded very early in the boot process. Once enabled we can change the content of `cr3` to load a new addressing space.

This can be done using inline assembly too:

```c
void load_cr3( void* cr3_value ) {
    asm volatile("mov %0, %%cr3" :: "r"((uint64_t)cr3_value) : "memory");
}
```

The inline assembly syntax will be explained in one of the appendices chapter: [C Language Info](../99_Appendices/C_Language_Info.md). The `mov` into a register here is hidden, by the label `"r"` in front of the variable `cr3_value`, this label indicates that the variable value should be put into a register.

The bits that we need to set to have paging enabled in long mode are, in order, the: `PAE` Page Address Extension, bit number 5 in CR4, the `LME` Long Mode Enable Bit (Bit 8 in EFER, and has to be loaded with the `rdmsr`/`wrmsr` instructions), and finally the `PG` Paging bit number 31 in `cr0`.

Every time we need to change a value of a system register, `cr*`, and similar we must always load the current value first and update its content, otherwise we can run into troubles. And finally the Paging bit must be the last to be enabled.

Setting those bits must be done only once at early stages of boot process (probably one of the first thing we do).


### PML4 & PDPR & PD

PML4 and PDPR entry structures are identical, while the PD one has few differences. Let's begin by looking at the structure of the first two types:

|63     | 62        | 51 ... 40            | 39 ... 12              | 11  ...  9 |
|-------|-----------|----------------------|------------------------|------------|
|**XD**| Available | _Reserved must be 0_ | **Table base address** | Available  |


|8   ...   6 | 5     |  4      |  3      |  2      |  1      | 0     |
|------------|-------|---------|---------|---------|---------|-------|
| _Reserved_ | **A** | **PCD** | **PWT** | **U/S** | **R/W** | **P** |

Where **Table base address** is a PDPR table base address if the table is PML4 or the PD base address if the table is the PDPR.

Now the Page Directory (PD) has few differences:

* Bits 39 to 12 are the page table's base address when using 4k pages, or 2mb area of physical memory if the PS bit is set.
* Bits 6 and 8 must be 0.
* Bit 7 is the Page Size bit (PS) if set it means that the entry points to a 2mb page, if clear it points to a Page Table (PT).
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

### Page Table/Directory Entry Fields

Below is a list of all the fields present in the table entries, with an explanation of the most commonly used.

* **P** (Present): If set this tells the CPU that this entry is valid, and can be used for translation. Otherwise translation stops here, and results in a page fault.
* **R/W** (Read/Write): Pages are always readable, setting this flag allows writing to memory via this virtual address. Otherwise an attempt to write to memory while this bit is cleared results in a page fault. Reminder that these bits also affect the child tables. So if a pml4 entry is marked as read-only, any address that gets translated through that will be read only, even if the entries in the tables below it have this bit set.
* **User/Supervisor**: It describes the privilege level required to access this address. If clear the page has the supervisor level, while if it is set the level is user. The cpu identifies supervisor/user level by checking the CPL (current protection level, set by the segment registers). If it is less than 3 then the accesses are made in supervisor mode, if it's equal to 3 they are made in user mode.
* **PWT** (Page Level Write Through): Controls the caching policy (write-through or write-back). I usually leave it to 0, for more information refer to the Intel Developer Manuals.
* **PCD** (Page Level Cache Disable): Controls the caching of individual pages or tables. I usually leave it to 0, for more information refer to the Intel Developer Manuals.
* **A** (Accessed): This value is set by the CPU, if is 0 it means the page hasn't been accessed yet. It's set when the page (or page teble) has been accessed since this bit was last cleared.
* **D** (Dirty): If set, indicates that a page has been written to since last cleared. This flag is supposed to only apply to page tables, but some emulators will set it on other levels as well. This flag and the accessed flag are provided for being use by the memory management software, the CPU only set it when its value is 0. Otherwise is up to the operating system's memory manager to decide if it has to be cleared or not. Ignoring them is also fine.
* **PS** (Page Size): Reserved in the pml4, if set on the PDPR it means address translation stops at this level and is mapping a 1GB page. Check for 1gb page support before using this. More commonly this can be set on the PD entry to stop translation at that level, and map a 2MB page.
* **PAT** (Page Attribute Table Index) only for the page table: It selects the PAT entry (in combination with the PWT and PCD bits above), refer to the Intel Manual for a more detailed explanation.
* **G** (Global): If set it indicates that when CR3 is loaded or a task switch occurs that this particular entry should not be ejected. This feature is not architectural, and should be checked for before using.
* **XD**: Also known as NX, the execute disable bit is only available if supported by the CPU (can be checked wit CPUID), otherwise reserved. If supported, and after enabling this feature in EFER (see the intel manual for this), attempting to execute code from a page with this bit set will result in a page fault.

Note about PWT and PCD, the definiton of those bits depends on whether PAT (page attribute tables) are in use or not. For a better understanding of those two bits please refer to the most updated intel documentation (is in the Paging section of the intel Software Developer Manual vol.3)

## Address translation

### Address Translation Using 2MB Pages

If we are using 2MB pages this is how the address will be handled by the paging mechanism:

|            |           |               |            |           |
|------------|-----------|---------------|------------|-----------|
| 63 .... 48 | 47 ... 39 | 38   ...   30 | 29  ..  21 | 20 ...  0 |
|  1 ...  1  | 1  ...  1 | 1    ...    0 | 0   ... 0  | 0  ...  0 |
|  Sgn. ext  |    PML4   |      PDPR     |   Page dir |   Offset  |

* Bits 63 to 48, not used in address translation.
* Bits 47 ... 39 are the PML4 entry.
* Bits 38 ... 30 are the PDPR entry.
* Bits 29 ... 21 are the PD entry.
* Offset in the page directory.

Every table has 512 elements, so we have an address space of $2^{512}*2^{512}*2^{512}*0x200000$ (that is the page size)

### Address translation Using 4KB Pages

If we are using 4kB pages this is how the address will be handled by the paging mechanism:

|           |           |           |           |             |           |
|-----------|-----------|-----------|-----------|-------------|-----------|
| 63 ... 48 | 47 ... 39 | 38 ... 30 | 29 ... 21 | 20  ...  12 | 11 ...  0 |
| 1  ...  1 | 1  ...  1 | 1  ... 0  | 0  ... 0  | 0   ...  0  | 0  ... 0  |
|  Sgn. ext |    PML4   |   PDPR    |  Page dir |  Page Table |   Offset  |

* Bits 63 to 48, not used in address translation.
* Bits 47 ... 39 are the PML4 entry.
* Bits 38 ... 30 are the PDPR entry.
* Bits 29 ... 21 are the PD entry.
* Bits 20 ... 12 are the PT entry.
* Offset in the page table.

Same as above:
Every table has 512 elements, so we have an address space of: $2^{512}*2^{512}*2^{512}*2^{512}*0x1000$ (that is the page size)

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

## Accessing Page Tables and Physical Memory

### Recursive Paging

One of the problems that we face while enabling _paging_ is of how to access the page directories and table, in case we need to access them, and especially when we need to map a new physical address.

There are two ways to achieve it:

* Having all the phyisical memory mapped somewhere in the virtual addressing space (probably in the _Higher Half_, in this case we should be able to retrieve all the tables easily, by just adding a prefix to the physical address of the table.
* Using a tecnique called _recursion_, where access the tables using special virtual addresses.

To use the recursion the only thing we need to do, is reserve an entry in the _root_ page directory (`PML4` in our case) and make its base address to point to the directory itsef.

A good idea is to pick a number high enough, that will not interfer with other kernel/hardware special addresses. For example let's use the entry `510` for the recurisve item

Creating the self reference is pretty straightforward, we just need to use the directory physical address as the base address for the entry being created:

```c
pml4[510l] = pml4_physical_address | PRESENT | WRITE;
```

This should be done again when setting up paging, on early boot stages.

Now as we have seen above address translation will split the `virtual address` in entry numbers for the different tables, starting from the leftmost (the root). So now if we have for example the following address:

```c
virt_addr = 0xff7f80005000
```

The entries in this address are: 510 for PML4, 510 for PDPR, 0 for PD and 5 for PT (we are using 4k pages for this example).  Now let's see what appens from the point of view of the address translation:

* First the `510th` PML4 entry is loaded, that is the pointer to the PDPR, and in this case its content is PML4 itself.
* Now it get the next entry from the address, to load the PD, that is again the `510th`, and is again PML4 itself, so it is loaded as PD too.
* It is time for the third entry the PT, and in this case we have `0`, so it loads the first entry from the Page Directory loaded, that in this case is still PML4, so it loads the PDPR table
* Finally the PT entry is loaded, that is `5`, and since the current PD loaded for translation is actually a PDPR we are going to get the `5th` item of the page directory.
* Now the last part of the address is the offset, this can be used then to access the entries of the directory/table loaded.

This means that by carefully using the recursive item from PML4 we can access all the tables.

Few more examples of address translation:

* PML4: 511 (hex: 1ff) - PDPR: 510 (hex: 1fe) - PD 0 (hex: 0) using 2mb pages translates to: `0xFFFF'FFFF'8000'0000`.
* Let's assume we mapped PML4 into itself at entry 510,
    - If we want to access the content of the PML4 page itself, using the recursion we need to build a special address using the entries: _PML4: 510, PDPR: 510, PD: 510, PT: 510_, now keep in mind that the 510th entry of PML4 is PML4 itself, so this means that when the processor loads that entry, it loads PML4 itself instead of PDPR, but now the value for the PDPR entry is still 510, that is still PML4 then, the table loaded is PML4 again, repat this process for PD and PT with page number equals to 510, and we got access to the PML4 table.
    - Now using a similar approach we can get acces to other tables, for example the following values: _PML4: 510, PDPR:510, PD: 1, PT: 256_, will give access at the Page Directory PD at entry number 256 in PDPR that is contained in the first PML4 entry.

This technique makes it easy to access page tables in the current address space, but it falls apart for accessing data in other address spaces. For that purpose, we'll need to either use a different technique or switch to that address space, which can be quite costly.

### Direct Map

Another technique for modifying page tables is a 'direct map' (similar to an identity map). As we know an identity map is when a page's physical address is the same as its virtual address, and we could describe it as: `paddr = vaddr`. A direct map is sometimes referred to as an _offset map_ because it introduces an offset, which gives us some flexibility. We're using to have a global variable containing the offset for our map called `dmap_base`. Typically we'll set this to some address in the higher half so that the lower half of the address space is completely free for userspace programs. This also makes other parts of the kernel easier later on.

How does the direct map actually work though? It's simple enough, we just map all of physical memory at the same virtual address *plus the dmap_base offset*: `paddr = vaddr - dmap_base`. Now in order to access a physical page (from our PMM for example) we just add `dmap_base` to it and we can read and write to it as normal.

The direct map does require a one-time setup early in your kernel, as you do need to map all usable physical memory starting at `dmap_base`. This is no more work than creating an identity map though.

What address should you use for the base address of the direct map? Well you can put it at the lowest address in the higher half, which depends on how many levels of page tables you have. For 4 level paging this will `0xffff'8000'0000'0000`.

While recursive paging only requires using a single page table entry at the highest level, a direct map consumes a decent chunk of address space. A direct map is also more flexible as it allows the kernel to access arbitrary parts of physical memory as needed, . Direct mapping is only really possible in 64-bit kernels due to the large address space made available, 32-bit kernels should opt to use recursive mapping to reduce the amount of address space used.

The real potential of this technique will unveil when we have multiple address spaces to handle, when the kernel may need to update data in different address spaces (especially the paging data structures), in this case using the direct map it can access any data in any address space, by only knowing its physical address. It will also help when we will start to work on device drivers (out of the scope of this book) where the kernel may need to access the DMA buffers, that are stored by their physical addresses.

### Troubleshooting

There are few things to take in account when trying to access paging structures using the recursion technique for `x86_64` architecture:


* When specifying entries using constant numbers (not stored in variables) during conversion, always use the long version appending the "l" letter (i.e. 510th entry became: 510l). Especially when dealing with macros, because otherwise they could be converted to the wrong type, causing wrong result. Usually `gcc` show a warning message while compiling if this happens:

```gcc
 warning: result of ‘510 << 30’ requires 40 bits to represent, but ‘int’ only has 32 bits
 ```

* Always remember to properly sign extend any addresses if we're creating them from nothing. We won't need to sign extend on every operation, as things are usually relative to a pointer we've already set up. The CPU will throw a page fault if it's a good address but something is wrong in the page tables, and a general protection fault if the virtual address is non-canonical (it's a bad address).

# Executable Linker Format

## ELF Overview

The *executable and linker file* (ELF) is an open standard for programs, libraries and shards of code and data that are waiting to be linked. It's the most common format used by linux and BSD operating systems, and sees some use elsewhere. It's also the most common format for programs in hobby operating systems as it's quite simple to implement and it's public specification is feature-complete.

That's not to say ELF is the *only* format for these kinds of files (there are others like PE/portable execute, a.out or even mach-o), but the ELF format is the best for our purposes. A majority of operating systems have come to a similar to conclusion. We could also use our own format, but be aware this requires a compiler capable of outputting it (meaning either write our own compiler, or modify an existing one - a lot of work!).

This chapter won't be too heavy on new concepts, besides the ELF specification itself, but will focus on bringing everything together. We're going to load a program in a new process, and run it in userspace. This is typically how most programs run, and then from there we can execute a few example system calls.

It should be noted that the original ELF specification is for 32-bit programs, but a *64-bit extension* was created later on called ELF64. We'll be focusing on ELF64.

It's worth having a copy of the ELF specification as a reference for this chapter as we won't define every structure required. The specification doesn't use fixed width types in its definiton, instead using `words` and `half words`, which are based on the word size of the cpu. For the exact definition of these terms we will need the platform-specific part of the ELF spec, which gives concrete types for these.

For `x86_64` these types are defined as follows:

```c
typedef uint64_t Elf64_Addr;
typedef uint64_t Elf64_Off;
typedef uint16_t Elf64_Half;
typedef uint32_t Elf64_Word;
typedef int32_t Elf64_Sword;
typedef uint64_t Elf64_Xword;
typedef int64_t Elf64_Sxword;
typedef uint8_t Elf64_UnsignedChar;
```

All structs in the base ELF spec are defined using these types, and so we will use them too. Note that their exact definitions *will* change depending on the target platform.

## Layout Of An ELF

The format has four main sections:

- *The ELF header*: This contains the magic number used to identify it as an ELF, as well as information about the architecture the ELF was compiled for, the target operating system and other useful info.
- *The data blob*: The bulk of the file is made up of this blob. This is a big binary blob containing code, all kinds of data, some string tables and sometimes debugging information. All program data lives here.
- *Section headers*: Each header has a name and some metadata associated with it, and describes a region of the data blob. Section names usually begin with a dot (`.`), like `.strtab` which refers to the string table. Section headers are for other software to parse the ELF and understand its structure and contents.
- *Program headers*: These are for the program loader (what we're going to write). Each program header has a type that tells the loader how to interpret it, as well as specifying a range within the data blob. These ranges in the data blob can overlap (or often cover the same area as some section header ranges) ranges described by section headers.

Within the ELF specification section headers and program headers are often abbreviated to *SHDRs* and *PHDRs*. In a real file the data blob is actually located after the section and program headers.

## Section Headers

Section headers describe the ELF in more detail and often contain useful (but not required for running) data. We won't be dealing with section headers at all in our program loader, since everything we need is nicely contained in the program headers.

Having said that, if we're curious about what's inside the rest of the ELF file, tools like `objdump` or `readelf` can parse and display section headers for us. They're also documented thoroughly in the ELF specification.

There are a few special section headers worth knowing about, even if we dont use them right now:

- `.text`, `.rodata`, `.data`, and `.bss`: These usually map directly to the program headers of the same name. Since section headers contain more information than program headers, there is often some extra information stored here about these sections. This is not needed by a program loader so it's not present in the PHDRs.
- `.strtab`: Short for *string table*, this section header is a series of null-terminated strings. The first entry in this table is also a null-terminator. When other sections need to store a string they actually store a byte offset into this section.
- `.symtab`: Short for *symbol table*, this section contains all the exported (and internal) symbols for the program. This section may also include some debugging symbols if compiling with `-g` or they may be stored under a `.debug_*` section. If we ever need to get symbols for a program, they'll be here.

Often there will be other section headers in a program, serving specific purposes. For example `.eh_frame` is used for storing language-based exception and unwinding information, and if there are any global constructors, the `.ctors` section may be present.

## Program Headers

While section headers contain a more granular description of our ELF binary, program headers contain just enough information to load the program. Program headers are designed to be simple, and by extension allow the program loader to be simple.

The layout of a `PHDR` is as follows:

```c
typedef struct {
    Elf64_Word p_type;
    Elf64_Word p_flags;
    Elf64_Off p_offset;
    Elf64_Addr p_vaddr;
    Elf64_Addr p_paddr;
    Elf64_Xword p_filesz;
    Elf64_Xword p_memsz;
    Elf64_Xword p_align;
} Elf64_Phdr;
```

The meaning of all these fields is explained below when we look at how actually loading a program header. The most important field here is `p_type`: this tells the program loader what it should do with this particular header. A full list of types is available in the ELF spec, but for now we only need one type: `PT_LOAD`.

Finding the program headers within an ELF binary is also quite straightforward. The offset of the first phdr is given by the `phoff` (program header offset) field of the ELF header.

Like section headers, each program header is tighly packed against the next one. This means that  program headers can be treated as an array. As an example is possible to loop through the _phdrs_ as follows:

```c
void loop_phdrs(Elf64_Hdr* ehdr) {
    Elf64_Phdr* phdrs = *(Elf64_Phdr*)((uintptr_t)ehdr + ehdr->e_phoff);

    for (size_t i = 0; i < ehdr->e_phnum; i++)
    {
        Elf64_Phdr* program_header = phdrs[i];
        //do something with program_header here.
    }
}
```

## Loading Theory

For now we're only interested in one type of phdr: `PT_LOAD`. This constant is defined in the elf64 spec as `1`.

This type means that we are expected to load the contents of this program header at a specified address before running the program. Often there will be a few headers with this type, with different permissions (to map to different parts of our program: `.rodata`, `.data`, `.text` for example).

To load our simple, statically-linked, program the process is as follows:

1) Load the ELF file in memory somewhere.
2) Validate the ELF header by checking the machine type matches what we expect (is this an x86_64 program?).
3) Find all program headers with the `PT_LOAD` type.
4) Load each program header: we'll cover this shortly.
5) Jump to the start address defined in the ELF header.

Do note that these are just the steps for loading the ELF, there are actually other things we'll need like a stack for the program to use. Of course this is likely covered when we create a new thread for the program to run.

### Loading A Program Header

Loading a program header is essentially a memcpy. The program header describes where we copy data from (via `p_offset` and `p_filesz`), and where we copy it to (via `p_vaddr` and `p_memsz`).

Like the program headers are located `e_phoff` bytes into the ELF, it's the same with `p_offset`. We can copy from `p_offset` bytes from the base of the ELF file. From that address we'll copy `p_filesz` bytes to the address contained in `p_vaddr` (virtual address). There's an important detail that's easy to miss with the copy: we are expected to make `p_memsz` bytes available at `p_vaddr`, even if `p_memsz` is bigger than `p_filesz`. The spec says that this extra space (`p_memsz` - `p_filesz`) should be zeroed.

This is actually how the `.bss` section is allocated, and any pre-zeroed parts of an ELF executable are created this way.

Before looking at some example code our VMM will need a new function that tries to allocate memory at a *specific* virtual address, instead of whatever is the best fit. For our example we're going to assume the following function is implemented (according to the chosen design):

```c
void* vmm_alloc_at(uintptr_t addr, size_t length, size_t flags);
```

Alternatively the in `vmm_alloc` function we can make use of the `flag` parameter, and add a new flag like `VM_FLAG_AT_ADDR` that indicates the VMM should use the extra arg as the virtual address. Bear in mind that if we're loading a program into another address space we will need a way to copy the phdr contents into that address space. The specifics of this don't matter too much, as long as there is a way to do it.

The reason we need to use a specific address is that the code and data contained in the ELF are compiled and linked assuming that they're at that address. There might be code that jumps to a fixed address or data that is expected to be at a certain address. If we don't copy the program header where it expects to be, the program may break.

*Authors Note: Relocations are another way of dealing with the problem of not being able to use the requested virtual address, but these are more advanced. They're not hard to implement, certainly easier than dynamic linking, but still beyond the scope of this chapter.*

Now that we have that, lets look at the example code (without error handling, as always):

```c
void load_phdr(Elf64_EHdr* ehdr, Elf64_Phdr* phdr) {
    if (phdr->p_type != PT_LOAD)
        return;

    void* dest = vmm_alloc_at(phdr->p_vaddr, phdr->p_memsz, VM_FLAG_WRITE);
    memcpy(dest, (void*)ehdr + phdr->p_offset, phdr->p_filesz);

    const zero_count = phdr->p_memsz - phdr->p_filesz;
    memset(dest + phdr->p_filesz, 0, zero_count);
}
```

### Program Header Flags

At this point we've got the program header's content loaded in the correct place. We'll run into an issue if we try to use the loaded program header in this state: we've mapped all program headers in virtual memory as read/write/no-execute. This means if we try to execute any of the headers as code (and at least one of them is guarenteed to be code), we'll fault. Some of these headers should be read-only, and some (in the case of code) should be readable and executable.

While everything could be mapped  as *read* + *write* + *execute*, that's not recommended for security reasons. It can also lead to bugs in programs, and potentially cause crashes.

Each program header stores what permissions it requires in the `p_flags` field. This field is actually a bitfield, with the following definition:

- `Bit 0`: Represents whether a phdr should be executable. Remember that the executable flag is backwards on x86: all memory can be executed by default, unless the NX bit is set. Ideally this should be hidden behind the VMM interface.
- `Bit 1`: Indicates a region should be writable, the region is read-only if this bit is clear.
- `Bit 2`: Indicates  a region should be readable. This bit should always be set, as exec-only or write-only memory is not very useful, and some hardware platforms will consider these states as an error.

We´ll also want to adjust the permissions of the mapped memory *after copying the program header content*. This is because we will need the memory to be mapped as writable so the CPU lets us copy the `phdr` content into it, and then the permissions can be adjusted to what the program header requested.

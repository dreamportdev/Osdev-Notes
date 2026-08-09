# Executable and Linkable Format

The *executable and linkable format* is an open standard for programs, libraries, object files waiting to be linked. It's flexible enough that it's been adapted over time as new technologies have come about, while remaining backwards compatible. It's also the default format for most open operating systems.

That's not to say ELF is the only format available, there are others like mach-o or portable executable (PE), but these are intended for use with their associated operating systems - so there can be some friction when using them elsewhere. We'll be using ELF as it's the most suitable for our purposes.

There is also the option of using our own custom file format, but that presents more challeneges, like adding support for it to our compiler and linker (or even writing our own!), and possibly other parts of the toolchain. This approach is not recommended.

## ELF Specifications

- how to get them

Jumping into the elf64 specification might seem confusing as it contains a lot of definitions but doesn't explain what to do with them. It's because elf64 is treated as an extension to the original elf specification (now referred to as elf32). The elf32 spec contains more descriptions and sets out how the mechanical parts of ELF work. So it's best to look at the original ELF document for the details, but keep in mind any changes made in the elf64 extension. These changes are limited to re-arranging structure layouts and updating the types used.

There is one more part of ELF that we'll need for the complete picture: the platform-specific spec. This is sometimes referred to as the *ps-abi* (platform specific ABI). Because different architectures like to run code in different ways, ELF leaves room in some areas for the cpu architecture to define certain details. These parts of the specification are obvious and we'll know when we need to consult the ps-abi. Since we're targeting x86_64, we're interested in the x86_64 elf ps-abi. 

Armed with these three documents we can begin to look at the format itself!

### ELF Data Types

The ELF specifications define some basic types used throughout the rest of the specification. We're also going to define them, so we can reference them later, it's important to note that these types have different definitions in elf32 and elf64. Since we are targeting x86_64, we're going to use the elf64 versions. 

```c
typedef uint64_t Elf64_Addr;
typedef uint64_t Elf64_Off;
typedef uint16_t Elf64_Half;
typedef uint32_t Elf64_Word;
typedef int32_t Elf64_Sword;
typedef uint64_t Elf64_Xword;
typedef int64_t Elf64_Sxword;
typedef unsigned char Elf64_UChar;
```

ELF64 also specifies an alignment for all of these types, however it's the types naturally alignment, which any reputable compiler should take care of. If we wanted to be pedantic we could add the alignment info to those types ourselves with `__attribute__((aligned(your_alignment_here)))` before the type name (remember this is a gcc/clang compiler extension).

### Abstracting Away the Specifics
- if you want to support both (or think you might, use a macro for the types) - np-syslib ref

## Parts of an ELF file

At a high level an ELF can have up to four main parts: the ELF header, an array of section headers, an array of program headers, and then space for the data referred to by those headers. There's not much to say about the data area, it's simply storage space for the data referred to by the section/program headers.

### ELF Header

The start of a valid ELF file contains the ELF header, which gives us high level info about the file. All of this info should be validated to be correct for the machine the program is being loaded on.

Let's take a look at the layout of the ELF header, and some associated magic numbers.

```c
struct Elf64_Ehdr
{
    Elf64_UChar e_ident[16];
    Elf64_Half e_type;
    Elf64_Half e_machine;
    Elf64_Word e_version;
    Elf64_Addr e_entry;
    Elf64_Off e_phoff;
    Elf64_Off e_shoff;
    Elf64_Word e_flags;
    Elf64_Half e_ehsize;
    Elf64_Half e_phentsize;
    Elf64_Half e_phnum;
    Elf64_Half e_shentsize;
    Elf64_Half e_shnum;
    Elf64_Half e_shstrndx;
};

#define EI_MAG0 0
#define EI_MAG1 1
#define EI_MAG2 2
#define EI_MAG3 3
#define EI_CLASS 4
#define EI_DATA 5
#define EI_VERSION 6
#define EI_OSABI 7
#define EI_ABIVERSION 8
```

*Authors note: the names given to the magic numbers from the ELF specs are constructed in a way that makes them easy to figure out. For example EI_CLASS is the _E_lf header struct, _I_dent field and then the value of CLASS. Another example is EM_X86_64, which is _E_lf header, _M_achine field, with a value for x86_64.*

Starting with the `e_ident` field: this is an array of values describing what environment the ELF is intended for and a magic number to verify this is an ELF. The first 4 elements of the `e_ident` array (`EI_MAG0` to `EI_MAG3`) should be `{ 'E', 'L', 'F', 0x77 }`.

### Sections

### Segments

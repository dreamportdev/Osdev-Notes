# Linker Scripts
If you've never done any kind of low level programming before, it's unlikely you've had to deal with linker scripts. Your compiler will provide a default one for your cpu and operating system. Most of the time this is exactly what you need, however since we are the operating system, we'll need our own!

A linker script is just a description of the final linked binary. It tells the linker how you want the various bits of code and data from your compiled source files (currently they're unlinked object files) to be laid out in the final executable.

For the rest of this section we'll assume you're using *elf* as your file format. If you're building a UEFI binary you'll need to use PE/COFF+ instead, and that's a separate beast of it's own. There's nothing x86 specific here, but it was written with x86 in mind, other architectures may have slight differences. We also reference some fields of structs, these are described very plainly in the elf64 base specification.

## Anatomy of a Script
A linker script is made up of 4 main areas:

- **Options**: A collection of options that can be set within the linker, to change how the output binary is generated. These normally take the form `OPTION_NAME(VALUE)`.
- **Memory**: This tells the linker what memory is available, and where, on the target device. If absent the linker assumes RAM starts at 0 and covers all memory addresses. This is what we want for x86, so this section is usually not specified.
- **Program Headers**: Program headers are specific to the elf format. They describe how the data of the elf file should be loaded into memory before it is run.
- **Sections**: These tell the linker how to map the sections of the object files into the final elf file.

These sections are commonly placed in the above order, but don't have to be.

Since the memory section doesn't see too much use on x86, it's not explained here, the ld and lld manuals cover this pretty well.

### LMA (Load Memory Address) vs VMA (Virtual Memory Address)
Within the sections area of the linker script, sections are described using two address. They're defined as:

- Load Memory Address: This is where the section is to be loaded.
- Virtual Memory Address: This is where the code is expected to be when run. Any jumps or branches in your code, any variable references are linked using this address. 

Most of the time these are the same, however this is not always true. One use case of setting these to separate values would be creating a higher half kernel that uses the multiboot boot protocol. Since mb leaves you in protected mode with paging disabled, you can't load a higher half kernel, as no one would have enough physical memory to have physical addresses in the range high enough.

So instead, you load the kernel at a lower physical memory address (by setting LMA), run a self-contained assembly stub that is linked in it's own section at a lower VMA. This stub sets up paging, and jumps to the higher half region of code once paging and long mode are setup. Now the code is at the address it expects to be in, and will run correctly, all done within the same kernel file.

### Adding Symbols
If you're not familiar with the idea of a symbol, it's a lower level concept that simply represents *a thing* in your program. 
A symbol has an address, and some extra details to describe it. These details tell you if the symbol is a variable, the start of a function, maybe a label from assembly code, or even something else. It's important to note that when being used in code, a symbol **is** the address associated with it.

You can think of a symbol as a pointer. 

Why is this useful though? Well we can add symbols to the linker script, and the linker will ensure any references to that symbol in our code point to the same place. That means we can now access info that is only known by the linker, such as where the code will be stored in memory, or how big the read-only data section in our kernel is.

Although not useful on x86, on some embedded platforms physical RAM does not start at address 0. These platforms usually don't have an  equivilent to the bios/uefi. Since you would need a different linker script for each of those platforms anyway, you could also include a symbol that tells your kernel where physical ram starts, and how much of it is available, letting your code remain more generic.

Keep reading to see how we use symbols later in the example makefile.

## Program Headers
A program header can be seen as a block of *stuff* that the program loader will need in order to load the program properly. What this *stuff* is, and how it should be interpreted depend on the `p_type` field of a program header. This field can contain a number of values, the common ones being:

| Name       | Value | Description |
|------------|-------|-------------|
| PT_NULL    | 0     | Just a placeholder, a null value. Does nothing. |
| PT_LOAD    | 1     | Means this program header describes that should be loaded, in orer for the program to run. The flags specify read/write/execute permissions. |
| PT_DYNAMIC | 2     | Advanced use, for dynamically linking functions into a program or relocating a program when it is loaded. |
| PT_INTERP  | 3     | A program can request a specific progam loader here, often this is just the default for the operating system. |
| PT_NOTE    | 4     | Contains non-useful data, often the linker name and version. |

Modern linkers are quite clever, and will often deduce which program headers are needed, but it never hurts to specify these yourself. For a freestanding kernel you will need at least threee program headers, all of type PT_LOAD:

- text, with execute and read permissions.
- rodata, with only the read permission.
- data, with both read and write permissions.

*But what about the bss, and other zero-initialized data?* Well that's stored in the data program header. Program headers have two variables for their size, one is the file size and the other is their memory size. If the memory size is bigger than the file size, that memory is expected to be zeroed (as per the elf spec), and thus the bss can be placed there!

### Example
An example of what a program headers section might look like:

```
/* This declares our program headers */
PHDRS
{
    text   PT_LOAD;
    rodata PT_LOAD;
    data   PT_LOAD;
}
```

This example is actually missing the flags field that sets the permissions, but modern linkers will see these common names like `text` and `rodata` and give them default permissions.

Of course, you can (and in best practice, should) set them manually:

```
PHDRS
{
    /* flags bits: 0 = execute, 1 = write, 2 = read */
    text   PT_LOAD FLAGS((1 << 0) | (1 << 2));
    rodata PT_LOAD FLAGS((1 << 2));
    data   PT_LOAD FLAGS((1 << 1) | (1 << 2));
}
```

## Sections
While program headers are a fairly course mechanism for telling the program loader what it needs to do in order to get our program running, sections allow us a lot of control over how the code and data within those areas is arranged.

### The '.' Operator
When working with sections, we'll want to control where sections are placed in memory. We can use absolute addresses, however this means we'll need to update the linker script manually everytime things change in size. Enter the dot operator (`.`), it represents the current VMA (remember this is the runtime address). 

The linker will automatically increment this when placing sections, and the current vma is read/write, so we have complete control over this process if we want.

Often simply setting it at the beginning (before the first section) is enough, like so:

```
SECTIONS
{
    . = 0xFFFFFFFF80000000;
    /* section descritions go here */
}
```

If you're wondering why most higher half kernels are loaded at this address, it's because it's the upper-most 2GB of the 66-bit address space

### Incoming vs Outgoing Sections
A section description has 2 parts: incoming sections (all your object files), and how they are placed into outgoing sections (the final output file).

Let's consider the following example:

```
.text :
{
    *(.text*)
    /* ... more input sections ... */
} :text
```

First we give this output section a name, in this case it's `.text`. To the right of the colon is where we would place any extra attributes for this section or override the LMA. By default the LMA will be the same as the VMA, but if you need you can override it here, with something like `.text : AT(0x1234)`. The text section would now have the VMA of 0 unless we've overriden it like before, but LMA of 0x1234. Unless you know you need to change the LMA, let this part empty like the example.

Next up we have a number of lines describing the input sections, with the format `FILES(INPUT_SECTIONS)`. In this case we want all files, so we use the wildcard '*', and then all sections from those files that begin with ".text", so we make use of the wildcard again.

After the closing brace is where we tell the linker what program header this section should be in, in this case its the `text` phdr. The program header name is prefixed with a colon in this case.

## Common Options

`ENTRY()`: Tells the linker which symbol should be used as the entry point for the program. This defaults to `_start`, but can be set to whatever function or label you want your program to start.

`OUTPUT_FORMAT()`: Tells the linker which output format to use. For x86_64 elf, you would want "elf64-x86-64", however this can be inferred from by the linker, and is not usually necessary.

`OUTPUT_ARCH()`: Like OUTPUT_FORMAT, this is not necessary most of the time, but it allows for specifying the target cpu architecture, used in the elf header. This can safely be omitted.

## Complete Example
To illustrate what a more complex linker script for an x86 elf kernel might look like:

```
OUTPUT_FORMAT(elf64-x86-64)
ENTRY(kernel_entry_func)

PHDRS
{
    /* bare minimum: code, data and rodata phdrs. */
    text   PT_LOAD FLAGS((1 << 0) | (1 << 2));
    rodata PT_LOAD FLAGS((1 << 2));
    data   PT_LOAD FLAGS((1 << 1) | (1 << 2));
}

SECTIONS
{
    /* start linking at the -2GB address. */
    . = 0xffffffff80000000;
    
    /* text output section, to go in 'text' phdr */
    .text :
    {
        /* we can use these symbols to work out where */
        /* the .text section ends up at runtime. */
        /* Then we can map those pages appropriately. */
        TEXT_BEGIN = .;
        *(.text*)
        TEXT_END = ,;
    } :text

    /* a trick to ensure the section next is on the next physical */
    /* page so we can use different page protection flags (r/w/x). */
    . += CONSTANT(MAXPAGESIZE);

    .rodata : 
    {
        RODATA_BEGIN = .;
        *(.rodata*)
        RODATA_END = .;
    } :rodata

    . += CONSTANT(MAXPAGESIZE);

    .data : 
    {
        DATA_BEGIN = .;
        *(.data*)
    } :data

    .bss :
    {
        /* COMMON is where the compiler places it's internal symbols */
        *(COMMON)
        *(.bss*)
        DATA_END = .;
    } :data

    /* we can use the '.' to determine how large the kernel is. */
    KERNEL_SIZE = . - 0xffffffff80000000;
}
```

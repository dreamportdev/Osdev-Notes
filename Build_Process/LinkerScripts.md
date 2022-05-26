# Linker Scripts
If you've never done any kind of low level programming before, it's unlikely you've had to deal with linker scripts. Your compiler will provide a default one for your cpu and operating system. Most of the time this is exactly what you need, however since we are the operating system, we'll need our own!

A linker script is just a description of the final linked binary. It tells the linker how you want the various bits of code and data from your compiled source files (currently they're unlinked object files) to be laid out in the final executable.

For the rest of this section we'll assume you're targetting x86, and are using elf as your file format. If you're building a UEFI binary you'll need to PE/COFF+ as per the spec, and that's a separate thing.

## Anatomy of a Script
A linker script is made up of 4 main area:
- **Options**: A collection of options that can be set within the linker, to change how the output binary is generated. 
- **Memory**: This tells the linker what memory is available, and where, on the target device. Is absent the linker assumes RAM starts at 0 and covers all memory addresses. This is what we want for x86, so this section is usually absent.
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
A symbol has an address, and usually some extra details that describe it. These details tell you if the symbol is a variable, the start of a function, maybe a label from assembly code, or even something else. It's important to note that when being used in code, a symbol **is** the address associated with it.

You can think of a symbol as a pointer. 

Why is this useful though? Well we can add symbols to the linker script, and the linker will ensure any references to that symbol in our code point to the same place. That means we can now access info that is only known by the linker, such as where the code will be stored in memory, or how big the read-only data section in our kernel is.

Although not useful on x86, on some embedded platforms physical RAM does not start at address 0. These platforms usually don't have an  equivilent to the bios/uefi. Since you would need a different linker script for each of those platforms anyway, you could also include a symbol that tells your kernel where physical ram starts, and how much of it is available, letting your code remain more generic.

Keep reading to see how we use symbols later in the example makefile.

## Program Headers

## Sections

## Common Options

`ENTRY()`: Tells the linker which symbol should be used as the entry point for the program. This defaults to `_start`, but can be set to whatever function or label you want your program to start.

`OUTPUT_FORMAT()`: Tells the linker which output format to use. For x86_64 elf, you would want "elf64-x86_64", however this can be inferred from by the linker, and is not usually necessary.

`OUTPUT_ARCH()`: Like OUTPUT_FORMAT, this is not necessary most of the time, but it allows for specifying the target cpu architecture, used in the elf header.

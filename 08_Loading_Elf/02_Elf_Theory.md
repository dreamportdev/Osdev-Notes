# Executable Linker Format

The executable and linker format (ELF) is a multi-purpose format: it can be used to store compiled (but not linked) object files, as well as fully linked programs/dynamic libraries.

The format has four main sections:

- The ELF header. This contains the magic number used to identify it as an ELF, as well as information about the architecture the ELF was compiled for, the target operating system and other useful info.
- The data blob. The bulk of the file is made up of this blob. This is a big binary blob containing code, all kinds of data, some string tables and sometimes debugging information. All program data lives here.
- Section headers. Each header has a name and some metadata associated with it, and describes a region of the data blob. Section names usually begin with a dot (`.`), like `.strtab` which refers to the string table. Section headers are for other software to parse the ELF and understand it's structure and contents.
- Program headers. These are for the program loader (what we're going to write). Each program header has a type that tells the loader how to interpret it, as well as specifying a range within the data blob. These ranges in the data blob can overlap (or often cover the same area as some section header ranges) ranges described by section headers.

Within the ELF specification section headers and program headers are often abbreviated to SHDRs and PHDRs. In a real file the data blob is actually located after the section and program headers.

## Section Headers

We won't be dealing with a lot of section headers, as the program loader is mainly interested in program headers. However there are some core SHDRs you should be aware of.

- special shdrs
- how to parse a shdr, 

## Program Headers

## Loading Theory

- validate header
- find all PT_LOAD headers, copy those in
- you're good!

# The Tar File System

In the previous chapter we have implemented the VFS layer. that will provide us with a common interface to access files and directories across different file systems on different devices. In this chapter we are going to implement our first file system and try to access it's content using the VFS function. As already anticipated we will implement the (US)TAR format.

## Introduction

The Tar (standing for Tape ARchive)  format is not a file system (sorry i lied!), it is a a unix's tape archive format. and the acronym USTar is used to identify the posix standard version of it. Although is not a real fs it can be easily used as one in read-only mode. 

It was first released on 1979 in Version 7 Unix, there are different tar formats (including historical and current ones) two are codified into standards: *ustar* (the one we will implement), and "pax", also still widely used but not standardized there is the GNU Tar format. 

A *tar* archive consists of a series of file objects, and each one of them includes any file of data and is preceded by a fixed size header (512 bytes) record, the file data is written as it is, but its size is rounded to a multiple of 512 bytes. Usually the padding bytes are filled extra zeros. The end of an archived is marked by at least two consecutive zero filled records.

## Implementation

To implement it we just need: 

* The header structure that represent a record (each record is a file object item)
* A function to lookup the file witin the archive
* Implement a function to open a file and read it's content.

### The Header

As anticipated above, the header structure is a fixed size struct of 512 bytes. It contains some information about the file, and they are placed just before the file start. The list below contains all the fields that are present in the structure: 

| Offset | Size |  Field     |
|--------|------|------------|
| 0   | 100	| File name |
| 100 | 8 	| File mode (octal) |
| 108 | 8 	| Owner's numeric user ID (octal) |
| 116 | 8 	| Group's numeric user ID (octal) |
| 124 | 12 	| File size in bytes (octal) |
| 136 | 12 	| Last modification time in numeric Unix time format (octal) |
| 148 | 8 	| Checksum for header record |
| 156 | 1 	| Type flag |
| 157 | 100 | Name of linked file |
| 57  | 6 	| UStar indicator, "ustar", then NULL |
| 263 | 2 	| UStar version, "00" |
| 265 |	32 	| Owner user name |
| 297 |	32 	| Owner group name |
| 329 |	8 	| Device major number |
| 337 |	8 	| Device minor number |
| 345 |	155 | Filename prefix |

To ensure portability all the information on the header are encoded in `ASCII`, so we can use the `char` type to store the information into those fields. Every record has a `type` flag, that says what kind of resource it represent, the possible values depends on the type of tar we are supporting, for the `ustar` format the possible values are: 

| Value | Meaning |
|-------|---------|
| '0'   | (ASCII Null)  Normal file |
| '1'   | Hard link |
| '2'   | Symbolic link | 
| '3'   | Character Special Device |
| '4'   | Block device |
| '5'   | Directory |
| '6'   | Named Pipe |

The _name of linked file_ field refers to symbolic links in the unix world, when a file is a link to another file, that field containes the value of the target file of the link.

The USTar indictator (containing the string `ustar` followed by NULL), and the version field are used to identify the format being used, and the version field value is "00". 

The `flename prefix` field, present only in the `ustar`, this format allows for longer file names, but the it is splitted into two parts the `file name` field ( 100 byteS) and the `filename prefix` field (155 bytes)

The other fields are either self-explanatory (like uid/gid) or can be left as 0 (TO BE CHECKED) the only one that needs more explanation is the `file size` field because it is expressed in octal format encoded in ASCII, so we need a function that converts an ascii octal into an decimal integer: 

```c
``` 



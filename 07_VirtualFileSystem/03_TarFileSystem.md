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

The _name of linked file_ field refers to symbolic links in the unix world, when a file is a link to another file, that field contains the value of the target file of the link.

The USTar indictator (containing the string `ustar` followed by NULL), and the version field are used to identify the format being used, and the version field value is "00". 

The `flename prefix` field, present only in the `ustar`, this format allows for longer file names, but the it is splitted into two parts the `file name` field ( 100 byteS) and the `filename prefix` field (155 bytes)

The other fields are either self-explanatory (like uid/gid) or can be left as 0 (TO BE CHECKED) the only one that needs more explanation is the `file size` field because it is expressed in octal format encoded in ASCII, so we need to convert an ascii octal into a decimal integer, an `octal` number is a number represetend in base 8, that means that we can use digits from 0 to 7 to represent number (is like binaries that use only 0 and 1 or hexadecimals that use from 0 to F). So for example:

```
octal 12 = hex A = bin 1010
```

In C an octal number is represented adding a `0` in front of the number, so for example 0123 is 83 in decimal.

But that's not all, we also have that the number is represented as an `ascii` characters, so to get the decimal number we need to: 

1. Convert each ansii digit into decimal, this should be pretty easy to do, since in the ascii table the digits are placed in ascending order starting from 0x30 ( `´0'` ), to get the digit we need just to subrstract the `ascii` code for the 0 to the char supplied
2.  To obtain the decimal number from an octal we need to multiply each digit per `8^i` where i is the digit position (rightmost digit is 0) and sum their results. For example 37 in octal is: 

```c
037 = 3 * 8^1 + 7 * 8^0 = 31
```

Remember we ignore the first 0 because it tells C that it is an octal number (and also it doesn't add any value to the final result!), since we are writing an os implementing this function should be pretty easy, so this will be left as exercise, we will just assume that we have the following function available to convert octal ascii to decimal: 


```c
int octascii_to_dec(char *number, int size);
```

The size parameter tells us how many bytes is the digit long, and in the case of a tar object record the size is fixed: 12 bytes.

### Searching for a file

Since the tar format doesn't have any file table or linked lists, or similar to search for files, we need everytime to start from the first record and scan one after each other, if the recordi is found we will return the pointer to it, otherwise we will eventually reach the end of the archive (file system in our cose) meaning that the file searched is not present. 

The picture below show how data is stored into a tar archive. 


![Tar Archive](/Images/tar.png)



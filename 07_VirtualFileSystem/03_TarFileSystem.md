# The Tar File System

In the previous chapter we have implemented the VFS layer. that will provide us with a common interface to access files and directories across different file systems on different devices. In this chapter we are going to implement our first file system and try to access it's content using the VFS function. As already anticipated we will implement the (US)TAR format.

## Introduction

The Tar (standing for Tape ARchive)  format is not a file system (sorry i lied!), it is a a unix's tape archive format. and the acronym USTar is used to identify the posix standard version of it. Although is not a real fs it can be easily used as one in read-only mode. 

It was first released on 1979 in Version 7 Unix, there are different tar formats (including historical and current ones) two are codified into standards: *ustar* (the one we will implement), and "pax", also still widely used but not standardized is the GNU Tar format. 

A *tar* archive consists of a series of file objects, and each one of them includes any file of data and is preceded by a fixed size header (512 bytes) record, the file data is written as it is, but its size is rounded to a multiple of 512 bytes. Usually the padding bytes are filled extra zeros. The end of an archived is marked by at least two consecutive zero filled records.

## Implementation

To implement it we just need: 

* The header structure that represent a record (each record is a file object item)
* A function to lookup the file within the archive
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

The `filename prefix` field, present only in the `ustar`, this format allows for longer file names, but it is splitted into two parts the `file name` field ( 100 bytes) and the `filename prefix` field (155 bytes)

The other fields are either self-explanatory (like uid/gid) or can be left as 0 (TO BE CHECKED) the only one that needs more explanation is the `file size` field because it is expressed  as an octal number encoded in ASCII. This means we need to convert an ascii octal into a decimal integer. Just to remind, an `octal` number is a number represetend in base 8, we can use digits from 0 to 7 to represent it (is like binaries that use only 0 and 1 or hexadecimals that use from 0 to F). So for example:

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

The size parameter tells us how many bytes is the digit long, and in the case of a tar object record the size is fixed: 12 bytes. Since we just need to implement a data structure for the header, this is left as exercise. Let's assume just that a new type is defined with the name `tar_record`.


### Searching for a file

Since the tar format doesn't have any file table or linked lists, or similar to search for files, we need everytime to start from the first record and scan one after each other, if the record is found we will return the pointer to it, otherwise we will eventually reach the end of the archive (file system in our case) meaning that the file searched is not present. 

The picture below show how data is stored into a tar archive. 


![Tar Archive](Images/tar.png)

To move from the first header to the next we simply need to use the following formula:

$$ next\_header = header\_ptr + header\_size + file\_size $$

The lookup function then will be in the form of a loop.  But how to tell if we have reached the end of the archive? As mentioned above, if there are two or more zero-filled records, it indicated the end. So while searching, we need to make sure that we keep track of the number of zeroed records. The main lookup loop should be similar to the following pseudo-code:

```c 
int zero_counter = 0;
while (zero_counter < 2) {
    if (is_zeroed(current_record) ) {
        zero_counter++;
        continue;
    }
    zero_counter = 0;
    //lookup for file or load next record if not found
}
```

The `is_zeroed` function is a helper function that we should implement, as the name suggest it should just check that the current record is full of zeros, the implementation is left as an exercise. Within the loop now we just need to search for the file requested, the tricky part here is that we can have two scenarios:

* The filename length is less than 100 bytes, in this case it is stored into the `file_name` field
* The length is greater than 100 bytes (up to 256) so in this case the filename is split in two parts, the first 100 bytes goes into the `file_name` field, the rest goes into the `filename_prefix` field. 

An easy solution is to check first the searched filename length, if it less than 100 characters, so we can use just the `file_name` field, otherwise we can merge the two fields and compare than with the searched filename. The updated loop pseudo-code should look similar to this: , 

```c

char tar_filename[256];
int zero_counter = 0;
//The starting address should be known somehow to the OS)
tar_record current_record = tar_fs_start_address; 
while (zero_counter < 2) {
    if (is_zeroed(current_record) ) {
        zero_counter++;
        continue;
    }
    zero_counter = 0;
    if ( strlen(searched_file) > 100) {
        // We need to merge the two strings;
        sprintf(tar_filename, "%s%s", tar_record.file_prefix, tar_record.file_name);
    }
    uint64_t file_size = octascii_to_dec(current_record.file_size, 12); 
    current_record = current_record + sizeof(tar_header) + file_size;
}
```


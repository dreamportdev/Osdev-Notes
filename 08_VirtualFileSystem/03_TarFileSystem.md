# The Tar File System

In the previous chapter we have implemented the VFS layer. That will provide us with a common interface to access files and directories across different file systems on different devices. In this chapter we are going to implement our first file system driver and try to access its content using the VFS function. As already anticipated we will implement the (US)TAR format.

## Introduction

The Tar (standing for Tape ARchive) format is not technically a file system, rather it's an archive format which stores a snapshot of a filesystem. The acronym USTar is used to identify the posix standard version of it. Although is not a real fs it can be easily used as one in read-only mode.

It was first released on 1979 in Version 7 Unix, there are different tar formats (including historical and current ones) two are codified into standards: *ustar* (the one we will implement), and "pax", also still widely used but not standardized is the GNU Tar format.

A *tar* archive consists of a series of file objects, and each one of them includes any file of data and is preceded by a fixed size header (512 bytes) record, the file data is written as it is, but its size is rounded to a multiple of 512 bytes. Usually the padding bytes are filled extra zeros. The end of an archived is marked by at least two consecutive zero filled records.

## Implementation

To implement it we just need:

* The header structure that represent a record (each record is a file object item).
* A function to lookup the file within the archive.
* Implement a function to open a file and read its content.

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
| 263 | 2 	| UStar version, "00" (it is a string) |
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

The other fields are either self-explanatory (like uid/gid) or can be left as 0 (TO BE CHECKED) the only one that needs more explanation is the `file size` field because it is expressed  as an octal number encoded in ASCII. This means we need to convert an ascii octal into a decimal integer. Just to remind, an `octal` number is a number represetend in base 8, we can use digits from 0 to 7 to represent it, similar to how binary (base 2) only have 0 and 1, and hexadecimal (base 16) has 0 to F. So for example:

```
octal 12 = hex A = bin 1010
```

In C an octal number is represented adding a `0` in front of the number, so for example 0123 is 83 in decimal.

But that's not all, we also have that the number is represented as an `ascii` characters, so to get the decimal number we need to:

1. Convert each ascii digit into decimal, this should be pretty easy to do, since in the ascii table the digits are placed in ascending order starting from 0x30 ( `´0'` ), to get the digit we need just to subrstract the `ascii` code for the 0 to the char supplied
2.  To obtain the decimal number from an octal we need to multiply each digit per `8^i` where i is the digit position (rightmost digit is 0) and sum their results. For example 37 in octal is:

```c
037 = 3 * 8^1 + 7 * 8^0 = 31
```

Remember we ignore the first 0 because it tells C that it is an octal number (and also it doesn't add any value to the final result!), since we are writing an os implementing this function should be pretty easy, so this will be left as exercise, we will just assume that we have the following function available to convert octal ascii to decimal:


```c
size_t octascii_to_dec(char *number, int size);
```

The size parameter tells us how many bytes is the digit long, and in the case of a tar object record the size is fixed: 12 bytes. Since we just need to implement a data structure for the header, this is left as exercise. Let's assume just that a new type is defined with the name `tar_record`.


### Searching For A File

Since the tar format doesn't have any file table or linked lists, or similar to search for files, we need everytime to start from the first record and scan one after each other, if the record is found we will return the pointer to it, otherwise we will eventually reach the end of the archive (file system in our case) meaning that the file searched is not present.

The picture below show how data is stored into a tar archive.


![Tar Archive](/Images/tar.png)

To move from the first header to the next we simply need to use the following formula:

$$ next\_header = header\_ptr + header\_size + file\_size $$

The lookup function then will be in the form of a loop. The first thing we'll need to know is when we've reached the end of the archive. As mentioned above, if there are two or more zero-filled records, it indicated the end. So while searching, we need to make sure that we keep track of the number of zeroed records. The main lookup loop should be similar to the following pseudo-code:

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
uint64_t tar_file_lookup(const char *filename) {
    char tar_filename[256];
    int zero_counter = 0;
    //The starting address should be known somehow to the OS
    tar_record *current_record = tar_fs_start_address;
    while (zero_counter < 2) {
        if (is_zeroed(current_record) ) {
            zero_counter++;
            continue;
        }
        zero_counter = 0;
        if ( tar_record->filename_prefix[0] != 0) {
            // We need to merge the two strings;
            sprintf(tar_filename, "%s%s", current_record->file_prefix, current_record->file_name);
        } else {
            strcpy(tar_filename, current_record->file_prefix);
        }
        if ( strcmp(tar_filename, searched_file) == 0) {
            // We have found the file, we can return wheter the beginning of data, or the record itself
        }
        uint64_t file_size = octascii_to_dec(current_record.file_size, 12);
        current_record = current_record + sizeof(tar_header) + file_size;
    }
    // If the while looop finish it means we have not found the file
}
```

The above code outlines what are the steps required to lookup for a file, the `searched_file` variable is the file we are looking for. With the function above now we are able to tell the vfs that the file is present and it can be opened. How things are implemented depends on design decisions, for example there are many paths we can take while implementing functions for opening a file on a fs:

* We can just keep a list of opened files like the VFS
* We can lookup the file and return the address of where it starts to the vfs, so the read will know where to look for it.
* We can map the file content somewhere in the memory

These are just few examples, but there can be different options. In this guide we are going to simply return the location address of starting position of the file to the VFS layer, the driver will not keep track of opened files, and also we assume that the tar fs is fully loaded into memory. In the real world we probably will need a more complex way to handle stuff, because file systems will be stored on different devices, and will unlikely be fully loaded into memory.

With the assumptions above, we already have all that we need for opening the file, from a file system point of view, it could be useful just to create a open function to eventually handle the extra parameters passed by the vfs:

```c
uint64_t ustar_open(const char* filename, int flags);
```

The implementation is left as exercise, since it just calling the `tar_lookup` and returning its value. Of course this function can be improved, and we can avoid creating a wrapper function, and use the lookup directly, but the purpose here was just to show how to search for a file and make it available to the vfs.

### Reading From A File

Reading from a file depends again on many implementation choices, in our scenario things are very easy, since we decided to return the address of the tar record containing the file, So what we need to access the file content are at least:

* A handle to access the content of the file
* How many bytes we want to read

In our case the handler is the pointer to the file, so to read it we just need to copy the number of bytes we want into the buffer passed as parameter to the vfs read function, So our `ustar_read` will need three parameters: a pointer, the number of bytes and the buffer where we want the data placed.

```c
ssize_t ustar_read(uint64_t file_handle, const char *buffer, size_t nbytes);
```

The function should be easy to write, we just need to convert the file handle to a pointer, and copy nbytes of it into the buffer, we can use just a strncpy or similar for it (if we have implemented it).

There is only one problem, since we have the pointer to the start of the file, every time the function is called will return the first n-bytes of it, and this is not what we want since read keeps track of the previously read data, and alway start from the first byte not accessed yet. This can be easily solved in the VFS layer since it keeps track of the last byte read, in this case we just need to add the number of bytes read to the file start address.

There is another problem: how do we know when we have reached the end of the file. This can be handled by the vfs, since in our case the list of opened files contains both information: current read position and the file size, so if `buf_read_pos + nbytes > filesize` we need to adjust the nbytes variable to `filesize - buf_read_pos` (filesize and buf_read_pos are the field of field_descriptor_t data structure).

### Closing A File

In our scenario there is no really need to close a file from a fs driver point of view, so in this case everything is done on the VFS layer. But in other scnearios, where we are handling opened filesi n the VFS, or keeping track of their status, it could be necessary to unmap/unload the file or the data structures associated to it.

## And Now from A VFS Point Of View

Now that we have a basic implementation of the tar file system we need to make it accessible to the VFS layer. To do we need to do two things: load the filesystem into memory and populate at least one mountpoint_t item. Since techincally there are no fs loaded yet we can add it as the first item in our list/array. We have seent the `mountpoint_t` type already in the previous chapter, but let's review what are the fields available in this data structure:

* The file system name (it can be whatever we want).
* The mountpoint (is the folder where we want to mount the filesystem), in our case since we have not mountpoints loaded, a good idea will be to mount it at "/".
* The file_operations field, that will contain the pointer to the fs functions to open/read/close/write files, in this field we are going to place the fs driver function we just created..

The file_operation field will be loaded as follows (this is according to our current implemeentation):

* The open function will be the ustar_open function.
* The read function will be the ustar_read function.
* We don't need a close function since we can handle it directly in the VFS, so we will set it to NULL.
* As well as we don't need a write function since our fs will be read only, so it can be set to NULL.

Loading the fs in memory instead will depend on the booting method we have chosen, since every boot manager/loader has its different approach this will be left to the boot manager used documentation.

#### Example loading a ramfs using multiboot2

Just as an example let's see how to load a tar archive into memory, to make it available to our kernel. The first thing of course will be creating the tar archive with the files/folder we want to add to it, for example let's assume we want to add two files: `README.md` and `example.txt`:

```
tar cvf examplefs.tar README.md example.txt
```

Then if we are going to create an ISO using grub-mkrescue, we must make sure that this file will be copied into the image. Once done, we need to update the grub menu entry configuration, adding the tar file as a module using the `module2` keyword: (refer to the _Boot Protocols_ paragraph for more information on the boot process):

```
menuentry "My Os" {
    multiboot2 /boot/kernel.bin // Path to the loader executable
    module2 /examplefs.tar
    boot
    // More modules may be added here
    // in the form 'module <path> "<cmdline>"'
}
```

The module path is the where the file is placed in the iso. Make sure that the `module2` commands is after the `multiboot2` line. Now when the kernel is loaded, we should have a new boot information item passed to the kernel (like the framebuffer, and acpi), the tag structure is:

```
        +-------------------+
u32     | type = 3          |
u32     | size              |
u32     | mod_start         |
u32     | mod_end           |
u8[n]   | string            |
        +-------------------+
```

The type is just a numeric id to identify the tag, the size is the file size. `mod_start` and `mod_end` are the phsyical address of the start and end of the module. The string is an arbitrary string associated with the module. How to parse the multioot information tags is explained in the _Boot Protocols_ chapter.

Once parsed the tag above, we now need to map the memory range from `mod_start` to `mod_end` into our virtual memory, and then the archive is ready to be accessed by the driver at the virtual address specified.

Now after parsing the information above

## Where To Go From Here

In this chapter we have tried to outline the implementation of an example file system to be used with our vfs layer. We have left many things unimplemented, or with a naive implementation.

For example: every time we lookup for a file we need to scan the list first until we find the file (if it exists), and for every item we need to compute the next file address, convert the size from ascii octal to decimal, lookup for the end file system (checking for two consecutive zeroes record) in case the file doesn't exist. This can be improved by populating a list with all the files present in the file system, keeping track of the informations needed for lookup/read purposes. We can add a simple struct like the following:

```c
struct tar_list_item {
    char filename[256];
    void *tar_record_pointer;
    size_t file_size
    int type;
    struct tar_list_item* next;
};
```

And using the new datatype initalize the list accordingly.

Now when the file system is accessed for the first time we can initalize this list, and use it to search for the files, saving a lot of time and reasources, and it can makes things easier to for the lookup and read function.

Another limitation of our driver is that it expects for the tar to be fully loaded into memory, while we know that probably file system will be stored into an external device, so a good idea is to make the driver aware of all possible scenarios.

And of course we can implement more file systems from here.

There is no write function too, it can be implemented, but since it has many limitations it is not really a good idea.

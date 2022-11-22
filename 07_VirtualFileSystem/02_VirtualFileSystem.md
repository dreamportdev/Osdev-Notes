# VirtualFS

## Overview

Nowadays there are many OSes available for many different hardware architectures, and probably there are even more file systems. One of the problems for the OS is to provide a generic enough interface to support as many file systems as possible, keeping also easy implementing new ones, this is where the VFS layer comes to aid, in this chapter we are going to see in detail how it works, and make a basic implementation of it. 
To keep our design simple the features of our VFS driver will be: 

* Fixed number of mountpoints using an array
* Support only the following functions: `open, read, write, close, opendir, readdir, closedir, stat`
* No extra features like permissions, uid and gid (although we are going to add those fields, they will not be used)
* The path length will be limited

## How does VFS works

The basic concept of a VFS layer is pretty simple, we can see it like a common way to access files/directories across different file systems, it is a layer that sits between the higher level interface to the FS and the low level implementation of the FS driver.

![Where the VFS sits in an OS](/Images/vfs_layer.png)

[SHOULD I ADD SOMETHING MORE?]

 How the different fs presented to the end user depends on design decisions for example windows operating systems wants to keep different file systems logically separated using unit letters, while unix/linux systems represents them under the same tree, so a folder can be either on the same FS or on another one, but in both cases the idea is the same, we want to use the same functions to read/write files on them. 

In this guide we will follow a unix approach. To better understand how does it works let's have a look at this picture: 

![Vfs Example Tree](/Images/vfs_tree_example.png)

It shows a portion of a unix directory tree (starting from root), the gray circle represents actual file systems, while the white ones are directories. 

So for example: 

* /home/userA point to a folder into the File System that is loaded at the "/" folder (we say that it's *mounted*)
* /mnt/ext_device instead points to a file that is mounted within the /mnt folder

When a file system is *mounted* in a folder it means that the folder is no longer a container of other files/directories for the same filesystem but is referring to another file systems somewhere else (it can be a network drive, external device, an image file, etc.) and the folder takes the name of *mountpoint*

Every mountpoint, will contain the information on how to access the target file system, so the VFS every time it has to access a file or directory (i.e. a `open` function is called), it does the following:

* Parse the file path to identify the mountpoint of the File System
* Once identified, it get access to the data structure holding all information on how to access it, this structure usually contains the pointer to the functions to open, write files, create dir, etc.
* It call the open function for that FS passing the path to the filename (in this case the path should be relative)
* From this point everything is handled by the File System Driver and once the file is accessed is returned back to the vfs layer

The multi-root approach, even if it is different, it share the same behaviour, the biggest difference is that instead of having to parse the path searching for a mountpoint it has only to check the first item in the it to figure out which FS is attached to. 

This is in a nutshell a very high level overview of how the Virtual File System wokrs, in the next paragraphs we will go in more in details and explain all the steps involved and see how to add mountpoints, how to open/close files, read them. 

## The VFS in details

Finally we are going to write our implementation of the virtual file system, followed by an example driver (**spoiler alert**: the tar archive format), in this section we will see how to: 

* load and unload a file system (mount/umount) 
* open and close a file
* read/write it's content 
* open, read and close a directory

### Loading a file system

To be able to access the different file systems currently lodaed (*mounted*) by the operating system it needs to keep track of where they are loaded (wheter it is a drive letter or a directory), and how to access them (implementation functions), to do that we need two things: 

* A data structure to store all the information related to the loaded File System
* A list/tree/array of all the file system currently loaded by the os 

As we anticipated earlier this chapter we are going to use an array to keep track of the mounted file systems, even if it has several limitations and probably a tree is the best choice, we want to focus on the implementation details of the VFS without having to write/explain also the tree-handling functions. 

We just said that we need a data structure to keep track of the information of a mounted file system, but what we need to keep track? Let's see what we need to store: 

1. The type of the filesystem, the user/os sometimes needs to know what fs is used for a specified mountpoint
2. The folder where it is mounted, this is how we are going to identify the correct mountpoint while accessing a file
3. How to access the driver, this field can vary widely depending on how is going to be implemented, but the basic idea is to provide access to the functions to read/write files, directories, etc. We will implement them later in the chapter for now we will assume they are already available within a data type called `fs_operations_t` (it will be another data structure).

Let's call this new structure `mountpoint_t` and start to fill in some fields: 

```c
#define VFS_TYPE_LENGTH 32
#define VFS_PATH_LENGTH 64
struct {

    char type[VFS_TYPE_LENGTH];
    char mountpoint[VFS_TYPE_LENGTH];

    fs_operations_t operations;

} mountpoint_t;

typedef struct mountpoint_t mountpoint_t;
```

The next thing is to declare an array with this new data structure, that is going to contain all the mounted filesystem, and will be the first place where we will look whenever we want to access a folder or a file: 

```c
#define MAX_MOUNTPOINTS 12
mountpoint_t mountpoints[MAX_MOUNTPOINTS];
```

This is all that we need to keep track of the mountpoints.


### Mounting and umounting

Now that we have a representation of a mountpoint, is time to see how to mount a file system. By mounting we mean making a device/image/network storage able to be accessed by the operating system on a target folder (the `mountpoint`) loading the driver and the target device. 

Usually a mount operation requires a set of minimum three parameters: 

* A File System type, it is needed to load the correct driver for accessing the file system on the target device.
* A target folder (that is the folder where the file system will be accessible by the OS) 
* The target device (in our simple scenario this parameter is going to be mostly ignored since the os will not support any i/o device)

There can be others of course configuration parameters like access permission, driver configuration attributes, etc. For now we haven't implemented a file system yet (we will do soon), but let's assume that our os has a driver for the `USTAR` fs (the one we will implement later), and that the following functions are already implemented: 

```c
int ustar_open(char *path, int flags);
int ustar_close(int ustar_fd);
void ustar_read(int ustar_fd, void *buffer, size_t count);
int close(int ustar_fd)
``` 

For the mount and umount operation we will need two functions: 

* The first one for mounting, let's call it for example `vfs_mount`, to work it will need at least the parameters explained above: 

```c
int vfs_mount(char *device, char *target, char *fs_type);
```

Once called it will simply add a new item in the mountpoint on the first available position, and will populate the data mountpoint data structure with the information provided, for example using the array approach, if a free spot is found at index `i` to add a new file sytem we will have something like: 

```c
mountpoints[i].device = device;
mountpoints[i].tpye = type;
mountpoints[i].mountpoint = target;
mountpoints[i[.operations = NULL 
```

the last line will be populated soon, for now let's leave it to null. 

* The second instruction is for umounting, in this case since we are just unloading the file device from the system, we don't need to know what type is it, so technically we need either the target device or the target folder, the function can actually accept both parameters, but use only one of them, let's call it `vfs_umount`: 

```c
int vfs_umount(char *device, char *targe);
```

In this case we need to find the item in the list that contains the required file system, and if found remove it from the list/tree. In our case since we are using an array we need to clear all the fields in the array at the position containing our fs. 

One thing that we should keep in mind is that using an array, once we umount a file system we are just marking that position as available again, so this means that it can be in the middle of the array, and there can be mounted file system after, so we need to keep in mind this while searching for the next free mouuntpoint.

#### A short diversion: the initialization

When the kernel first boot up, of course there is no file system mounted, and all data structures are not allocated, if we decide to use a linked list for example, before the initialization the pointer will point to nothing (or better to garbage) so we will need to allocate the first item of the list to have the first fs accessible. 

In our case since we are using an array we need just to clean all the items in it order to make sure the kernel will not be tricked into thinking that there is a FS loaded, and we need an index pointer to know what is the position of the first available file system.

But where should be the first file system mounted? That again is depending on the project decisions:

* Using a single root approach, the first file system will be mounted on the "/" folder, and this is what we are going to do, this means that all other file systems will be going to stay into subfolders of the root folder. 
* Using a multi root approach, like windows os, we will have every fs that will have it's own root folder and it will be identified with a letter (A, B, C...)
* Nothing prevent us to use different approaches, or a mix of them, we can have some file system to share the same root, while some other to have different root, this totally depends on design decision. 

One last thing about the initialization, since our kernel is loaded fully in memory, we don't actually need to have a file system mounted for the kernel to run (even if probably in the future we will need one) so the initialization is just optional to be done during boot time, if the the os already has a kind of shell we can initialize it on the first mount when it will be called. 

#### Finding the correct mountpoint

Now that we know how to handle the mountpoints, we need to understand how given a path find the correct route toward the right mountpoint. Depending on the approach how a path is defined can vary slightly: 

* if we are using a single root approach we will have a path in the form of: `/path/to/folder/and/file`
* if we are using a multi-root approach the the path will be similar to: `<device_id>/path/to/folder/and/file` (where device_id is what identify the file system to be used, and the device, what it is depend on the os, it can be a letter, a number, a mix, etc.)

We will cover the single root approach, but eventually changing to a multi-root approach should be pretty easy. One last thing to keep in mind is that the path separator is another design decision, mostly every operating system use either "/" or "\" (the latter is mostly on windows os and derivatives), but in theory everything can be used as a path separator, we will stick with the unix-friendly "/", just keep in mind if going for the "windows" way, the separator is the same as the escape character, so it can interfere with the escape sequences.

For example let's assume that we have the following list of mountpoints: 

```c
mountpoints[0].mountpoint = "/"
mountpoints[1].mountpoint = "/home/mount"
mountpoints[2].mountpoint = "/usr"
mountpoints[3].mountpoint = "/home"
```

And we want to access the following paths: 

* /home/user/folder1/file
* /home/mount/folder1/file
* /opt

As we can see the first two paths have a common part, but belongs to different file system so we need to implement a function that given a path return the index of the file system it belongs to. 

How to do it is pretty simple, we scan the array, and search for the "longest" mountpoint that is contained in the path, so for in the first example, we can see that there are two items in the array that are contained in the path: "/" (0), and "/home" (3), and the longest one is number 3, so this is what our function is going to return. 

The second path instead has three mountpoints contained into it: "/" (0), "/home/mount" (1), "/home", in this case we are going to return 1. 

The last one, has only one mountpoint that is contained into the path, and it is "/" (0). 

In a single root scenario, there is always at least a mountpoint that is contained into the given path, and this is the root folder "/".

What if for example path doesn't start with a "/"? this means that it's a relative path, it will be explained soon.

Implementing the function is left as exercise, below we just declare the header (that we will use in the next sections): 

```c
int get_mounpoint_id(char *path);
```
#### Absolute vs relative path

Even though the concept of absolue and relative path, should be alresady known, it could be a good idea to understand how it works from a fs point of view. 

An absolute path, is a path that starts from the root folder ("/") and contains all the path toward the file, in a multi-root scenario it will always start with a device_id. While when we talk about relative paths it means that they are relative to the current working directory ( usually denoted with a "."), and they are represented in two ways: 

* with a leading dot: "./path/to/file"
* without the leading dot, and without the leading "/": "path/to/file"

So if for example the current working directory is: "/home/user/", the full path will become: "/home/user/path/to/file". Current Working Directory, depends on the process/thread/shell, but usually is the folder where the program is launched or the directory we are in a shell (that is a process) again. 

Usually the VFS should worry only about absolute paths, and the relative path resolution should be done a layer above it.

### Opening a file

After having implemented all the functions to load file systems and identify given a file path which mountpoint is containing it, we can now start to implement functions to opening and reading files. 

Let's quickly recap on how we usually read a file in C:

```C
FILE *file_pointer;
char ch;
file_pointer = fopen("/path/to/file/to_open", "modes");

do {
    ch = fgetc(file_pointer);
    printf("%c", ch);
} while ( ch != EOF);
fclose(file_pointer);
```

The code snipeet above is using the C stdlib file handling libraries, what the code above is doing is: 

* Calling fopen to get a reference to a file on the FS, that is the described by the FILE* pointer. FILE is a data structure containing information about the status of the current opened file, i.e. flags used to pen it, buffer pointers (for read and write purpose), lock status, etc. 
* If the file is found and the file_pointer is not null, than we can read it, in this example we used fgetc, but there are other functions too (i.e. fscanf), the read file function will use the FILE pointer struct to get the content from the file 
* When we reach the end of file we can close the file (freeing the file_pointer memory)

As you can see from the above code there are no instructions where we specify the file system type, or the driver to use this is all handled by the vfs layer. The above functions will avail of the kernel system calls open/read/close, and those are the functions we are going to implement. (IS THAT CORRECT?)

To open a file what we need to do is: 

* Parse the path to get the correct mountpoint, as described in the previous paragraph
* Get the mountpoint item and call it's FS open function
* Return a file descriptor or an error if needed. 

The function header for our open function will be: 

```c 
int vfs_open(const char *filename, int flags);
```

The `flags` parameter will tell how the file will be opened, there are many flags, and the three below should be mutually exclusive:

* O_RDONLY it opens a file in read only mode
* O_RDWR it opens a file for reading and writing
* O_WRONLY it opens a file only for writing.

The flags value is a bitwise operator, and there are other possible values to be used, but for our purpose we will just use the three above. 

The return value of the function is the file descriptor id




 

### Next.

Let's call it ArrayFS. 

What we are going to cover in this chapter is: 

* The basic functions of the FileSytstem and how to implement them
* How to create an image file containing our fs
* Create a tool to copy some files into the image.

Differently from other chapters, in this case we need to write a program to copy the files for our host OS.

## ArrayFS features and basic concepts

As already mentioned in the overview the functionalities will be quite limited, and they are going to be implemented using an array, so the first thing we need to decide is how many files we want to store, i'll go for 256 elements (i don't think that we will store many files in it).

The minimum information we need for storing a file are: 

* The  name 
* The file size
* Where it is located (that can be an address an offset, it depends on the implementation)

As you are probably aware there are many more information on a regular file like the creation and last modified date, author, attributes, but all these information are implementation dependent, and totally optional, so we will stick with the minimum required set. 






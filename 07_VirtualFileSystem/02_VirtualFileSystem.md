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

#### A short diversion: the initialization

When the kernel first boot up, of course there is no file system mounted, and all data structures are not allocated, if we decide to use a linked list for example, before the initialization the pointer will point to nothing (or better to garbage) so we will need to allocate the first item of the list to have the first fs accessible. 

In our case since we are using an array we need just to clean all the items in it order to make sure the kernel will not be tricked into thinking that there is a FS loaded, and we need an index pointer to know what is the position of the first available file system.

But where should be the first file system mounted? That again is depending on the project decisions:

* Using a single root approach, the first file system will be mounted on the "/" folder, and this is what we are going to do, this means that all other file systems will be going to stay into subfolders of the root folder. 
* Using a multi root approach, like windows os, we will have every fs that will have it's own root folder and it will be identified with a letter (A, B, C...)
* Nothing prevent us to use different approaches, or a mix of them, we can have some file system to share the same root, while some other to have different root, this totally depends on design decision. 

One last thing about the initialization, since our kernel is loaded fully in memory, we don't actually need to have a file system mounted for the kernel to run (even if probably in the future we will need one) so the initialization is just optional to be done during boot time, if the the os already has a kind of shell we can initialize it on the first mount when it will be called. 


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






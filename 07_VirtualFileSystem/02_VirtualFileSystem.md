# The Virtual File System

## Overview

Nowadays there are many OSes available for many different hardware architectures, and probably there are even more file systems. One of the problems for the OS is to provide a generic enough interface to support as many file systems as possible, and making it easy to implement new ones, in the future. This is where the VFS layer comes to aid, in this chapter we are going to see in detail how it works, and make a basic implementation of it. 
To keep our design simple, the features of our VFS driver will be: 

* Fixed number of mountpoints using an array.
* Support only the following functions: `open, read, write, close, opendir, readdir, closedir, stat`.
* No extra features like permissions, uid and gid (although we are going to add those fields, they will not be used).
* The path length will be limited.

## How Does VFS Works

The basic concept of a VFS layer is pretty simple, we can see it like a common way to access files/directories across different file systems, it is a layer that sits between the higher level interface to the FS and the low level implementation of the FS driver.

![Where the VFS sits in an OS](/Images/vfs_layer.png)

 How the different file systens are presented to the-end user depends on design decision. For example windows operating systems wants to keep different file systems logically separated using unit letters, while unix/linux systems represents them under the same tree, so a folder can be either on the same FS or on another one, but in both cases the idea is the same, we want to use the same functions to read/write files on them. 

In this guide we will follow a unix approach. To better understand how does it works let's have a look at this picture: 

![Vfs Example Tree](/Images/vfs_tree_example.png)

It shows a portion of a unix directory tree (starting from root), the gray circle represents actual file systems, while the white ones are directories. 

So for example: 

* /home/userA point to a folder into the file system that is loaded at the "/" folder (we say that it's *mounted*)
* /mnt/ext_device instead points to a file that is mounted within the /mnt folder

When a filesystem is *mounted* in a folder it means that the folder is no longer a container of other files/directories for the same filesystem but is referring to another one somewhere else (it can be a network drive, external device, an image file, etc.) and the folder takes the name of *mountpoint*.

Every mountpoint will contain the information on how to access the target file system, so the VFS every time it has to access a file or directory (i.e. a `open` function is called), it does the following:

* Parse the file path to identify the mountpoint of the filesystem
* Once we have the mountpoint struct, we can access a series of function pointers, one for each operation like opening/closing/reading/writing a file
* It call the open function for that FS passing the path to the filename (in this case the path should be relative)
* From this point everything is handled by the File System Driver and once the file is accessed is returned back to the vfs layer

The multi-root approach, even if it is different, it share the same behaviour, the biggest difference is that instead of having to parse the path searching for a mountpoint it has only to check the first item in the it to figure out which FS is attached to. 

This is in a nutshell a very high level overview of how the virtual filesystem works, in the next paragraphs we will go in more in details and explain all the steps involved and see how to add mountpoints, how to open/close files, read them. 

## The VFS in Detail

Finally we are going to write our implementation of the virtual file system, followed by an example driver (**spoiler alert**: the tar archive format), in this section we will see how to: 

* load and unload a file system (mount/umount).
* open and close a file.
* read/write it's content 
* open, read and close a directory

### Loading a file system

To be able to access the different filesystems currently lodaed (*mounted*) by the operating system it needs to keep track of where to access them (wheter it is a drive letter or a directory), and how to access them (implementation functions), to do that we need two things: 

* A data structure to store all the information related to the loaded File System
* A list/tree/array of all the file system currently loaded by the os 

As we anticipated earlier this chapter we are going to use an array to keep track of the mounted file systems, even if it has several limitations and probably a tree is the best choice. We want to focus on the implementation details of the VFS without having to also write and explain the tree-handling functions.

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
int ustar_close(int ustar_fd)
``` 

For the mount and umount operation we will need two functions: 

The first one for mounting, let's call it for example `vfs_mount`, to work it will need at least the parameters explained above: 

```c
int vfs_mount(char *device, char *target, char *fs_type);
```

Once called it will simply add a new item in the mountpoint on the first available position, and will populate the data mountpoint data structure with the information provided, for example using the array approach, if a free spot is found at index `i` to add a new file sytem we will have something like: 

```c
mountpoints[i].device = device;
mountpoints[i].type = type;
mountpoints[i].mountpoint = target;
mountpoints[i[.operations = NULL 
```

the last line will be populated soon, for now let's leave it to null. 

The second instruction is for umounting, in this case since we are just unloading the file device from the system, we don't need to know what type is it, so technically we need either the target device or the target folder, the function can actually accept both parameters, but use only one of them, let's call it `vfs_umount`: 

```c
int vfs_umount(char *device, char *target);
```

In this case we need to find the item in the list that contains the required file system, and if found remove it from the list/tree. In our case since we are using an array we need to clear all the fields in the array at the position containing our fs. 

One thing that we should keep in mind is that using an array, once we umount a file system we are just marking that position as available again, so this means that it can be in the middle of the array, and there can be mounted file system after, so we need to keep in mind this while searching for the next free mouuntpoint.

#### A Short Diversion: The Initialization

When the kernel first boots up, there is no file system mounted, and not all data structures are allocated, if we decide to use a linked list for example, before the initialization the pointer will point to nothing (or better to garbage) so we will need to allocate the first item of the list to have the first fs accessible. 

In our case since we are using an array we need just to clean all the items in it order to make sure the kernel will not be tricked into thinking that there is a FS loaded, and we need an index pointer to know what is the position of the first available file system.

But where should be the first file system mounted? That again is depending on the project decisions:

* Using a single root approach, the first file system will be mounted on the "/" folder, and this is what we are going to do, this means that all other file systems will be going to stay into subfolders of the root folder. 
* Using a multi root approach, like windows os, we will have every fs that will have it's own root folder and it will be identified with a letter (A, B, C...)
* Nothing prevent us to use different approaches, or a mix of them, we can have some file system to share the same root, while some other to have different root, this totally depends on design decision. 

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

How to do it is pretty simple, we scan the array, and search for the "longest" mountpoint that is contained in the path, so in the first example, we can see that there are two items in the array that are contained in the path: "/" (0), and "/home" (3), and the longest one is number 3, so this is what our function is going to return. 

The second path instead has three mountpoints contained into it: "/" (0), "/home/mount" (1), "/home", in this case we are going to return 1. 

The last one, has only one mountpoint that is contained into the path, and it is "/" (0). 

In a single root scenario, there is always at least a mountpoint that is contained into the given path, and this is the root folder "/".

What if for example path doesn't start with a "/"? this means that it's a relative path, it will be explained soon.

Implementing the function is left as exercise, below we just declare the header (that we will use in the next sections): 

```c
int get_mounpoint_id(char *path);
```

If the above function fail it should return a negative number (i.e. -1) to let the caller know that something didn't work (it should always return at least 0 in a single root implementation). 

#### Absolute vs Relative Path

Even though the concept of absolue and relative path, should be alresady known, it could be a good idea to understand how it works from a fs point of view. 

An absolute path, is a path that starts from the root folder ("/") and contains all the path toward the file, in a multi-root scenario it will always start with a device_id (i.e. C:\, D:\). While when we talk about relative paths it means that they are relative to the current working directory ( usually denoted with a "."), and they are represented in two ways: 

* with a leading dot: "./path/to/file"
* without the leading dot, and without the leading "/": "path/to/file"

So if for example the current working directory is: "/home/user/", the full path will become: "/home/user/path/to/file". Current Working Directory, depends on the process/thread/shell, but usually is the folder where the program is launched or the directory we are in a shell (that is a process) again. 

Usually the VFS should worry only about absolute paths, and the relative path resolution should be done elsewhere in the kernel. When it come to the filesystem  driver, it doesn´t care about the mountpoint part of the path, and it cares only about what comes after the mountpoint. Obtaining a relative path should be pretty straightforward, if we have the full path and the mountpoint, we should just strip the frist from the second. The implementation of this function is pretty straightforward, and is left as exercise, but in the next sections we will assume that it is implemented with the following signature: 

```c
char *get_rel_path(char *mountpoint_part, char* full_path);
```

### Accessing A File

After having implemented all the functions to load file systems and identify given a file path which mountpoint is containing it, we can now start to implement functions to opening and reading files. 

Let's quickly recap on how we usually read a file in C:

```C
int fd;
char *buffer = (char *) calloc(11, sizeof(char));
int file_descriptor = open("/path/to/file/to_open", O_RDONLY);
int sz = read(file_descriptor, buffer, 10) 
buffer[sz] = '\0';
printf("%s", buffer);
close(file_pointer);
```

The code snippet above is using the C stdlib file handling libraries, what the it does is: 

* Calls `open` to get the file descriptor id that will contain information on how to access the file itself on the file system.  
* If the file is found and the fd value is not -1, than we can read it
* It now reads 10 bytes from the opened file (the `read` function will access it via the fd field), and store the output in the buffer. The read function returns the number of bytes read.
* If we want to print the string read we need to append the EndOfLine symbol after the last byte read. 
* Now we can close the file_pointer (destroying the file descriptor associated with the id if it is possible, otherwise -1 will be returned). 

As you can see there are no instructions where we specify the file system type, or the driver to use this is all managed by the vfs layer. The above functions will avail of kernel system calls open/read/close, they usually sits somewhere above the kernel VFS layer, in our _naive_ implementation they we are not going to create new system calls, and let them to be our VFS layer, and where needed  make a simpler version of them.

We can assume that any file system i/o operation consists of three basic steps: opening the file, reading/writing from/to it and then closing it. 

#### Opening (and closing) A File

To open a file what we need to do is: 

* Parse the path to get the correct mountpoint, as described in the previous paragraph
* Get the mountpoint item and call it's FS open function
* Return a file descriptor or an error if needed. 

The function header for our open function will be: 

```c 
int open(const char *filename, int flags);
```

The `flags` parameter will tell how the file will be opened, there are many flags, and the three below should be mutually exclusive (please note that our example header is simplified compared to the posix open, where there is the `...` parameter, but for our purposes not needed):

* O_RDONLY it opens a file in read only mode
* O_RDWR it opens a file for reading and writing
* O_WRONLY it opens a file only for writing.

The flags value is a bitwise operator, and there are other possible values to be used, but for our purpose will focus only on the three mentioned above.

The return value of the function is the file descriptor id. We have already seen how to parse a path and get the mountpoint id if it is available. But what about the file descriptor and it's id? What is it? File descriptors represents a file that has been opened by the VFS, and contain information on how to access it (i.e. mountpoint_id), the filename, the various pointers to keep track of current read/write positions, eventual locks, etc. So before proceed let's outline a very simple file descriptor struct: 

```c
struct {
    int fs_file_id;
    int mountpoint_id;
    char *filename;
    int buf_read_pos;
    int buf_write_pos;
    int file_size;
    char *file_buffer;
} file_descriptor_t
```

We need to declare a variable that contains the opened file descriptors, as usual we are using a naive approach, and just use an array, this means that we will have a limited number of files that can be opened: 

```c 
struct file_descriptors_t vfS_opened_files[MAX_OPENED_FILES]
```

Where the `mountpoint_id` fields is the id of the mounted file system that is contining the requested file. The `fs_file_id` is the fs specific id of the fs opened by thefile descriptor, `buf_read_pos` and `buf_write_pos` are the current positions of the buffer pointer for the read and write operations and `file_size` is the the size of the opened file.

So once our open function has found the mountpoint for the requested file, eventually a new file descriptor item will be created and filled, and an id value returned. This id is different from the ine in the data structure, since it represent the internal fs descriptor id, while this one represent the vfs descriptor id. In our case the descriptor list is implemented again using an array, so the id returned will be the array position where the descriptor is being filled. 

Why "eventually" ? Having found the mountpoint id for the file doesn't mean that the file exists on that fs, the only thing that exist so far is the mountpoint, but after that the VFS can't really know if the file exists or not, it has to defer this task to the fs driver, hence it will call the implementation of a function that open a file on that FS that will do the search and return the an error if the file doesn't exists.  

But how to call the fs driver function? Earlier in this chapter when we outlined the `mountpoint_t` structure we added a field called `operations`, of type `fs_operations_t` and left it unimplemented. Now is the time to implement it, this field is going to contain the pointer to the driver functions that will be used by the vfs to open, read, write, and close files:

```c
struct fs_operations_t {
	int (*open)(const char *path, int flags, ... );
	int (*close)(int file_descriptor);
	ssize_t (*read)(int file_descriptor, char* read_buffer, size_t nbyte);
	ssize_t (*write)(int file_descriptor, const void* write_buffer, size_t nbyte);
};

typedef struct fs_operations_t fs_operations_t;
```

The basic idea is that once mountpoint_id has been found, the vfs will use the mountpoint item to call the fs driver implementation of the open function, remember that when calling the driver function, it cares only about the relative path with mountpoint folder stripped, if the whole path is passed, we will most likely get an error. Since the fs root will start from within the mountpoint folder we need to get the relative path, we will use the `get_rel_path` function defined earlier in this chapter, and the pseudocode for the open function should look similar to the following:


```c
int open(const char *path, int flags){
    mountpoint_id = get_mountpoint_id(pathname);
    
    if (mountpoint_id > -1) {
        char *rel_path = get_rel_path(mountpoints[mountpoint_id], path);
        int fs_specific_id = mountpoints[mountpoint_id].operations.open(rel_path, flags);
        if (fs_specific_id != ERROR) {
            /* IMPLEMENTATION LEFT AS EXERCISE */
            // Get a new vfs descriptor id vfs_id
            vfs_opened_files[vfs_id] = //fill the file descriptor entry at position 
        }
    }
    return vfs_id
}
```

The pseudo code above should give us an idea of what is the workflow of opening a file from a VFS point of view, as you can see the process is pretty simple in principle: getting the mountpoint_id from the vfs, if one has been found get strip out the mountpoint path from the path name, and call the fs driver open function, if this function call is succesfull is time to initialize a new vfs file descriptor item. 

Let's now have a look at the `close` function, as suggested by name this will do the opposite of the open function: given a file descriptor id it will free all the resources related to it and remove the file descriptor from the list of opened files. The function signature is the following:


```c 
int close(int fildes);
```

The fildes argument is the VFS file descriptor id, it will be searched in the opened files list (using an array it will be found at `vfs_opened_files[fildes]`) and if found it should first call the fs driver function to close a file (if present), emptying all data structures associated to that file descriptor (i.e. if there are data on pipes or FIFO they should be discarded) and then doing the same with all the vfs resources, finally it will mark this position as available again. We have only one problem how to mark a file descriptor available using an array? One idea can be to use -1 as `fs_file_id` to identify a position that is marked as available (so we will need to set them to -1 when the vfs is initialized).

In our case where we have no FIFO or data-pipes, we can outline our close function as the following: 

```c
int close(int fildes) {
    if (vfs_opened_files[fildes].fs_file_id != -1) {
        mountpoint_id = vfs_opened_files[fildes].mountpoint_id;
        fs_file_id = vfs_opened_files[fildes].fs_file_id;
        fs_close_result = mountpoints[mountpoint_id].close(fs_file_id);
        if(fs_close_result == 0) {
            vfs_opened_files[fildes].fs_file_id = -1;
            return 0;
        }
        return -1;
    }
}
```

#### Reading From A File

So now we have managed to access a file stored somewhere on a file system using our VFS, and now we need to read its contents. The function used in the file read example at the beginning of this chapter is the C read include in unistd, with the following signature:

```c
ssize_t read(int fildes, void *buf, size_t nbyte);
```

Where the paramaters are the opened file descriptor (fildes) the buffer we want to read into (buf), and the number of bytes (nbyte`) we want to read.

The read function will return the number of bytes read, and in case of failure -1. Like all other vfs functions, what the read will do is search for the file descriptor with id `fildes`, and if it exists call the fs driver function to read data from an opened file and fill the `buf` buffer.  

Internally the file descriptor keeps track of a 'read head' which points to the last byte that was read. The next read() call will start reading from this byte, before updating the pointer itself.

For example let's imagine we have opened a text file with the following content: 

```
Text example of a file...
```

And we have the following code: 

```c
char *buffer[5]
int sz = read(file_descriptor, buffer, 5) 
sz = read(file_descriptor, buffer, 5) 
```

The `buffer` content of the first read will be: `Text `, and the second one `examp`. This is the purpose  `buf_read_pos` variable in the file descriptor, so it basically needs to be incremented of nbytes, of course only if `buf_read_pos + nbytes < file_size` . 
The pseudocode for this function is going to be similar to the open/close: 

```c
ssize_t read(int fildes, void *buf, size_t nbytes) {

    if (vfs_opened_files[fildes].fs_fildes_id != -1) {
        int mountpoint_id = vfs_opened_files[fildes].mountpoint_id;
        int fs_file_id = vfs_opened_files[fildes].fs_file_id;
        int bytes_read = mountpoints[mountpoint_id].read(fs_file_id, buf, nbytes)
        if (opened_files[fildes].buf_read_pos + nbytes < opened_files[fildes].file_size) {
            opened_files[fildes].buf_read_pos += nbytes;
        } else {
            opened_files[fildes].buf_read_pos = opened_files[fildes].file_size;
        }
        return bytes_read;
    }

    return -1;
}
```

This is more or less all the code needed for the VFS level of the read function, from the moment the driver `read` function will be called the control will leave the VFS and will go one layer below, and in most cases it will involve similar steps for the VFS with few differences like: 

* It will use the relative path (without the mountpoint part) to search for the file
* It will use some internal data-structures to keep track of the files we are accessings (yes this can bring to some duplication of similar data stored in two different data structure)
* It will read the content of the file if found in different ways: if it is a file system loaded in memory, it will read it accessing its location, instead if it is stored inside a device it will probably involve another layer to call the device driver and access the data stored on it, like reading from disk sectors, or from a tape. 

The above differences are valid for all of the vfs calls. 

Now that we have implemented the `read` function we should be able to code a simple version of the `write` function, the logic is more or less the same, and the two key differences are that we are saving data (so it will call the fs driver equivalent for write) and there probably be at least another addition to the file descriptor data structure, to keep track of the position we are writing in (yes better keep read and write pointers separated, even because files can be opened in R/W mode). This is left as an exercise. 

### What About Directories

We have decided to not cover how to open and read directories, because the implementation will be similar to  the above cases, where we need to identify the mountpoint, call the filesystem driver equivalent of the vfs function called, and make it available to the caller. This means that most of its implementation will be a repetition of what has been done until now, but there are few extra things we need to be aware: 

* A directory is a container of files and/or other directories 
* There will be a function that will read through the items into a folder usually called `readdir` that will return the next item stored into the directory, and if it reach the end NULL will be reutrned. 
* There will be a need for a new data structure to store the information about the items stored within a directory that will be returned by the `readdir` (or similar) function.
* There are some special "directories" that should be known to everyone: "." and ".."

Initially let's concentrate with the basic function for directory handling: `opendir`, `readdir` and `closedir`, then when we get a grasp on them we can implement other more sophisticated functions.


### Conclusions And Suggestions

In this chapter we tried to outline a naive `VFS` layer to access files on different file systems. The features implemented are very basic, we left some topics uncovered to keep it as simple as possible, but if all the functions above are implemented, it will represent a good start for the kernel vfs, and we can think to new features like permissions, implement the standardlib C function to access files (fopen, fread and friends), or add protection mechanism to handle concurrency (see the *Locks* chapter), etc.

In the next section  we will implement one of the most basic fs: the `USTAR` file system and finally see our os reading the content of a file from memory. 



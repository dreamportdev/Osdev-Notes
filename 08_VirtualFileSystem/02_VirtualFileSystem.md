# The Virtual File System

Nowadays there are many OSes available for many different hardware architectures, and probably there are even more file systems. One of the problems for the OS is to provide a generic enough interface to support as many file systems as possible, and making it easy to implement new ones, in the future. This is where the VFS layer comes to aid, in this chapter we are going to see in detail how it works, and make a basic implementation of it.
To keep our design simple, the features of our VFS driver will be:

* Mountpoints will be handled using a simple linked list (with no particular sorting or extra features)
* Support only the following functions: `open, read, write, close, opendir, readdir, closedir, stat`.
* No extra features like permissions, uid and gid (although we are going to add those fields, they will not be used).
* The path length will be limited.

## How The VFS Works

The basic concept of a VFS layer is pretty simple, we can see it like a common way to access files/directories across different file systems, it is a layer that sits between the higher level interface to the FS and the low level implementation of the FS driver, as shown in the picture

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

* Parse the file path to identify the mountpoint of the filesystem.
* Once we have the mountpoint struct, we can access a series of function pointers, one for each operation like opening/closing/reading/writing a file.
* It call the open function for that FS passing the path to the filename (in this case the path should be relative).
* From this point everything is handled by the File System Driver and once the file is accessed is returned back to the vfs layer.

The multi-root approach, even if it is different, it share the same behaviour, the biggest difference is that instead of having to parse the path searching for a mountpoint it has only to check the first item in the it to figure out which FS is attached to.

This is in a nutshell a very high level overview of how the virtual filesystem works, in the next paragraphs we will go in more in details and explain all the steps involved and see how to add mountpoints, how to open/close files, read them.

## The VFS in Detail

Finally we are going to write our implementation of the virtual file system, followed by an example driver (**spoiler alert**: the tar archive format), in this section we will see how to:

* Load and unload a file system (mount/umount).
* Open and close a file.
* Read/write its content.
* Open, read and close a directory.

### Mountiung a File System

To be able to access the different filesystems currently lodaed (*mounted*) by the operating system it needs to keep track of where to access them (wheter it is a drive letter or a directory), and how to access them (implementation functions), to do that we need two things:

* A data structure to store all the information related to the loaded File System
* A list/tree/array of all the file system currently loaded by the os

As we anticipated earlier in this chapter we are going to use a linked list to keep track of the mounted file systems, even if it has several limitations and probably a tree is the best choice. We want to focus on the implementation details of the VFS without having to also write and explain the tree-handling functions.

So we assume that functions to handle list of mountpoints are present (their implementation is left as exercise), from now on we assume the following functions are present:

```c
mountpoint_t *create_mountpoint(...)
mountpoint_t *add_mountpoint(mountpoint_t* mountpoint);
void remove_mountpoint(mountpoint_t* mountpoint);
```

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

The next thing is to have a variable to store those mountpoints, since we are using a linked list it is going to be just a pointer to its root, this will be the first place where we will look whenever we want to access a folder or a file:

```c
#define MAX_MOUNTPOINTS 12
mountpoint_t *mountpoints_root;
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


Once called it will simply create and add a new item to the mountpoints list, and will populate the data structure with the information provided, for example inside the function to create a  mountpoint (in our example `create_mountpoint`) we are going to  have something like the following code:
```c
mountpoint_t *new_mountpoint = malloc(sizeof(mountpoint_t)); // We assume a kind of malloc is present
new_mountpoint.device = device;
new_mountpoint.type = type;
new_mountpoint.mountpoint = target;
new_mountpoint.operations = NULL
```

the last line will be populated soon, for now let's leave it to `NULL`.

The second instruction is for umounting, in this case since we are just unloading the file device from the system, we don't need to know what type is it, so technically we need either the target device or the target folder, the function can actually accept both parameters, but use only one of them, let's call it `vfs_umount`:

```c
int vfs_umount(char *device, char *target);
```

In this case we just need to find the item in the list that contains the required file system, and if found remove it from the list/tree by calling the `remove_mountpoint` function, making sure to free all resources if possible, or return an error.


#### A Short Diversion: The Initialization

When the kernel first boots up, there is no file system mounted, and not all data structures are allocated, if we decide to use a linked list for example, before the initialization the pointer will point to nothing (or better to garbage) so we will need to allocate the first item of the list to have the first fs accessible.

In our case since we are using an array we need just to clean all the items in it order to make sure the kernel will not be tricked into thinking that there is a FS loaded, and we need an index pointer to know what is the position of the first available file system.

But where should be the first file system mounted? That again is depending on the project decisions:

* Using a single root approach, the first file system will be mounted on the "/" folder, and this is what we are going to do, this means that all other file systems will be going to stay into subfolders of the root folder.
* Using a multi root approach, like windows os, we will have every fs that will have its own root folder and it will be identified with a letter (A, B, C...)
* Nothing prevent us to use different approaches, or a mix of them, we can have some file system to share the same root, while some other to have different root, this totally depends on design decision.

#### Finding The Correct Mountpoint

Now that we know how to handle the mountpoints, we need to understand how given a path find the correct route toward the right mountpoint. Depending on the approach how a path is defined can vary slightly:

* if we are using a single root approach we will have a path in the form of: `/path/to/folder/and/file`
* if we are using a multi-root approach the the path will be similar to: `<device_id>/path/to/folder/and/file` (where device_id is what identify the file system to be used, and the device, what it is depend on the os, it can be a letter, a number, a mix, etc.)

We will cover the single root approach, but eventually changing to a multi-root approach should be pretty easy. One last thing to keep in mind is that the path separator is another design decision, mostly every operating system use either "/" or "\" (the latter is mostly on windows os and derivatives), but in theory everything can be used as a path separator, we will stick with the unix-friendly "/", just keep in mind if going for the "windows" way, the separator is the same as the escape character, so it can interfere with the escape sequences.

For example let's assume that we have the following list of mountpoints :

* "/"
* "/home/mount"
* "/usr"
* "/home"

And we want to access the following paths:

* /home/user/folder1/file
* /home/mount/folder1/file
* /opt

As we can see the first two paths have a common part, but belongs to different file system so we need to implement a function that given a path return a reference of the file system it belongs to.

How to do it is pretty simple, we scan the list, and search for the "longest" mountpoint that is contained in the path, so in the first example, we can see that there are two items in the array that are contained in the path: _"/" (0)_, and _"/home" (3)_, and the longest one is number 3, so this is the file system our function is going to return (wheter it is going to be an id or the reference to the mountpoint item).

The second path instead has three mountpoints contained into it: _/" (0)_, _"/home/mount" (1)_, _"/home" (3)_, in this case we are going to return 1.

The last one, has only one mountpoint that is contained into the path, and it is _"/" (0)_.

In a single root scenario, there is always at least a mountpoint that is contained into the given path, and this is the root folder "/".

What if for example path doesn't start with a "/"? this means that it's a relative path, it will be explained soon.

Implementing the function is left as exercise, below we just declare the header (that we will use in the next sections):

```c
mountpoint_t get_mountpoint(char *path);
```

If the above function fail it should return  NULL to let the caller know that something didn't work (even if it should always return at least the root "/" item in a single root implementation).

#### Absolute vs Relative Path

Even though these concepts should already be familiar, let's discuss how they work from the view of the VFS.
An absolute path is easy to understand: it begins at the top of the filesystem tree and specifics exactly where to go. The one caveat is that in a multi-root design it will need to indicate which filesystem the root is, windows does this by prepending a device id like so: `C:` or `D:`.
A relative path begins traversing the filesystem from the current directory. Sometimes this is indicated by starting the filepath with a single dot '.'. A relative path is also one that doesn't begin at the file system root.

It can be easier to design a design our VFS to only accept absolute paths, and handle relative paths by combing them with the current working directory, giving us an absolute path. This removes the idea of relative paths from the VFS code and can greatly simplify the cases we have to handle.

As for how we track the current working directory of a program or user, that's information is usually stored in a process's control block, alongside things like privately mapped files (if support for those exists).

A filesystem driver also shouldn't need to worry about full filepaths, rather it should only care about the path that comes after its root node.

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

As we can see there are no instructions where we specify the file system type, or the driver to use this is all managed by the vfs layer. The above functions will avail of kernel system calls open/read/close, they usually sits somewhere above the kernel VFS layer, in our _naive_ implementation they we are not going to create new system calls, and let them to be our VFS layer, and where needed  make a simpler version of them.

We can assume that any file system i/o operation consists of three basic steps: opening the file, reading/writing from/to it and then closing it.

#### Opening (and closing) A File

To open a file what we need to do is:

* Parse the path to get the correct mountpoint, as described in the previous paragraph
* Get the mountpoint item and call its FS open function
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

The return value of the function is the file descriptor id. We have already seen how to parse a path and get the mountpoint id if it is available. But what about the file descriptor and its id? What is it? File descriptors represents a file that has been opened by the VFS, and contain information on how to access it (i.e. mountpoint_id), the filename, the various pointers to keep track of current read/write positions, eventual locks, etc. So before proceed let's outline a very simple file descriptor struct:

```c
struct {
    uint64_t fs_file_id;
    int mountpoint_id;
    char *filename;
    int buf_read_pos;
    int buf_write_pos;
    int file_size;
    char *file_buffer;
} file_descriptor_t
```

We need to declare a variable that contains the opened file descriptors, as usual we are using a naive approach, and just use an array for simplicity, this means that we will have a limited number of files that can be opened:

```c
struct file_descriptors_t vfs_opened_files[MAX_OPENED_FILES]
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
    mountpoint_t *mountpoint = get_mountpoint(pathname);

    if (mountpoint != NULL`) {
        char *rel_path = get_rel_path(mountpoint, path);
        int fs_specific_id = mountpoint.operations.open(rel_path, flags);
        if (fs_specific_id != ERROR) {
            /* IMPLEMENTATION LEFT AS EXERCISE */
            // Get a new vfs descriptor id vfs_id
            vfs_opened_files[vfs_id] = //fill the file descriptor entry at position
        }
    }
    return vfs_id
}
```

The pseudo code above should give us an idea of what is the workflow of opening a file from a VFS point of view, as we can see the process is pretty simple in principle: getting the mountpoint_id from the vfs, if one has been found get strip out the mountpoint path from the path name, and call the fs driver open function, if this function call is succesfull is time to initialize a new vfs file descriptor item.

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
        mountpoint_t *mountpoint  = get_mountpoint_by_id(mountpoint_id);
        fs_file_id = vfs_opened_files[fildes].fs_file_id;
        fs_close_result = mountpoint.close(fs_file_id);
        if(fs_close_result == 0) {
            vfs_opened_files[fildes].fs_file_id = -1;
            return 0;
        }
        return -1;
    }
}
```

The above code expects a function to find a mountpoint given its id `get_mountpoint_by_id`, the implementation is left as exercise, since it's pretty trivial and consists only of iterating inside a list where the header is:

```c
mountpoint_t *get_mountpoint_by_id(size_t mountpoint_id);
```

This function will be used in the following paragraphs too.

#### Reading From A File

So now we have managed to access a file stored somewhere on a file system using our VFS, and now we need to read its contents. The function used in the file read example at the beginning of this chapter is the C read include in unistd, with the following signature:

```c
ssize_t read(int fildes, void *buf, size_t nbyte);
```

Where the paramaters are the opened file descriptor (`fildes) the buffer we want to read into (`buf`), and the number of bytes (`nbytes`) we want to read.

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
        mountpoint_t *mountpoint = get_mountpoint_by_id(mountpoint_id)
        int fs_file_id = vfs_opened_files[fildes].fs_file_id;
        int bytes_read = mountpoints.read(fs_file_id, buf, nbytes)
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

### What About Directories?

We have decided to not cover how to open and read directories, because the implementation will be similar to  the above cases, where we need to identify the mountpoint, call the filesystem driver equivalent of the vfs function called, and make it available to the caller. This means that most of its implementation will be a repetition of what has been done until now, but there are few extra things we need to be aware:

* A directory is a container of files and/or other directories
* There will be a function that will read through the items into a folder usually called `readdir` that will return the next item stored into the directory, and if it reach the end NULL will be reutrned.
* There will be a need for a new data structure to store the information about the items stored within a directory that will be returned by the `readdir` (or similar) function.
* There are some special "directories" that should be known to everyone: "." and ".."

Initially let's concentrate with the basic function for directory handling: `opendir`, `readdir` and `closedir`, then when we get a grasp on them we can implement other more sophisticated functions.


### Conclusions And Suggestions

In this chapter we outlined a naive VFS that abstracts access to different filesystems. The current feature-set is very basic, but it serves as a good starting point. From here you begin to think about more features like memory mapping files and permissions.

We haven't added any locks to protect our VFS data structures in order to keep the design simple. However in a real implementation this should be done. Implementing a file-cache/page-cache is also a useful feature to have, and can be a nice way to make use of all the extra physical memory we've had sitting around until now.

In the next section we're going to implement a basic tempfs, with files loaded from a USTAR archive. This will result in our kernel being able to read files into memory and access them via the VFS.



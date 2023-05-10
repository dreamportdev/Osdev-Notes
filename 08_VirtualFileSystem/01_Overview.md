# Virtual File System

After we have made our kernel works with multiple programs, let them communicate each other, handle access to shared resources and protect the kernel space, now it is time to start to think about how to store and access files on our kernel, and how to support one or more file systems.

# The VFS and The File System

As we probably already know there are many different operating system available nowadays, some are proprietary of specific os/architectures, some are open source etc. Using any operating system daily usually we deal with at least 2/3 different file system types, that can grow quickly if we start to add an external device. For example if we are using a linux operating system with an external drive plugged, and a cdrom inserted we are already dealing with three different file system: 

* The main hard drive file system (it can be any of the supported fs like ext2, ext4, reiserfs, etc) 
* The external drive file system (probably a vfat, exfat or ntfs file system)
* The cdrom file system (usually iso9660)
* The pseudo file-systems like: /proc and /dev in unix-like operating systems.

But how can an operating system works with so many different file system, how can they coexist like in linux under the same directory tree? And most important of all: how are we going to implement it?

In this part we are going to understand how everything works, and how the OS can handle so many different file systems, we will try to make our basic implementation, to put the knowledge to work, and making our OS able to read and write (kind of...) files.

It will be divided into two main topics: 

* [The Virtual File System (VFS)](02_VirtualFileSystem.md): will introduce the basic VFS concepts and describe how implement a very simple version of it. For now it can be defined simply as a layer that works as an abstraction for the different file systems supported by our os, in this way the application and the kernel use a unified interface of functions to interact with files and directories on different fs, it offers functions like `open, write, opendir`
* In the [TAR File System] chapter we will see how the theory within a VFS interface works by implementing the Tar File System.

## A Quick Recap

Before proceeding is useful to recap some basic file system concepts.

The main purpose of a file system is to store data and make it easily accessible on a human readable way. What a file system does is organize how the data is stored, how they are represented on the disk, and provide functionalities to access, create, update and delete them. More advanced FS can also provide some kind of recovery mechanism (aka `journaling`), permissions,  but we are not going to cover them because it's out of the scope of this guide. 

Any operating system usually implements it's own FS version, and like many other OS topics, there are different types available that try to solve specific issues, or optimize certain type of operations. 

Any file system is provided by a driver, so an OS has to implement one for each type they want to support (the most popular and easy to implement are probably FAT, tar and ext2).

They will internally represents file, directories in different ways, wether they are just an overhead structure on top of the data, or an entry into an array/list. 

But how to make different file systems with different file representation, be seen in a uniform way by the os? This is achieved through an abstraction layer, that is the Virtual File System, it will be responsible to talk with the different drivers and provide an unified way to represent them to the user.

How the different drivers are presented to the user is a design decision, but the two most known (and probably common) ways to do that are:

* Show them as separated entities, like windows does, where every file system is identified by a unique letter (called the `drive letter`). The pro of this design is that we can have for example same path on two different device with the only difference being the drive letter (this is called the *multi-root* approach, and Windows is the most famous os using it)
* Show them under a single tree, where there is a unique root `/` and device is `mounted` in a subfolder of the root, and even the root is a filesystem mounted. So a folder can be either a just an fs folder or a mountpoint to another file system.  This is the way used by any unix inspired operating system. The pro of this design are that we have everything under the same tree, and the feeling of being using the same file system on our OS.


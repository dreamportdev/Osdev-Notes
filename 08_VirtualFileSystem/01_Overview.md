# Virtual File System

After we have made our kernel works with multiple programs, let them communicate each other, handle access to shared resources and protect the kernel space. Now it is time to start to think about how to store and access files in our kernel, and how we want to support file systems.

## The VFS and File Systems

As we probably already know there are many different operating system available nowadays, some are proprietary of specific os/architectures, some are open source etc. Using any operating system daily usually we deal with at least 2/3 different file system types, that can grow quickly if we start to add an external device. For example if we are using a linux operating system with an external drive plugged, and a cdrom inserted we are already dealing with three different file system:

* The main hard drive file system (it can be any of the supported fs like ext2, ext4, reiserfs, etc).
* The external drive file system (probably a vfat, exfat or ntfs file system).
* The cdrom file system (usually iso9660).
* The pseudo file-systems like: /proc and /dev in unix-like operating systems.

How can an operating system manage all these difference file systems and expose them to userspace under the same interface (and directory tree) - and most important of all: how are we going to implement it?

In this part we're going to look at the subsystem that handles all of this, and how we might implement one.

It will be divided into two main topics:

* [The Virtual File System (VFS)](02_VirtualFileSystem.md): will introduce the basic VFS concepts and describe how implement a very simple version of it. For now it can be defined simply as a layer that works as an abstraction for the different file systems supported by our os, in this way the application and the kernel use a unified interface of functions to interact with files and directories on different fs, it offers functions like `open, write, opendir`
* In the [TAR File System](03_TarFileSystem.md) chapter we will see how the theory within a VFS interface works by implementing the Tar File System.

## A Quick Recap

Before proceeding is useful to recap some basic file system concepts.

The main purpose of a file system is to store and organise data, and make it easily accessible to humans and programs. A file system also provides the ability to access, create and update files. More advanced file systems can also provide some kind of recovery mechanism (aka `journaling`), permissions,  but we are not going to cover them because it's out of the scope of this guide.

Different filesystems have different advantages: some are simpler to implement, otherwise may be offer extreme redundancy and others may be usable across a network. Each filesystem implementation is typically provided by a separate driver that then interacts with the virtual file system provided by the kernel. The most common filesystem drivers you will want to provide are ext2, FAT(12/16/32 - they are fundamentally all the same) and an ram-based 'temp fs'. The tempfs may also support loading its contents from a TAR passed by the bootloader. This is the concept of a init ramdisk, and we'll look at an example of how to implement this.

Each filesystem interally represents file (and directory) data in different ways. Whether they are just a structure laid out before the data, or an entry in a array or list somewhere.

How do we combine the output of all these different filesystems in a uniform way that's usable by the rest of the OS? We achieve this through a layer of abstraction, which we called the *virtual file system*, or VFS. It's responsible for acting as a scaffold that other filesystems can attach themselves to.

How the VFS presents itself is another design decision, but the two common ways to do it are:

* Each mounted filesystem is a distinct filesystem, with a separate root. Typically each root is given a single letter to identify it. This is the MS-DOS/Windows approach and is called the *multi-root* approach.
* Each mounted filesystem exists within a single global tree, under a single root. This is the usual unix approach, where a directory can actually be a window into another filesystem.


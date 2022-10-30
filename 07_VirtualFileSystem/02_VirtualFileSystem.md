# VirtualFS

## Overview

Nowadays there are many OSes available for many different hardware architectures, and probably there are even more file systems. One of the problems for the OS is to provide a generic enough interface to support as many file systems as possible, keeping also easy implementing new ones, this is where the VFS layer comes to aid, in this chapter we are going to see in detail how it works, and make a basic implementation of it. 
To keep our design simple the features of our VFS driver will be: 

* Fixed number of mountpoints using an array
* Support only the following functions: `open, read, write, close, opendir, readdir, closedir, stat`
* No extra features like permissions, uid and gid (although we are going to add those fields, they will not be used)

## How does VFS works

The basic concept of a VFS layer is pretty simple, we can see it like a common way to access files/directories across different file systems, how they are presented it depends on design decisions for example windows operating systems wants to keep different file systems logically separated using unit letters, while unix/linux systems represents them under the same tree, so a folder can be either on the same FS or on another one, but in both cases the idea is the same, we want to use the same functions to read/write files on them. 

In this guide we will follow a unix approach. To better understand how does it works let's have a look at this picture: 

![Vfs Example Tree](Images/vfs_tree_exmple.png)

It shows a portion of a unix directory tree (starting from root), the gray circle represents actual file system, while the white ones are directories. 

So for example: 

* /home/userA point to a folder into the File System that is loaded at the "/" folder (we say that it's *mounted*)
* /mnt/ext_device instead points to a file that is mounted within the /mnt folder

When a file system is *mounted* in a folder it means that the folder is no longer a container of other files/directories for the same filesystem but is referring to another file systems somewhere else (it can be a network drive, external device, an image file, etc.) and the folder takes the name of *mountpoint*

Every mountpoint, will contain the information to access the target file system, so the VFS every time it has to access a file, it does the following:

* Parse the file path to identify the mountpoint of the File System
* Once identified, it get access to the data structure holding all information on how to access it, this structure usually contains the pointer to the functions to open, write files, create dir, etc. * It call the open function for that FS passing the path to the filename (in this case the path should be relative)

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






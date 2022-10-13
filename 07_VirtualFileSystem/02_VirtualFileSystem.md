# A toy FS, the ArrayFS

## Overview

As we already mentioned there are many OSes available nowadays, and probably far more file system, and one of the problem for the OS is to provide a generic enough interface to support as many file systems as possible, keeping also easy implementing new ones, this is where the VFS layer comes to aid, in this chapter we are going to see in detail how it works, and make a basic implementation of it. 
To keep our design simple the features of our VFS driver will be: 

* Fixed number of mountpoints using an array
* Support only the following functions: `open, read, write, close, opendir, readdir, closedir, stat`
* No extra features like permissions, uid and gid (although we are going to add those fields, they will not be used)

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
A directory can be seen as a file with a special attri






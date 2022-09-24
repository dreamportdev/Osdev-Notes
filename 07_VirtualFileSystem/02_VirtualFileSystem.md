# The Virtual File System

## Overview

As we already mentioned there are many OSes available nowadays, and probably far more file system, and one of the problem for the OS is to provide a generic enough interface to support as many file systems as possible, keeping also easy implementing new ones, this is where the VFS layer comes to aid, in this chapter we are going to see in detail how it works, and make a basic implementation of it. 
To keep our design simple the feature of our VFS driver will be: 

* Fixed number of mountpoints using an array
* Support only the following functions: `open, read, write, close, opendir, readdir, closedir, stat`
* No extra features like permissions, uid and gid (although we are going to add those fields, they will not be used)



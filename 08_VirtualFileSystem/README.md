# Virtual File System

In this part we're going to look at what a *virtual file system* is, why it's useful and an example implementation.

* [Overview](01_Overview.md) goes over some high level theory and looks at why a VFS is useful.
* [Virtual File System](02_VirtualFileSystem.md) goes into detail on the inner workings of a typical VFS and it's main components. We also look at some example code.
* [Tar FS](03_TarFileSystem.md) adds a readonly in-memory filesystem, which is based on the contents of a tar file given by the bootloader. Useful for an init ramdisk.

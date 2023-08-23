# Welcome

Whether you're reading this online, or in a book, welcome to our collection of notes about operating systems development! We've written these while writing (and re-writing) our own operating systems, with the intent of guiding a reader through the various stages of building an operating system from scratch. We've tried to focus more on the concepts and theory behind the various components, with the code only provided to help solidify some concepts.

We hope you enjoy, and find something interesting here!

## Structure Of The Book

The book is divided in parts and every part is composed by one or more capter. Each numbered chapter adds a new layer to the kernel, expanding its capabilities. While it's not strictly necessary to read them in order, it is encouraged as some later chapters may reference earlier ones.

There is also a series of appendices at the end of the book, covering some extra topics that may be useful along the way. The appendices are intended to be used a reference, and can be read at any time. 

### Topics covered

As we've already mentioned, our main purpose here is to guide the reader through the general process of building a kernel (and surrounding operating system). We're using `x86_64` as our reference architecture, but most of the concepts should transfer to other architectures, with the exception of the very early states of booting.

Below the list of parts that compose the book: 

* *Build Process* - The first part is all about setting up a suitable environment for operating systems development, explaining what tools are needed and the steps required to build and test a kernel.
* *Architecture/Drivers* - This part contains most the architecture specific components, as well as most of the data structures and underlying mechanisms of the hardware we'll need. It also includes some early drivers that are very useful during further development (like the keyboard and timer).
* *Video Output* - This part looks at working with linear framebuffers, and how we can display text on them to aid with early debugging.
* *Memory Management* - This part looks at the memory management stack of a kernel. We cover all the layers from the physical memory manager, to the virtual memory manager and the heap.
* *Scheduling* - A modern operating system should support running multiple programs at once. In this part we're going to look at how processes and threads are implemented, write a simple scheduler and have a look at some of the typical concurrency issues that arise. 
* *Userspace* - Many modern architectures support different level of privileges, that means programs that are running on lower levels can't access resources/data reserved for higher levels.
* *Inter-Process Communication (IPC)* - This part looks at how we might implement IPC for our kernel, allowing isolated programs to communicate with each other in a controlled way. 
* *Virtual File System (VFS)* - This part will cover how a kernel presents different file systems to the rest of the system. We'll also take a look at implementing a 'tempfs' that is loaded from a tape archive (tar), similar to initrd. 
* *The ELF format* - Once we have a file system we can load files from it, why not load a program? This part looks at writing a simple program loader for ELF64 binaries, and why you would want to use this format.
* *Going Beyond* - The final part (for now). We have implemented all the core components of a kernel, and we are free to go from here. This final chapter contains some ideas for new components that you might want to add, or at least begin thinking about.

In the appendices we cover various topic, from debugging tips, language specific information, troubleshooting, etc.

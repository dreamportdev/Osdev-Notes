# Welcome

Whether you're reading this online, or in a book, welcome to our collection of notes about operating systems development! We've written these while writing (and re-writing) our own operating systems, with the intent of guiding a reader through the various stages of building an operating system from scratch. We've tried to focus more on the concepts and theory behind the various components, with the code only provided to help solidify some concepts.

We hope you enjoy, and find something interesting here!

## Structure Of The Book

Each numbered chapter adds a new layer to the kernel, expanding it's capabilities. While it's not strictly necessary to read them in order, it is encouraged as some later chapters may reference earlier ones. 

There are also a pair of special chapters at the end of the book: one containing a series of unrelated but useful topics (appendices), and one containing descriptions of various hardware devices you might want to support. 

The appendices chapter is intended to be used a reference, and can be read at any time. The drivers chapter can also be read at any time, but implementing support for these devices should come after the memory management chapter (when a VMM has been implemented).

### Topics covered

As we've already mentioned, our main purpose here is the guide the reader through the general process of building a kernel (and surrounding operating system). We're using `x86_64` as our reference architecture, but most of the concepts should transfer to other architectures, with the exception of the very early states of booting.

Below a short list of all the topics that are covered so far: 

* *Build Process* - The first part is all about getting an osdev environment up and running, explaining what tools are needed, and the steps to build and run a kernel.
* *Architecture/Drivers* - This part contains most the architecture specific parts, as well as most of the data structures and unerlying mechanisms of the hardware we'll need. It also includes some early drivers that are very useful during further development (like the keyboard and timer).
* *Memory Management* - This chapter offer an overview of the memory management layers of a kernel. We cover all the layers from the physical memory magager, virtual memory manager and the heap. We'll look at how these fit into the memory management stack, and how they work together.
* *Scheduling* - A modern operating system should support running multiple programs at once. In this part we're going to look at how processes and threads are implemented, implement a simple scheduler and have a look at some of the typical concurrency issues that arise. 
* *Userspace* - Many modern architectures support different level of privileges, that means that programs that are running on lower levels can't access resources/data reserved for higher levels.
* *IPC* - Also known as inter-process communication, is a mechanism for programs to communicate with each other in a safe and controlled way. We're going to take a look at a few ways to implement this.
* *Virtual File System* - This will cover how a kernel presents different file systems to the rest of the OS. We'll also take a look at implementing a 'tempfs' that is loaded from a tape archive (tar), similar to initrd. 
* *The Elf format* - Once we have a file system we can load files from it, why not a program? This chapter looks at writing a simple program loader for ELF64 binaries, and why you would want to use this format.
* *Going beyond* - The final part (for now): we have implemented all the core components of a kernel, and we are free to go from here. This final chapter contains some ideas for new components that you might want to add, or at least begin thinking about.

# Welcome

Wheter you are reading the notes online or as a book this is a collection of notes about operating systems development. They were written by the authors while writing (and re-writing) their own operating systems. The notes are written with the intent of guiding the reader through the various stages of building an operating system kernel from scratch. Trying to focus more on the concepts behind and how things works than on the code.

We hope you enjoy, and find something interesting here!

## Structure Of The Book

Each numbered chapter adds a new layer to the kernel, expanding it's capabilities. It's not strictly necessary to read them in order, but it is encouraged as some later chapters may reference earlier ones. 

There are also a pair of special chapters at the end of the book: one containing a series of unrelated but useful topics (appendices), and one containing descriptions of various hardware devices you might want to support.

The appendices chapter is intended to be used a reference, and can be read at any time. The drivers chapter can also be read at any time, but implementing support for these devices should come after the memory management chapter (when a VMM has been implemented).

### Topics covered

As already said this book (or set of notes depending where are you reading it) main purpose is to guide the reader through the process of writing a kernel from scratch, as reference architecture we are using `x86_64`, but most of the concept (with the exception of few architecture specific chapters/parts) apply to any architecture.

Below a short list of all the topics that are covered so far: 

* *Build Process* - The firsts part is all about getting an osdev environment up and running explaining what tools are needed, and what are the steps to build and run a kernel.
* *Architecture/Drivers* - This part contains most the architecture specific parts (`x86_64`), it covers most of the data structure and services that are needed to be set-up on the very early stages of our kernel development, and some early drivers that are useful to develop (like keyboard, timer). 
* *Memory Management* - This chapter offer an overview of the whole Memory Management layer of a kernel, covering all the components from the Physical Memory to the Virtual Memory manager, trying to explain how things works together and what are their interaction.
* *Scheduling* - Any modern Operating system support multitasking, and sometime multithreading too, in this part we are going to describe how are process and threads implementd, implement a simple scheduler and having a look at some of the typical concurrency issues that arises. 
* *Userspace* - Many modern architecture support different level of privileges, that means that programs that are running on lower levels can't access resources/data reserved for higher levels. This part focus on `x86_64` architectures, so some parts are specific to that, but many concept apply to all modern architectures (Arm, RiscV, etc).
* *IPC* - Also known as Inter Process Communication, in this part we are going to see how process communicate between each other, and exchange messages.
* *Virtual File System* - This will cover how a kernel presnet different file system to the rest of the OS, and we will implement also a simple file system based on the Tar Archive Format. 
* *The Elf format* - Once we have file system it means that we are ready (or nearly) to execute programs stored on it, this part is going to cover one of the most common executable format the Executable Linking Format (ELF).
* *Going beyond* - The final part, we have implemented all the core components of a kernel, and we are free to go from here, this final chapter contains some ideas for new components that can be implemented/integrated analyzing what is needed, and some very high level explanation on how it can be implemented. 

Finally the Appendices, contains useful information and good to know stuff that will be useful useful information and good to know stuff that will be useful during our osdev journey.

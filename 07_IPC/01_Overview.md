# Inter-Process Communication

So far we've put a lot of effort into making sure each program (represented by a process in our kernel) is completely isolated from all others. This is great for safety and security, but it presents a big problem: what if we want two processes to communicate with each other?

The answer to this is some form of inter-process communication (aka `IPC`). This part will look at some basic implementations for the common types and will hopefully serve a good jumping off point for further implementations. It should be noted that IPC is mainly intended for userspace programs to communicate with each other, if you have multiple kernel threads wanting to communicate there's no need for the overhead of IPC.

## Shared Memory vs Message Passing

All IPC can be broken down into two forms:

- _Shared Memory_: In this case the kernel maps a set of physical pages into a process's address space, and then maps the same physical pages into another processes address space. Now the two processes can communicate by reading and writing to this shared memory. This will be explained in the [Shared Memory](02_Shared_Memory.md) chapter.
- _Message Passing_: Message passing is a more discrete form of IPC, one process sends self-contained packets to another service, which is waiting to receive them. We use the kernel to facilitate passing the buffer containing the packet between processes, as explored in [Message Passing](03_Message_Passing.md).

## Single-Copy vs Double-Copy

These terms refer to the number of times the data must be copied before reaching its destination. Message passing as described above is double-copy (process A's buffer is copied to the kernel buffer, kernel buffer is copied to process B's buffer). There are ways to implement single-copy of course.

For fun, we can think of shared memory as 'zero-copy', since the data is never copied at all.

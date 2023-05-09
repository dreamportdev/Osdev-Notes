# Inter-Process Communication

So far we've put a lot of effort into making sure each program (represented by a process in our kernel) is completely isolated from all others. This is great for safety and security, but it presents a big problem: what if we want two processes to communicate with each other?

The answer to this is some form of IPC (aka Inter-Process Communication). This part will look at some basic implementations for the common types and will hopefully serve a good jumping off point for further implementations.

## Shared Memory vs Message Passing

All IPC can be broken down into two forms:

- Shared Memory: In this case the kernel maps a set of physical pages into a process's address space, and then maps the same physical pages into another processes address space. Now the two processes can communicate by reading and writing to this shared memory. This will be explained in the [Shared_Memory](02_Shared_Memory.md) chapter
- Message Passing: This works by writing the message we want to send into a buffer, and then giving that buffer to the kernel. The kernel will then pass that buffer to the destination process. The chapter [Message Passing](03_Message_Passing.md) will cover this topic.

## Single-Copy vs Double-Copy

These terms refer to the number of times the data must be copied before reaching it's destination. Message passing as described above is double-copy (process A's buffer is copied to the kernel buffer, kernel buffer is copied to process B's buffer). There are ways to implement single-copy of course.

For fun, we can think of shared memory as 'zero-copy', since the data is never copied at all.

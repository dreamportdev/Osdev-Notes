# Scheduling

In this part we are going to explore how task/thread scheduling works

Below the list of chapters:

* [The Scheduler](02_Scheduler.md) This is the core of the scheduling subsystem. It's responsible for selecting the next process to run, as well as some general housekeeping. There are many implementations, we've chosen one that is simple and easy to expand upon.
* [Processes and Threads](03_Processes_And_Threads.md) These are the two basic units our scheduler deals with. A stream of code is represented by a thread, which contains everything we need to save and restore it's context: a stack, the saved register state and the iret frame used to resume it's execution. A process represents a whole program, and can contain a number of threads (or just one), as well as a VMM and a list of resource handles (file descriptors and friends). Both processes and threads can also have names and unique identifiers.
* [Locks](04_Locks.md) Once the scheduler start running, there will be a range of new problems that we will need to take care of, like same resource being accessed by multiple processes/threads, this is what we are going to cover in this chapter.

# Scheduling And Tasks

So far our kernel has been running a single stream of code, initializing various parts of the cpu and system hardware in sequence and handling interrupts from few sources. 

While it is possible to go further,  we'll begin to run into a handful of problems. Some devices take *time* to perform actions, and our code may need to wait. If we have a lot of devices, this can lead to things becoming very slow. What if we want to start running multiple threads, or even multiple programs with multiple threads? This is a common scenario, and what the scheduler is responsible for.

The scheduler is similar to a hardware multiplexer (_mux_) in that it takes multiple inputs (programs or threads) and allows them to share a single output (the cpu executing the code). 

The scheduler does this by interrupting the current stream of code, saving its state, selecting the next stream, loading the new state and then returning. If done at a fast enough rate, all programs will get to spend a little time running, and to the user it will appear as if all programs are running at the same time. This whole operation is called a *context switch*.

For our examples the scheduler is going to do its selection inside of an interrupt handler, as that's the simplest way to get started. As always, there are other designs out there.

This part will cover the following areas:

* [The Scheduler](02_Scheduler.md): This is the core of the scheduling subsystem. It's responsible for selecting the next process to run, as well as some general housekeeping. There are many implementations, we've chosen one that is simple and easy to expand upon, a first come first served approach, called Round Robin.
* [Processes and Threads](03_Processes_And_Threads.md): These are the two basic units our scheduler deals with. A stream of code is represented by a thread, which contains everything that is needed to save and restore its context: a stack, the saved registers state and the iret frame used to resume its execution. A process represents a whole program, and can contain a number of threads (or just one), as well as a VMM and a list of resource handles (file descriptors and friends). Both processes and threads can also have names and unique identifiers.
* [Locks](04_Locks.md):  Once the scheduler starts running different tasks, there will be a range of new problems that we will need to take care of, for example the same resource being accessed by multiple processes/threads. This is what we are going to cover in this chapter, describing how to mitigate it.

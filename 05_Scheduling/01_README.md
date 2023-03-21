# Scheduling And Tasks

So far our kernel has been running a single stream of code, initializing various parts of the cpu and system hardware in sequence. While it is possible to go further, we'll begin to run into a handfuls of problems. Some hardware takes *time* to perform actions, and our code may need to wait. If we have a lot of devices this can lead to things becoming very slow. What if we want to start running multiple threads, or even multiple programs with multiple threads? This is a common scenario, and what the scheduler is responsible for.

The scheduler is similar to a hardware multiplexer (mux) in that it takes multiple inputs (programs or threads) and allows them to share a single output (the cpu executing the code). The scheduler does this by interrupting the current stream of code, saving it's state, selection the next stream, loading the new state and then returning. If done at a fast enough rate, all programs will get to spend a little time running, and to the user it will appear as if all programs are running at the same time. This whole operation is called a *context switch*.

For our examples the scheduler is going to do it's selection inside of an interrupt handler, as that's the simplest way to get started. As always, there are other designs out there.

This section will cover two main areas:

* [The Scheduler](02_Scheduler.md) This is the core of the scheduling subsystem. It's responsible for selecting the next process to run, as well as some general housekeeping. There are many implementations, we've chosen one that is simple and easy to expand upon.
* [Processes and Threads](03_Processes_And_Threads.md) These are the two basic units our scheduler deals with. A stream of code is represented by a thread, which contains everything we need to save and restore it's context: a stack, the saved register state and the iret frame used to resume it's execution. A process represents a whole program, and can contain a number of threads (or just one), as well as a VMM and a list of resource handles (file descriptors and friends). Both processes and threads can also have names and unique identifiers.

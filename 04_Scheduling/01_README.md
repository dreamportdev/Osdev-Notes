# Scheduling and Tasks

Up until this point, we've be running a single stream of code. Getting the cpu and other hardware setup how we want. However we very quickly run into a few issues: what if we want to wait on some hardware, but with a timeout? What if we want to run multiple streams of code at the same time? Multiple programs with multiple threads?
This is where a scheduler comes in. It's similar to a hardware multiplexer (sometimes called a mux), in that it takes multiple inputs (our code) and allows them to share a single output (our cpu, which can only run one instruction stream). 

The scheduler works by interrupting the currently running program, saving it's state and then loading the state of a new program. This is called a context switch, and if often quite an expensive and slow operation to perform, as we'll see later. As you might have guessed, the scheduler often operates within an interrupt handler, and if written correctly, the running program will never know it has paused at all. If these context switches are performed at the right speed, the user will never notice programs briefly pausing and unpausing, and it will appear to the user as if all programs are running at the same time.

Of course unless you support multiple cores, we know this is far from the truth. It's all just a clever trick.

This section will be focused mainly on two topics:

* [The Scheduler](Scheduler.md) that is in charge of suspending the current program, picking the next one and execute it, is called the **Scheduler**, there are many implementation for them and everyone with it's pros and cons, as usual it is not our scope to explain different algorithms (we leave them to the more canonical operating system books), but we will pick the simplest one and show how it works and what is needed to implement it. 
* [Tasks and Threads](TasksAndThreads.md) A program being executed is usually refferred as a **Task**, it usually contains the references to the code to execute and all data structure needed for it to run (memory heap, virtual memory tables, etc), along with some other information (name, status, unique id), depending on design decision a task can be split in smaller parts called **threads**, sometime known also as **lightweight tasks**, they, but we will going to explain it in the Tasks And thread Section.




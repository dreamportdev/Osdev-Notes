# Scheduling and Tasks

First of all Congratulations, you have made it until here one of the parts of the OS where things start to get Serious (yeah more than memory management!)... if you have implemented all the previous parts, you probably already are in the "Higher Half" of kernel hobbyists... Many hobby operating systems doesn't go through the memory management swamps (of despair :)) and let their project die...

So far what we have done was implementing basic structures and algorithms in our kernel to handle resources, interact with hardware, do some more or less fancy output, but whatever we have done untill now there is a common thing: everything is still in the kernel, and the CPU is just executing a set of instructions one after each other, This chapter is where we start to draw a line between kernel code and application (we just start here, but it will take several chapters before full separation is achieved).

What we are going to see in the next few sections is how to implement task management and scheduling, having our kernel jumping back and forth between different tasks/threads. 

But first let's answer a question, why is that needed? 

Well at the end of day a cpu is just a complex object that can execute an instruction at a time, but we all know that modern operating systems can execute more than one task at time, right? 

Well the answer is: no (in a multicore/multicpu environment this is not totally true since there are many cpu/cores so we can execute as many instruction as the number of cpu/cores installed on the computer), the cpu is still executing one instruction at time, but we have the impression that the os is executing much more tasks, how it is achieved? This is a "trick", it avail of the fact that a CPU can execute now adays billions of instructions per second, so if we execute a small portion of each program running on the for a small ammout of time, they will probably be executed and stopped many times during one second. 

So let's start with some terminology:

* W[The Scheduler](Scheduler.md) who is in charge of suspending the current program, picking the next one and execute it, is called the **Scheduler**, there are many implementation for them and everyone with it's pros and cons, as usual it is not our scope to explain different algorithms (we leave them to the more canonical operating system books), but we will pick the simplest one and show how it works and what is needed to implement it. 
* [Tasks and Threads](TasksAndThreads.md) A program being executed is usually refferred as a **Task**, it usually contains the references to the code to execute and all data structure needed for it to run (memory heap, virtual memory tables, etc), along with some other information (name, status, unique id), depending on design decision a task can be split in smaller parts called **threads**, sometime known also as **lightweight tasks**, they, but we will going to explain it in the Tasks And thread Section.



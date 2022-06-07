# The Scheduler

## What is it? 

In a multitasking system (from now on the term *multitasking* refer to both multitasking and multithreading, if there is need to make a distinction the proper term will be used), the scheduler is the operating system componet that is responsible of selecting and loading the next task to be executed by the CPU. 

There are many algorithm that can be used to implement it, and they try to solve different issues or optimize different scenarios, for example a real time operating system will probably wants to execute higher priority tasks more often, where a desktop operating system will probably wants only to divide the time evenly between tasks, etc. 

As usual the purpose of this guide is not to explain the algoirthms, for them there are many Operating System Books that can be used as reference, our purpose is to understand how is it implemented, and make our own scheduler, so we will implement a very simple algorithm that will serve tasks on a FCFS basis (First Come First Served) without priority.



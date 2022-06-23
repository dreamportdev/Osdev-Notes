# The Scheduler

## What is it? 

In a multitasking system (from now on, the term *multitasking* can refer to both multitasking and multithreading, if there is need to make a distinction the proper term will be used), the scheduler is the operating system componet that is responsible of selecting and loading the next task to be executed by the CPU. 

The idea of a task scheduler is pretty straightforward, it picks a task from a list, grant it some execution time, then put it back in the list and pick the next one.

On how to select the task from the list there are many algorithms that can be used to implement it, and they try to solve different issues or optimize different scenarios, for example a real time operating system will probably wants to execute higher priority tasks more often, where a desktop operating system will probably wants only to divide the time evenly between tasks, etc. 

As usual the purpose of this guide is not to explain the algoirthms, for them there are many Operating System Books that can be used as reference, our purpose is to understand how it is implemented, and make our own one, so we will implement a very simple algorithm that will serve tasks on a FCFS basis (First Come First Served) without priority.

## Overview of how a scheduler work

As we said above a task scheduler is basically a function that picks a task from a list and execute it for some time and when done places it back in the list to pick a new one. 

But before going directly into the workflow let's answer few questions: 

* Who is going to call the scheduler? Again this is a design choice but usually what we expect is to have it called periodically. 
* What is a task? This concept will be described in more detail on the next chapter, but generally speaking a task is a data structure that reperesent an application running, and threads if implemented are portion of tasks that can run concurrently. 
* How long a task is supposed to execute before being replaced? That is another design choice that depends on different factors (for example algorithm used, personal choice, it can be even customized by the user), but usually the minimum is the time between one timer interrupt and the next other.
* Are there cases where the task is not finished yet, but it is unavailable to run at the moment? Yes, and it will be discussed later, and the scheduler must be aware of that.  


The basic idea behind ever scheduler is more or less the following: 

* As soon as the function is called it checks the current executing task if it has finished it's allocated time. If not, it will end here, and exit, if yes it will proceed to the next step. 
* If the task has finished it's allocated time, the scheduler take the current context (we have already seen this concept in the Interrupt handling chapter) and save it to the current executing task, then proceed to the next step.
* After having saved the context of the current running task, it needs to pick up the next one from the list. It will start to pick task one after each other searching for the first *ready* to execute task available (generally there are more than one task ready to execute and which one is taken it depends totally on the algorithm implemented, but the basic idea is: it pick a task to execute), and loads it as the current executing one
    * During the search of the READY task, it could be useful (but not necessary, is  up to the design choices again) to do some housekeeping on the non-reaady tasks. For example: has the current task finished it's execution? Can it be removed from the list? Does the tasks in WAIT State still needs to wait? 
* Once the new task is loaded the scheduler return the new context to the operating system.

The basic scheduler we are going to implement will have the following characteristics: 

1. It will execute tasks in a First Come First Served basis
2. The tasks will be kept in a fixed size array (to keep the implementation simple, and focus on the main topic)
3. The execution time for each task will be just 1 timer tick. (so they will be changed every time the timer interrupt will be called)


Now that we have an idea of what we have to write we can start describing how it will be implement

### Part 1 Calling the scheduler

The first thing that we need to do is to decide when to call the scheduler, as already mentioned above it can be called in many different cases and it's totally up to us (nothing prevent us to have the scheduler function called only when a big red button plugged to the computer is pressed).

But in a multitasking operating system, where what expect is at least that every task gets it's own fair share of cpu-time, we want it to be called at regular intervals of time. And this can be easily achieved letting the timer interrupt handler routine do the call i( you have followed this guide you probably have it already implemented). 

Let's assume that we have a centralized interrupt handling routine that the correspoding action is selected within a switch statement, and we (will) have a `schedule()` function to call. In this case according to the design outlined above we want `schedule()` to be called within the interrupt timer case (labeled as TIMER_INTERRUPT in the example): 

```c 
switch(interrupt_number) {
    case KEYBOARD_INTERRUPT:
        //do something with keyboard
        break;
    case TIMER_INTERRUPT:
        // eventually doing some other stuff 
        schedule(); // <-- here we call the scheduler
        break;
    case ANOTHER_INTERRUPT:
        // ...
        break;
}
```

Is that all? More or less, we may eventually want to have it called in other cases too (i.e. maybe while serving a syscall, or create a custom interrupt to handle specific cases), but the logic is always the same, we call it in all the parts where we decide is time to have a task switch. 


When the function is called we need to check if it has finished it's allocated time. Who decides it? How long it is? How we calculate it? Well the answer is that this is a design choice, we can schedule a thread at every single timer interrupt, or give it a certain number of *ticks* (where a *tick* is the time passed between a schedule function call and the next one), that number can be fixed (decided at compile time, or by a configuration parameter of the kernel), or variable (for example if we are having tasks with different priorities, maybe we want to give more time to higher priority tasks). But in any case the minimum amount of time a task is in execution is for at least 1 *tick*. 

In the examples that follow we will try to keep things simple and will change task every time the scheduler is called. 

Now if the `current_thread` har reached it's allocated time, it's time to pick the next one. But before doing that we need to save make sure that next time `current_thread` will be picked up, it will resume from the exact point it is being interrupted. This is achieved by saving the current execution context. And what is it? Well we already encountered that, in the [interrupt handling](../InterruptHandling.md) chapter, it is the status of the cpu in that exact istant, all the registers value (the instruction pointer, the stack values, the general purpose registers etc). And this gives us a big hint on how we are going to switch between threads: we will avail of our interrupt handler (*Authors note: of course this is not the only way to switch between task, but this is in our opinion one of the easiest to implement).*)

Let's recall quickly what our interrupt handling routine does: 

* It first save the context pushing all registers on the stack
* Then it calls the interrupt handling function, that serves the interrupt
* It restore the context from the stack
* Return (if possible) the control to the kernel

This means that we have the current execution status saved already on the stack, so we just need to find a way to save it, but before doing that we need to make sure that the scheduler knows what is the starting address of the saved registers, so we need to make sure that the `rsp` address is passed to the interrupt handler routine. If it was not done before, we need to make few changes to our interrupt handling:

* After saving the context we need to pass the current value of rsp to the interrupt handling function, this depends on the architecture used, in our case if we are using x86-64 architecture the first function parameter is placed on the `rdi` register.
* We need to make sure that the interrupt routine will return the context (returning the updated/new rsp value)
* This is optional but it can make the code more reaadable, create a data structure that represent the context.



# The Scheduler

## What is it? 

In a multitasking system (from now on the term *multitasking* refer to both multitasking and multithreading, if there is need to make a distinction the proper term will be used), the scheduler is the operating system componet that is responsible of selecting and loading the next task to be executed by the CPU. 

There are many algorithm that can be used to implement it, and they try to solve different issues or optimize different scenarios, for example a real time operating system will probably wants to execute higher priority tasks more often, where a desktop operating system will probably wants only to divide the time evenly between tasks, etc. 

As usual the purpose of this guide is not to explain the algoirthms, for them there are many Operating System Books that can be used as reference, our purpose is to understand how is it implemented, and make our own scheduler, so we will implement a very simple algorithm that will serve tasks on a FCFS basis (First Come First Served) without priority.

## What it does? in a nutshell

The most basic explanation of a scheduler is just of a function that picks item from a list and load the "context" of the task to let it execute for a while. 

Ok but we now want to go deeper, so first of all let's see what is the workflow of a scheduling function:

* As soon as the function is called it checks the current executing task if it has finished it's allocated time. If no, it will end here, and exit, if yes it will proceed to the next step.
* The task has finished it's allocated time, so the scheduler take the current context (don't worry we will explain it later, but *spoiler alert* technically you already know what it is) and save it to the task, then proceed to the next step
* Now is time to pick up the next task from the list, here the scheduler will start to pick task one after each other searching for the first READY to execute one available (generally there are more than one task ready to execute and which one is taken it depends totally on the algorithm implemented, but the basic idea is: it pick a task to execute), and loads it
    * While searching for the READY tasks, it could be useful (but this is totally up to the design choices again) to also do some housekeeping on the non-reaady tasks, for example has the current task finished it's execution? can it be removed from the list? Does the tasks in WAIT State still needs to wait? 
* Once loaded the new task it finish the execution and return the new context to the operating system.

Probably after having read the above explanation, it can have been raised more questions than answersi (but nothing prevent us to have the schedule function called by just pressing a specific button!), but don't worry this chapter will try to answer as many questions as it can. 

Probably on of the first questions is: Who is calling the `schedule()`  function? It is easy, usually is the interrupt handler, in particular the timer IRQ (but not necessarily only that). So we can imagine to have our ISR hadling routine to be something like: 

```c 
switch(interrupt_number) {
    case KEYBOARD_INTERRUPT:
        //do something with keyboard
        break;
    case TIMER_INTERRUPT:
        // there could be some code here 
        schedule(context); // <-- here we call the scheduler
        break;
    case ANOTHER_INTERRUPT:
        // ...
        break;
}
```

So when the function is called we need to check if it has finished it's allocated time. Who decides it? How long it is? How we calculate it? Well the answer is that this is a design choice, we can schedule a thread at every single timer interrupt, or give it a certain number of *ticks* (where a *tick* is the time passed between a schedule function call and the next one), that number can be fixed (decided at compile time, or by a configuration parameter of the kernel), or variable (for example if we are having tasks with different priorities, maybe we want to give more time to higher priority tasks). But in any case the minimum amount of time a task is in execution is for at least 1 *tick*.

Let's assume that we want to execute our tasks for ten ticks, and let's assume that our *thread_t* structure has a ticks field, we can start to draft a schedule function: 

```c
//This define probably will go in a header file
#define MAX_NUMBER_OF_TASK_TICKS 10

context_t* schedule(context_t* context) {
    // ... more code will go here 
    if (current_thread->ticks < MAX_NUMBER_OF_TASK_TICKS) {
        current_thread->ticks = current_thread->ticks + 1;
        return context;
    }
    // more code will go here
}
```

The above code snippet check if the time slot is finished for the task that is stored in the `current_thread` variable, if not will increment the number of ticks and exit there returning the untouched context.

Now if the `current_thread` har reached it's allocated time, it's time to pick the next one. But before doing that we need to save make sure that next time `current_thread` will be picked up, it will resume from the exact point it is being interrupted. This is achieved by saving the current execution context. And what is it? Well we already encountered that, in the [interrupt handling](../InterruptHandling.md) chapter, it is the status of the cpu in that exact istant, all the registers value (the instruction pointer, the stack values, the general purpose registers etc). And this gives us a big hint on how we are going to switch between threads: we will avail of our interrupt handler (*Authors note: of course this is not the only way to switch between task, but this is in our opinion one of the easiest to implement).*)

Let's recall quickly what our interrupt handling routine does: 

* It first save the context pushing all registers on the stack
* Then it calls the interrupt handling function, that serves the interrupt
* It restore the context from the stack
* Return (if possible) the control to the kernel

This means that we have the current execution status saved already on the stack, so we need just to find a way to save it, but before it we need to make sure that the scheduler knows what is the starting address of the saved registers, so we need to make sure that the `rsp` address is passed to the interrupt handler routine



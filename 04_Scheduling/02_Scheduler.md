# The Scheduler

## What is it? 

In a multitasking system (from now on, the term *multitasking* can refer to both multitasking and multithreading, if there is need to make a distinction the proper term will be used), the scheduler is the operating system componet that is responsible of selecting and loading the next task to be executed by the CPU. 

The idea of a task scheduler is pretty straightforward, it picks a task from a list, grant it some execution time, then put it back in the list and pick the next one.

On how to select the task from the list there are many algorithms that can be used to implement it, and they try to solve different issues or optimize different scenarios, for example a real time operating system will probably wants to execute higher priority tasks more often, where a desktop operating system will probably wants only to divide the time evenly between tasks, etc. 

As usual the purpose of this guide is not to explain the algoirthms, for them there are many Operating System Books that can be used as reference, our purpose is to understand how it is implemented, and make our own one, so we will implement a very simple algorithm that will serve tasks on a FCFS basis (First Come First Served) without priority.

## Overview of how a scheduler work

As we said above a task scheduler is basically a function that picks a task from a list and execute it for some time and when done places it back in the list to pick a new one. 

But before going explaining its the workflow let's answer few questions: 

* Who is going to call the scheduler? This is a design choice but usually a timer is the most common reason for a scheduler tick, but you can also reschedule anytime code enters the kernel. If code performs a blocking system call, you might want to reschedule until that call can complete (waiting on the network to send some data for example).
* What is a task? This concept will be described in more detail on the next chapter, but generally speaking a task is a data structure that reperesent an application running, and threads,if implemented, are portion of tasks that can run concurrently. 
* How long a task is supposed to run before being replaced? That is another design choice that depends on different factors (for example algorithm used, personal choice, it can be even customized by the user), but usually the minimum is the time between one timer interrupt and the next other. The act of interrupting an executing task with the intention of resuming it later is called *preemption*
* Are there cases where the task is not finished yet, but it is unavailable to run at the moment? Yes, and it will be discussed later, and the scheduler must be aware of that.  


The basic idea behind ever scheduler is more or less the following: 

* The first thing that the scheduler function does when called is checking if the task should be preempted or not, that depends on design decision, in the most simple scenario we switch task at every scheduler tick (but there can be more complex designs). If the task doesn't need to be switched yet, it exits here, otherwise it takes the current context (we have already seen this concept in the Interrupt handling chapter) and save it to the current executing task, then proceed to the next step.
* After having saved the context of the current task, it needs to pick up the next one from the list. It will start to pick tasks one after each other searching for the first one that is  *ready* to execute  (there are probably more than one ready to execute and which one is taken depends totally on the algorithm implemented. The selected one will be the new current task.
    * During the search of the READY task, it could be useful (but not necessary, is  up to the design choices again) to do some housekeeping on the non-reaady tasks. For example: has the current task finished it's execution? Can it be removed from the list? Does the tasks in WAIT State still needs to wait? 
* Once the new task is loaded the scheduler return the new context to the operating system.

The basic scheduler we are going to implement will have the following characteristics: 

1. It will execute tasks in a First Come First Served basis
2. The tasks will be kept in a fixed size array (to keep the implementation simple, and focus on the main topic)
3. The execution time for each task will be just 1 timer tick. (so they will be changed every time the timer interrupt will be called)

Now that we have an idea of what we have to write we can start describing how it will be implemented

### Prerequisites and initialization

Our scheduler to work correctly needs to keep track of some information, related to the current execution status. 

The first thing that it needs is a list that holds all the tasks that it are currently active (with *active* we mean that are not finished their execution yet), as we mentioned above we will do it using a simple array: 

```c
//This probably will go in the header file
#define MAX_TASKS 100

task_t* tasks_list[MAX_TASK]
```

The datatype `task_t` is not a basic type, it is a data structure that we have to implement, it will be explained in detail in the *Tasks and thread* Chapter, but for now let's assume it contains the the minimum set of information needed: the  context information, and the current task status:

```c
#define TASK_NAME_MAX_LEN 64

typedef struct {
    status_t task_status;
    cpu_status_t context
} task_t;
```

Here we go again, there are new customized datatypes, let's start with the simple one `status_t` that is just an enum to use a more human readable status identifier, for now we assume that our tasks will have just three statuses:

* READY: the task is ready to be executed
* RUNNING: this task is currently running on a cpu/core
* DEAD: this task has reached the end of it's life (it has been killed or it just finished executing the code), and can be deleted

Our enum will look like: 

```c
typedef enum {
    READY,
    RUNNING,
    DEAD
} status_t;
```

As for `cpu_status_t`, it'll store the current context of the thread. What's a context? It needs to be able to store enough state to allow us to stop the thread, do other stuff on the cpu, and then start running the thread again. All without the thread knowing it was stopped. It's essentially a snapshot of the parts of the cpu that the running thread can see. To be more concrete about it we'll be storing all of the general purpose registers (on x86 that's rax - r15), the current stack and on x86 we'll need an iret frame, since we'll be running inside of an interrupt handler. This is starting to sound very familiar! This is exactly the structure we described in the interrupts chapter. Setting up our context in this way allows us to reuse the same structure, and since on x86 we store all those details on the stack, we just need to store a pointer to the top of the stack.

Next thing that he scheduler need is to keep track of what is the current executing task, so this is implementation specific, for example if we are using a linked list it will probably be a pointer to the `task_t` strucutre, but in our case, since we are using an array we can use a simple integer to point to the current executing task.

```c
size_t current_executing_task_idx;
```

Now that we have all the variables and structures declared we need to initialize the scheduler, in our simple scenario there are just few things that we have to do: 

* Initialize the array of active tasks to NULL (we will use NULL as identifier for an available position in the array)
* Initialize the `current_executing_task_idx` to 0. 

### Calling the scheduler

The first thing that we need to do is to decide when to call the scheduler, as already mentioned above it can be called in many different cases and it's totally up to us (nothing prevent us to have the scheduler function called only when a big red button plugged to the computer is pressed).

But in a multitasking operating system, where what expect is at least that every task gets it's own fair (more or less) share of cpu-time, we want it to be called at regular intervals of time. And this can be easily achieved letting the timer interrupt handler routine do the call if ( you have followed this guide you probably have it already implemented). 

Let's assume that we have a centralized interrupt handling routine where the correspoding action is selected within a switch statement, and we (will) have a `schedule()` function to call that implements our scheduler. In this case according to the design outlined above we want `schedule()` to be called within the interrupt timer case (labeled as TIMER_INTERRUPT in the example): 

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

#### Checking if the task should be preempted

Even if we are not going to make this check in our algorithm, it is worth spending few more words about it.

Depending on the algorithm selected (or created) we can decide to let tasks execute for more time than one *quantum* (this terms indicates the amount of time between two ticks of the timer), and in this case we will need to implement a mechanism to decidere whether the task should be interrupted or not. 

When the function is called we need to check if it has finished it's allocated time. Who decides it? How long it is? How we calculate it? Well the answer is that this is a design choice, we can schedule a task at every single timer interrupt, or give it a certain number of *ticks*, that number can be fixed (decided at compile time, or by a configuration parameter of the kernel), or variable (for example if we are having tasks with different priorities, maybe we want to give more time to higher priority tasks). But in any case the minimum amount of time for a task in execution is for at least 1 *tick*. 

As mentioned above we will try to keep things simple and will change task every time the scheduler is called. So we will skip this check. 

### Selecting task to execute

The main purpose of the scheduler is of course to select the next task to run (and pause/stop the current one). How is done depends heavily on the algorithm implemented, that in our case is very simple: it select them on order of arrival, the older get executed first, and once the last is reached it starts again from the first until there are tasks to execute. 

This is called a Round Robin algorithm. Let's focus just on the selection for now, ignoring all other parts (like status check, context save/load), there is just one thing we need to be aware of: when we reach the last item in the array to go back to the beginning. We have defined the maximum number of tasks in the MAX_TASKS constant, so our increment will look like: 

```c
void schedule() {
    current_executing_task_idx = (current_executing_task_idx + 1) % MAX_TASKS
}
```

This is a simple trick that use the "Modulo" operation to get the remainder of the division by MAX_TASKS, because we are always guaranteed that the remainder will always be between 0 and MAX_TASKS. 
And that's it, this is how we get to the next item and start all over again when we hit the end (of course it assumes that all the variables are correctly initialized). 

But that is not enough because and there are some issues that are related to our design, the first one is: since we are using a fixed size array when a task will finish it's execution time, it will be removed by replacing the value pointer with NULL. So in this case we need to make sure that the selected index is not empty, and it contains an actual task (otherwise prepare for some very strange behaviour...). This can be achieved by adding a while loop that keep increasing the index until it finds an item in the array that is not NULL: 

```c
void schedule() {

    current_executing_task_idx = (current_executing_task_idx + 1) % MAX_TASKS;
    while(tasks_list[current_executing_task_idx] == NULL) {        
        current_executing_task_idx = (current_executing_task_idx + 1) % MAX_TASKS;
    }
}
``` 

Now our schedule function every time that is called will pick the next not null item (task) in the array. But there is a problem: if there are no tasks in the array, the while loop will never end, and so the interrupt handler will never exit, leaving the kernel stuck there. And that's true, but we will see how to solve this problem later in the chapter, for now let's just pretend that this case never happen, and continue with our implementation.

### Saving the task context 

In the previous section we have seen how to iterate throught tasks, but that basically just iterating through items of a list, so for now our scheduler is still doing nothing. Once the next task to be executed has been selected selected, the first thing that the scheduler has to do is stop the current task, and save its current status. If you have implemented the interrupt handler following this guide you should already have the context being passed to the it, so now we need to change the signature of our schedule function, adding a new parameter: 

```c
void schedule(cpu_status_t* context);
````

### this part will be explaine during the scontext switch 

The other issue is that if there are no tasks left on the array, this loop will runn enldlessy, in theory, in practice it will most likely run into garbage as soon as it return from the interrupt. The details about this problem will be more clear later, but to fix it we just need to make sure that we don't run out of tasks, and the easiest way to do it, is have an idle


### Next stuff to be completed...

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



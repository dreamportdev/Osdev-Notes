# The Scheduler

## What is it? 

In a multitasking system (from now on, the term *multitasking* can refer to both multitasking and multithreading, if there is need to make a distinction the proper term will be used), the scheduler is the operating system component that is responsible of selecting and loading the next process to be executed by the CPU. 

With process we usually mean a program in execution, in literature it can be referred to with many names: task, job, etc. In this guide we will use the term process. 

The idea of a process scheduler is pretty straightforward, it picks an item (process) from a list, grant it some execution time, then put it back in the list and pick the next one.

On how to select a process from the list there are many algorithms that can be used, and they try to solve different problems or optimize different scenarios, for example a real time operating system will probably wants to execute higher priority processes more often, where a desktop operating system will probably wants only to divide the time evenly between processes, etc. 

As usual the purpose of this guide is not to explain the algoirthms, for them there are many Operating System Books that can be used as reference, our purpose is to understand how it is implemented, and implement one, so we will write a very simple algorithm that will serve processes on a FCFS basis (First Come First Served also known as Round Robin) without priority based on an array.

## Overview of how a scheduler work

As we said above a process scheduler is basically a function that picks a process from a list and execute it for some time and when done places it back in the list to pick a new one. 

But before going explaining its the workflow let's answer few questions: 

* Who is going to call the scheduler? This is a design choice but usually a timer is the most common reason for a scheduler tick, but you can also reschedule anytime code enters the kernel. If code performs a blocking system call, you might want to reschedule until that call can complete (waiting on the network to send some data for example).
* What is a process? This concept will be described in more detail on the next chapter, but generally speaking a process is a data structure that reperesent an application running, and threads,if implemented, are portion of processes that can run concurrently. 
* How long a process is supposed to run before being replaced? That is another design choice that depends on different factors (for example algorithm used, personal choice, it can be even customized by the user), but usually the minimum is the time between one timer interrupt and the next other. The act of interrupting an executing process with the intention of resuming it later is called *preemption*
* Are there cases where the process is not finished yet, but it is unavailable to run at the moment? Yes, and it will be discussed later, and the scheduler must be aware of that.  


The basic idea behind every scheduler is more or less the following: 

* The first thing that the scheduler function does when called is checking if the process should be preempted or not, that depends on design decision, in the most simple scenario we switch process at every scheduler tick (but there can be more complex designs). If the process doesn't need to be switched yet, it exits here, otherwise it takes the current context (we have already seen this concept in the Interrupt handling chapter) and save it to the current executing process, then proceed to the next step.
* After having saved the context of the current process, it needs to pick up the next one from the list. It will start to pick processes one after each other searching for the first one that is  *ready* to execute  (there are probably more than one ready to execute and which one is taken depends totally on the algorithm implemented. The selected one will be the new current process.
    * During the search of the READY process, it could be useful (but not necessary, is  up to the design choices again) to do some housekeeping on the non-reaady processes. For example: has the current process finished it's execution? Can it be removed from the list? Does the processes in WAIT State still needs to wait? 
* Once the new process is loaded the scheduler return the new context to the operating system.

The basic scheduler we are going to implement will have the following characteristics: 

1. It will execute processes in a First Come First Served basis
2. The processes will be kept in a fixed size array (to keep the implementation simple, and focus on the main topic)
3. The execution time for each process will be just 1 timer tick. (so they will be changed every time the timer interrupt will be called)

Now that we have an idea of what we have to write we can start describing how it will be implemented

### Prerequisites and initialization

Our scheduler to work correctly needs to keep track of some information, related to the current execution status. 

The first thing that it needs is a list that holds all the processes that it are currently active (with *active* we mean that are not finished their execution yet), as we mentioned above we will do it using a simple array: 

```c
//This probably will go in the header file
#define MAX_TASKS 100

process_t* processes_list[MAX_TASK]
```

The datatype `process_t` is not a basic type, it is a data structure that we have to implement, it will be explained in detail in the *Tasks and thread* Chapter, but for now let's assume it contains the the minimum set of information needed: the  context information, and the current process status:

```c
#define TASK_NAME_MAX_LEN 64

typedef struct {
    status_t process_status;
    cpu_status_t context;
} process_t;
```

Here we go again, there are new customized datatypes, let's start with the simple one `status_t` that is just an enum to use a more human readable status identifier, for now we assume that our processes will have just three statuses:

* READY: the process is ready to be executed
* RUNNING: this process is currently running on a cpu/core
* DEAD: this process has reached the end of it's life (it has been killed or it just finished executing the code), and can be deleted

Our enum will look like: 

```c
typedef enum {
    READY,
    RUNNING,
    DEAD
} status_t;
```

As for `cpu_status_t`, it'll store the current context of the thread. What's a context? It needs to be able to store enough state to allow us to stop the thread, do other stuff on the cpu, and then start running the thread again. All without the thread knowing it was stopped. It's essentially a snapshot of the parts of the cpu that the running thread can see. To be more concrete about it we'll be storing all of the general purpose registers (on x86 that's rax - r15), the current stack and on x86 we'll need an _iret frame_, since we'll be running inside of an interrupt handler. This is starting to sound very familiar! This is exactly the structure we described in the [interrupts](../InterruptHandling.md) chapter. Setting up our context in this way allows us to reuse the same structure, and since on x86_64 we store all those details on the stack, we just need to store a pointer to the top of the it.

Next thing that he scheduler need is to keep track of what is the current executing process, so this is implementation specific, for example if we are using a linked list it will probably be a pointer to the `process_t` strucutre, but in our case, since we are using an array we can use a simple integer to point to the current executing process.

```c
size_t current_executing_processes_idx;
```

Now that we have all the variables and structures declared we need to initialize the scheduler, in our simple scenario there are just few things that we have to do: 

* Initialize the array of active processes to NULL (we will use NULL as identifier for an available position in the array)
* Initialize the `current_executing_processes_idx` to 0. 

### Calling the scheduler

The first thing that we need to do is to decide when to call the scheduler, as already mentioned above it can be called in many different cases and it's totally up to us (nothing prevent us to have the scheduler function called only when a big red button plugged to the computer is pressed).

But in a multitasking operating system, where what expect is at least that every process gets it's own fair (more or less) share of cpu-time, we want it to be called at regular intervals of time. And this can be easily achieved letting the timer interrupt handler routine do the call if ( you have followed this guide you probably have it already implemented). 

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

Is that all? More or less, we may eventually want to have it called in other cases too (i.e. maybe while serving a syscall, or create a custom interrupt to handle specific cases), but the logic is always the same, we call it in all the parts where we decide is time to have a process switch. 

#### Checking if the process should be preempted

Even if we are not going to make this check in our algorithm, it is worth spending few more words about it.

Depending on the algorithm selected (or created) we can decide to let processes execute for more time than one *quantum* (this terms indicates the amount of time between two ticks of the timer), and in this case we will need to implement a mechanism to decidere whether the process should be interrupted or not. 

When the function is called we need to check if it has finished it's allocated time. Who decides it? How long it is? How we calculate it? Well the answer is that this is a design choice, we can schedule a process at every single timer interrupt, or give it a certain number of *ticks*, that number can be fixed (decided at compile time, or by a configuration parameter of the kernel), or variable (for example if we are having processes with different priorities, maybe we want to give more time to higher priority processes). But in any case the minimum amount of time for a process in execution is for at least 1 *tick*. 

As mentioned above we will try to keep things simple and will change process every time the scheduler is called. So we will skip this check. 

### Selecting process to execute

The main purpose of the scheduler is of course to select the next process to run (and pause/stop the current one). How is done depends heavily on the algorithm implemented, that in our case is very simple: it select them on order of arrival, the older get executed first, and once the last is reached it starts again from the first until there are processes to execute. 

This is called a Round Robin algorithm. Let's focus just on the selection for now, ignoring all other parts (like status check, context save/load), there is just one thing we need to be aware of: when we reach the last item in the array to go back to the beginning. We have defined the maximum number of processes in the MAX_TASKS constant, so our increment will look like: 

```c
void schedule() {
    current_executing_processes_idx = (current_executing_processes_idx + 1) % MAX_TASKS
}
```

This is a simple trick that use the "Modulo" operation to get the remainder of the division by MAX_TASKS, because we are always guaranteed that the remainder will always be between 0 and MAX_TASKS. 
And that's it, this is how we get to the next item and start all over again when we hit the end (of course it assumes that all the variables are correctly initialized). 

But that is not enough because and there are some issues that are related to our design, the first one is: since we are using a fixed size array when a process will finish it's execution time, it will be removed by replacing the value pointer with NULL. So in this case we need to make sure that the selected index is not empty, and it contains an actual process (otherwise prepare for some very strange behaviour...). This can be achieved by adding a while loop that keep increasing the index until it finds an item in the array that is not NULL: 

```c
void schedule() {

    current_executing_processes_idx = (current_executing_processes_idx + 1) % MAX_TASKS;
    while(processes_list[current_executing_processes_idx] == NULL) {        
        current_executing_processes_idx = (current_executing_processes_idx + 1) % MAX_TASKS;
    }
}
``` 

Now our schedule function every time that is called will pick the next not null item (process) in the array. But there is a problem: if there are no processes in the array, the while loop will never end, and so the interrupt handler will never exit, leaving the kernel stuck there. And that's true, but we will see how to solve this problem later in the chapter, for now let's just pretend that this case never happen, and continue with our implementation.

### Saving and restoring the process context 

In the previous section we have seen how to iterate throught processes, but that basically was just iterating through items of a list, not very useful. 

#### Saving Context

Once the next process to be executed has been selected, the first thing that the scheduler has to do is stop the current process, and save its current status. If you have implemented the interrupt handler following this guide you should already have the context being passed to, what we want is to pass down the context to the schedule function, but first  we need to change its signature, adding a new parameter: 

```c
void schedule(cpu_status_t* context);
````

And now add the context parameter where the function is called. Now with this new parameter we have a snapshot of the cpu just before the interrupt was fired, and what was it was doing just before it? Running our process, so what we just need to do is update the context variable of the current process just before picking the next: 

```c
void schedule(cpu_status_t* context) {
    processes_list[current_executing_processes_idx].context = context
    current_executing_processes_idx = (current_executing_processes_idx + 1) % MAX_TASKS;
    while(processes_list[current_executing_processes_idx] == NULL) {        
        current_executing_processes_idx = (current_executing_processes_idx + 1) % MAX_TASKS;
    }
}

```

that's it, this is how how we save the status of the current executing process. 

#### Restoring context

After the previous process has been saved and the next one has been selected we are now ready to make the switch. How to do it is pretty straightforward, but let's have a quick recap on how we are handling interrupts: 

1. The first thing is that whenever an interrupt is fired an asm code snippet is called saves the current cpu registers status, on the stack, 
2. Then once the status is saved, it place the current stack pointer (`rsp`) on the `rdi` register (it is the first c function parameter for x86_64 architecture) and call the interrupt handler. This parameter is our `context` variable (that is passed also to the scheduler)
3. Then our interrupt handler function (unless we are writing an os entirely in asm, this usually is on our language of choice, in our case C)  does whatever it needs to serve the interrupt and return the context variable. Returning a variable, according to the ABI calling convention is corresponding to placing the returning value to the `rax` register
4. Now we are back in the asm code where `rax` value is placed on the `rsp` register, and then the context restored...
5. and everyone lived happily after (until the next interrupt will happens...) 

So what is happening is that we pass the context as a parameter to the interrupt handler routine, and when we leave it we return it and use the returned value to restore the cpu status just before resuming the normal execution. 

And the context being passed is the stack pointer, now the whole idea behind the interrupt handling routine is that we save the context on the stack before starting the interrupt handler, and restore it once the interrupt is done. So what happens if instead of restoring the context from the same stack pointer, we restore it from a different one? 

What will happens is that it resumes the execution of whatever was stored on that other context (if it was a valid one), hence we have a *process switch*. 

And to implement this change we just need to make two tiny adjustments to our scheduler function: change its return type from `void` to `cpu_status_t*` and return the newly loaded context to the caller: 

```c
cpu_status_t* schedule(cpu_status_t* context) {
    processes_list[current_executing_processes_idx].context = context
    current_executing_processes_idx = (current_executing_processes_idx + 1) % MAX_TASKS;
    while(processes_list[current_executing_processes_idx] == NULL) {        
        current_executing_processes_idx = (current_executing_processes_idx + 1) % MAX_TASKS;
    }
    return processes_list[current_executing_processes_idx].context;
}
```

And now our scheduler is capable of switching processes (if you have remembered to replace `rsp` with the value returned from the interrupt handler in `rax`).

### The process status

In the paragraphs above we covered mostly everything that is needed to make the process switching possible, in fact it is already able to switch between them. But there are some  problem and limitations, that we should consider. Let's see what they are. 

The high level definition of a process is of a program or portion of prorgam that is being executed by a cpu, but usually programs have a lifecycle, they start, run for a while and sooner or later they will terminate in many cases (of course this is not generally true there are many programs that are supposed to run indefenetely). 

This means that sooner or later one or more of our processes can finish its work and would like to terminate, but with the actual scheduler what will more likely happen is that once the program has terminated it will remanins in the queue and next time it will be selected for execution it starts to run into garbage causing unpredicatble behaviour. So our scheduler needs to know if a process is terminated or not. 

And consider also another scenario: imagine we have a process that needs to wait for output from a slow i/o device, that will take few seconds to run, now with the current scheduler what will happen is that the process will be granted execution time hundred of times while it is actually doing nothing, wasting cpu time that could be used by other processes. Again if the scheduler could know that the process is waiting for an action to be completed, we could make it more efficient probably putting the process to sleep. 

This is where the status variable comes handy, by defining several states we can let the scheduler know what is the current status of the process so it can take the appropriate action. This is another area where the number of states totally depend on design decision and the scheduler, there is no fixed number or best choice. So again it's up to us. 

In this section we will start with only 3 states, the ones defined above: READY, RUN, DEAD (we will cover the sleeping scenario in the next chapter). The name is pretty self explanatory:

* READY is the status of a process that is in the queue waiting for it's turn and able to be executed
* RUNNING is the status of a process being executed by the cpu 
* DEAD is the status of a process that has terminated (or being killed) and waits to be removed from the queue. 

So our algorithm before executing a process will check its status and take the appropriate action: 

* If the process that has been picked has the status as READY it means that it can be executed so we can select it and go ahead
* If the process that has been picked has the status as DEAD it has to be removed from the array, in our case we need to set the status as null. 

And of course we need to update the status of the current executing process from RUNNING to READY or DEAD depending on the case. So the updated code will look similar to the following:  

```c
cpu_status_t* schedule(cpu_status_t* context) {
    processes_list[current_executing_processes_idx].context = context
    processes_list[current_executing_processes_idx].status = READY;
    current_executing_processes_idx = (current_executing_processes_idx + 1) % MAX_TASKS;
    while (processes_list[current_executing_processes_idx] == NULL) {        
        current_executing_processes_idx = (current_executing_processes_idx + 1) % MAX_TASKS;
        if (processes_list[current_executing_processes_idx] != NULL && processes_list[current_executing_processes_idx].status == DEAD) {
            processes_list[current_executing_processes_idx] = NULL;
            continue;
        }
    }
    return processes_list[current_executing_processes_idx].context;
}
```

Now the question is: how we mark the process as DEAD. This will be explained in detail in the Tasks and Threads chapter, but let's introduce it in this paragraph. When we create a process we also pass a function pointer that will be the entry point for it, and in theory it should be placed in the `rip` field of the frame, the only problem is that in this way we have no way to update the process status and prevent it to run into garbage. The trick here is to wrap the entry point into another function, that will do just two things: 

* First call the function pointer
* And then call a suicide function. 

The function will look like this: 

```c
void process_wrapper( void (*_processes_entry_point)(void *), void *arg) {
    _processes_entry_point(arg);
    process_suicide();
}
``` 

The process_wrapper function will be the one that will be placed on the rip field. And for the function parameters they will be placed in the stack. But we will get back to it with more detail in the next chapter. 

## Wrapping up

This chapter has covered nearly everything needed to get the context switch done, there are few gaps about process handling and creation that will be covered in the next chapter. As already mentioned we tried to keep the algorithm as simple as possible to focus on the concept of process switching, but from here there are many improvements that can be implemented on the scheduler, few examples: 

* Replace the array with another type of list possibly dynamic
* Add more process statuses (we will add at least another one in the next chapter)
* Add some kind of priority mechanism or differentiate processes time running on the cpu. 



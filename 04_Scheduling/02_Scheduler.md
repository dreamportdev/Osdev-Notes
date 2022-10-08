# The Scheduler

## What Is It?
The scheduler is the part of the kernel responsible for selecting the next process to run, as well as keeping track of what threads and processes exist.

The primitives used (thread and process) have various names in other kernels and literature: job, task, lightweight task. 

### Thread Selection
There are many selection algorithms out there, ranging from general purpose to special purpose. A real-time kernel might have a selection algorithm that focuses on meeting hard deadlines (required for real-time softare), where as a general purpose algorithm might focus on flexibility (priority levels and being extensible).

Our scheduler is going to operate on a first-come first-served (FCFS) bases, commonly known as round-robin. 

## Overview 
Before we start describing the workflow in detail, let's answer a few questions:

* When does the scheduler run? The simplest answer is during a timer interrupt. Having said that, there are many other times you might want to trigger the scheduler, such as a waiting on a slow IO operation to complete (the network, or an old hard drive). Some programs may have run out of work to do temporarily and want to ask the scheduler to end their current time slice early. This is called *yielding*.
* How long does a thread run for before being replaced by the next one? There's no simple answer to this, as it can depend a number of factors, even down to personal preference. There is a minimum time that a thread can run for, and that's the between between one timer interrupt and the next. This portion of time is called a *quantum*, because it represents the fundamental unit of time we will be dealing with. The act of a running thread being interrupted and replaced is called *pre-emption*.

The main part of your scheduler is going to be thread selection. Let's breakdown how we're going to implement it:

* When called, the first thing the scheduler needs to do is check whether the current thread should be pre-empted or not. Some critical sections of kernel code may disable pre-emption for various reasons, or a thread may simply be running for more than one quantum. The scheduler can choose to simply return here if it decides it's not time to reschedule.
* Next it must save the current thread's context so that we can resume it later. 
* The step is where we select the next thread to run. For a round robin scheduler we will search the list of threads that are available to run, starting with the current thread. We stop searching when we find the next thread that can run.
* Optionally, while iterating through the list of threads we may want to do some house-keeping. This is a good time to do things like check wake-timers for sleeping threads, or remove dead threads from the list. If this is unfamiliar to you, we'll discuss this more later don't worry.
* Now we load the context for the selected thread and mark it as the current thread.

The basic scheduler we are going to implement will have the following characteristics:

1. It will execute in a first-come first-served basis.
2. The threads will be kept in a fixed size array. This was done to keep the implementation simple, and keep the focus on the scheduling code. This is an easy first step to improving your own scheduler!
3. Each thread will only run for a single quantum (i.e. each timer interrupt will trigger the thread to reschedule).
4. While we have explained the difference between a thread and process, we're going to combine them both into the same structure for simplicity. This limits each process to one thread, but this is an easy next-step for you to take with your own scheduler. We'll be referring to this structure as just a process from now on.

### Prerequisites and Initialization
For our scheduler to work correctly it will need to keep track of some information. The first thing will be a list of the currently active processes (by *active* we mean that the process has not finished executing yet). As we mentioned above we're going to use a simple array:

```c
#define MAX_PROCESSES 100

process_t* processes_list[MAX_PROCESSES];
```

We'll delve into what exactly a process might need to contain in a separate chapter, but for now we'll define it as the following:

```c
typedef struct {
    status_t process_status;
    cpu_status_t context;
} process_t;
```

If `cpu_status_t` looks familiar, it's the struct we created in the interrupts chapter. This represents a snapshot of the cpu when it was interrupted, which conviniently contains everything we need to resume the process properly. This is our processes's `context`.

As for `status_t`, it's a enum representing one of the possible states a process can be in. This could also be represented by a plain integer, but this is nicer to read and debug. For now our processes are just going to have three statuses:

* READY: The process is runnable, and can be executed.
* RUNNING: The process is currently running.
* DEAD: The process has finished executing, and can have it's resources cleaned up.

Our enum wll look like the following:

```c
typedef enum {
    READY,
    RUNNING,
    DEAD
} status_t;
```

The scheduler will also need to keep track of which process is currently being executed. How exactly you do this depends on the data structure used to store your proceses, since we're using an array, we can just store the index of the current process.

```c
size_t current_process_idx;
```

All that remains is to initialize the array of processes to `NULL` to indicate they are empty slots in the array (and not a real process), and set the current process index to 0.

### Triggering the Scheduler

As mentioned above we're going to have the scheduler run in response to the timer interrupt, but you can trigger it however you wish. There's nothing to stop you only have the scheduler run when a big red button is pushed, if you wanted. Having the scheduler attached to the timer interrupt like this is a good first effort to ensuring your scheduler gives each process a fair share of cpu time. 

For the following sections we assume your interrupt handlers look like the ones described in the interrupt handling chapter, and all route to a single function. We're going to have a function called `scheduler()` that will do process selection for us. Patching that into our interrupt routing function would look something like:

```c
switch (interrupt_number) {
    case KEYBOARD_INTERRUPT:
        //do something with keyboard
        break;
    case TIMER_INTERRUPT:
        //eventually do other stuff here
        schedule();
        break;
    case ANOTHER_INTERRUPT:
        //...
        break;
}
```

That's the foundation for getting our scheduler running. As previously mentioned, there may be other times you want to reschedule, but these are left as an exercise for the reader.

### Checking For Pre-Emption

While we're not going to implement this here, it's worth spending a few words on this idea.

Swapping processes quantum is simple, but very wasteful. One way to help deal with this is to store a time-to-live value for the current process. If there are a lot of processes running, the scheduler gives each process a lower time-to-live. This results in more context switches, but also allows more processes to run. There's a lot of variables here (minimum and maximum allowed values), and how do you determine how much time to give a process? There's other things you could do with this approach, like giving high priority processes more time, or having a real-time process run more frequently, but with less time.

### Process Selection

This is the main part of the scheduler: selecting what runs next. It's important to remember that this code runs inside of an interrupt handler, so we want to keep it simple and short. Since we're using round robin scheduling, our code meets both of these criteria!

The core of the algorithm is deceptively simple, and looks as follows:

```c
void schedule() {
    current_process_idx = (current_process_idx++) % MAX_PROCESSES;
}
```

We make use of the module operator here to keep the current process index within the bounds of the array. You'll need to change this if you use your own data structure.

There are a few issues we need to address with this version of the algorithm though: we said before that we'll use `NULL` to represent an empty process in the array. We'll need to handle that.

```c
void schedule() {
    do {
        current_process_idx = (current_process_idx++) % MAX_PROCESSES;
    }
    while (processes_list[current_process_idx] == NULL);
}
```

Now our schedule function will handle `NULL` processes correctly. However now we have another problem to address: what if there are no processes to be run? In our case our selection function would loop forever. We're going to solve this problem by having a special process we run when there are no others. This is called the idle process, and will be looked at later.

### Saving and Restoring Context

Now we have the next process to run, and are ready to load it's context and begin executing it. Before we can do that though, we need to save the context for the current process. 

In our case, we're storing all the state we need on the stack, meaning we only need to keep track of one pointer for each process: the stack we pushed all of the registers onto. We can also return this pointer to the interrupt stub and it will swap the stack for us, and then load the saved registers.

In order for this to happen, we need to modify our `schedule()` function a little:

```c
cpu_status_t* schedule(cpu_status_t* context) {
    processes_list[current_process_idx]->context = context;

    do {
        current_process_idx = (current_process_idx++) % MAX_PROCESSES;
    }
    while (processes_list[current_process_idx] == NULL);

    return processes_list[current_process_idx]->context;
}
```

#### In-Review

1. When a timer interrupt is fired, the cpu pushes the iret frame on to the stack. We then push a copy of what all the general purpose registers looked like before the interrupt. This is the context of the interrupted code.
2. We place the address of the stack pointer into the `rdi` register, as per the calling convention, so it appears as the first argument for our `schedule()` function.
3. After the selection function has returned, we use the value in `rax` for the new stack value. This is where a return value is placed according to the calling convention.
4. The context saved on the new stack is loaded, and the new iret frame is used to return to the stack and code of the new process.

This whole process is referred to as a *context switch*, and perhaps now you can understand why it can be a slow operation.

### The States of a Process

While some programs can run indefinitely, most will do some assigned work and then terminate. Our scheduler needs to handle a process terminating, because if it attempts to load the context of a finished program, the cpu will start executing whatever memory comes next as code. This is often garbage and can result in anything happening. Therefore our scheduler needs to know that a process has finished, and shouldn't be scheduled again.

There is also another scenario to consider: imagine we have a process that is a driver for a slow IO device. A single operation could take a few seconds to run, and if this process is doing nothing the whole time, thats time taken away from other threads that could be doing work. This is something our scheduler needs to know about as well.

Both of these are solved by the use of the `status` field of our process struct. Our scheduler is going to operate as a state machine, and this field represents the state of a process. Your scheduler may have more or less states.

Our scheduler will only have three states for now:

* READY: The process is in the queue and waiting to be scheduled.
* RUNNING: The process is currently running on the cpu.
* DEAD: The process has finished running and should not be scheduled. It's resources can also be cleaned up.

We'll modify our selection algorithm to take these new states into account:

```c
cpu_status_t* schedule(cpu_status_t* context) {
    processes_list[current_process_idx]->context = context;
    processes_list[current_process_idx]->status = READY;

    do {
        current_process_idx = (current_process_idx++) % MAX_PROCESSES;
        if (processes_list[current_process_idx] != NULL && processes_list[current_process_idx]->status == DEAD)
            process_list[current_process_idx] = NULL;
    }
    while (processes_list[current_process_idx] == NULL || processes_list[current_process_idx] != READY);

    processes_list[current_process_idx]->status = RUNNING;
    return processes_list[current_process_idx]->context;
}
```

We'll look at the DEAD state more in the next chapter, but for now we can set a processes state to DEAD to signal it's termination. When a thread is in the DEAD state, it will be removed from the queue the next time the scheduler encounters it.

### The Idle Process

We mentioned the idle process before. When there are no processes in the `READY` state, we'll run the idle process. It's purpose is to do nothing, and in a priority-based scheduler it's always the lowest priority. 

The main function for the idle process is very simple. It can be just three lines of assembly!

```x86asm
loop:
    hlt
    jmp loop
```

That's all it needs to do: halt the cpu. We halt inside a loop so that we wake from an interrupt we halt again, rather than trying to execute whatever comes after the jump instructon.

You can also do this in C using inline assembly:

```c
void idle_main(void* arg) {
    while (true)
        asm("hlt");
}
```

The idle task is scheduled a little differently: it should only run when there is nothing else to run. You wouldn't want it to run when there is real work to do, because it's essentially throwing away a full quantum that could be used by another thread.

## Wrapping Up

This chapter has covered everything needed to have a basic scheduler up and running. In the next chapter we'll look at creating and destroying processes. As mentioned this scheduler was written to be simple, not feature-rich. There are a number of ways you could improve upon it in your own design:

* Replace the statically-sized array with a dynamic data structure, allowing as many threads as you want.
* Add more states for a process to be in. We're going to add one more in the next chapter.
* Implement priority queues, where the scheduler runs threads from a higher priority first if they're available, otherwise it selects background processes.
* Add support for multiple processor cores. This can be very tricky, so some thought needs to go into how you design for this.

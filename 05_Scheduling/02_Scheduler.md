# The Scheduler

## What Is It?

The scheduler is the part of the kernel responsible for selecting the next process to run, as well as keeping track of what threads and processes exist in the system.

The primitives used (thread and process) have various names in other kernels and literature: job, task, lightweight task.

### Thread Selection

There are many selection algorithms out there, ranging from general purpose to special purpose. A real-time kernel might have a selection algorithm that focuses on meeting hard deadlines (required for real-time software), where as a general purpose algorithm might focus on flexibility (priority levels and being extensible).

Our scheduler is going to operate on a first-come first-served (FCFS) bases, commonly known as round-robin.

## Overview

Before we start describing the workflow in detail, let's answer a few questions:

* When does the scheduler run? The simplest answer is during a timer interrupt. Having said that, there are many other times you might want to trigger the scheduler, such as a waiting on a slow IO operation to complete (the network, or an old hard drive). Some programs may have run out of work to do temporarily and want to ask the scheduler to end their current time slice early. This is called *yielding*.
* How long does a thread run for before being replaced by the next one? There's no simple answer to this, as it can depend by a number of factors, even down to personal preference. There is a minimum time that a thread can run for, and that's the time between one timer interrupt and the next. This portion of time is called a *quantum*, because it represents the fundamental unit of time we will be dealing with. The act of a running thread being interrupted and replaced is called *pre-emption*.

The main part of our scheduler is going to be thread selection. Let's breakdown how we're going to implement it:

* When called, the first thing the scheduler needs to do is check whether the current thread should be pre-empted or not. Some critical sections of kernel code may disable pre-emption for various reasons, or a thread may simply be running for more than one quantum. The scheduler can choose to simply return here if it decides it's not time to reschedule.
* Next it must save the current thread's context so that we can resume it later.
* Then we select the next thread to run. For a round robin scheduler we will search the list of threads that are available to run, starting with the current thread. We stop searching when we find the first thread that can run.
* Optionally, while iterating through the list of threads we may want to do some house-keeping. This is a good time to do things like check wakeup-timers for sleeping threads, or remove dead threads from the list. If this concept is unfamiliar, we'll discuss this more later don't worry.
* Now we load the context for the selected thread and mark it as the current thread.

The basic scheduler we are going to implement will have the following characteristics:

1. It will execute on a first-come first-served basis.
2. The threads will be kept in a linked list. This was done to keep the implementation simple, and keep the focus on the scheduling code.
3. Each thread will only run for a single quantum (i.e. each timer interrupt will trigger the thread to reschedule).
4. While we have explained the difference between a thread and process, for now we're going to combine them both into the same structure for simplicity. We'll be referring to this structure as just a process from now on.
5. For context switching we are going to use the interrupt stub we have created in the [Interrupt Handling](../02_Architecture/05_InterruptHandling.md) chapter, of course this is not the only method available, but we found it useful for learning purposes.

### Prerequisites and Initialization

As said above we are going to use a linked list, the implementation of the functions to add, remove and search for processes in the list are left as an exercise, since their implemenation is trivial, and doesn't have any special requirement. For our purposes we assume that the functions: `add_process`, `delete_process`, `get_next_process` are present.

For our scheduler to work correctly it will need to keep track of some information. The first thing will be a list of the currently active processes (by *active* we mean that the process has not finished executing yet). This is our linked list, so for it we need a pointer to its root:

```c
process_t* processes_list;
```

We'll delve into what exactly a process might need to contain in a separate chapter, but for now we'll define it as the following:


```c
typedef struct process_t {
    status_t process_status;
    cpu_status_t* context;
    struct process_t* next;
} process_t;
```

If `cpu_status_t` looks familiar, it's because the struct we created in the interrupts chapter. This represents a snapshot of the cpu when it was interrupted, which conviniently contains everything we need to resume the process properly. This is our processes's `context`.

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

The scheduler will also need to keep track of which process is currently being executed. How exactly you do this depends on the data structure used to store your proceses, in our case using a linked list, we just need a pointer to it:

```c
process_t *current_process;
```

All that remains is to initialize the pointers to `NULL`, since we don't have any process running yet and the linked list is empty.

### Triggering the Scheduler

As mentioned above we're going to have the scheduler run in response to the timer interrupt, but it can be triggered however we want. There's nothing to stop us only running the scheduler when a big red button is pushed, if we want. Having the scheduler attached to the timer interrupt like this is a good first effort to ensuring it gives each process a fair share of cpu time.

For the following sections we assume the interrupt handlers look like the ones described in the interrupt handling chapter, and all route to a single function. We're going to have a function called `scheduler()` that will do process selection for us. Patching that into our interrupt routing function would look something like:

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

That's the foundation for getting our scheduler running. As previously mentioned, there may be other times we want to reschedule, but these are left as an exercise.

### Checking For Pre-Emption

While we're not going to implement this here, it's worth spending a few words on this idea.

Swapping processes quantum is simple, but very wasteful. One way to help deal with this is to store a time-to-live value for the current process. If there are a lot of processes running, the scheduler gives each process a lower time-to-live. This results in more context switches, but also allows more processes to run. There's a lot of variables here (minimum and maximum allowed values), and how do you determine how much time to give a process? There's other things that could be done with this approach, like giving high priority processes more time, or having a real-time process run more frequently, but with less time.

### Process Selection

This is the main part of the scheduler: selecting what runs next. It's important to remember that this code runs inside of an interrupt handler, so we want to keep it simple and short. Since we're using round robin scheduling, our code meets both of these criteria!

The core of the algorithm is deceptively simple, and looks as follows:

```c
void schedule() {
    current_process = current_process->next;
}
```

Of course it is not going to work like that, and if executed like this the kernel will most likely end up in running garbage, but don't worry it is going to work later on, the code snippet above is just the foundation of our scheduler.

There are few problems with this implementation, the first is that it doesn't check if it has reached the end of the list, to fix this we just need to add an if statement:

```c
void schedule() {
    if (current_process->next != NULL) {
        current_process = current_process->next;
    } else {
        current_process = processes_list;
    }
}
```

The `else` statement is in case we reached the end, where we want to move back to the first item. This can vary depending on the data structure used. The second problem is that this function is not checking if the `current_process` is `NULL` or not, it will be clear shortly why this shouldn't happen.

The last problem is: what if there are no processes to be run? In our case our selection function would probably run into garbage, unless we explicitly check that the current_process and/or the list are empty. But there is a more useful and elegant solution used by modern operating systems: having a special process that the kernel run when there are no others. This is called the idle process, and will be looked at later.

### Saving and Restoring Context

Now we have the next process to run, and are ready to load its context and begin executing it. Before we can do that though, we need to save the context of the current process.

In our case, we're storing all the state we need on the stack, meaning we only need to keep track of one pointer for each process: the stack we pushed all of the registers onto. We can also return this pointer to the interrupt stub and it will swap the stack for us, and then load the saved registers.

In order for this to happen, we need to modify our `schedule()` function a little:

```c
cpu_status_t* schedule(cpu_status_t* context) {
    current_process->context = context;

    if (current_process->next != NULL) {
        current_process = current_process->next;
    } else {
        current_process = processes_list;
    }

    return current_process->context;
}
```

#### In-Review

1. When a timer interrupt is fired, the cpu pushes the iret frame on to the stack. We then push a copy of what all the general purpose registers looked like before the interrupt. This is the context of the interrupted code.
2. We place the address of the stack pointer into the `rdi` register, as per the calling convention, so it appears as the first argument for our `schedule()` function.
3. After the selection function has returned, we use the value in `rax` for the new stack value. This is where a return value is placed according to the calling convention.
4. The context saved on the new stack is loaded, and the new iret frame is used to return to the stack and code of the new process.

This whole process is referred to as a *context switch*, and perhaps now it should be clearer why it can be a slow operation.

### The States Of A Process

While some programs can run indefinitely, most will do some assigned work and then terminate. Our scheduler needs to handle a process terminating, because if it attempts to load the context of a finished program, the cpu will start executing whatever memory comes next as code. This is often garbage and can result in anything happening. Therefore the scheduler needs to know that a process has finished, and shouldn't be scheduled again.

There is also another scenario to consider: imagine there is a process that is a driver for a slow IO device. A single operation could take a few seconds to run, and if this process is doing nothing the whole time, thats time taken away from other threads that could be doing work. This is something the scheduler needs to know about as well.

Both of these are solved by the use of the `status` field of the process struct. The scheduler is going to operate as a state machine, and this field represents the state of a process. Depending on the design decisions, the scheduler may have more or less states.

For the purpose of our example the scheduler will only have three states for now:

* READY: The process is in the queue and waiting to be scheduled.
* RUNNING: The process is currently running on the cpu.
* DEAD: The process has finished running and should not be scheduled. It's resources can also be cleaned up.

We'll modify our selection algorithm to take these new states into account:

```c
cpu_status_t* schedule(cpu_status_t* context) {
    process_t* prempted_process;
    current_process->context = context;
    current_process->status = READY;

    while () {
        process_t *prev_process = current_process;
        if (current_process->next != NULL) {
            current_process = current_process->next;
        } else {
            current_process = processes_list;
        }

        if (current_process != NULL && current_process->STATUS == DEAD) {
            // We need to delete dead processes
            delete_process(prev_process, current_process);
        } else {
            current_process->status = RUNNING;
            break;
        }
    }
    return current_process->context;
}
```

We'll look at the DEAD state more in the next chapter, but for now we can set a processes state to DEAD to signal its termination. When a thread is in the DEAD state, it will be removed from the queue the next time the scheduler encounters it.

### The Idle Process

We mentioned the idle process before. When there are no processes in the `READY` state, we'll run the idle process. Its purpose is to do nothing, and in a priority-based scheduler it's always the lowest priority.

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

A common issue is that Interrupts stop working after context switch, in this case make sure to check the value of the flags register (rflags/eflags). You might've set it to a value where the interrupt bit is cleared, causing the computer to disable hardware interrupts.

## Wrapping Up

This chapter has covered everything needed to have a basic scheduler up and running. In the next chapter we'll look at creating and destroying processes. As mentioned this scheduler was written to be simple, not feature-rich. There are a number of ways you could improve upon it in your own design:

* Use a more optimized algorithm.
* Add more states for a process to be in. We're going to add one more in the next chapter.
* Implement priority queues, where the scheduler runs threads from a higher priority first if they're available, otherwise it selects background processes.
* Add support for multiple processor cores. This can be very tricky, so some thought needs to go into how you design for this.

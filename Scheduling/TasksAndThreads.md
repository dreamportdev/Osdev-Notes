# Tasks and Threads

** THIS SECTION IS IN EARLY STAGES For now it will be more a set of bullet lists with things to be expaneded in the future ** 

## Tasks

### What are tasks

In a task usually there are the following information: 

* Virtual memory base
* Task ID
* Thread List (if we implement multithreading) or function pointer if we don't
* Stack reference
* Arguments 
* Parent task

While a thread should contains at minimum:

* Thread name
* Thread id
* Stack pointer
* Execution frame
* Pointer to function to run
* Eventually arguments for the function
* Depending on how the scheduler is designed, it could contains a pointer to the next thread
* Task containing the current thread

### Prerequisites 

Even if technically not necessary, is better to have implemented a memory allocation mechanism, ideally both physical and virtual memory manager should be implemented, if we want to have full tasks/thread separation and protection. But in case we don't want to have memory separation and protection in place a physical memory manager can be enough.

Technically we could also decide to implement a "kind of" multitasking without any memory allocator, but in this case we must use an array with a fixed size. So the Operating system will be limited to a certain number of concurrent task, and this memory will be always be unavailable to the os even when the tasks are dead.

### Creating a thread

When creating a thread we must first of all create it's execution frame (yeah even if not executed yet, it will need one).

### Execution frame

One of the way to implement stack switching is replacing the current iret frame with a the one contained in the next thread. To do that a task need when created to build an ad-hoc frame that will not cause any crash. What it should contain? Well this is basically a copy of the stack frame during the handling of an interrupt routine. 

### What a task should contain ?

So what are the information that we should store in a task? That depends on the design choices, because if we are implementing a multitask/single thread os it will need more information, but if we are going to implement a multi-task/multi-threaded OS some of the information will be stored in the Thread structure. So let's start with the minimum set of information that we need to save into a task: 

* First of all a name, all tasks have a task name, most of the time is the excuatble name, sometime something different
* Every task will have their own task id, this value usually is used by the scheduler to pick up the next task to execute or and in all the scenarios where an access to the task is needed (for example interprocess comunication)
* A reference to it's own virtual addressing space, that is a pointer to a PML4 table (this only if we are going to implement an os where every task has it's own address space)

### Context Switching

* Usually context switch is done during an IRQ (when it depends on design decision. 

One way to achieve context switching, is to clone the current stack frame for the IRQ being served and update some of it's values:

* rip - this will contain the pointer to the thread function
* rflgas - will containg 0x202
* rsp - is the stack pointer, since the pointer is growing backward 
* // to add other registers to initialize

The rip will contain the function that is associated with the thread, sp contains the newly allocated stack for it. 

### Exiting the thread

After the thread finish its execution, we need a way to make it exit gracefully (otherwise it start to run into grabage omst likely...) so there are two possible scenarios:

* The programmer has called a thread_exit function so in this case we are fine
* The programmer didn't called the function and the thread has terminated finished the execution of the function, at this point if it will not be stopped it will run into garbage. 

To achieve that we need to have an "exit" function to be executed after the function in the thread terminates it's execution. But how to do it? We need to check on the X86_64 Abi calling convention (or what architecture applies to you). As usual there are multiple ways to achieve that, the easiest one is to create a wrapper function that takes two parameters

* the first is the function we want to execute
* the second is the variable containing the arguments (we will go back to this later) 

This function will call the wrapper function passing the argument as it is and after that will call our exit function. So the code will look similar to the following;

```c
void thread_execution_wrapper( void (*function)(void *), void *arg) {
    function(arg);
    _thread_exit();
}
```

What should do the exit function? Again this depends on the design choice, and as usual there are multiple paths, it depends if we want to exit the thread as soon as it calls the the exit function, or let the scheduler do that, just updating its status to the one correspinding to a terminated task (let's call it DEAD status). 

* If the choice is to delete the thread as soon as it exit terminate the function what will happen then is that the thread is placed into a DEAD state, then the function will take care of removing the task from the scheduler queue, freeing all resources (stack, execution frame, page tables, etc.) that are allocated to it, and after that it will free the memory allocated to the task itself. Remember that when a task call the exit function is still the one being executed
* In the other scenario, what the exit function does is basically just updating the status of the task to DEAD. And not much more. Then next time the scheduler will be called, it will pick the next task, execute it, and so on, after sometime it will pick up again the terminated task, it will see the status as DEAD, so it will start the same process explained above, free the associated resources to the thread, remove it from the queue, and free the thread item. After that the scheduler will pick the next task, if the status will be not DEAD it will prepare it for the execution
So when a function is called we have: 

* The first 6 parameters stored into the rdi, rsi, rdx, rcx, r8 to r15 registers
* The rest of the parameters are pushed on the stack
* The return address is pushed on the stack after the parameters.
* rax (and eventually rbx) are used for the return value

The third item in the bullet list is the one we are interested to. When a function is called in asm we have something like: 

```asm 
mov rdi, 5 // First parameter
call _function
; do something
```

Now when a function is  called, the cpu put the next instruction on the stack. And here is where we will put the end function.

* Then the thread_exit function should take also care of updating the thread status to DEAD (and by extension if it was the last thread on a task it should update that too)
* The schedule function when pick a task that has the status set to DEAD knows that it doesn´t have to execute it, and will call the routine to free the thread resources. 
* If the thread is the last in a task, the task should be ready to be deleted too. So in this case we need to change the status to the task too. 
 
## Switching tasks/thread

So who is responsible of switching tasks? The scheduler, that every time is called it checks if the current task needs to be replaced with a new one, and eventually pick the "best" next task candidate. How to decide who is the next depends on the scheduling algorithm implemented and the design choice of the operating system (there are many scheduling algorithm). 

In this guide we will show one of the simplest algorithm available, the "round robin" algorithm. The idea behind it is very basic:

* Check if the current task execution has reached the threshold time (the _threshold_ is again a design choice there is no constrain on it's value)
* If not, just exit without do nothing
* Else, pick the current task, and change it's status to a non-running status, and save it's current execution context.
* Try to pick a new task, set it in the running status and return it's saved context. 

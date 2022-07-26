# Processes and Threads

## Definitions

Even if in the previous chapter we briefly introduced the concept of process, here we are going to have a more detailed explanation and introduce a also the whreads concept. 

* _Process_ - We introduced it in the previous chapter, let's give a more detailed definition for it. A _process_ (also known as task, job) is a program in execution, it is identified by a _Process Control Block_ (PCB) that holds it's definition. Part of the definition is design dependent, but all the informations needed when switching between tasks are stored there. 
* _Threads_ - Threads are often referred as lightweight processes, they are part of the process, and contains portion of the program to run, they can be scheduled too, introducing the concept of parallelism (that we explain briefly later). An os that support multiple threads per process is called `Multithread`. A process in this scenario is composed of at least one thread. They share some information with the process, like virtual memory space, privilege level, memory heap, but in the same time each threads has it's own stack, it's own registers, instruction pointer, etc.

Now as already said many times the design decisions will have an impact on how a process will be structured when developing a scheduler we can end up in one of the following scenarios:  

* _Single task - Single thread_ Ok this is just basically a kernel without a scheduler i mentioned it only for completion of information, so it doesn't even classify as multi-tasking! 
* _Single task - Multiple threads_ - Is not very useful, but in amateur osdev is the entry point toward real multi-tasking. This scenario is when we have a single virtual memory space, memory heap, and many threads running within it. 
* _Multi task - single thread_ - Multi-threading is not really necessary we if we don't want to have parallelism within a program. In this case we have the PCB and a single thread that will be execuyting the program. 
* _Multi task - Multiple threads_ - Similar to the above case, but in now a single process can have more than one threads running, each one running part of it concurrently (They can maybe run the same piece of code concurrently), this introduce the new feature of parallelism (and introduce also lot of new things that we need to take care). 

In this chapter we are going to implement a *multi process (task), single thread* environment, but ready to become multi-thread with few adjustments. 

** THIS SECTION IS IN EARLY STAGES For now it will be more a set of bullet lists with things to be expaneded in the future ** 

## Processes

In the previous chapter we have introduced the bare minimum information for a process to run, that was defined in the following structure: 

```c
typedef struct {
    status_t process_status;
    cpu_status_t context;
} process_t;
```

The two fields above are all what we need to achieve a very simple multitasking. But them alone leave many limitations and problems that we need to solve: 

* They can't be easily identified if we want for example to manually kill them, or just find what their represent
* All the processes are running in the same virtual address space (even if technically possible that is not a good idea)
* They all share the same virtual memory allocator (that can be ok, but we can have some processes that have full access to some memory areas while others not maybe have read only access to it)
* If they are using any resource we are not keeping track of them
* It can make harder to write a scheduler that want to prioritize processes according to some algorithm

The list above is not complete, but these are some of the major issues with our initial struct. We'll look at how to solve some of these, and you'll get to see how the control block develops in our case.


### Identifying a process

So the first problem we face, is that the process as it is doesn't have any identification information, so once created is hard to associate a process with the actual program, imagine you want to print to implement a `ps` like command, with the actual level of information is impossible, since there is no way to identification information about the process. Also imagine we are implementing a `kill` command, and we want to kill a process, again we can't because there is no PID. 

So what we need to do to solve these issues is just add more details to the process. The minimum that we need for now is: 

* A unique identifier, the Process ID (PID) 
* A process name

Even if they don´t add specific characteristics to our scheduler, they help the identification of a process. Let's then update our struct with these new information: 

```c
typedef struct {
    size_t pid;
    char name[NAME_MAX_LEN];
    status_t process_status;
    cpu_status_t context;
} process_t;
```

Where `NAME_MAX_LEN` is a constant with the maximum length for our process it´s up to us. The pid is a unique number, it can even be a uuid if we want, but the easiest way to achieve this is just using sequential number that starts from zero. To achive this we just need to add a global variable that contains the next available number. Now since we are using size_t on a 64bit architecture, we don't need to worry about overflowing the variable size, technically we can decide to reuse pids that are no longer used by a process, that is totally up to us, but in our simple scenario we will increment a global variable: 

```c
size_t next_free_pid = 0;
```  


### Virtual memory space

On of the most useful features of having the paging enabled is that we have the concept of Virtual Memory available (for a complete definition refer to the [Paging](,,/02_Memory_Management/Paging.md) and [Virtual Memory](../02_Memory_Management/04_Virtual_Memory_Manager.md) chapter), and from a process point of view it means that we can have each process with it's own addressing space. 

What are the improvements that we can have from adding this feature: 

* The most important one is that it provides isolation between processes, so same address location in two different process will point to two different physicall addresses (unless we we want it otherwise in some special cases). 
* Every process will have it's own memory heap (technically we can implement also different type of processes to use different type of memory allocators. 

What we need to add this feature to our proceess? The paging in x86_64 bits is handled by a set of hierarchical page directories/tables, and the address is basically containing the entry number in those tables. The root address of this table is stored in the PDBR (if you have not clear how it works, go back and read the paging chapter), then the first thing we need to change in our process structure is to add a new variable to store the value of the PDBR register: 

```c
typedef struct {
    size_t pid;
    char name[NAME_MAX_LEN];
    status_t process_status;
    cpu_status_t context;
    uint64_t pdbr;
} process_t;

```

Adding the pdbr reference is not enough. Let's see why:

* The first problem is that the PDBR contains the pointer to the root page directory of the virtual memory space (remember that an address with pagin enabled is a composition of table indexes), so this means we need to allocate for it.
* A memory address to be accessibile, has to have the present flag set, and various directories/table entries to be properly configured
* The step above means that when we create a new virtual memory space, we lose any reference to the kernel, so this means that as soon as we switch to the new pdbr, if the kernel is not mapped where it is suppose to be we will cause our kernel to crash, so we need to remap the kernel in the new process memory environment. How to map it is explained in the Paging chapter.

Implementing them is just a variation of what we have seen in the Paging chapter, so we'll leave it as an exercies.

#### Memory allocation

Having every process with it's own memory space, will let us introduce a new feature: per process virtual memory allocator. 

This simply means that now every process will be able to have it's own allocator (read [The heap](../02_Memory_Management/05_Heap_Allocation.md)), but that's not all, we can eventually also have different allocators depending on process type. Again the main change that we need on the struct is adding a new field on the process structure that will be the entry point of our memory allocator, the variable type depends strongly on design choices, in our case let's use the same data type we used in the Heap chapter: 

```c
typedef struct {
    size_t pid;
    char name[NAME_MAX_LEN];
    status_t process_status;
    cpu_status_t context;
    uint64_t pdbr;
    Heap_Node* heap_root;
    Heap_Node* cur_heap_position;
} process_t;

```

You can notie that we have actually added two variabiles, this is because of our memory allocation algorithm. 

Of course we need to make changes to our memory allocation function, the logic can be kept the same but what we need to change are the variable used, now we no longer want to use a global variable as a base for our allocator, but we want to pick it from the current process. So If we take for example the third_alloc() function in the Heap chapter what we need to do is replace the references to the global variables with the pointer stored in the current process, so we will have something like: 

```c
void *third_alloc(size_t size) {
  Heap_Node* cur_heap_position = get_current_running_process()->cur_heap_position;
  cur_pointer = get_current_running_process()->heap_root;

  while(cur_pointer < cur_heap_position) {
    cur_size = *cur_pointer;
    status = *(cur_pointer + 1);

    if(cur_size >= size && status == FREE) {
       status = USED;
       return cur_pointer + 2;
    }
    cur_pointer = cur_pointer + (size + 2);
  }

  *cur_heap_position=size;  
  cur_heap_position = cur_heap_position + 1;
  *cur_heap_position = USED;
  cur_heap_position = cur_heap_position + 1;
  uint8_t *addr_to_return = cur_heap_position;
  cur_heap_position+=size;
  return (void*) addr_to_return;
}
```

Be careful that the function above was not a complete one, we used it just as a nexample of how the updated code shoul look like, and of course we must do similar changes to the free function too. 

What does it mean? Let's make an example: 

* Process 1 make the following malloc call:

```c
    int *a = malloc(sizeof(int));
```

* Proess 2 make the following call:

```c
    custom_struct *cs = malloc(sizeof(custom_struct))
```

And in both cases the address returned is 0x10000. Apparently they are the same. But the pdb address in process 1 is different from pdbr address in process 2, and this means that we will have different page directories/and tables used. Since they are different we are physically referring to two different items, and they are not related so the will contain two different physical addresses (yes we can in theory having them pointing to the same physical address, and in some case we will also do it, for example when mapping the kernel, but is our physical memory manager duty to make sure that we don't allocate the same physical address twice). 



### Resource and priorities

TBD



### Why a process 

.... ? ?  ?
### What are processes

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

The list of prerequisites vary a lot depending on some design decision, but the following is a good set of features that we should have already implemented before starting to work on processes/threads creation and scheduling: 

* We  should have already implemented a memory allocation mechanism, both physical and virtual memory manager (especially if we want to have full processes/thread separation and protection).
* Interrupts must be configured and enabled.
* At least one time ready to use


### Creating a thread

When creating a thread we must first of all create it's execution frame (yeah even if not executed yet, it will need one).

### Iret  frame

One of the way to implement stack switching is replacing the current iret frame with the one contained in the next thread. To do that a task needs when created to build an ad-hoc frame that will not cause any crash. What it should contain? Well this is basically a copy of the stack frame during the handling of an interrupt routine, in our case is represented by the `cpu_status_t` structure. When a task is newly created all the registers we can safely assume that can be initalized to Zero. The most important information needed is what will be the value of the `instruction pointer`, that is the entry point of the task, and of course the pointer to the function we want to start. This value will be stored in the `rip` field of the structure.

Depending on design decisions, we could want also to pass one or more arguments to the function being called.

### What a task should contain ?

We already started to see what a task should contain at minimum, and we start from there below the data structure we used in the scheduler chapter: 

```c
typedef struct {
    status_t task_status;
    cpu_status_t context;
} task_t;

```

As already mentioned the context is the iret frame that was explained in the (interrupts chapter)[../InterruptHandling.md], and the status so far is an enum containing three states: READY, RUNNING and DEAD. And this is already enough to scheduler our processes, but this implementaion is very limited. For example, let's imagine that we have a program that needs to depend on other task output, and we need to refer to it somehow, currently there is no way to make it, because there is no actual distinction between them. A quick fix for it is to add a unique identifier for each task. The identifier is just a `size_t` variable that will be incremented for every task created. 

Now imagine tha we want to implement a `ps` like command on our os, currently what it will be able to print is just it's id, and few extra information but mostly addresses, that make hard to identify what that task is actually running, so another nice addition (even though not necessary) can be a name field, so whenever we create a task we also give it a name (but this field require a `strcpy()` like function implemented, let's assume we have one, our new task structure will look like: 

```c 
//This will probably go in a header
#define MAX_NAME_LEN 32

typedef struct {
    size_t task_id;

    char name[MAX_NAME_LEN]

    status_t task_status;
    cpu_status_t context;
} task_t;
``` 

So what are the information that we should store in a task? That depends on the design choices, because if we are implementing a multitask/single thread os it will need more information, but if we are going to implement a multi-task/multi-threaded OS some of the information will be stored in the Thread structure. So let's start with the minimum set of information that we need to save into a task: 

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

After the thread finish its execution, we need a way to make it exit gracefully (otherwise it start to run into garbage most likely...) so there are two possible scenarios:

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

What should the exit function do? Again this depends on the design choice, and as usual there are multiple paths, it depends if we want to exit the thread as soon as it calls the the exit function, or let the scheduler do that, just updating its status to the one correspinding to a terminated task (let's call it DEAD status). 

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
 
## Switching processes/thread

So who is responsible of switching processes? The scheduler, that every time is called it checks if the current task needs to be replaced with a new one, and eventually pick the "best" next task candidate. How to decide who is the next depends on the scheduling algorithm implemented and the design choice of the operating system (there are many scheduling algorithm). 

In this guide we will show one of the simplest algorithm available, the "round robin" algorithm. The idea behind it is very basic:

* Check if the current task execution has reached the threshold time (the _threshold_ is again a design choice there is no constrain on it's value)
* If not, just exit without do nothing
* Else, pick the current task, and change it's status to a non-running status, and save it's current execution context.
* Try to pick a new task, set it in the running status and return it's saved context. 

### Thread Sleep

* To implement thread sleep we need to have the IRQ timer configured correctly

The idea of a sleep function is to place the calling thread in a sleep state for a specific amount of time. While in the sleep state, the scheduler will check it's wakeup time, if it is not passed yetit will skip to the next one, otherwise will reset the wakeup time, and execute the thread. 

The `thread_sleep` function will take just one parameter, that is the amount of time we want it to wait (usually in ms). The function once called it just needs to: 

* change the status of the thread from RUN to SLEEP (the status label are totally arbitrary)
* set the wakeuptime variable to: `current_time + millis_to_wait` where current_time can be either the current time in milliseconds or the kernel uptime in milliseconds, and millis_to_way is the parameter to the sleep function that tells the scheduler for how long it has to sleep.



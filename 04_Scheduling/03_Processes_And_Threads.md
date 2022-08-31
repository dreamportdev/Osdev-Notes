# Processes And Threads

## Definitions and Terminology

Let's refine some of the previous definitions:

* *Process*: A process can be thought of as representing a single running program. A program can be multi-threaded, but it is still a single program, running in a single address space and with one set of resources. Resources in this context refer to things like file handles. All of this information is stored in a process control block (PCB).
* *Thread*: A thread represents an instance of running code. They live within the environment of a process and multiple threads with a process share the same resources, including the address space. This allows them share memory directly to communicate, as opposed to two processes which would need to use some form of IPC (which involves the kernel). While the code a thread is running can be shared, each thread must have it's own stack and context (saved registers).

With these definitions you could create a cross-section of possible scheduler configurations:

- *Single Process - Single Thread*: This is how the kernel starts. We have a single set of resources and address space, and only one running thread.
- *Single Process - Multi Thread*: In reality this is not very useful, but it can be a good stepping stone when developing a scheduler. Here we would have multiple threads running, but all within the same address space.
- *Multi Process - Single Thread*: This is what our example scheduler is going to look like. Here each process contains only a single thread (at that point the distinction between thread and process isn't needed), but we do have multiple address spaces and resources.
- *Multi Process - Multi Thread*: This is where most kernels live. It's similar to the previous case, but we can now have multiple threads per process. We won't be implementing this, but it's an easy next step.

## Processes

We introduced a very basic process control block in the previous chapter:

```c
typedef struct {
    status_t status;
    cpu_status_t context;
} process_t;
```

While this is functional, there's a few problems:

- They can't be easily identified, how do we know the difference between procesess.
- All processes currently share the same address space, and as a byproduct, the same virtual memory allocator. 
- We can't keep track of any resources they might be using, like file handles or network sockets.
- We can't prioritize them, as we dont know which ones are more important.

We're not going to look at how to solve all of these, but we'll the important ones.

### Indentifying A Process

How do we tell which process is which? We're going to use a unique number as our process id (`pid`). This will let us refer to any process by passing this number around. This is `pid` can be used for programs like `ps`, `kill` and others.

While an identifier is all that's required here, it can also be nice to have a `process name`. Unlike the `pid` this isn't authoritative, it can't be used to uniquely identify a process, but it does provide a nice description.

We're going to update our process struct to look like the following:

```c
typedef struct {
    size_t pid;
    status_t process_status;
    cpu_status_t context;
    char name[NAME_MAX_LEN];
} process_t;
```

Define `NAME_MAX_LEN` to be a length of your choosing, a good starting place is 64. We've taken the approach of storing the name inside of the control block, but you could also store a pointer to a string on the heap. Using the heap would require more care when using this struct, as you'd have to be sure you managed the memory properly. 

How do we assign pids? We're using to use a bump allocator: which if you'll remember is just a pointer that increases. The next section covers the details of this. It's worth noting that since we're on a 64-bit architecture and using `size_t`, we don't really have to worry about overflowing this simple allocator, as we have 18446744073709551615 possible ids. That's a lot!

### Creating A New Process

Creating a process is pretty trivial. We need a place to store the new `process_t` struct, in our case the static array, but you might have another data struct for it. We'll want a new function that creates a new process for us. We're going to need the starting address for the new process, and it can be nice to in an argument to this function.

```c
size_t next_free_pid = 0;

process_t* create_process(char* name, void(*function)(void*), void* arg)
{
    process_t* process;
    for (size_t i = 0; i < MAX_PROCESSES; i++)
    {
        if (processes_list[i] != NULL)
            continue;
        process = &processes_list[i];
        break;
    }

    strncpy(process->name, name, NAME_MAX_LEN);
    process->pid = next_free_pid++;
    process->process_status = READY;
    process->context.iret_ss = KERNEL_SS;
    process->context.iret_rsp = alloc_stack();
    process->context.iret_flags = 0x202;
    process->context.iret_cs = KERNEL_CS;
    process->context.iret_rip = (uint64_t)function;
    process->context.rdi = (uint64_t)arg;
    process->context.rbp = 0;

    return process;
}
```

The above code omits any error handling, but this is left as an exercise to the reader. You may also want to disable interrupts while creating a new process, so that you aren't pre-empted and the half-initialized process starts running.

Most of what happens in the above function should be familiar, but let's look at `iret_flags` for a moment. The value `0x202` will clear all flags except for bits 2 and 9. Bit 2 is a legacy feature and the manual recommends that it's set, and bit 9 is the interrupts flag. If the interrupt flag is not set when starting a new process, we won't be able to pre-empt it!

We also set `rbp` to 0. This is not strictly required, but it can make debugging easier. If you choose to load and run elf files later on this is the expected set up. Zero is a special value that indicates you have reached the top-most stack frame.

The `alloc_stack()` function is a left an exercise to the reader, but it should allocate some memory, and return a pointer to *the top* of the allocated region. 16KiB (4 pages) is a good starting place, although you can always go bigger. Modern systems will allocate around 1MiB per stack.

### Virtual Memory Allocator

One of the most useful features of modern processors is paging. This allows us to isolate each process in a different virtual address space, preventing them from interfering with each other. This is great for security and lets us do some memory management tricks like copy-on-write or demand paging. 

Now we have the issue of how these isolated processes communicate with each other? This is called IPC (Inter-Process Communication) and is not covered in this chapter, but it is worth being aware of.

One thing to note with this, is that while each process has it's own address space, the kernel exists in *all* address spaces. This is where a higher half kernel is useful: since the kernel lives entirely in the higher half, the higher half of any address space can be the same. 

Keeping track of an address space is fairly simple, it requires an extra field in the process control block to hold the root page table:

```c
typedef struct {
    size_t pid;
    status_t process_status;
    cpu_status_t context;
    void* root_page_table;
    char name[NAME_MAX_LEN];
} process_t;
```

When creating a new process we'll need to populate these new page tables: make sure the process stack is mapped, as well as the program's code and any data are also mapped. We'll also copy the higher half of the current process's tables into the new tables, so that the kernel is mapped into the new process. Doing this is quite simple: we just copy entries 256-511 of the pml4 (the top half of the page table). These pml4 entries will point to the same pml3 entries used by the kernel tables in other processes, and so on.

Copying the higher half page tables like this can introduce a subtle issue: If the kernel modifies a pml4 entry in one process the changes won't be visible in any of the other processes. Let's say the kernel heap expands across a 512 GiB boundary, this would modify the next pml4 (since each pml4 entry is responsible for 512 GiB of address space). The current process would be able to see the new part of the heap, but upon switching processes the kernel could fault when trying to access this memory.

While we're not going to implement a solution to this, but it's worth being aware of. One possible solution is to keep track of the current 'generation' of the kernel pml4 entries. Everytime a kernel pml4 is modified the generation number is increased, and whenever a new processes is loaded it's kernel pml4 generation is checked against the current generation. If the current generation is higher, we copy it's kernel tables over, and now the page tables in are synchronized again.

Don't forget to load the new process's page tables before leaving the `schedule()`.

#### The Heap

Let's talk about the heap for a moment. With each process being isolated, they can't really share any data, meaning they can't share a heap, and will need to bring their own. The way this usually works is programs link with a standard library, which includes a heap allocator. This heap is exposed through the familiar `malloc()`/`free()` functions, but behind the scenes this heap is calling the VMM and asking for more memory when needed. 

Of course the kernel is the exception, because it doesn't live in it's own process, but instead lives in *every* process. It's heap is available in every process, but can only be used by the kernel.

What this means is when we look at loading programs in userspace, these programs will need to provide their own heap. However we're only running threads within the kernel right now, so we can just use the kernel heap.

### Resources

Resources are typically implemented an opaque handle: a resource is given an id by the subsystem it interacts with, and that id is used to represent the resource outside of the subsystem. Other kernel subsystems or programs can use this id to perform operations with the resource. These resources are usually tracked per process. 

As an example, let's look at opening a file. We wont go over the code for this, as it's beyond the scope of this chapter, but it serves as a familiar example.

When a program goes to open a file, it asks the kernel's VFS (virtual file system) to locate a file by name. Assuming the file exists and can be accesses, the VFS loads the file into memory and keeps track of the buffer holding the loaded file. Let's say this is the 23rd file the VFS has opened, it might be assigned the id 23. You could simply use this id as your resource id, however that is a system-wide id, and not specific to the current process. 

Commonly each process holds a table that maps process-specific resource ids to system resource ids. A simple example would be an array, which might look like the following:

```c
#define MAX_RESOURCE_IDS 255
typedef struct {
... other fields ...
    size_t resources[MAX_RESOURCE_IDS];
} process_t;
```

We've used `size_t` as the type to hold our resource ids here. To open a file, like the previous example, might look like the following. Note that we don't check for any errors, like the file not existing or having invalid permissions.

```c
size_t open_file(process_t* proc, char* name) {
    size_t system_id = vfs_open_file(name);
    for (size_t i = 0; i < MAX_RESOURCE_IDS; i++)
    {
        if (proc->resources[i] != 0)
            continue;
        proc->resources[i] = system_id;
        return i;
    }
}
```

Now any further operations on this file can use the returned id to reference this resource. 

### Priorities

There are many ways to implement priorities, but the easiest way to get started is with multiple process queues: one per periority level. Then your scheduler would always check the highest priority queue first, and if there's no threads in the READY state, check the next queue and so on.

## From Processes To Threads

### Exiting A Thread

### Thread Sleep

//--- original text below here ---//

## From Processes to Threads

Now that we have implemented a basic, but complete process structure, let's introduce the Thread concept. 

A thread is the smallest unit of processing that can be executed by an OS. A thread in modern operating systems usually lives within a process. A process can have one or multiple threads, and they represents portion of the programs being executed, and they can be scheduled concurrently, they share part of the execution environment with the process:

* The heap
* The memory environment
* Resources (... correct?) 

But they have their own stack, their own function to be called (multiple threads can eventually call the same function, and they will be executed independently), their own context depending on the algorithm they can have their own priority, and so on. 

In our example we will going to have a single thread per process (not very useful) but, we will make it easy to add more threads in the future. 

Let's go through the changes that we need.

### A new data type

Since a thread is a sub-component of a process, that needs to be scheduled it is useful to wrap the information needed in a new data structure, it will make easier to handle it. 

But what does a thread contain? Let's see: 

* A thread like a process needs a way to be uniquely identified (again not strictly necessary) but maybe we want to implement functions to kill threads, or put them to sleep, so we are going to need a thread id field, just like we did in the process, it can be again just an intenger, a uuid, or what we think will fit better to our needs, we are going for just an integer number.
* Since it is the part of the process that it is going to execute the actual program (or parts of it) it will need its own context, this means that we need a field for storing the current context
* They can have different statuses just like processes, they can be running, waiting for their turn, sleeping, etc, it again depends on design choices, but we need a status field too.
* Another optional information to make thread identification easier can be a thread name.

We can wrap the information above in a new data structure, and update the process structure accordingly: 

```c
struct {
    size_t tid;
    cpu_status_t* context;
    void* stack;
    thread_status_t status;
    char *name[THREAD_NAME_LEN];
} thread_t
```

The `thread_status_t` field is not defined yet, so depending on the design decisions and or the scheduling algorithm implemented it can be the same as the process statuses or not, for now let's assume that the thread statuses are the same with process statuses, and just declare it as a new data type: 

```c
typedef status_t thread_status_t;
```

We need to update also the `process_t` data structure with few changes: 

* We need to remove from a field the that is moved into the thread: the context
* We need to add a new field that will contain at least one thread. 
* And finally we need to add a `thread_t` pointer field, that will contain the list of threads

```c
typedef struct {
    size_t pid;
    char name[NAME_MAX_LEN];
    status_t process_status;
    uint64_t pdbr;
    thread_t* threads; // This is our new field
    Heap_Node* heap_root;
    Heap_Node* cur_heap_position;
} process_t;

```

Now that we have updated our process, we need to make few adjustments to our `create_process` function: 

* Now it needs to allocate a `thread_t*` data structure and populate it
* It can be a good idea to create a `create_thread` function that takes care of it.
* The thread_name can be the same as  process name, or we can give it its own name, this is a design decision to make. 

The scheduler needs to be updated too, the main change is thata now the iret_frame (the process context) is no longer in the `process_t` structure, but now is a field within `threads` field. So we need to update the function to read it from there. 

These are most of the changes needed to start to use threads, even if in our case we are allowing a single thread per process, moving towards mulitple threads per process is pretty easy now, we just need eventually to make them into a linked list, adding a `thread_t *next` field to the data structure (or using a fixed length array like we did in the process scheduler), and update our scheduler to iterate through the threads within a process. 

Then we can create new threads, and append them into an existing process. 

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



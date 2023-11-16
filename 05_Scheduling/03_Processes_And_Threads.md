# Processes And Threads

## Definitions and Terminology

Let's refine some of the previous definitions:

* *Process*: A process can be thought of as representing a single running program. A program can be multi-threaded, but it is still a single program, running in a single address space and with one set of resources. Resources in this context refer to things like file handles. All of this information is stored in a process control block (PCB).
* *Thread*: A thread represents an instance of running code. They live within the environment of a process and multiple threads with a process share the same resources, including the address space. This allows them share memory directly to communicate, as opposed to two processes which would need to use some form of IPC (which involves the kernel). While the code a thread is running can be shared, each thread must have its own stack and context (saved registers).

With these definitions is possible to create a cross-section of scheduler configurations:

- *Single Process - Single Thread*: This is how the kernel starts. We have a single set of resources and address space, and only one running thread.
- *Single Process - Multi Thread*: In reality this is not very useful, but it can be a good stepping stone when developing a scheduler. Here we would have multiple threads running, but all within the same address space.
- *Multi Process - Single Thread*: Here each process contains only a single thread (at that point the distinction between thread and process isn't needed), but we do have multiple address spaces and resources.
- *Multi Process - Multi Thread*: This is where most kernels live. It's similar to the previous case, but we can now have multiple threads per process. We won't be implementing this, but it's an easy next step.

In this chapter we will explore a basic _Multi Process - Multi Thread_ approach.

## Processes

We introduced a very basic process control block in the previous chapter:

```c
typedef struct {
    status_t status;
    cpu_status_t context;
    process_t *next;
} process_t;
```

While this is functional, there are few problems:

- They can't be easily identified, how do we know the difference between procesess.
- All processes currently share the same address space, and as a byproduct, the same virtual memory allocator.
- Is not possible to keep track of any resources they might be using, like file handles or network sockets.
- They can't be prioritized, since we don't know which ones are more important.

We're not going to look at how to solve all of these, but we'll cover the important ones.

### Identifying A Process

How do we tell which process is which? We're going to use a unique number as our process id (`pid`). This will let us refer to any process by passing this number around. This `pid` can be used for programs like `ps`, `kill` and others.

While an identifier is all that's required here, it can also be nice to have a `process name`. Unlike the `pid` this isn't authoritative, it can't be used to uniquely identify a process, but it does provide a nice description.

We're going to update our process struct to look like the following:

```c
typedef struct {
    size_t pid;
    status_t process_status;
    cpu_status_t context;
    char name[NAME_MAX_LEN];
    process_t *next;
} process_t;
```

Decide what value to assign to  `NAME_MAX_LEN`, a good starting place is 64. We've taken the approach of storing the name inside of the control block, but we could also store a pointer to a string on the heap. Using the heap would require more care when using this struct, as we'd have to be sure the memory is managed properly.

How do we assign _pids_? We're going to use a bump allocator:  is just a pointer that increases (that should sound familiar). The next section covers the details of this. It's worth noting that since we're on a 64-bit architecture and using `size_t`, we don't really have to worry about overflowing this simple allocator, as we have 18446744073709551615 possible ids. That's a lot!

### Creating A New Process

Creating a process is pretty trivial. We need a place to store the new `process_t` struct, in our case is a linked list, where is up to us, for a round robin algorithm, we will add it at the end of the list, and it should be done by the `add_process` function mentioned in the previous chapter. We'll want a new function that creates a new process for us. We're going to need the starting address for the code we want our process to run, and it can be nice to pass an argument to this starting function.

```c
size_t next_free_pid = 0;

process_t* create_process(char* name, void(*function)(void*), void* arg) {
    process_t* process = alloc(sizeof(process_t));

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

    add_process(process);

    return process;
}
```

The above code omits any error handling, but this is left as an exercise to the reader. We may also want to disable interrupts while creating a new process, so that we aren't pre-empted and the half-initialized process starts running.

Most of what happens in the above function should be familiar, but let's look at `iret_flags` for a moment. The value `0x202` will clear all flags except for bits 2 and 9. Bit 2 is a legacy feature and the manual recommends that it's set, and bit 9 is the interrupts flag. If the interrupt flag is not set when starting a new process, we won't be able to pre-empt it!

We also set `rbp` to 0. This is not strictly required, but it can make debugging easier. If we choose to load and run elf files later on this is the expected set up. Zero is a special value that indicates we have reached the top-most stack frame.

The `alloc_stack()` function is left  as an exercise to the reader, but it should allocate some memory, and return a pointer to *the top* of the allocated region. 16KiB (4 pages) is a good starting place, although we can always go bigger. Modern systems will allocate around 1MiB per stack.

### Virtual Memory Allocator

One of the most useful features of modern processors is paging. This allows us to isolate each process in a different virtual address space, preventing them from interfering with each other. This is great for security and lets us do some memory management tricks like copy-on-write or demand paging.

Now we have the issue of how these isolated processes communicate with each other? This is called IPC (Inter-Process Communication) and is not covered in this chapter, but it is worth being aware of.

One thing to note with this, is that while each process has its own address space, the kernel exists in *all* address spaces. This is where a higher half kernel is useful: since the kernel lives entirely in the higher half, the higher half of any address space can be the same.

Keeping track of an address space is fairly simple, it requires an extra field in the process control block to hold the root page table:

```c
typedef struct {
    size_t pid;
    status_t process_status;
    cpu_status_t context;
    void* root_page_table;
    char name[NAME_MAX_LEN];
    process_t *next;
} process_t;
```

When creating a new process we'll need to populate these new page tables: make sure the process stack is mapped, as well as the program's code and any data are also mapped. We'll also copy the higher half of the current process's tables into the new tables, so that the kernel is mapped into the new process. Doing this is quite simple: we just copy entries 256-511 of the `PML4` (the top half of the page table). These pml4 entries will point to the same pml3 entries used by the kernel tables in other processes, and so on.

If we are using the recursion techcnique to access entries on page directories one of them will be the pointer to `PML4` itself (in our case the entry 510), in this case we don't want to copy the current `PML4` value, but assign to it the physical address of the new table contained in `root_page_table`, with the PRESENT and WRITE flags set (don't forget that the physical address has to be page aligned).

Copying the higher half page tables like this can introduce a subtle issue: If the kernel modifies a pml4 entry in one process the changes won't be visible in any of the other processes. Let's say the kernel heap expands across a 512 GiB boundary, this would modify the next pml4 (since each pml4 entry is responsible for 512 GiB of address space). The current process would be able to see the new part of the heap, but upon switching processes the kernel could fault when trying to access this memory.

While we're not going to implement a solution to this, but it's worth being aware of. One possible solution is to keep track of the current 'generation' of the kernel pml4 entries. Everytime a kernel pml4 is modified the generation number is increased, and whenever a new processes is loaded its kernel pml4 generation is checked against the current generation. If the current generation is higher, we copy its kernel tables over, and now the page tables are synchronized again.

Don't forget to load the new process's page tables before leaving the `schedule()`.

#### The Heap

Let's talk about the heap for a moment. With each process being isolated, they can't really share any data, meaning they can't share a heap, and will need to bring their own. The way this usually works is programs link with a standard library, which includes a heap allocator. This heap is exposed through the familiar `malloc()`/`free()` functions, but behind the scenes this heap is calling the VMM and asking for more memory when needed.

Of course the kernel is the exception, because it doesn't live in its own process, but instead lives in *every* process. Its heap is available in every process, but can only be used by the kernel.

What this means is when we look at loading programs in userspace, these programs will need to provide their own heap. However we're only running threads within the kernel right now, so we can just use the kernel heap.

### Resources

Resources are typically implemented as an opaque handle: a resource is given an id by the subsystem it interacts with, and that id is used to represent the resource outside of the subsystem. Other kernel subsystems or programs can use this id to perform operations with the resource. These resources are usually tracked per process.

As an example, let's look at opening a file. We wont go over the code for this, as it's beyond the scope of this chapter, but it serves as a familiar example.

When a program goes to open a file, it asks the kernel's VFS (virtual file system) to locate a file by name. Assuming the file exists and can be accessed, the VFS loads the file into memory and keeps track of the buffer holding the loaded file. Let's say this is the 23rd file the VFS has opened, it might be assigned the id 23. We could simply use this id as the resource id, however that is a system-wide id, and not specific to the current process.

Commonly each process holds a table that maps process-specific resource ids to system resource ids. A simple example would be an array, which might look like the following:

```c
#define MAX_RESOURCE_IDS 255
typedef struct {
    //other fields
    size_t resources[MAX_RESOURCE_IDS];
} process_t;
```

We've used `size_t` as the type to hold our resource ids here. To open a file, like the previous example, might look like the following. Note that we don't check for any errors, like the file not existing or having invalid permissions.

```c
size_t open_file(process_t* proc, char* name) {
    size_t system_id = vfs_open_file(name);
    for (size_t i = 0; i < MAX_RESOURCE_IDS; i++) {
        if (proc->resources[i] != 0)
            continue;
        proc->resources[i] = system_id;
        return i;
    }
}
```

Now any further operations on this file can use the returned id to reference this resource.

### Priorities

There are many ways to implement priorities, the easiest way to get started is with multiple process queues: one per priority level. Then the scheduler would always check the highest priority queue first, and if there's no threads in the READY state, check the next queue and so on.

## From Processes To Threads

Let's talk about how threads fit in with the current design. Currently each process is both a process and a thread. We'll need to move some of the fields of the `process_t` struct into a `thread_t` struct, and then maintain a list a threads per-process.

As for what a thread is (and what fields we'll need to move): A thread is commonly the smallest unit the scheduler will interact with. A process can be composed by one or multiple threads, but a thread always belongs to a single process.

Threads within the same process share a lot of things:

- The virtual address space, which is managed by the VMM, so this is included too.
- Resource handles, like sockets or open files.

Each thread will need its own stack, and its own context. That's all that's needed for a thread, but we may want to include fields for a unique id and human-readable name, similar to a process. This brings up the question of do we use the same pool of ids for threads and processes? There's no good answer here, it is possible, but is also possible to use separate pools. The choice is personal!

We'll also need to keep track of the thread's current status, and we may want some place to keep some custom flags (is it a kernel thread vs user thread etc).

### Changes Required

Let's look at what our `thread_t` structure will need:

```c
typdef struct {
    size_t tid;
    cpu_status_t* context;
    status_t status;
    char* name[THREAD_NAME_LEN];
    thread_t* next;
} thread_t;
```

The `status_t` struct is the same one previously used for the proceses, but since we are scheduling threads now, we'll use it for the thread.

You might be wondering where the stack is stored, and it's actually the `context` field. You'll remember that we store the current context on the stack when an interrupt is served, so this field actually represents both the stack and the context.

We'll also need to adjust our process, to make use of threads:

```c
typedef struct {
    size_t pid;
    thread_t* threads;
    void* root_page_table;
    char name[NAME_MAX_LEN];
} process_t;
```

We're going to use a linked list as our data structure to manage threads. Adding a new thread would look something like the following:

```c
size_t next_thread_id = 0;

thread_t* add_thread(process_t* proc, char* name, void(*function)(void*), void* arg) {
    thread_t* thread = malloc(sizeof(thread_t));
    if (proc->threads = NULL)
        proc->threads = thread;
    else {
        for (thread_t* scan = proc->threads; scan != NULL; scan = scan->next) {
            if (scan->next != NULL)
                continue;
            scan->next = thread;
            break;
        }
    }

    strncpy(thread->name, name, NAME_MAX_LEN);
    thread->tid = next_thread_id++;
    thread->status = READY;
    thread->next = NULL:
    thread->context.iret_ss = KERNEL_SS;
    thread->context.iret_rsp = alloc_stack();
    thread->context.iret_flags = 0x202;
    thread->context.iret_cs = KERNEL_CS;
    thread->context.iret_rip = (uint64_t)function;
    thread->context.rdi = (uint64_t)arg;
    thread->context.rbp = 0;

    return thread;
}
```

You'll notice this function looks almost identical to the `create_process` function from before. That's because a lot of it is the same! The first part of the function is just inserting the new thread at the end of the list of threads.

Let's look at how our `create_process` function would look now:

```c
process_t* create_process(char* name) {
    process_t* process = alloc(sizeof(process_t));
    process->pid = next_process_id++;
    process->threads = NULL;
    process->root_page_table = vmm_create();
    strncpy(process->name, name, NAME_MAX_LEN);
    add_process(process)
    return process;
}
```

The `vmm_create` function is just a placeholder, but it should create a new vmm instance for our new process. The details of this function are described more in the chapter on the virtual memory manager itself. Ultimately this function should set up some new page tables for the new process, and then map the existing kernel into the higher half of these new tables. You may wish to do some other things here as well.

The last part is we'll need to update the scheduler to deal with threads instead of processes. A lot of the things the scheduler was interacting with are now contained per-thread, rather than per-process.

That's it! Our scheduler now supports multiple threads and processes. As always there are a number of improvements to be made:

- The `create_process` function could add a default thread, since a process with no threads is not very useful. Or it may not, it depends on the design.
- Similarly, `add_thread` could accept `NULL` as the process to add to, and in this case create a new process for the thread instead of returning an error.

### Exiting A Thread

After the thread has finished its execution, we'll need a way for it to exit gracefully. If we don't, and the thread is scheduled again after running the last of its code, we'll try to run whatever comes after the code: likely junk, resulting in a #UD of #GP.

This also places a requirement on the programmer when creating threads: they must call `thread_exit` before the main function used for the thread returns, otherwise we will crash.

We're going to go a step further and implement a wrapper function that will call the thread's main function, and then call `thread_exit` for us. This will only work for kernel threads, but it removes the burden from the programmer. Our wrapper function will look like the following:

```c
void thread_execution_wrapper(void (*function)(void*), void* arg) {
    function(arg);
    thread_exit();
}
```

Now we'll need to modify `create_thread` to make use of the wrapper function. Since we're targeting `x86_64` we're using the appropriate calling convention which tells us which registers to use for passing arguments.

```c
thread->context.rip = (uint64_t)thread_execution_wrapper;
//rdi and rsi are used for argument passing
thread->context.rdi = (uint64_t)function;
thread->context.rsi = (uint64_t)arg;
```

The implementation of `thread_exit` can look very different depending on what we want to do. In our case we're going to change the thread's status to DEAD.

```c
void thread_exit() {
    current_thread->status = DEAD;
    while (true);
}
```

At this point the thread can exit succesfully, but the thread's resources are still around. The big ones are the thread control block and the stack. They can be freed in the `thread_exit` but be careful we're not exiting the current thread. If we do, we'll free the stack being currently used. We could switch to a kernel-only stack here, and then safely free the stack.

Alternatively the thread could be placed into a 'cleanup queue' that is processed by a special thread that frees the resources associated with threads. Since the cleanup thread has its own stack and resources, we can safely free those in the queued threads.

Another option, which we've chosen here, is to update the thread's status here. Then when the scheduler encounters a thread in the DEAD state, it will free its resources there.

Note that we use an infinite loop at the end of `thread_exit` since that function cannot return (it would return to the junk after the thread's main function). This will busy-wait until the end of the current quantum, however we could also call the scheduler to reschedule early here.

#### Last Thread Standing

What about freeing processes? As always there are a few approaches, but the easiest is the check if the thread that is about to be freed is the last in the process. If it is, the process should be deleted too.

Cleaning up a process requires significantly more work, tearing down page tables properly, freeing other resources, sometimes there is buffered data to flush. This should be approached with some care, so as not the delete the currently page tables in use.

### Thread Sleep

Being able to sleep for an amount of time is very useful. Note that most sleep functions offer a `best effort` approach, and shouldn't be used for accurate time-keeping. Most operating system kernels will provide a more involved, but more accurate time API. Hopefully why should be more clear shortly.

Putting a thread to sleep is very easy, and we'll just need to add one field to our thread struct:

```c
typedef struct {
//other fields here
    uint64_t wake_time;
} thread_t;
```

We will also need a new status for the thread:  `SLEEPING`.

To actually put a thread to sleep, we'd need to do the following:

- Change the thread's status to `SLEEPING`. Now the scheduler will not run it since it's not in the `READY` state.
- Set the `wake_time` variable to the wakeup time, that is: `current_time + requested_sleep_time`
- Force the scheduler to change tasks, so that the sleep function does not immediately return, and then sleep on the next task switch.

We will need to modify the scheduler to check the wake time of any sleeping threads it encounters. If the wake time is in the past, then we can change the thread's state back to `READY`.

An example of how the sleep function might be implemented is shown below:

```c
void thread_sleep(thread_t* thread, size_t millis) {
    thread->status = SLEEPING;
    thread->wake_time = current_uptime_ms() + millis;
    scheduler_yield();
}
```

The function `current_uptime_ms()` is a simple function that return the kernel uptime in ms. How to compute the kernel uptime is very simple and is left as exercise, if don't know where to start, remember that we have the timer enabled and that is configured to interrupt the kernel regularly.

The function `scheduler_yield()` is just informing the kernel that the current thread wants to be interrupted, for example by firing the timer interrupt manually (asm instruction `int interrupt_number`.

### Advanced Designs

We've discussed the common approach to writing a scheduler using a periodic timer. There is another more advanced design: the tickless scheduler. While we won't implement this here, it's worth being aware of.

The main difference is how the scheduler interacts with the timer. A periodic scheduler tells the timer to trigger at a fixed interval, and runs in response to the timer interrupt. A tickless scheduler instead uses a one-shot timer, and set the timer to send an interrupt when the next task switch is due.

At a first glance this may seem like the same thing, but it eliminates unnecessary timer interrupts, when no task switch is occuring. It also removes the idea of a `quantum`, since we can run a thread for any arbitrary amount of time, rather than a number of timer intervals.

*Authors note: Tickless schedulers are usually seen as more accurrate and operate with less latency than periodic ones, but this comes at the cost of added complexity.*

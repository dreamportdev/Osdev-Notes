# Critical Sections and locks

## Introduction

Now that we have introduced a multi tasking mechanism our kernel is able to run different programs concurrently. But now this can introduce new problems, having concurrent process being able to access same resources at nearly the "same time". Let's start with an example scenario.

Imagine that we have a shared resource that can be accessed at a specified address (that resource can be anything: an i/o memory mapped device, a memory mapped hard drive location, a shared variable, or whatever).

Let's assume for example that the shared resource is accessible at the address 0xDEADBEEF, this resource is a serial port connected to an output device. 

Now we have initially a single process that is sending a string to the serial port one character at time: 

```c 
#define SHARED_RESOURCE 0xDEADBEEF 

char string_to_send[] = "I am the first string"

int i = 0;
while(i < strlen(string_to_send) {
    *((int *) shared_resource) = string_to_send[i++];
}
```

So with just one task accessing the shared resource everything is fine, and we have no problem. But now let's create a second Process (Process B), that wants to use the same resource for a different purpose

```c
#define SHARED_RESOURCE 0xDEADBEEF 
char string_to_send[] = "While i am the second"

int i = 0;
while(i < strlen(string_to_send) {
    *shared_resource = string_to_send[i++];
}
// Some other code 
```

This task as we can see is using the same resource of process A, if B start it's execution after A is finished, in this case we are fine, but if we are in a multi-tasking environment it can be very likely that we have A and B being interrupted and executed many times before they quit. For example imagine we have the following tasks sequence: 

![Tasks execution sequence](Images/taskssequence.png)

Where A, B, and C are the processes being executed, and tasks are prempted everytime they write something to the serial port, what we will have is that the output of the serial will be junk text with A and B outputs overlapping, the picture below describe what can happen in this scenario: 

![Shared Resource Sequence](Images/sharedressequence.png)

This means that a user reading on the serial output (it can be an lcd display, a printer, whatever) he will see something like: 

```
IWahmi....
```

While we should expect: 

```
I am the first string While i am the second
```

The above scenario happens because both processes (A and B)  have access to the shared resource at the same time, and both of them are writing to it. The junk string above is an example of _race condition_, they are situation in which memory location are accessed concurrently, and at least one of the access is a write. We can imagine that the scenario above can lead to many problems so what we need is a mechanism to protect the shared resource. This is where we introduce the concept of locking.

## Implementing the Lock 

A _lock_ mechanism provide mutual exclusion , ensuring that only a process (or cpu or thread) at a time  can hold the lock and access the shared resource. 

To achieve that we need:

* A lock variable, that is shared betwen  processes/threads who wants to use the shared resource
* Two new functions to handle the lock called `acquire` and `release` that respectively will acquire the lock to the shared resource blocking other processes to access it, and release it.

For the lock variable a good idea is to create a new datatype, so we can eventually expand it in the future. We will define a data structure with just a single boolean variable for now that will represent the lock.

```c

struct {
    bool lock;
} spinlock_t;

typedef struct spinlock_t spinlock_t;

void acquire(spinlock_t *lock);
void release(spinlock_t *lock);
```

But how can we ensure mutual exclusion then? The basic idea is pretty straight forward, imagine we update both processes to use the acquire and release function while accessing the the shared resource(be aware in order to have a functionig lock mechanism we should have some kind of memory allocation mechanism implemented). This is the first process:

```c
//Process A
#define SHARED_RESOURCE 0xDEADBEEF 

char string_to_send[] = "I am the first string"

spinlock_t *lock = malloc(sizeof(spinlock_t));

int i = 0;
acquire(lock);
while(i < strlen(string_to_send) {
    *((int *) shared_resource) = string_to_send[i++];
}
release(lock)
``` 

and below the second one: 

```c
#define SHARED_RESOURCE 0xDEADBEEF 
char string_to_send[] = "While i am the second"

int i = 0;
// We don't define a new lock since we are using the same one for process A
acquire(lock);
while(i < strlen(string_to_send) {
    *shared_resource = string_to_send[i++];
}
release(lock);
```

Now what we want is that once a process has acquired the lock, the other one(s) must be kept waiting somehow. A lock is _acquired_ if the `locked` field in the `spinlock_t` type variable is currently false and set to `true` by the current process. Otherwise, thre is another process that is already using that shared resource then the `locked` field is already set true, and the current process then should just keep trying until it will be able to set the `locked` field from false to true. Let's outline a first draft of the acquire function: 

```c
void acquire(spinlock_t *lock) {

    while(1) {
        if(lock->locked == false) {
            lock->locked = true;
            break;
        }
    }
}
```
What our function does is an active waiting, so it just use it's cpu time waiting for the resource to be released, this is the reason of the name `spin lock`. 
The release function is pretty simple, it just has to set the locked field to `false`: 

```c
void release(spinlock_t *lock) {
    lock->locked = false;
}
```

Consider the sequence of tasks outlined in the previous section, let's see what happens now using the `acquire/release`:

* The lock is created and is set to false
* The process A execute the `acquire` instruction so the locked variable is set to true.
* Process A start to write the first letter to the shared resource
* Process A is preempted and C started running, C is not using the shared resource so it goes doing whatever he was doing.
* Process C is preempted and then B start running, B try to acquire the lock, but locked variable is already true, so it can't leave the loop in the acquire function.
* Sooner or later the process B is preempted and C starts running again, it keep doing is job
* C is preempted and it is time for B again now to run, that it is still in the acquire function loop, and since the lock is still set to true, it will be stuck there until the next preemption
* Process B is preempted and now is time for A to run, it writes it second character 
* ... skip until A hasn't finished to write it's string (B will be always kept waiting in the acquire loop)
* A is running and has just sent the latest character to the shared resource, it leaves the string write loop, and run the `release` function that set the locked varialbe to false.
* A is preempted and then sooner or later B will start running, now it is still in the acquire loop, but at the next iteration it will find the variable locked to false, so it can set it to true and finally leave the loop, and start write it's string...
* ... etc.

As we can see this simple algorithm has prevented two processes to interfere with each other. So can we assume that now we are safe? Well... no, there is one problem with the above implementation, this doesn't ensure mutual exclusion in a multi processor environment. Imagine we have 2 different processors calling the acquire at the same time (when we have a multi-cpu environment we have several processes/thread that run simultaneously) and they reach the if statement at the same time with the locked variable still to false, they will both reclaim the lock and will start to write to the shared resource, causing again a _race condition_. 

But how to solve this issue? We need a real _atomic operation_ that has to be used within the acquire loop. By _atomic_ we mean an operation that can do in a single step whatever it exactly need to be done.  There are different solutions that we can adopt (for example use the `xchgl` instruction in the for loop, that is guaranteed to be atomic), but as usual we want to keep thing extremely simple, and in this case we can avail of the help of the compiler (gcc) that provides a whole set of atomic functions to be used by our kernel. 

In this case the function that we need to use is: 

```c
bool __atomic_test_and_set (void *ptr, int memorder)
```

This function perform an atomic _test and set_ operation on the byte ptr, as for the memorder parameter we are going to use `__ATOMIC_ACQUIRE` (for more details about the memorder parameter consult the gcc manual). If the test and set operation is succesfull (the lock was false and then set to true) the function return true, otherwise it will return false. 

So to ensure multi-cpu isolation we can just replace our acquire code with the following: 

```c
void acquire(spinlock_t *lock) {
    while(__atomic_test_and_set(&lock->locked, __ATOMIC_ACQUIRE));
}
```

Of course we have also an atomic function to release the lock: 

```c
bool __atomic_release (void *ptr, int memorder)
```

And we need to update the release function too, but in this case we are going to use a different memorder value: `__ATOMIC_RELEASE`: 

```c
void release(spinlock_t *lock) {
    __atomic_release(&lock->locked, __ATOMIC_RELEASE);
}
```

Now we have a basic locking mechanism to protect shared resources on our systems. 

## Where to go from here?

What we have seen in this chapter is a simple locking mechanism to protect shared resources, as you can imagine this is not the only implementation, and it still has it's own limitation. For example the algorithm outlined above has the following problem

* It doesn't guarantee the order of the processes requiring access to it. So if processes A, B and C require access to the shared resource, they are not guaranteed to be granted the lock in the same order, and in some scenario this could be a problem
* It also doesn't prevent a _deadlock_ to happen. A _deadlock_ is a scenario where there are two or more processes that are waiting to acquire a shared resource that is hold by the other one. For example if A is holding resource X and needs to acquire a lock on Y, while B is holding a lock on Y and needs to acquire a lock on X, if not handled correctly we will have A and B stuck in the acquire loop forever.

Solution to the problems above (and others that can arise) is a research area and out of scope of this guide, but is good to know that there are many algorithms available that are target to solve or mitigate these issues, and could be a good idea to add few of them to our kernel. 

Spin locks are not the only type of locks available, there are other algorithms that can be implemented that have different purpsoes, like semaphores, that can be used system wide by different processes, or locks that doesn't use busy wait (so if the resource is busy they will just go to sleep again). 


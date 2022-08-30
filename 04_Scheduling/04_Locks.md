# Critical Sections and locks

## Introduction

Now that we have introduced a multi tasking mechanism our kernel is able to run different programs concurrently. But now this can introduce new problems, having concurrent process being able to access same resources at nearly the "same time". Let's start with an example scenario.

Imagine that we have a shared resource that can be accessed at a specified address (that resource can be anything: an i/o memory mapped device, a memory mapped hard drive location, a shared variable, or whatever).

Let's assume for example that the shared resource is accessible at the address 0xDEADBEEF, this resource is a serial port connected to an output device. 

Now we have initially a single process that is sending a string to the serial port one character at time: 

```c 
#define SHARED_RESOURCE 0xDEADBEEF 

// Other code doing other stuff
char string_to_send[] = "I am the first string"

int i = 0;
while(i < strlen(string_to_send) {
    *((int *) shared_resource) = string_to_send[i++];
}
// Some other code 
```

So with just one task accessing the shared resource everything is fine, and we have no problem. But now let's create a second Process (Process B), that wants to use the same resource for a different purpose

```c
#define SHARED_RESOURCE 0xDEADBEEF 
// Other code doing other stuff
char string_to_send[] = "While i'm the second"

int i = 0;
while(i < strlen(string_to_send) {
    *shared_resource = string_to_send[i++];
}
// Some other code 
```

This task as we can see is using the same resource of process A, if B start it's execution after A is finished, in this case we are fine, but if we are in a multi-tasking environment it can be very likely that we have A and B being interrupted and executed many times before they quit. For example imagine we have the following tasks sequence: 

![Tasks execution sequence](Images/taskssequence.png)

Where A, B, and C are the processes being executed, and tasks are prempted everytime they write something to the serial port, what we will have is that the output of the serial will be junk text with A and B outputs overlapping, the picture below describe what happens in this scenario: 

![Shared Resource Sequence](Images/sharedressequence.png)

Locks ensure mutual exclusion. 

Example: same linked list updated by two processors at the same time

Definition: critical section (that is usually the section between acquire and release)

## Functions

It requires just two functions

```c
void acquire(spinlock_t *lock)
```

and

```c
void release(spinlock_t *lock)
```

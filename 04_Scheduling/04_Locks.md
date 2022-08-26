# Critical Sections and locks

## Introduction

Now that we have introduced a multi tasking mechanism our kernel is able to run different programs concurrently. But now this can introduce new problems, having concurrent process being able to access same resources at nearly the "same time". Let's start with an example scenario.

Imagine that we have a shared resource that can be accessed at a specified address (that resource can be anything: an i/o memory mapped device, a memory mapped hard drive location, a shared variable, or whatever).

Let's for example assume that the shared resource is accessible at the address 0xDEADBEEF, this resource is a R/W (read write resource) so a user process can read to it and write to it. 

Initially there is only one process using it (Process A) that uses it to store and read some status data. 

```c 
#define SHARED_RESOURCE 0xDEADBEEF 
#define STATUS_ACCESS_GRANTED 0x25
#define STATUS_ACCESS_DENIED 0x50
#define STATUS_ERROR    0x75

// Other code doing other stuff
*((int *) SHARED_RESOURCE) = STATUS_ACCESS_DENIED; 
// Some other code 
int access_status = *((int *) SHARED_RESOURCE);
if (access_status == ACCESS_GRANTED) {
    grant_access_to_the_super_admin_mode(); // This fucntion doesn't exist... :) 
} else {
    you_shall_not_pass(); // This function doesn't exist too!
    }
```

So with just one task accessing the shared resource everything is fine, and we have no problem. But now let's create a second Process (Process B), that wants to use the same resource for a different purpose

```c
#define SHARED_RESOURCE 0xDEADBEEF 
#define DATA_READ 0x25
#define DATA_WRITTEN 0x50
#define DATA_ERROR   0x75

// Some code doing some stuff
*((int *) SHARED_RESOURCE) = DATA_READ;
// Do other important stuff here
int data_status = *((int *) SHARED_RESOURCE);
if (data_status == DATA) {
    all_data_loaded_do_whatever_you_need(); // This fucntion doesn't exist... :) 
} else {
    we_haven_loaded_yet(); // You should know now... :) 
}
```



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

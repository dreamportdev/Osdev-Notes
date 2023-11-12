# Critical Sections and Locks

## Introduction

Now that we have a scheduler, we can run multiple threads at the same time. This introduces a new problem though: shared resources and synchronization.

Imagine we have a shared resource that can be accessed at a specific address. This resource could be anything from MMIO, a buffer or some variable, the important part is that multiple threads *can* access it at the same time.

For our example we're going to say this resouce is a NS16550 uart at address `0xDEAD'BEEF`. If not familiar with this type of uart device, it's the de facto standard for serial devices. The COM ports on x86 use one of these, as do many other platforms.

The key things to know are that if we write a byte at that address, it will be sent over the serial port to whatever is on the other end. So if to send a message, we must send it one character at a time, at the address specified (`0xDEADBEEF`).

## The Problem

Let's say we use this serial port to for log messages, with a function like the following:

```c
void serial_log(const char* msg) {
    volatile char* resource = (char*)0xDEADBEEF;
    for (size_t i = 0; msg[i] != 0; i++)
        *resource = msg[i];
}
```

Note that in reality we should check that the uart is ready to receive the next byte, and there is some setup to be done before sending. It will need a little more code than this for a complete uart driver, but that's outside the scope of this chapter.

Now let's say we have a thread that wants to log a message:

```c
void thead_one() {
    serial_log("I am the first string");
}
```

This would work as expected. We would see `I am the first string` on the serial output.

Now lets introduce a second thread, that does something similar:

```c
void thead_two() {
    serial_log("while I am the second string");
}
```

What would we expect to see on the serial output? We don't know! It's essentially non-deterministic, since we can't know how these will be scheduled. Each thread may get to write the full string before the other is scheduled, but more likely they will get in the way of each other.

![Tasks execution sequence](/Images/taskssequence.png)

The image above is an example of threads being scheduled, assuming there are only three of them in the system (labeled as _A, B, C_).
Imagine that A is `thread_one` and B is `thread_two`, while C does not interact with the serial. One example of what we could see then is `Iwh aI ammi  lethe secfionrsd t stristngring`. This contains all the right characters but it's completely unreadable. The image below shows what a scenario that could happen:

![Shared Resource Sequence](/Images/sharedressequence.png)

What we'd expect to see is one of two outcomes: `I am the first string while I am the second` or `while I am the second I am the first string`.

The situation described is an example of a _race condition_. The order of accesses to the shared resource (the uart) matters here, so we need a way to protect it. This where a lock comes in.

## Implementing A Lock

A _lock_ provides us with something called mutual exclusion: only one thread can hold the lock at a time, while the rest must wait for it to be free again before they can take it. While a thread is holding the lock, it's allowed to access the shared resource.

We'll need a few things to achieve that:

- A variable that represents the lock's state: locked or unlocked.
- Two functions called `acquire` (taking the lock) and `release` (freeing the lock).

While we only need one variable per lock, we're going to create a new struct for it so it can be expanded in the future.

```c
typedef struct {
    bool lock;
} spinlock_t;

void acquire(spinlock_t* lock);
void release(spinlock_t* lock);
```

We'll look at how to implement these functions shortly, but let's quickly look at how a lock would be used:

```c
spinlock_t serial_lock;

void serial_log(const char* msg) {
    acquire(&serial_lock);

    volatile char* resource = (char*)0xDEADBEEF;
    for (size_t i = 0; msg[i] != 0; i++)
        *resource = msg[i];

    release(&serial_lock);
}
```

It's a small change, but it's very important! Now anytime a thread tries to call `serial_log`, the `acquire` function will block (wait) until the lock is free, before trying to print to the serial output.

This ensures that each call to `serial_log` completes before another is allowed to start, meaning each message is written properly without being jumbled by another.

It's worth noting that each instance of a lock is independent, so to protect a single resource, we must use a single lock.

## First Implementation

Let's look at how `acquire` and `release` should function:

- `acquire` will wait until the lock is free, and then take it. This prevents a thread from going any further than this function until it has the lock.
- `release` is much simpler, it simply frees the lock. This indicates to other threads that they can now take the lock.

We've used a boolean to represent the lock, and are going to use `true` for locked/taken, and `false` for free/unlocked. Let's have look at a naive implementation for these functions:

```c
void acquire(spinlock_t* lock) {
    while (true) {
        if (lock->locked == false) {
            lock->locked = true;
            return;
        }
    }
}

void release(spinlock_t* lock) {
    lock->locked = false;
}
```

What we've implemented here is a `spinlock`. To take the lock we keep checking the lock variable within a loop (aka 'spinning') until it's available. A spinlock is the simplest kind of lock to implement, and very low latency compared to some others. It can be very wasteful when it comes to CPU time however, as the CPU is constantly querying memory only to do nothing but query it again, instead of doing actual work.

Consider the previous example of threads being sequenced, and let's see what happens now:

* The lock is created and starts out free.
* Thread A calls `serial_log` which calls the `acquire` function, so the lock is taken.
* Process A writes the first few characters of its message to the uart.
* Process A is preempted and C starts running. C is not using the shared resource, so it continues on as normal.
* Process C is preempted and then B start running. Thread B calls `serial_log`, which again calls `acquire`, but this time the lock is already taken. So B will do nothing but check the state of the lock.
* Then thread B is preempted and thread C begins to run, it continues on as normal.
* Thread C is preempted and thread B runs again. It's still in the `acquire` function waiting for the lock to be freed, so it will continue to wait. Thread B will spin until it's preempted again.
* Thread B is preempted and now thread A runs again. It will continue writing its message.
* This cycle will continue until A has written all of its message. At this point thread A will release the lock and continue on.
* Now thread A is preempted, and B will start running. Since the lock is now free, thread B will be able to take it. `acquire` will take the lock and return, and then write thread B's message to the uart.

Now we can see how locks can be used to keep two threads from interfering with each other.

Unfortunately this implementation has some issues, and can fail to ensure mutual exclusion in several ways:

- We haven't marked the lock variable as `volatile`, so the acquire and release operations may or may not be written to memory. This means other threads might not even see the changes made to the lock variable.
- If we're operating in a multiprocessor environment, this is also an issue, because the other processors won't see the updated lock state. Even if we do use `volatile`, two threads on separate processors could still both take the lock at the same time. This is because processors will generally perform a `read-modify-write` operation, which leaves time for another processor to read the old state, while another is modifying it.

## Atomic Operations

Let's talk about *atomic operations*. An atomic operation is something the CPU does that cannot be interrupted by anything (including other processors). The relevant cpu manuals can provide more information how this is implemented (for x86, look for information on the `LOCK` opcode prefix). For now, all we need to know is that it works.

Rather than writing assembly directly for this, we're going to use some compiler intrinsic functions to generate the assembly for us. These are provided by any compatible GCC compiler (that includes clang).

We're going to use the following two functions:

```c
bool __atomic_test_and_set(void* ptr, int memorder);
void __atomic_release(void* ptr, int memorder);
```

We'll also be using two constants (these are provided by the compiler as well): `__ATOMIC_ACQUIRE` and `__ATOMIC_RELEASE`. These are memory order constraints and are used to describe to the compiler what we want to accomplish. Let's look at the difference between these, and a third constraint, sequential consistency (`__ATOMIC_SEQ_CST`).

- `__ATOMIC_SEQ_CST`: An atomic operation with this constraint is a two-way barrier. Memory operations (reads and writes) that happen before this operation must complete before it, and operations that happen after it must also complete after it. This is actually what we expect to happen most of the time, and if not sure which constraint to use, this is an excellent default. However it's also the most restrictive, and implies the biggest performance penalty as a result.
- `__ATOMIC_ACQUIRE`: Less restrictive, it communicates that operations after this point in the code cannot be reordered to happen before it. It allows the reverse though (writes that happened before this may complete after it).
- `__ATOMIC_RELEASE`: This is the reverse of acquire, this constraint says that any memory operations before this must complete before this point in the code. Operations after this point may be reordered before this point however.

Using these constraints we can be specific enough to achieve what we want while leaving room for the compiler and cpu to optimize for us. We won't use it here, but there is another ordering constraint to be aware of: `__ATOMIC_RELAXED`. Relaxed ordering is useful when in case a memory operation is deisred to be atomic, but not interact with the memory operations surrounding it.

Both of the previously mentioned atomic functions take a pointer to either a `bool` or `char` that's used as the lock variable, and the memory order. The `__atomic_test_and_set` function returns the *previous* state of the lock. So if it returns true, the lock was already taken. A return of falses indicates we successfully took the lock.

Using our new compiler instrinsics, we can update the `acquire` and `release` functions to look like the following:

```c
void acquire(spinlock_t* lock) {
    while (__atomic_test_and_set(&lock->locked, __ATOMIC_ACQUIRE));
}

void release(spinlock_t* lock) {
    __atomic_release(&lock->locked, __ATOMIC_RELEASE);
}
```

Using the compiler built-in functions like this ensures that the compiler will always generate the correct atomic instructions for us. These are also cross-platform: meaning if the kernel is ported to another cpu architecture, it can still use these functions.

### Side Effects

While atomic operations are fantastic, they are often quite slow compared to their non-atomic counterparts. Of course it's impossible to implement a proper lock without atomics so we must use them, however it's equally important not to *over use* them.

## Locks and Interrupts

With the introduction of locks we've also introduced a new problem.
Using the previous example of the shared uart, used for logging, let's see what might happen:

- A thread wants to log something, so it takes the uart lock.
- An interrupt occurs, and some event happens. This might be something we want to know about so we've added code to log it.
- The log function now tries to take the lock, but it can't since it's already been taken, and will spin until the lock is free.
- The kernel is now in a deadlock: the interrupt handler won't continue until the lock is freed, but the lock won't be freed until after the interrupt handler has finished.

There is no decisive solution to this, and instead care must be taken when using locks within the kernel. One option is to simply disable interrupts when taking a lock that might also be taken inside an interrupt handler. Another option is to have alternate code paths for things when inside of an interrupt handler.

## Next Steps

In this chapter we've implemented a simple spinlock that allows us to protect shared resources. Obiously there are other types of locks that could be implemented, each with various pros and cons. For example the spinlock shown here has the following problems:

- It doesn't guaren'tee the order of processes accessing it. If we have threads A, B and C wanting access to a resource, threads A and B may keep acquiring the lock before C can, resulting in thread C stalling. One possible solution to this is called the ticket lock: it's a very simple next step to take from a basic spinlock.
- It also doesn't prevent a *deadlock* scenario. For example lets say thread A takes lock X, and then needs to take lock Y, but lock Y is held by another thread. Thread B might be holding lock Y, but needs to take lock X. In this scenario neither thread can progress and both are effectively stalled.

Preventing a deadlock is big topic that can be condensed to be: be careful what locks are held when taking another lock. Best practice is to never hold more than a single lock if it can be avoided.

There are also more complex types of locks like semaphores and mutexes. A semaphore is a different kind of lock, as it's usually provided by the kernel to other programs. This makes the semaphore quite expensive to use, as every lock/unlock requires a system call, but it allows the kernel to make decisions when a program wants to acquire/release the semaphore. For example if a thread tries to acquire a semaphore that is taken, the kernel might put the current thread to sleep and reschedule. When another thread releases the semaphore, the kernel will wake up the sleeping thread and have it scheduled next. Semaphores can also allow for more than one thread to hold the lock at a time.

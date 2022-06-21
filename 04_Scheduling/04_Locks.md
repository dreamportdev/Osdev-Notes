# Critical Sections and locks

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

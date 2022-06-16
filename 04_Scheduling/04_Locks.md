# Critical Sections and locks

Locks are mutual exclusion. 

Example: same linked list updated by two processors at the same time

## Functions

It requires just two functions

```c
void acquire(spinlock_t *lock)
```

and

```c
void release(spinlock_t *lock)
```

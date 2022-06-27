# Example System Call ABI
*"We break things inside the kernel constantly, but there is one rule among the kernel developers: we never, ever, break userspace." - Linus Torvalds*

While breaking the system call ABI in your kernel won't have the same ramifications as it would in Linux, it's a good idea to set up a stable ABI early on. Early on meaning as soon as you begin writing code that will use your ABI. As such, we're going to take a look at an example ABI to show how it could be done. This example is loosely based on the system V calling convention for x86_64.

## Register Interface
The system V ABI chooses to pass as many function arguments in registers as it can, simply because it's *fast*. This works nicely for a system call, as unlike the stack, the registers remain unchanged during an interrupt.

As for how many registers, and which ones? We'll pick five registers (explained below), and we'll use the first five registers the system V ABI uses for arguments: `rdi`, `rsi`, `rdx`, `rcx` and `r8`.

The reason we selected five registers is to allow four registers for passing data (that's 4x 8 bytes = 32 bytes of data we can pass in registers), as well as an extra register for selecting the system call number. Since we don't need to return the system call number that was run, we can also reuse this register to return a status code, meaning we don't need to use part of a data register.

Something that was alluded to before was the idea of treating the data registers as a single big block. This would let us pass more than 4 values, and could even pass through more complex structs or unions. 

The last piece is how we're going to trigger a system call. We're going to use an interrupt, and use interrupt vector 0x50. You can use whatever you like, as long as it doesn't conflict with other interrupts.

## Example In Practice
Let's say we have a system call like the following:

```
Name: memcpy
Id: 3
Args: source addr, dest addr, count in bytes
Returns: count copied
```

Please don't actually do this, `memcpy` does not need to be a system call, but it serves for this example, as it's a function everyone is familiar with.

We're going to implement a wrapper function for system calls in C, purely for convinience, which might look so:

```c
void do_syscall(uint64_t num, uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3)
{
    asm volatile("");
}
```

Using a wrapper function like this also helps ensure that your code uses the ABI, since you can manually control which registers are used.

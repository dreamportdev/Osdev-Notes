# Example System Call ABI
*"We break things inside the kernel constantly, but there is one rule among the kernel developers: we never, ever, break userspace." - Linus Torvalds*

While breaking the system call ABI in our kernel won't have the same ramifications as it would in Linux, it's a good idea to set up a stable ABI early on. Early on meaning as soon as we begin writing code that will use the ABI. As such, we're going to take a look at an example ABI to show how it could be done. This example is loosely based on the system V calling convention for `x86_64`.

## Register Interface
The system V ABI chooses to pass as many function arguments in registers as it can, simply because it's *fast*. This works nicely for a system call, as unlike the stack, the registers remain unchanged during an interrupt.

As for how many registers, and which ones? We'll pick five registers (explained below), and we'll use the first five registers the system V ABI uses for arguments: `rdi`, `rsi`, `rdx`, `rcx` and `r8`.

The reason we selected five registers is to allow four registers for passing data (that's `4x8 bytes = 32 bytes` of data we can pass in registers), as well as an extra register for selecting the system call number. Since we don't need to return the system call number that was run, we can also reuse this register to return a status code, meaning we don't need to use part of a data register.

We'll also be using those same four data registers to return data from the system call, and we'll use the system call number register to return an error (or success) code.

Something that was alluded to before was the idea of treating the data registers as a single big block. This would let us pass more than 4 values, and could even pass through more complex structs or unions.

The last piece is how we're going to trigger a system call. We're going to use an interrupt, specificially vector 0x50 for our example ABI. You can use whatever you like, as long as it doesn't conflict with other interrupts.

There are some other design considerations that haven't been discussed so far, including:

- How to treat unused registers in a system call?
- What happens when a system call isn't found? Or not available?
- How to pass arguments that doesn't fit in the 4 registers?
- How to return data that doesn't fit in the 4 registers?
- If asynchronous operations are supported, how do callback functions work?

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
__attribute__((naked))
void do_syscall(uint64_t num, uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3) {
    asm ("int $0x50" ::: "rdi", "rsi", "rdx", "rcx", "r8", "memory");
}
```

The above function takes advantage of the fact the system V calling convention is the one used by GCC/Clang. If a different compiler/calling convention is used, then the arguments need to be moved into the registers manually. This is as straightfoward as it sounds, but is left as an exercise for the reader.

This function also uses the `naked` attribute. If unfamiliar with attributes, they are discussed in the C language chapter. This particular attribute tells the compiler not to generate the entry and exit sequences for this function. These are normally very useful, but in our case are unnecessary.

Now, let's combine our wrapper function with our example system call from above. We're going to write a `memcpy` function that could be called by another code, but uses the system call internally:

```c
void memcpy(void* src, void* dest, size_t count) {
    return do_syscall(3, (uint64_t)src, (uint64_t)dest, (uint64_t)count, 0, 0);
}
```

## Summary

At this point we should be ready to go off and implement our own system call interface, and maybe even begin to expose some kernel functions to userspace. Always keep in mind that values (especially pointers) coming from userspace may contain anything, so we should verify them and their contents as much as possible before passing them deeper into the kernel.

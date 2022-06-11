# System Calls
System calls are a way for a user mode program to request something from the kernel, or other supervisor code. For this section we're going to focus on a user program calling the kernel directly. If you're writing a micro-kernel, system calls are often a bit more complicated, as they can be redirected to other supervisor (or user) programs, but we're not going to talk about that here.

As mentioned at the start of this chapter, in this context it's better to think of the kernel as a library that the current program can call.

On x86_64 there are a few ways to perform a system call. The first is to dedicate an interrupt vector to be used for software interrupts. This is the most common, and straightforward way. There other main way is to use the dedicated instructions (`sysenter` and friends), however these are rather niche and have some issues of their own. This is discussed below.

There are other obscure ways to perform syscalls. For example, executing a bad instruction will cause the cpu to trigger a #UD exception. This transfers control to supervisor code, and could be used as an entry to a system call. While not recommended for beginners, there was one hobby OS kernel that used this method.

## The System Call ABI
A stable ABI is always a good thing, but especially in the case of system calls. If you start to write user code that uses your system calls, and then the ABI changes later, all of the previous code will break. Therefore it's recommended to take some time to design the core of your ABI before implementing it. 

Some common things to consider include:

- How does the user communicate which system call they want?
- How does the user pass arguments to the kernel?
- How does the kernel return data to the user?
- How do you pass larger amounts of data?

On x86_64, using registers to pass arguments/return values is the most straightfoward way. Which registers specifically are left as an exercise to the reader. Note there's no right or wrong answer here (except maybe `rsp`), it's a matter of preference.

## Using Interrupts
You've probably heard of `int 0x80` before. That's the interrupt vector used by Linux for system calls. It's a common choice as it's easy to identify in logs, however you're free to choose any vector number you like. Some people like to place the system call vector up high (0xFE, just below the LAPIC spurious vector), others place it down low (0x24).

*What about using multiple vectors for different syscalls?* Well this is certainly possible, but it's more points of entry into supervisor code. System calls are also not the only thing that uses interrupts, and with enough hardware you may find yourself running out of interrupt vectors to allocate. So only using a single vector is recommended.

### Using Software Interrupts
Now we've selected which interrupt vector to use for system calls, we can install an interrupt handler. On x86, this is done via the IDT like any other interrupt handler. The only different is the DPL field. 

As mentioned before, the DPL field is the highest ring that is allowed to call this interrupt from software. By default we've left it as 0, meaning only ring 0 can trigger software interrupts. Other rings trying to do this will trigger a general protection fault. However since we want ring 3 code to call this vector, we'll need to set it's DPL to 3.

Now we have an interrupt that can be called from software in user mode, and a handler that will be called on the supervisor side.

### A Quick Example
We're going to use vector 0xFE as our system call handler, and assume that your interrupt stub pushes all registers onto the stack before executing the interrupt handler (we're taking this as the `registers_t*` argument).
We'll also assume that `rdi` is used to pass the system call number, and `rsi` passes the argument to that syscall. These are things that should be decided when writing the ABI for your kernel.

First we'll set up things on the kernel side:

```c
//left to the user to implement
void set_idt_entry(uint8_t vector, void* handler, uint8_t dpl);

//see below
registers_t* syscall_handler(registers_t* regs);

void setup_syscalls()
{
    set_idt_entry(0xFE, syscall_handler, 3);
}
```

Now on the user side, we can use `int $0xFE` to trigger a software interrupt. If we try to trigger any other interrupts, we'll still get a protection fault.

```c
__attribute__((naked))
size_t do_syscall(size_t syscall_num, size_t arg)
{
    asm("int $0xFE" 
        : "S"(arg) 
        : "D"(syscall_enum), "S"(arg));

    return arg;
}
```

There's a few tricks happening with the inline assembly above. First is the `naked` attribute. This is not strictly necessary, but since we're only doing inline assembly in the function it's a nice optimization hint to the compiler. It tells the compiler not to generate the prologue/epilogue sequences for this function. This is stuff like creating the stack frame.

Next we're using two special constraints for the input and output operands. "S" and "D" are the source and destination registers, or on x86 the `rsi` and `rdi` registers. This means the compiler will ensure that those registers are loaded with the values we specify before the assembly body is run. The compiler will then also move the value of "S" (`rsi`) into `arg` after the assembly body has run. This is where we'll be placing the return value of the system call, hence why the `return arg` line below.

For more details on line assembly, see the dedicated section on it, or check your compiler's manual.

Now assuming everything is setup correctly, running the above code in user mode should trigger your kernel's system call handler. In this example, the `syscall_handler` function. As an example of how that might look:

```c
registers_t* syscall_handler(registers_t* regs)
{
    log("Got syscall %lx, with argument %lx", regs->rdi, regs->rsi);

    //remember rdi is our syscall number
    switch (regs->rdi)
    {
        //syscall 2 only wants the argument
        case 2:
            do_syscall_2(regs->rsi);
            break;

        //syscall 3 wants the full register state
        case 3:
            do_syscall_3(regs);
            break;

        //no syscall with that id, return an error
        default:
            regs->rsi = E_NO_SYSCALL;
            break;
    }

    return regs;
}
```

In this case we used the dispatch pattern, but you can do anything you want here.

## Using Dedicated Instructions
TODO: syscall/sysret and sysenter/sysexit

### Compatibility Issues

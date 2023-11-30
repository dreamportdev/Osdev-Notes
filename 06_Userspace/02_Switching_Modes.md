# Switching Modes

In this chapter we are going to study how to get to userspace, and back. Although it is focused on `x86_64`, a lot of high level concepts apply to other platforms too.

## Getting to User Mode

There are a few ways to do this, but the most straightforward way is to use the `iret` instruction.

The `iret` instruction _pops_ five arguments off of the stack, and then performs several operations atomically:

- It pops `rip` and `cs` from the stack, this is like a far jump/return. `cs` sets the mode for instruction fetches, and `rip` is the first instruction to run after `iret`.
- It pops `rflags` into the flags register.
- It pops `rsp` and `ss` from the stack. This changes the mode for data accesses, and the stack used after `iret`.

This is a very powerful instruction because it allows us to change the mode of both code and data accesses, as well as jump to new code all at once. It has the added benefit of switching the stack and flags at the same time, which is fantastic. This is everything we need to properly jump to user code.

Changing the flags atomically like this means we can go from having interrupts disabled in supervisor mode, to interrupts enabled in user code. All without the risk of having an interrupt occuring while we change these values ourselves.

### What to Push Onto The Stack

Now let's talk about what these values should be: `rflags` is an easy one, set it to `0x202`. Bit 1 is a legacy feature and must always be set, the ninth bit (`0x200`) is the `IF` interrupt enable flag. This means all other flags are cleared, and is what C/C++ and other languages expect flags to look like when starting a program.

For `ss` and `cs` it depends on the layout of your GDT. We'll assume that there are 5 entries in the GDT:

- 0x00, Null
- 0x08, Supervisor Code (ring 0)
- 0x10, Supervisor Data (ring 0)
- 0x18, User Code (ring 3)
- 0x20, User Data (ring 3)

Now `ss` and `cs` are *selectors*, which you'll remember are not just a byte offset into the gdt, the lowest two bits contain a field called _RPL_ (Requested Privilege Level) that is a legacy feature, but it's still enforced by the cpu, so we have to use it. _RPL_  is a sort of 'override' for the target ring, it's useful in some edge cases, but otherwise is best set to the ring we want to jump to.

So if we're going to ring 0 (supervisor), RPL can be left at 0. If going to ring 3 (user) we'd set it to 3.

This means our selectors for `ss` and `cs` end up looking like this:

```c
kernel_ss = 0x08 | 0;
kernel_cs = 0x10 | 0;
user_cs   = 0x18 | 3;
user_ss   = 0x20 | 3;
```

The kernel/supervisor selectors don't need to have their RPL set explicitly, since it'll be zero by default. This is why we may not have dealt with this field before.

If RPL is not set correctly, it will throw _#GP_ (General Protection) exception.

As for the other two values? We're going to set `rip` to the instruction we want to execute after using `iret`, and `rsp` can be set to the stack we want to use. Remember that on `x86_64` the stack grows downwards, so if we allocate memory this should be set to the *highest* address of that region. It's a good idea to run user and supervisor code on separate stacks. This way the supverisor stack can have the `U/S` bit cleared in the paging structure, and prevent user mode accessing supervisor data that may be stored on the stack.

### Extra Considerations

Since we have paging enabled, that means page-level protections are in effect. If we try to run code from a page that has the NX-bit set (bit 63), we'll page fault. The same is true for trying to run code or access a stack from a page with the U/S bit cleared. On `x86_64` this bit must be set at every level in the paging structure.

*Authors Note: For my VMM, I always set write-enabled + present flags on every page entry that is present, and also the user flag if it's a lower-half address. The exception is the last level of the paging structure (pml1, or pml2 for 2mb pages) where I apply the flags I actually need. For example, for a read-only user data page I would set the R/W + U/S + NX + Present bits in the final entry. This keeps the rest of implementation simple. - DT.*

#### Testing userspace

This also leaves us with a problem: how to test if userspace is working correctly? If the scheduler has been implemented using [part five](../05_Scheduling/01_Overview.md) of this book, just creating a thread with user level `ss` and `cs` is not enough, since the thread to run uses the code that is present in the higher half (even the function to execute), and this mean that according to our design that area is marked as supervisor only.

The best way to test it should be implementing support for an executable format (this is explained on [part nine](../09_Loading_Elf/01_Elf_Theory.md)), in this case we're going to write a simple program with just one instruction that loops infinitely. compile it (but not link it to the kernel), and load it somewhere in memory while booting the os (for example as a mulbiboot2 module). Later on we can put it together with the VFS, to load and execute programs for there.

But the problem is that this takes some time to implement, and what we probably want is just check that our kernel can enter and exit the user mode safely. A quick solution to this problem is:

* Write an infinite loop in assembly language:

```x86asm
loop:
    jmp loop
```

and compile it, in using _binary_ as format specifier , for example using nasm:

```x86asm
nasm -f bin example.s -o example
```


* Get the binary code of the compiled source, for example using the following `objdump` command:

```sh
objdump -D -b binary -m i386:x86-64 ../example
```

we get the following output:

```
example:     file format binary

Disassembly of section .data:
0000000000000000 <.data>:
   0:   eb fe                   jmp    0x0
```

The code is stored in the `.data` section, and as you can see in this case is very trivial, and its binary is just two bytes: `eb fe`.

* Assign those two bytes in a `char` array somewhere in our code.
* Now we can map the address of variable containing the program to a userspace memory location, and pass assign this pointer as the new `rip` value for the userspace thread.(how to do it is left as exercise).

In this way the function being executed by the thread will be a userspace executable address containing an infinite loop. If the scheduler keep switching between the idle thread and this  thread, well everything should be working fine.

### Actually Getting to User Mode

First we push the 5 values on to the stack, in this order:

- `ss`, ring 3 data selector.
- `rsp`, the stack we'll use after `iret`.
- `rflags`, what the flags register will look like.
- `cs`, ring 3 code selector.
- `rip`, the next instruction to run after `iret`.

Then we execute `iret`, and we're off! Welcome to user mode!

This is not how it should be done in practice, but for the purposes of an example, here is a function to switch to user mode. Here we're using the example user cs of `0x1B` (or `0x18 | 3`) and user ss of `0x23` (or `0x20 | 3`).

```c
__attribute__((naked, noreturn))
void switch_to_user_mode(uint64_t stack_addr, uint64_t code_addr)
{
    asm volatile(" \
        push $0x23 \n\
        push %0 \n\
        push $0x202 \n\
        push $0x1B \n\
        push %1 \n\
        iretfq \n\
        " :: "r"(stack_addr), "r"(code_addr));
}
```

And voila! We're running user code with a user stack.
In practice this should be done as part of a task-switch, usually as part of the assembly stub used for returning from an interrupt (hence using `iret`).

Note the use of the `naked` and `noreturn` attributes. These are hints for the compiler that it can use certain behaviours. Not *necessary* here, but nice to have.

## Getting Back to Supervisor Mode

This is trickier! Since we don't want user programs to just execute kernel code, there are only certain ways for supervisor code to run. The first is to already be in supervisor mode, like when the bootloader gives control of the machine to the kernel. The second is to use a system call, which is a user mode program asking the kernel to do something for it. This is often done via interrupt, but there are specialized instructions for it too. We have a dedicated chapter on system calls.

The third way is inside of an interrupt handler. While is _possible_ to run interrupts in user mode (an advanced topic for sure), most interrupts will result in supervisor code running in the form of the interrupt handler. Any interrupt will work, for example a page fault or ps/2 keyboard irq, but the most common one is a timer. Since the timer can be programmed to tick at a fixed interval, we can ensure that supervisor code gets to run at a fixed interval. That code may return immediately, but it gives the kernel a chance to look at the program and machine states and see if anything needs to be done. Commonly the handler code for the timer also runs the scheduler tick, and can trigger a task switch.

Handling interrupts while not in supervisor mode on x86 is a surprisingly big topic, so we're going to cover it in a separate chapter. In fact, it's the next chapter!

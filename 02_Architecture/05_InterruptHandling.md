# Interrupt Handling on x86_64

As the title implies, this chapter is purely focused on `x86_64`. Other platforms will have different mechanisms for handling interrupts.

If not familiar with the term *interrupt*, it's a way for the cpu to tell our code that something unexpected or unpredictable has happened, and that it needs to be handled. When an interrupt is triggered, the cpu will *serve* the interrupt by loading the *interrupt handler* specified. The handler itself is just a function, but with a few special conditions.

__Interrupts__ get their name because they interrupt the normal flow of execution, stop whatever code was running on the cpu, execute a handler function, and then resume the previously running code. Interrupts can signal a number of events from the system, from fatal errors to a device telling us it has some data ready to be read.

The `x86` architecture makes a distinction between *hardware interrupts* and *software interrupts*. Don't worry though, this is only something we'll need to worry about if deliberately use it. A software interrupt is one that's triggered by the `int` instruction, anything else is considered a hardware interrupt. The difference is that some hardware interrupts will store an error code (and some will not), but a software interrupt will **never** store an error code. Meaning if the `int` instruction is used to trigger an interrupt which normally has an error code, there wont be one present, and most likely run into bugs if the handler function is not prepared for this.

### The Interrupt Flag and Cli/Sti

There will be situations where we don't want to be interrupted, usually in some kind of critical section. In this case, `x86` actually provides a flag that can be used to disable almost all interrupts. Bit 9 of the `flags` register is the interrupt flag, and like other flag bits it has dedicated instructions for clearing/setting it:

- `cli`: Clears the interrupt flag, preventing the cpu from serving interrupts.
- `sti`: Sets the interrupt flag, letting the cpu serve interrupts.

### Non-Maskable Interrupts

When the interrupt flag is cleared, most interrupts will be *masked*, meaning they will not be served. There is a special case where an interrupt will still be served by the cpu: the *non-maskable interrupt* or NMI. These are extremely rare, and often a result of a critical hardware failure, therefore it's perfectly acceptable to simply have the operating system panic in this case.

*Authors note: Don't let NMIs scare you, we've never run actually run into one on real hardware. You do need to be aware that they exist and can happen at any time, regardless of the interrupt flag.*

## Setting Up For Handling Interrupts

Now we know the theory behind interrupts, let's take a look at how we interact with them on `x86`. As expected, it's a descriptor table! We will be referencing some GDT selectors in this, so a GDT loaded is required. We're also going to introduce a few new terms:

- _Interrupt Descriptor_: A single entry within the interrupt descriptor *table*, it describes what the cpu should do when a specific interrupt occurs.
- _Interrupt Descriptor Table_: An array of interrupt descriptors, usually referred to as the _IDT_.
- _Interrupt Descriptor Table Register_: Usually called the _IDTR_, this is the register within the cpu that holds the address of the IDT. Similar to the GDTR.
- _Interrupt Vector_: Refers to the interrupt number. Each vector is unique, and vectors 0-32 are reserved for special purposes (which we'll cover below). The x86 platform supports 256 vectors.
- _Interrupt Request_: A term used to describe interrupts that are sent to the Programmable Interrupt Controller. The PIC was deprecated long ago and has since been replaced by the APIC. An IRQ refers to the pin number used on the PIC: for example, IRQ2 would be pin #2. The APIC has [a chapter](07_APIC.md) of its own.
- _Interrupt Service Routine_: Similar to IRQ, this is an older term, used to describe the handler function for IRQ. Often shortened to ISR.

To handle interrupts, we need to create a table of descriptors, called the *Interrupt Descriptor Table*. We then load the address of this IDT into the IDTR, and if the entries of the table are set up correctly we should be able to handle interrupts.

### Interrupt Descriptors

The protected mode IDT descriptors have a different format to their long mode counterparts. Since we're focusing on long mode, they are what's described below. The structure of an interrupt descriptor is as follows:

```c
struct interrupt_descriptor
{
    uint16_t address_low;
    uint16_t selector;
    uint8_t ist;
    uint8_t flags;
    uint16_t address_mid;
    uint32_t address_high;
    uint32_t reserved;
} __attribute__((packed));
```

Note the use of the packed attribute! Since this structure is processed by hardware, we don't want the compiler to insert any padding in our struct, we want it to look exactly as we defined it (and be exactly 128 bits long, like the manual says).
The three `address_` fields represent the 64-bit address of our handler function, split into different parts: with `address_low` being bits 15:0, `address_mid` is bits 31:16 and `address_high` is bits 63:32. The `reserved` field should be set to zero, and otherwise ignored.

The selector field is the *code selector* the cpu will load into `%cs` before running the interrupt handler. This should be our kernel code selector. Since the kernel code selector should be running in ring 0, there is no need to set the RPL field. This selector can just be the byte offset into the GDT we want to use.

The `ist` field can safely be left at zero to disable the IST mechanism. For the curious, this is used in combination with the TSS to force the cpu to switch stacks when handling a specific interrupt vector. This feature can be useful for certain edge cases like handling NMIs. ISTs and the TSS are covered later on when we go to userspace.

The `flags` field is a little more complex, and is actually a bitfield. Its format is as follows:

| Bits   | Name      | Description                                     |
|--------|-----------|-------------------------------------------------|
| 3:0    | Type      | In long mode there are two types of descriptors we can put here: trap gates and interrupt gates. The difference is explained below. |
| 4      | Reserved  | Set to zero.                                    |
| 6:5    | DPL       | The *Descriptor Privilege Level* determines the highest cpu ring that can trigger this interrupt via software. A default of zero is fine. |
| 7      | Present   | If zero, means this descriptor is not valid and we don't support handling this vector. Set this bit to tell the cpu we support this vector, and that the handler address is valid. |

Let's look closer at the type field. We have two options here, with only one difference between them: an interrupt gate will clear the interrupt flag before running the handler function, and a trap gate will not. Meaning if a trap gate is used, interrupts can occur while inside of the handler function. There are situations where this is useful, but we will know those when we encounter them. An interrupt gate should be used otherwise. They have the following values for the `type` field:

- Interrupt gate: `0b1110`.
- Trap gate: `0b1111`.

The DPL field is used to control which cpu rings can trigger this vector with a software interrupt. On `x86` there are four protection rings (0 being the most privileged, 3 the least). Setting DPL = 0 means that only ring 0 can issue a software interrupt for this vector, if a program in another ring tries to do this it will instead trigger a *general protection fault*. For now we have no use for software interrupts, so we'll set this to 0 to only allow ring 0 to trigger them.

That's a lot writing, but in practice it won't be that complex. Let's create a function to populate a single IDT entry for us. In this example we'll assume the kernel code selector is 0x8, but it may not be.

```c
interrupt_descriptors idt[256];

void set_idt_entry(uint8_t vector, void* handler, uint8_t dpl)
{
    uint64_t handler_addr = (uint64_t)handler;

    interrupt_descriptor* entry = &idt[vector];
    entry->address_low = handler_addr & 0xFFFF;
    entry->address_med = (handler_addr >> 16) & 0xFFFF;
    entry->address_high = handler_addr >> 32;
    //your code selector may be different!
    entry->selector = 0x8;
    //trap gate + present + DPL
    entry->flags = 0b1110 | ((dpl & 0b11) << 5) |(1 << 7);
    //ist disabled
    entry->ist = 0;
}
```

In the above example we just used an array of descriptors for our IDT, because that's really all it is! However, a custom type that represents the array can be created.

### Loading an IDT

We can fill in the IDT, now we need to tell the cpu where it is. This is where the `lidt` instruction comes in. It's nearly identical to how the `lgdt` instruction works, except it loads the IDTR instead of the GDTR. To use this instruction we'll need to use a temporary structure, the address of which will be used by `lidt`.

```c
struct idtr
{
    uint16_ limit;
    uint64_t base;
} __attribute__((packed));
```

Again, note the use of the packed attribute. In long mode the `limit` field should be set to `0xFFF` (16 bytes per descriptor * 256 descriptors, minus 1). The `base` field needs to contain the *logical address* of the idt. This is usually the virtual address, but if the segmentation have been re-enabled in long mode (some cpus allow this), this address ignores segmentation.

*Authors Note: The reason for subtracting one from the size of the idt is interesting. Loading an IDT with zero entries would effectively be pointless, as there would be nothing there to handle interrupts, and so no point in having loaded it in the first place. Since the size of 1 is useless, the length field is encoded as one less than the actual length. This has the benefit of reducing the 12-bit value of 4096 (for a full IDT), to a smaller 11-bit value of 4096. One less bit to store!*

```c
void load_idt(void* idt_addr)
{
    idtr idt_reg;
    idt_reg.limit = 0xFFF;
    idt_reg.base = (uint64_t)idt_addr;
    asm volatile("lidt %0" :: "m"(&idt_reg));
}
```

In this example we stored `idtr` on the stack, which gets cleaned up when the function returns. This is okay because the IDTR register is like a segment register in that it caches whatever value was loaded into it, similar to the GDTR. So it's okay that our `idtr` structure is no longer present after the function returns, as the register will have a copy of the data our structure contained. Having said that, the actual _IDT_ can't be on the stack, as the cpu does not cache that.

At this point we should be able to install an interrupt handler into the IDT, load it,  and set the interrupts flag. The kernel will likely crash as soon as an interrupt is triggered though, as there are some special things we need to perform inside of the interrupt handler before it can finish.

## Interrupt Handler Stub

Since an interrupt handler uses the same general purpose registers as the code that was interrupted, we'll need to save and then restore the values of those registers, otherwise we may crash the interrupted program.

There are a number of ways we could go about something like this, we're going to use some assembly (not too much!) as it gives us the fine control over the cpu we need. There are other ways, like the infamous `__attribute__((interrupt))`, but these have their own issues and limitations. This small bit of assembly code will allow us to add other things as we go.

*Authors Note: Using `__attribute__((interrupt))` may seem tempting with how simple it is, and it lets you avoid assembly! This is easy mistake to make (one I made myself early on). This method is best avoided as covers the simple case of saving all the general purpose registers, but does nothing else. Later on you will want to do other things inside your interrupt stub, and thus have to abandon the attribute and write your own stub anyway. Better to get it right from the beginning. - DT.*

There are a number of places where the state of the general purpose registers could be stored, we're going to use the stack as it's extremely simple to implement. In protected mode there are the `pusha`/`popa` instructions for this, but they're not present in long mode so we have to do this ourselves.

There is also one other thing: when an interrupt is served the cpu will store some things on the stack, so that when the handler is done we can return to the previous code. The cpu pushes the following on to the stack (in this order):

- `%ss`: The previous stack selector.
- `%rsp`: The previous stack-top.
- `%rflags`: The previous value of the flags register, before the cpu modified any flags for serving the interrupt.
- `%cs`: The previous code selector.
- `%rip`: The previous instruction pointer.

Optionally, for some vectors the cpu will push a 64-bit error code (see the table below for specifics).
This structure is known as an *iret frame*, because to return from an interrupt we use the `iret` instruction, which pops those five values from the stack.

Hopefully the flow of things is clear at this point: the cpu serves the interrupt, pushes those five values onto the stack. Our handler function runs, and then executes the `iret` instruction to pop the previously pushed values off the stack, and returns to the interrupted code.

### An Example Stub

Armed with the above infomation, now we should be able to implement our own handler stubs. One common way to do this is using an assembler macro. Here we would create one macro that pushes all registers, calls a C function and then pops all registers before executing `iret`. What about the optional error code? Well, the easiest solution is to define *two* macros, one like the previous one, and another that pushes a pretend error code of 0, before pushing all the general registers. Because we know which vectors push an error code and which don't, we can change which macro we use.

The benefit of this is our stack will always look the same regardless of whether a real error was used or not. This allows us to do all sorts of things later on.

Another solution, is to only write a single assembly stub like the first macro. Then for each handler function we could either just jump to the stub function (if an error code was pushed by the cpu), or push a dummy error code and then jump to the stub function. We'll go with the second option.

First of all, let's write a generic stub. We're going to route all interrupts to a C function called `interrupt_dispatch()`, to make things easier in the future. That does present the issue of knowing which interrupt was triggered since they all call the same function, but we have a solution! We'll just push the vector number to the stack as well, and we can access it from our C function.

```x86asm
interrupt_stub:
push %rax
push %rbx
//push other registers here
push %r14
push %r15

call interrupt_disaptch

pop %r15
pop %r14
//push other registers here
pop %rbx
pop %rax

//remove the vector number + error code
add $16, %rsp

iret
```

A thing to notice is that  we added 16 bytes to the stack before the `iret`. This is because there will be an error code (real or dummy) and the vector number that we need to remove, so that the iret frame is at the top of the stack. If we don't do this, `iret` will use the wrong data and likely trigger a general protection fault.

As for the general purpose registers, the order they're pushed doesn't really matter, as long as they're popped in reverse. You can skip storing `%rsp`, as its value is already preserved in the `iret` frame. That's the generic part of our interrupt stub, now we just need the handlers for each vector. They're very simple!

We're also going to align each handler's function to 16 bytes, as this will allow us to easily install all 256 handlers using a loop, instead of installing them individually.

```x86asm
.align 16
vector_0_handler:
//vector 0 has no error code
pushq $0
//the vector number
pushq $0
jmp interrupt_stub

//align to the next 16-byte boundary
.align 16
vector_1_handler:
//also needs a dummy error code
pushq $0
//vector number
pushq $1
jmp interrupt_stub

//skipping ahead

.align 16
vector_13_handler:
//vector 13(#GP) does push an error code
//so we wont. Just the vector number.
pushq $13
jmp interrupt_stub
```

There's still a lot of repetition, so we could take advantage of our assembler macro features to automate that down into a few lines. That's beyond the scope of this chapter though.
Because of the 16-byte alignment, we know that handler number `xyz` is offset by `xyz * 16` bytes from the first handler.

```c
extern char vector_0_handler[];

for (size_t i = 0; i < 256; i++)
    set_idt_entry(i, (uint64_t)vector_0_handler + (i * 16), 0);
```

The type of vector_0_handler isn't important, we only care about the address it occupies. This address gets resolved by the linker, and we could just as easily use a pointer type instead of an array here.

### Sending EOI

With that done, we can now enter and return from interrupt handlers correctly! We should keep in mind that this is just handling interrupts from the cpu's perspective. The cpu usually does not send interrupts to itself, it receives them from an external device like the local APIC. APICs are discussed in their own chapter, but we will need to tell the local APIC that we have handled the latest interrupt. This is called sending the EOI (End Of Interrupt) signal.

The EOI can be sent at any point inside the interrupt handler, since even if the local APIC tries to send another interrupt, the cpu won't serve it until the interrupts flag is cleared. Remember the interrupt gate type we used for our descriptors? That means the cpu cleared the interrupts flag when serving this interrupt.

If we don't send the EOI, the cpu will return from the interrupt handler and execute normally, but we will never be able to handle any future interrupts because the local APIC thinks we're still handling one.

## Interrupt Dispatch

*Authors Note: This chapter is biased towards how I usually implement my interrupt handling. I like it because it lets me collect all interrupts in one place, and if something fires an interrupt I'm not ready for, I can log it for debugging. As always, there are other ways to go about this, but for the purposes of this chapter and the chapters to follow, it's assumed that your interrupt handling looks like the following (for simplicity of the explanations). -DT*

We introduced the `interrupt_dispatch` function before, and had *all* of our interrupts call it. The `dispatch` part of the name hints that its purpose is to call other functions within the kernel, based on the interrupt vector. There is also a hidden benefit here that we don't have to route one interrupt to one kernel function. An intermediate design could maintain a list for each vector of functions that wish to be called when something occurs. For example there might be multiple parts of the kernel that wish to know when a timer fires. This design is not covered here, but it's something to think about for future uses. For now we'll stick with a simple design which just calls a single kernel function directly.

```c
void interrupt_dispatch()
{
    switch (vector_number)
    {
        case 13:
            log("general protection fault.");
            break;
        case 14:
            log("page fault.");
            break;
        default:
            log("unexpected interrupt.");
            break;
    }
}
```

There's an immediate issue with the above code though: How do we actually get `vector_number`? The assembly stub stored it on the stack, and we need it here in C code. The answer might be obvious if worked with assembly and C together before, but if not: read on.

Each platform has at least one *psABI* (Platform-Specific Application Binary Interface). It's a document that lays out how C structures translate to the specific registers and memory layouts of a particular platform, and it covers *a lot* of things. What we're interested in is something called the *calling convention*. For x86 there are a few calling conventions, but we're going to use the default one that most compilers (gcc and clang included) use: system V x86_64. Note that the x86_64 calling convention is different to the x86 (32-bit) one.

Calling conventions are explored more in the appendix chapter about the C language, but what we care about is how to pass an argument to a function, and how to access the return value. For the system V x86-64 calling convention the first argument is passed in `%rdi`, and and the return value of a function is left in `%rax`.

Excellent, we can pass data to and from our C code now. As for what we're going to pass? The stack pointer.

The logic behind this is that all of our saved registers, the vector number, error code and iret frame are all saved on the stack. So by passing the stack pointer, we can access all of those values from our C code. We're also going to return the stack pointer from `interrupt_dispatch` to our assembly stub. This serves no purpose currently, but is something that will be used by future chapters (scheduling and system calls).

Passing the stack pointer is useful, but we can do better by creating a C structure that mirrors what we've pushed onto the stack. This way we can interpret the stack pointer as a pointer to this structure, and access the fields in a more familiar way. We're going to call this structure `cpu_status_t`, it has been called all sorts of things from `context_t` to `registers_t`. What's important about it is that we define the fields in the **reverse** order of what we push to the stack. Remember the stack grows downwards, so the earlier pushes will have higher memory addresses, meaning they will come later in the structs definition. Our struct is going to look like the following:

```c
struct cpu_status_t
{
    uint64_t r15;
    uint64_t r14;
    //other pushed registers
    uint64_t rbx;
    uint64_t rax;

    uint64_t vector_number;
    uint64_t error_code;

    uint64_t iret_rip;
    uint64_t iret_cs;
    uint64_t iret_flags;
    uint64_t iret_rsp;
    uint64_t iret_ss;
};
```

The values pushed by the cpu are prefixed with `iret_`, which are also the values that the `iret` instruction will pop from the stack when leaving the interrupt handler. This is another nice side effect of having our stack laid out in a standard way, because of the dummy error code we pushed we know we can always use this structure.

Our modified `interrupt_dispatch` now looks like:

```c
void interrupt_dispatch(cpu_status_t* context)
{
    switch (vector_number)
    {
        case 13:
            log("general protection fault.");
            break;
        case 14:
            log("page fault.");
            break;
        default:
            log("unexpected interrupt.");
            break;
    }
    return context;
}
```

All that's left is to modify the assembly `interrupt_stub` to handle this. It's only a few lines:

```x86asm
//push other registers here
push %r15

mov %rsp, %rdi
call interrupt_dispatch
mov %rax, %rsp

pop %r15
//pop other registers here
```

That's it! One thing to note is that whatever is returned from `interrupt_dispatch` will be loaded as the new stack, so only return things we know are valid. Returning the existing stack is fine, but don't try to return `NULL` or anything as an error.

### Reserved Vectors

There's one piece of housekeeping to take care of! On x86 there first 32 interrupt vectors are reserved. These are used to signal certain conditions within the cpu, and these are well documented within the Intel/AMD manuals. A brief summary of them is given below.

|  Vector Number | Shorthand | Description                           | Has Error Code |
|----------------|-----------|---------------------------------------|----------------|
| 0              | #DE       | Divide By Zero Error                  | No             |
| 1              | #DB       | Debug                                 | No             |
| 2              | #NMI      | Non-Maskable Interrupt                | No             |
| 3              | #BP       | Breakpoint                            | No             |
| 4              | #OF       | Overflow                              | No             |
| 5              | #BR       | Bound Range Exceeded                  | No             |
| 6              | #UD       | Invalid Opcode                        | No             |
| 7              | #NM       | Device not available                  | No             |
| 8              | #DF       | Double Fault                          | Yes (always 0) |
| 9              |           | Unused (was x87 Segment Overrrun)     | -              |
| 10             | #TS       | Invalid TSS                           | Yes            |
| 11             | #NP       | Segment Not Present                   | Yes            |
| 12             | #SS       | Stack-Segment Fault                   | Yes            |
| 13             | #GP       | General Protection                    | Yes            |
| 14             | #PF       | Page Fault                            | Yes            |
| 15             |           | Currently Unused                      | -              |
| 16             | #MF       | x87 FPU error                         | No             |
| 17             | #AC       | Alignment Check                       | Yes (always 0) |
| 18             | #MC       | Machine Check                         | No             |
| 19             | #XF       | SIMD (SSE/AVX) error                  | No             |
| 20-31          |           | Currently Unused                      | -              |

While some of these vectors are unused, they are still reserved and might be used in the future. So consider using them as an error. Most of these are fairly rare occurrences, however we will quickly explain a few of the common ones:

- _Page Fault_: Easily the most common one to run into. It means there was an issue with translating a virtual address into a physical one. This does push an error code which describes the memory access that triggered the page fault. Note the error describes what was being attempted, not what caused translation to fail. The `%cr2` register will also contain the virtual address that was being translated.
- _General Protection Fault_: A GP fault can come from a large number of places, although it's generally from an instruction dealing with the segment registers in some way. This includes `iret` (it modifies cs/ss), and others like `lidt`/`ltr`. It also pushes an error code, which is described below. A GP fault can also come from trying to execute a privileged instruction outside when it's not allowed to be. This case is different to an undefined opcode, as the instruction exists, but is just not allowed.
- _Double Fault_: This means something has gone horribly wrong, and the system is not in a state that can be recovered from. Commonly this occurs because the cpu could not call the GP fault handler, but it can be triggered by hardware conditions too. This should be considered as our last chance to clean up and save any state. If a double fault is not handled, the cpu will 'triple fault', meaning the system resets.

A number of the reserved interrupts will not be fired by default, they require certain flags to be set. For example the x87 FPU error only occurs if `CR0.NE` is set, otherwise the FPU will silently fail. The SIMD error will only occur if the cpu has been told to enable SSE. Others like bound range exceeded or device not available can only occur on specific instructions, and are generally unseen.

A Page Fault will push a bitfield as its error code. This is not a complete description of all the fields, but it's all the common ones. The others are specific to certain features of the cpu.

| Bit | Name      | Description                            |
|-----|-----------|----------------------------------------|
| 0   | Present   | If set, means all the page table entries were present, but translation failed due to a protection violation. If cleared, a page table entry was not present. |
| 1   | Write     | If set, page fault was triggered by a write attempt. Cleared if it was a read attempt. |
| 2   | User      | Set if the CPU was in user mode (CPL = 3). |
| 3   | Reserved Bit Set | If set, means a reserved bit was set in a page table entry. Best to walk the page tables manually and see what's happening. |
| 4   | Instruction Fetch | If NX (No-Execute) is enabled in EFER, this bit can be set. If set the page fault was caused by trying to fetch an instruction from an NX page. |

The other interrupts that push an error code (excluding the always-zero ones) use the following format to indicate which selector caused the fault:

| Bits | Name     | Description                            |
|------|----------|----------------------------------------|
| 0    | External | If set, means it was a hardware interrupt. Cleared for software interrupts. |
| 1    | IDT      | Set if this error code refers to the IDT. If cleared it refers to the GDT or LDT (Local Descriptor Table - mostly unused in long mode). |
| 2    | Table Index | Set if the error code refers to the LDT, cleared if referring to the GDT. |
| 31:3 | Index    | The index into the table this error code refers to. This can be seen as a byte offset into the table, much like a GDT selector would. |

## Troubleshooting

### Remapping The PICs

This is touched on more in the APIC chapter, but before the current layout of the IDT existed there were a pair of devices called the PICs that handled interrupts for the cpu. They can issue 8 interrupts each, and by default they send them as vectors 0-7 and 8-15. That was fine at the time, but now this interferes with the reserved vectors, and can lead to the cpu thinking certain events are happening when they're actually not.

Fortunately the PICs allow us to offset the vectors they issue to the cpu. They can be offset anywhere about 0x20, and commonly are placed at 0x20 and 0x28.

### Halt not Halting

If a `hlt` call has been placed  at the end of the kernel, and are suddenly getting errors after successfully handling an interrupt, read on. There's a caveat to the halt instruction that's easily forgotten: this instruction works by telling the cpu to stop fetching instructions, and when an interrupt is served the cpu fetches the instructions required for the interrupt handler function. Now, since the cpu is halted, it must un-halt itself to execute the interrupt handler. This is what we expect, and we are fine so far.
However, when we return from the interrupt, we have already run the `hlt` instruction, so we return to the *next instruction*. See the issue? There's usually nothing after we halt, in fact that memory is probably data instead of code. Therefore we end up executing *something*, and ultimately trigger some sort of error.
The solution is to use the halt instruction within a loop, so that after each instruction we run `hlt` again, like so:

```c
//this is what you want
while (true)
    asm("hlt");

//not good!
asm("hlt");
```

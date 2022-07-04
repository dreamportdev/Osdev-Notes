# Interrupt Handling on x86

As the title implies, this chapter is purely focused on x86. Other platforms will have different mechanisms for handling interrupts.

If you're not familiar with the term *interrupt*, it's a way for the cpu to tell your code that something unexpected or unpredictable has happened, and that you need to handle it. When an interrupt is triggered, the cpu will *serve* the interrupt by loading the *interrupt handler* we specified. The interrupt handler itself is just a function, but with a few special conditions. 

Interrupts get their name because they interrupt the normal flow of execution, instead stopping whatever code was running on the cpu, running a handler function, and then resuming the previously running code. Interrupts can signal a number of events from the system, from fatal errors to a device telling you it has some data for you to read.

The x86 architecture makes a distinction between *hardware interrupts* and *software interrupts*. Don't worry though, this is only something you'll need to worry about if you deliberately use it. A software interrupt is one that's triggered by the `int` instruction, anything else is considered a hardware interrupt. The difference is that some hardware interrupts will store an error code (and some will not), but a software interrupt will **never** store an error code. Meaning if you use the `int` instruction to trigger an interrupt which normally has an error code, there wont be one present, and you'll run into bugs if your handler function is not prepared for this.

### The Interrupt Flag and Cli/Sti

There will be situations where you don't want to be interrupted, usually in some kind of critical section. In this case, x86 actually provides a flag you can use to disable almost all interrupts. Bit 9 of the `flags` register is the interrupt flag, and like other flag bits it has dedicated instructions for clearing/setting it:

- `cli`: Clears the interrupt flag, preventing the cpu from serving interrupts.
- `sti`: Sets the interrupt flag, letting the cpu serve interrupts.

### Non-Maskable Interrupts

When the interrupt flag is cleared, most interrupts will be *masked* meaning they will not be served. There is a special case where an interrupt will still be served by the cpu: the *non-maskable interrupt* or NMI. These are extremely rare, and often a result of a critical hardware failure, therefore it's perfectable acceptable to simply have your operating system panic in this case. 

*Authors note: Don't let NMIs scare you, I've never run actually run into one on real hardware. You do need to be aware that they exist and can happen at any time, regardless of the interrupt flag.*

## Setting Up For Handling Interrupts

Now we know the theory behind interrupts, let's take a look at how we interact with them on x86. As expected, it's a descriptor table! We will be referencing some GDT selectors in this, so you'll need to have your own GDT setup. We're also going to introduce a few new terms:

- Interrupt Descriptor: A single entry within the interrupt descriptor *table*, it describes what the cpu should do when a specific interrupt occurs.
- Interrupt Descriptor Table: An array of interrupt descriptors., usually referred to as the IDT.
- Interrupt Descriptor Table Register: Usually called the IDTR, this is register within the cpu that holds the address of the IDT. Similar to the GDTR.
- Interrupt Vector: Refers to the interrupt number. Each vector is unique, and vectors 0-32 are reserved for special purposes (which we'll cover below). The x86 platform supports 256 vectors.
- Interrupt Request: A term used to describe interrupts that are sent to the Programmable Interrupt Controller. The PIC was deprecated long ago and has since been replaced by the APIC. An IRQ refers to the pin number used on the pic: IRQ2 would be pin #2 for example. The APIC has a chapter of it's own.
- Interrupt Service Routine: Similar to IRQ, this is an older term, used to describe the handler function for IRQ. Often shortened to ISR.

In order for us to be able to handle interrupts, we're going to need to create an array of descriptors (or rather a table, called the *Interrupt Descriptor Table*). We then load the address of this IDT into the IDTR, and if the entries of the table are set up correctly we should be able to handle interrupts.

### Interrupt Descriptors

The protected mode IDT descriptors have a different format to the long mode versions. We're focusing on long mode, so they're what's described below. The structure of an interrupt descriptor is as follows:

```c
struct interrupt_descriptor
{
    uiunt16_t address_low;
    uint16_t selector;
    uint8_t ist;
    uint8_t flags;
    uint16_t address_mid;
    uint32_t address_high;
    uint32_t reserved;
} __attribute__((packed));
```

Note the use of the packed attribute! Since this structure is processed by hardware, we dont want the compiler to insert any padding in our struct, we want it to look exactly as we defined it.
The three `address_` fields represent the 64-bit address of our handler function, split into different parts: with `address_low` being bits 15:0, `address_mid` is bits 31:16 and `address_high` is bits 63:32. The `reserved` field should be set to zero, and otherwise ignored.

The selector field is the *code selector* the cpu will load into `%cs` before running the interrupt handler. This should be your kernel code selector. Since your kernel code selector should be running in ring 0, there is no need to set the RPL field. This selector can just be the byte offset into the GDT you want to use. 

The `ist` field can safely be left at zero to disable the IST mechanism. For the curious, this is used in combination with the TSS to force the cpu to switch stacks when handling a specific interrupt vector. This is covered later on when we go to userspace. 

The `flags` field is a little more complex, and is actually a bitfield. It's format is as follows:

| Bits   | Name      | Description                                     |
|--------|-----------|-------------------------------------------------|
| 3:0    | Type      | In long mode there are two types of descriptors we can put here: trap gates and interrupt gates. The difference is explained below. |
| 4      | Reserved  | Set to zero.                                    |
| 6:5    | DPL       | The *Descriptor Privilege Level* determines the highest cpu ring that can trigger this interrupt via software. A default of zero is fine. |
| 7      | Present   | If zero, means this descriptor is not valid and we don't support handling this vector. Set this bit to tell the cpu we support this vector, and that the handler address is valid. |

Let's look closer at the type field. We have two options here, with only one difference between them: an interrupt gate will clear the interrupt flag before running the handler function, and a trap gate will not. Meaning if a trap gate is used, interrupts can occur while inside of the handler function. There are situations where this is useful, but you'll know those when you encounter them. An interrupt gate should be used otherwise. They have the following values for the `type` field:

- Interrupt gate: `0b1110`.
- Trap gate: `0b1111`.

The DPL field is used to control which cpu rings can trigger this vector with a software interrupt. On x86 there are four protection rings (0 being the most privileged, 3 the least). Setting DPL = 0 means that only ring 0 can issue a software interrupt for this vector, if a program in another ring tries to do this it will instead trigger a *general protection fault*. This is expanded on more in the userspace chapter, and should be left to zero for now.

That's a lot writing, but in practice it won't be that complex. Let's create a function to populate a single IDT entry for us. In this example we'll assume your kernel code selector is 0x8, but yours may not be.

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

In the above example you we just used an array for our IDT. You can create your own type to handle that if you want, or you can leave it bare like we did.

### Loading an IDT
We can fill in the IDT, now we need to tell the cpu where it is. This is where the `lidt` instruction comes in. It's nearly identical to how the `lgdt` instruction works, except it loads the IDTR instead of the GDTR. To use this instruction we'll need to use a temporary structure, the address of which will be used by `lidt`. 

```c
struct idtr
{
    uint16_ limit;
    uint64_t base;
} __attribute__((packed));
```

Again, note the use of the packed attribute. In long mode the limit field should be set to 0xFFF (16 bytes per descriptor * 256 descriptors, and substract 1 because that's how this is encoded). The `base` field needs to contain the *logical address* of the idt. This is usually the virtual address, but if you have re-enabled segmentation in long mode (some cpus allow this), this address ignores segmentation.

```c
void load_idt(void* idt_addr)
{
    idtr idt_reg;
    idt_reg.limit = 0xFFF;
    idt_reg.base = (uint64_t)idt_addr;
    asm volatile("lidt %0" :: "m"(&idt_reg));
}
```

In this example we stored `idtr` on the stack, which gets cleaned up when the function returns. This is okay because the IDTR register is like a segment register in that it caches whatever value was loaded into it. So it's okay that our idtr structure is no present, as the register will still have it. The actual IDT can't be on the stack, as the cpu does not cache that.

At this point you should be able to install an interrupt handler into your IDT, load the IDT and set the interrupts flag. Your kernel will likely crash as soon as an interrupt is triggered though, as there are some special things we need to perform inside of an interrupt handler.

## Interrupt Handler Stub
Since an interrupt handler uses the same general purpose registers as the code that was interupted, we'll need to save and then restore the values of those registers, otherwise we may crash the interrupted program.
There are a number of places you could store the state of these registers, we're going to use the stack as it's extremely simple to implement. In protected mode we have the `pusha`/`popa` instructions for this, but they're not present in long mode so we have to do this ourselves.

There is also one other thing: when an interrupt is served the cpu will store some things on the stack, so that when the handler is done we can return to the previous code. The cpu pushes the following on to the stack (in this order):

- `%ss`: The previous stack selector.
- `%rsp`: The previous stack-top.
- `%rflags`: The previous value of the flags register, before the cpu modified any flags for serving the interrupt.
- `%cs`: The previous code selector.
- `%rip`: The previous instruction pointer.

Optionally, for some vectors the cpu will push a 64-bit error code (see the table below for specifics).
This structure is known as an *iret frame*, because to return from an interrupt we use the `iret` instructin, which pops those five values from the stack. Hopefully the flow of things is clear at this point: the cpu serves the interrupt, pushes those five values onto the stack. Our handler function runs, and then executes the `iret` instruction to pop the previously pushed values off the stack, and return to the interrupted code.

### An Example Stub
Armed with the above infomation, you should be able to implement your own handler stubs. One common way to do this is using an assembler macro. Here you would create one macro that pushes all registers, calls a C function and then pops all registers before executing `iret`. What about the optional error code? Well, the easiest solution is to define *two* macros, one like the previous one, and another that pushes a pretend error code of 0, before pushing all the general registers. Because we know which vectors push an error code and which don't, we can change which macro we use. 

The benefit of this is your stack will always look the same regardless of whether a real error was used or not. This allows us to do all sorts of things later on.

Another solution, is to only write a single assembly stub like the first macro. Then for each handler function you could either just jump to the stub function (if an error code was pushed by the cpu), or push a dummy error code and then jumpo to the stub function. We'll go with the second option.

First of all, lets write our generic stub. We're going to route all interrupts to a C function called `interrupt_dispatch()`, to make things easier in the future. That does present the issue of knowing which interrupt was triggered since they all call the same function, but we have a solution! We'll just push the vector number to the stack as well, and we can access from our C function.

```x86asm
interrupt_stub:
push %rax
push %rbx
[ ... push other registers here ... ]
push %r14
push %r15

call interrupt_disaptch

pop %15
pop %r14
[ ... pop registers in reverse order ... ]
pop %rbx
pop %rax

//remove the vector number + error code
add $16, %rsp

iret
```

You'll notice we added 16 bytes to the stack before the `iret`. This is because there will be an error code (real or dummy) and the vector number that we need to remove, so that the iret frame is at the top of the stack. If we don't do this, `iret` will use the wrong data and likely trigger a general protection fault.

As for the general purpose registers, the other they're pushed doesn't really matter, as long as they're popped in reverse. You can skip storing `%rsp`, as it's value is already preserved in the `iret` frame. That's the generic part of our interrupt stub, now we just need the handlers for each vector. They're very simple!

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
jmp interrupty_stub

[ ... Skipping ahead ... ]

.align 16
vector_13_handler:
//vector 13(#GP) does push an error code
//so we wont. Just the vector number.
pushq $13
jmp interrupt_stub
```

There's still a lot of repetition, so you could take advantage of your assemblers macro features to automate that down into a few lines. That's beyond the scope of this chapter though.
Because of the 16-byte alignment, we know that handler number `xyz` is offset by `xyz * 16` bytes from the first handler. 

```c
extern char vector_0_handler[];

for (size_t i = 0; i < 256; i++)
    set_idt_entry(i, (uint64_t)vector_0_handler + (i * 16), 0);
```

### Sending EOI
With that done, we can now enter and return from interrupt handlers correctly! You should keep in mind that this is handling interrupts with the cpu. The cpu usually does not send interrupts to itself, it receives them from an external device like the local APIC. APICs are discussed in their own chapter, but you will need to tell the local APIC that you haven handled the latest interrupt. This is called sending the EOI (End Of Interrupt) signal.

You can send the EOI at any point inside the interrupt handler, since even if the local APIC tries to send another interrupt, the cpu won't serve it until the interrupts flag is cleared. Remember that the interrupt gate type we used for our descriptors? That means the cpu cleared the interrupts flag when serving this interrupt.

If we don't send the EOI, the cpu will resume the interrupt code and execute normally, but we will never be able to handle any future interrupts because the local APIC thinks we're still handling one.

## Interrupt Dispatch


-cpu_status_t

### Reserved Vectors
-first 32 reserved
-remap pics

|  #idx | ID  | Description                           | Type     | ErrorCode |
|-------|-----|---------------------------------------|----------|-----------|
|   0   | #DE | Divide Error                          | Fault    |     No    | 
|   1   | #DB | RESERVED                              | Fault    |     No    |
|   2   |  -  | NMI Interrupt                         | Interrupt|     No    |
|   3   | #BP | Breakpoint                            | Trap     |     No    |
|   4   | #OF | Overflow                              | Trap     |     No    |
|   5   | #BR | BOUND Range Exceeded                  | Fault    |     No    |
|   6   | #UD | Invalid Opcode                        | Fault    |     No    | 
|   7   | #NM | Device not available                  | Fault    |     No    |
|   8   | #DF | Double Fault                          | Abort	 |   Yes (0) |
|   9   |     | Coprocessor segment overrun (reserved)| Fault	 |     No    |
|   10  | #TS | Invalid TSS                           | Fault    |    Yes    |
|   11  | #NP | Segment Not Present                   | Fault    |    Yes    |
|   12  | #SS | Stack-Segment Fault                   | Fault    |    Yes    |
|   13  | #GP | General Protection                    | Fault    |    Yes    |
|   14  | #PF | Page Fault                            | Fault    |    Yes    |
|   15  |     | Reserved                              |          |     No    |
|   16  | #MF | x87FPU Floating-Point Err (Math Fault)| Fault    |     No    |
|   17  | #AC | Alignment Check                       | Fault    |   Yes (0) |
|   18  | #MC | Machine Check                         | Abort    |     No    | 
|   19  | #XF | SIMD Floating point Exception         | Fault    |     No    |
| 20-31 |     | Reserved                              |          |           |
| 32-255|     | User defined (non reserved)interrupts | Interrup |           |

## Troubleshooting

If you've placed a `hlt` at the end of your kernel, and are suddenly getting errors after successfully handling an interrupt, read on. There's a caveat to the halt instruction that's easily forgotten: this instruction works by telling the cpu to stop fetching instructions, and when an interrupt is served the cpu fetches the instructions required for the interrupt handler function. Now since the cpu is halted, it must un-halt itself in order for the interrupt handler instructions to be executed. This is what we expect, and fine so far. 
However when we return from the interrupt, we have already run the `hlt` instruction, so we return to the *next instruction*. See the issue? There's usually nothing after we halt, in fact that memory is probably data instead of code. Therefore we end up executing *something*, and ultimately trigger some sort of error.
The solution is the use the halt instruction within a loop, so that after each instruction we run `hlt` again, like so:

```c
//this is what you want
while (true)
    asm("hlt");

//not good!
asm("hlt);
```

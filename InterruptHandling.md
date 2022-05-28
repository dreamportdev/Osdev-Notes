# IDT

Although the IDT in long mode is pretty similar to the IA32 one, there are few differences. I'll try to cover them in this document.

## IDT Entry Structure

First important difference, is that while the IA32 idt entry is 64 bit, in long mode is 128 bit, and the structure is little bit different. 

This is how a idt entry structure looks like more or less: 
```C 
typedef struct IDT_desc {
   uint16_t offset;
   uint16_t segment_selector;
   uint8_t ist; //only first 2 bits are used, the rest is 0
   uint8_t flags; //P(resent) DPL (0) TYPE
   uint16_t offset_2;
   uint32_t offset_3;
   uint32_t reserved;
} __attribute__((__packed__))IDT_descriptor;
```

Where: 

* offset, offset_2 and offset_3 are the base address of interrupt handling function
* segment_selector: it indicates the selector for the destination code segment (specified in the GDT)
* ist: only the first 4 bits are used it is the interrupt stack table
* flags: it contains several information (from bit 0 to 8): 
    * Type, 4 bits it indicates the type of the IDT entry, in this case has to be 14 (this value indicate a 64 bit interrupt gate)
    * The next bit is always 0
    * DPL two bits, it can be 0 if handling cpu interrupts/exceptions
    * P one bit, present flag, if set to 1 this means the interrupt gatae is present.
    
In total the cpu can handle 256 interrupts, so you need to create an array of the structure above containing 256 elements: 

```C 
IDT_descript idt_table[256]; 
```

The layout of the idt table is specified by the following table: 

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


To correctly enable interrupts handling on our OS we need to do basically two steps:

* Populate an IDT vector
* Load it's address on a special register called IDTR

## Saving and restoring context

There are few things to keep in mind: 

* The first is that some exception contains also an error code and some not (the error code will be on the stack)
* Unfortunately the compiler is not helping us in this scenario, and it tries to optimize the code, so part of the exception handling has to be done using assembly
* In 64bit mode... the *PUSHA* instruction is gone :(
* Another difference (maybe in this case an improvement), registers pushed on the stack when passing the control to the handler now are always the same, no matter we are doing a privilege level change or not. 

So when passing the control to the handler the following registers are always pushed on the stack by the CPU: 

|        |
|--------|
| SS     |
| RSP    |
| RFLAGS |
| CS     |
| RIP    |

but we will need to save more stuff on the stuck while serving interrupts, or we could lose some important data on other registers that was being used by our kernel. 

What we want to save are the other registers that area not saved by the cpu. As mentioned above when we are in 32 bit mode we can easily use the PUSHA instruction, that pushes the content of all the general purpose registers on the stack, but unfortunately in 64 bit mode this instruction is gone so we need to do it manually. The registers to push are: _rax,rbx,rcx,rdx,rbp,rsi,rdi_ that are the 64bits equivalent of the 32 bit general purpose registers, but in addition the x86_64 architecture add a set of new registers that we need also to push: _r8,r9,r10,r11,r12,r13,r14,r15_. These registers must be popped on the stack just after we serve the the interrupt but in a reverse order, starting from last to the first. Again in 32 bits mode we can use the POPA instruction that is basically the opposite of pusha. But in 64 bits we need again to pop them one by one. 

So the first thing our interrupt handling routine does will be something like: 

```asm
    push rax
    push rbx
    push rcx
    push rdx
    push rbp
    push rsi
    push rdi
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
```

and then after serving the interrupt it will pop everything in reverse order: 

```asm
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rbp
    pop rdx
    pop rcx
    pop rbx
    pop rax
```

The order of the registers is not really important when pushing them, but what is important is that we pop them we do in reverse order.

## Misc Notes
If you want to halt the cpu, and interrupts are enabled, be sure to use `hlt` inside of a loop.
Otherwise when the cpu receives an interrupt, the halt flag will be cleared in order to execute the handler, 
and isn't restored. Therefore when you exit the interrupt, if not inside a loop, you'll start executing junk data after the halt!

What you're after:
```c
while(true)
    asm("hlt");
```

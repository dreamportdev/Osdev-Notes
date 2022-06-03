# Handling Interrupts
This is not a complete guide on how to handle interrupts, it assumes you already have an IDT setup and working in supervisor mode. This section is focused on handling interrupts when you have user mode programs executing.

On x86_64 there are two main structures involved in handling interrupts. The first is the IDT, which you should already be familiar with. The second is the task state segment (TSS). It's important to note that the TSS is mandatory for handling interrupts if any code is running outside of ring 0.

The TSS served a different purpose on x86, and was for *hardware task switching*. Since this proved to be slower than *software task switching*, it was removed in long-mode. The 32 and 64 bit TSS structures are very different and not compatible. Note that example below uses the `packed` attribute, as is always a good idea when dealing structures that are dealing with hardware directly. We want to ensure our compiler lays out the memory as we expect. A C version of the long mode TSS is given below:

```c
__attribute__((packed))
struct tss
{
    uint32_t reserved0;
    uint64_t rsp0;
    uint64_t rsp1;
    uint64_t rsp2;
    uint64_t reserved1;
    uint64_t ist1;
    uint64_t ist2;
    uint64_t ist3;
    uint64_t ist4;
    uint64_t ist5;
    uint64_t ist6;
    uint64_t ist7;
    uint64_t reserved2;
    uint16_t reserved3;
    uint16_t io_bitmap_offset;
};
```

The reserved fields should be left as zero (as per the manual), but the rest of the fields can be broken up into three groups:

- `rspX`: where `X` represents a cpu ring (0 = supervisor). When an interrupt occurs, the cpu switches the code selector to the selector in the IDT entry. Remember the CS register is what determines the current prilege level. If this new CS has a lower privilege level (lower = more privileged), the cpu will automatically switch to this stack before pushing the `iret` frame.
- `istX`: where `X` is a non-zero identifier. These are the IST (Interrupt Stack Table) stacks, and are used by the IST field in the IDT descriptors. If an IDT descriptor has non-zero IST field, the cpu will always load the stack in the corresponding IST field in the TSS. This is useful for some interrupts that can occur at any time, like a machine check or NMI, or if you do sensitive work in a specific interrupt and don't want to leak data afterwards.
- `io_bitmap_offset`: Works in tandem with the `IOPL` field in the flags register. If `IOPL` is less than the current privilege level, IO port access is not allowed (results in a #GP). Otherwise IO port accesses can allowed by setting a bit in a bitmap (cleared bits deny access). This field in the tss specifies where this bitmap is located in memory, as an offset from the base of the tss. If `IOPL` is zero, ring 0 can implicitly access all ports, and `io_bitmap_offset` will be ignored in all rings.

So with the exception of the IO bitmap, the TSS is just a way of switching stacks when interrupts happen. An interesting side effect of this is that (except for interrupts that use ISTs) if the cpu is already in ring 0 it will not switch stacks to handle interrupts. Meaning any data stored on the interrupt stack will be available to ring 0 code, something to keep in mind if code that's not the kernel (like drivers) in ring 0.

### Loading a TSS
Loading a TSS has three major steps. First we need to create an instance of the above structure in memory somewhere. Second we'll need to create a new GDT entry that points to our TSS structure. Third we'll use the GDT entry to load our TSS into the task register (`TR`).

The first step should be self explanatory, so we'll jump into the second step. The GDT entry we'll need to create is a special one, dedicated to loading our tss. Unlike most long mode descriptors, this one is 16-bytes! Although the upper 4 bytes are reserved and should be set to zero, the lower 48-bits are as follows:

| Bits  | Should Be Set To | Description                         |
|-------|------------------|-------------------------------------|
| 15:0  | 0xFFFF           | Represents the limit field for this segment. Ignored in long mode, but best set to max value in case you support compatability mode in the future.
| 31:16 | TSS address bits 15:0 | Contains the lowest 16 bits of the tss address. |
| 39:32 | TSS address bits 23:16 | Contains the next 8 bits of the tss address. |
| 47:40 | 0b10001001 | Sets the type of GDT descriptor, this magic value indicates it's a valid TSS descriptor. If you're curious as to how this value was created, see the manual or the section on the GDT. |
| 55:48 | 0b10000 | Additional fields for the TSS entry. This bit means the TSS is `available`, it's generally unused in long mode, but has some side effects if you enable compatability mode. |
| 63:56 | TSS address bits 31:24 | Contains the next 8 bits of the tss address. |
| 95:64 | TSS address bits 63:32 | Contains the upper 32 bits of the tss address. |

### Putting It All Together
Now that we have a TSS, lets review what happens when an interrupt occurs, and the cpu is in user mode:

- The cpu receives the interrupt, and finds the entry in the IDT.
- The cpu switches the CS register to the selector field in the IDT entry.
- If the new privilege is less than the old privilege, the cpu loads the new stack from the corresponding `rsp` field. E.g. if switching to ring 0, `rsp0` is loaded.
- The cpu pushes the iret frame onto the new stack.
- The cpu now jumps to the handler function stored in the IDT entry.
- Your interrupt handler runs.

### The TSS and SMP
Something to be aware of if you support multiple cores is that the TSS has no way of ensuring exclusivity. Meaning is core 0 loads the `rsp0` stack and begins to use it for an interrupt, and core 1 gets an interrupt it will also happily load `rsp0` from the same TSS. This ultimately leads to much hair pulling and confusing stack corruption bugs.

Since

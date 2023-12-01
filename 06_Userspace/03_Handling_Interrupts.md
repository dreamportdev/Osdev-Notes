# Handling Interrupts

This is not a complete guide on how to handle interrupts. It assumes we already have an IDT setup and working in supervisor mode, if don't refer the earlier chapter that covers how to set up an IDT and the basics of handling interrupts. This chapter is focused on handling interrupts when user mode programs are executing.

On `x86_64` there are two main structures involved in handling interrupts. The first is the IDT, which we should already be familiar with. The second is the task state segment (TSS). While the TSS is not technically mandatory for handling interrupts, once we leave ring 0 it's functionally impossible to handle interrupts without it.

## The Why

*Why is getting back into supervisor mode on x86_64 so long-winded?* It's an easy question to ask. The answer is a combination of two things: legacy compatibility, and security. The security side is easy to understand. The idea with switching stacks on interrupts is to prevent leaking kernel data to user programs. Since the kernel may process sensitive data inside of an interrupt, that data may be left on the stack. Of course a user program can't really know when it's been interrupted and there might be valuable kernel data on the stack to scan for, but it's not impossible. There have already been several exploits that work like this. So switching stacks is an easy way to prevent a whole class of security issues.

As for the legacy part? `X86` is an old architecture, oringinally it had no concept of rings or protection of any kind. There have been many attempts to introduce new levels of security into the architecture over time, resulting in what we have now. However for all that, it does leave us with a process that is quite flexible, and provides a lot of possibilities in how interrupts can be handled.

## The How

The TSS served a different purpose on `x86` (protected mode, not `x86_64`), and was for *hardware task switching*. Since this proved to be slower than *software task switching*, this functionality was removed in long-mode. The 32 and 64 bit TSS structures are very different and not compatible. Note that the example below uses the `packed` attribute, as is always a good idea when using structures that are dealing with hardware directly. We want to ensure our compiler lays out the memory as we expect. A `C` version of the long mode TSS is given below:

```c
typedef struct tss
{
    uint32_t reserved0;
    uint64_t rsp0;
    uint64_t rsp1;
    uint64_t rsp2;
    uint64_t reserved1;
    uint64_t reserved2;
    uint64_t ist1;
    uint64_t ist2;
    uint64_t ist3;
    uint64_t ist4;
    uint64_t ist5;
    uint64_t ist6;
    uint64_t ist7;
    uint64_t reserved3;
    uint16_t reserved4;
    uint16_t io_bitmap_offset;
}__attribute__((__packed__)) tss_t;
```

As per the manual, the reserved fields should be left as zero. The rest of the fields can be broken up into three groups:

- `rspX`: where `X` represents a cpu ring (0 = supervisor). When an interrupt occurs, the cpu switches the code selector to the selector in the _IDT_ entry. Remember the _CS_ register is what determines the current prilege level. If the new CS is a lower ring (lower value = more privileged), the cpu will switch to the stack in `rspX` before pushing the `iret` frame.
- `istX`: where `X` is a non-zero identifier. These are the _IST_ (Interrupt Stack Table) stacks, and are used by the IST field in the IDT descriptors. If an IDT descriptor has non-zero IST field, the cpu will always load the stack in the corresponding IST field in the TSS. This overrides the loading of a stack from an `rspX` field. This is useful for some interrupts that can occur at any time, like a machine check or NMI, or if you do sensitive work in a specific interrupt and don't want to leak data afterwards.
- `io_bitmap_offset`: Works in tandem with the `IOPL` field in the flags register. If `IOPL` is less than the current privilege level, IO port access is not allowed (results in a #GP). Otherwise IO port accesses can be allowed by setting a bit in a bitmap (cleared bits deny access). This field in the tss specifies where this bitmap is located in memory, as an offset from the base of the tss. If `IOPL` is zero, ring 0 can implicitly access all ports, and `io_bitmap_offset` will be ignored in all rings.

With the exception of the IO permissions bitmap, the TSS is all about switching stacks for interrupts. It's worth noting that if an interrupt doesn't use an _IST_, and occurs while the cpu is in ring 0, no stack switch will occur. Remember that the `rspX` stacks only used when the cpu switches from a less privileged mode. Setting the _IST_ field in an _IDT_ entry will always force a stack switch, if that's needed.

### Loading a TSS

Loading a TSS has three major steps. First we need to create an instance of the above structure in memory somewhere. Second we'll need to create a new _GDT_ descriptor that points to our TSS structure. Third we'll use that GDT descriptor to load our TSS into the task register (`TR`).

The first step should be self explanatory, so we'll jump into the second step.

The GDT descriptor we're going to create is a *system descriptor* (as opposed to the *segment descriptors* normally used). In long mode these are expanded to be 16 bytes long, however they're essentially the same 8-byte descriptor as protected mode, just with the upper 4 bytes of the address tacked on top. The last 4 bytes of system descriptors are reserved.
The layout of the TSS system descriptor is broken down below in the following table:

| Bits  | Should Be Set To | Description                         |
|--------|------------------|-------------------------------------|
| 15:0   | 0xFFFF           | Represents the limit field for this segment. |
| 31:16 | TSS address bits 15:0 | Contains the lowest 16 bits of the tss address. |
| 39:32  | TSS address bits 23:16 | Contains the next 8 bits of the tss address. |
| 47:40  | 0b10001001 | Sets the type of GDT descriptor, its DPL (bits 45:46) to 0, marks it as present (bit 47). Bit 44 (S) along with bits 40 to 43 indicate the type of descriptor. If curious as to how this value was created, see the  intel SDM manual or our section about the GDT.|
| 48:51 | Limit 16:9 | The higher part of the limit field, bits 9 to 16 |
| 55:52  | 0bG000A | Additional fields for the TSS entry. Where G (bit 55) is the granularity bit and A (bit 52) is a bit left available to the operating system. The other bits must be left as 0 |
| 63:56  | TSS address bits 31:24 | Contains the next 8 bits of the tss address. |
| 95:64  | TSS address bits 63:32 | Contains the upper 32 bits of the tss address. |
| 96:127 | Reserved | They should be left as 0. |

Yes, it's right a TSS descriptor for the GDT is 128 bits. This because we need to specify the 64 bit address containing the TSS data structure.

Now for the third step, we need to load the task register. This is similar to the segment registers, in that it has visible and invisible parts. It's loaded in a similar manner, although we use a dedicated instruction instead of a simple `mov`.

The `ltr` instruction (load task register) takes the byte offset into the GDT we want to load from. This is the offset of the TSS descriptor we created before. For the example below, we'll assume this descriptor is at offset `0x28`.

```x86asm
ltr $0x28
```

It's that simple! Now the cpu knows where to find our TSS. It's worth noting that we only need to reload the task register if the TSS has moved in memory. Ideally it should never move, and so should only be loaded once. If the fields of the TSS are ever updated, the CPU will use the new values the next time it needs them, no need to reload TR.

### Putting It All Together

Now that we have a TSS, lets review what happens when the cpu is in user mode, and an interrupt occurs:

- The cpu receives the interrupt, and finds the entry in the IDT.
- The cpu switches the CS register to the selector field in the IDT entry.
- If the new ring is less than the previous ring (lower = more privileged), the cpu loads the new stack from the corresponding `rsp` field. E.g. if switching to ring 0, `rsp0` is loaded. Note that the stack selector has not been updated.
- The cpu pushes the iret frame onto the new stack.
- The cpu now jumps to the handler function stored in the IDT entry.
- The interrupt handler runs on the new stack.

## The TSS and SMP

Something to be aware of if we support multiple cores is that the TSS has no way of ensuring exclusivity. Meaning if core 0 loads the `rsp0` stack and begins to use it for an interrupt, and core 1 gets an interrupt it will also happily load `rsp0` from the same TSS. This ultimately leads to much hair pulling and confusing stack corruption bugs.

The easiest way to handle this is to have a separate TSS per core. Now we can ensure that each core only accesses its own TSS and the stacks within. However we've created a new problem here: Each TSS needs its own entry in the GDT to be loaded, and we can't know how many cores (and TSSs) we'll need ahead of time.

There's a few ways to go about this:

- Each core has a separate GDT, allowing us to use the same selector in each GDT for that core's TSS. This option uses the most memory, but is the most straightforward to implement.
- Have a single GDT shared between all cores, but each core gets a separate TSS selector. This would require some logic to decide which core uses which selector.
- Have a single GDT and a single TSS descriptor within it. This works because the task register caches the values it loads from the GDT until it is next reloaded. Since the TR is never changed by the cpu, if we never change it ourselves, we are free to change the TSS descriptor after using it to load the TR. This would require logic to determine which core can use the TSS descriptor to load its own TSS. Uses the least memory, but the most code of the three options.

## Software Interrupts

On `x86(_64)` IDT entries have a 2-bit DPL field. The DPL (Descriptor Privilege Level) represents the highest ring that is allowed to call that interrupt from software. This is usually left to zero as default, meaning that ring 0 can use the `int` instruction to trigger an interrupt from software, but all rings higher than 0 will cause a general protection fault. This means that user mode software (ring 3) will always trigger a #GP instead of being able to call an interrupt handler.

While this is a good default behaviour, as it stops a user program from being able to call the page fault handler for example, it presents a problem: without the use of dedicated instructions (which may not exist), how do we issue a system call?

Fortunately the solution is less words than the question: Set the DPL field to 3.

Now any attempts to call an IDT entry with a `DPL < 3` will still cause a general protection fault. If the entry has `DPL == 3`, the interrupt handler will be called as expected. Note that the handler runs with the code selector of the IDT entry, which is kernel code, so care should be taken when accessing data from the user program. This is how most legacy system calls work, linux uses the infamous `int 0x80` as its system call vector.

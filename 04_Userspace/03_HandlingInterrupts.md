# Handling Interrupts
This is not a complete guide on how to handle interrupts, it assumes you already have an IDT setup and working in supervisor mode. This section is focused on handling interrupts when you have user mode programs executing.

On x86_64 there are two main structures involved in handling interrupts. The first is the IDT, which you should already be familiar with. The second is the task state segment (TSS). While the TSS is not technically mandatory for handling interrupts, it's functionally impossible to handle interrupts while non-ring 0 code is running on x86. Therefore it's the recommended approach.

### The Why
*Why is getting back into supervisor mode on x86_64 so long-winded?* It's an easy question to ask. The answer is a combination of two things: legacy compatibility, and security. The security side is easy to understand. The idea with switching stacks on interrupts is to prevent leaking kernel data to user programs. Since the kernel may process sensitive data inside of an interrupt, that data may be left on the stack. Of course a user program can't really know when it's been interrupted and there might be valuable kernel data on the stack to scan for, but it's not impossible. There have already been several exploits that work like this. So switching stacks is an easy way to prevent a whole class of security issues. 

As for why the process involves so many steps? X86 is an old architecture, oringinally it had no concept of rings or protection of any kind. There have been many attempts to introduce new levels of security into the architecture over time, resulting in what we have now. However for all that, it does leave us with a process that is quite flexible, and provides a lot of possibilities in how interrupts can be handled.

### The How
The TSS served a different purpose on x86 (protected mode, not x86_64), and was for *hardware task switching*. Since this proved to be slower than *software task switching*, this functionality was removed in long-mode. The 32 and 64 bit TSS structures are very different and not compatible. Note that example below uses the `packed` attribute, as is always a good idea when dealing structures that are dealing with hardware directly. We want to ensure our compiler lays out the memory as we expect. A C version of the long mode TSS is given below:

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

- `rspX`: where `X` represents a cpu ring (0 = supervisor). When an interrupt occurs, the cpu switches the code selector to the selector in the IDT entry. Remember the CS register is what determines the current prilege level. If the new CS is a lower ring (lower value = more privileged), the cpu will switch to the stack in `rspX` before pushing the `iret` frame.
- `istX`: where `X` is a non-zero identifier. These are the IST (Interrupt Stack Table) stacks, and are used by the IST field in the IDT descriptors. If an IDT descriptor has non-zero IST field, the cpu will always load the stack in the corresponding IST field in the TSS. This overrides the loading of a stack from an `rspX` field. This is useful for some interrupts that can occur at any time, like a machine check or NMI, or if you do sensitive work in a specific interrupt and don't want to leak data afterwards.
- `io_bitmap_offset`: Works in tandem with the `IOPL` field in the flags register. If `IOPL` is less than the current privilege level, IO port access is not allowed (results in a #GP). Otherwise IO port accesses can allowed by setting a bit in a bitmap (cleared bits deny access). This field in the tss specifies where this bitmap is located in memory, as an offset from the base of the tss. If `IOPL` is zero, ring 0 can implicitly access all ports, and `io_bitmap_offset` will be ignored in all rings.

So with the exception of the IO bitmap, the TSS is just a way of switching stacks when interrupts happen. An interesting side effect of this is that (except for interrupts that use ISTs) if the cpu is already in ring 0 it will not switch stacks to handle interrupts. Meaning any data stored on the interrupt stack will be available to ring 0 code, something to keep in mind if code that's not the kernel (like drivers) in ring 0. If you want to force a stack switch, even if interrupting ring 0 code, you can use the IST mechanism. ISTs are best used only when necessary though, as there's a fixed number of them. They're also x86_64 specific, meaning they're unavailable on other platforms, if that's important to you.

### Loading a TSS
Loading a TSS has three major steps. First we need to create an instance of the above structure in memory somewhere. Second we'll need to create a new GDT entry that points to our TSS structure. Third we'll use the GDT entry to load our TSS into the task register (`TR`).

The first step should be self explanatory, so we'll jump into the second step. 

The GDT entry we'll need to create is a special one, dedicated to loading our tss. Unlike most long mode descriptors, this one is 16-bytes! That's because the TSS descriptor is a *system descriptor*, which are expanded to 16 bytes in long mode, unlike segment descriptors (which remain 8 bytes long). Having said that, the upper 4 bytes of system descriptors are reserved, so it's essentially a 12-byte structure. The structure can be thought of as a normal protected mode system descriptor (8 bytes), with another 4 bytes added on top. This extra 4 bytes (32-bits) is the higher half of the address field. This allows the TSS to be located anywhere within the 64-bit memory space. The lower 48-bytes are as follows:

| Bits  | Should Be Set To | Description                         |
|-------|------------------|-------------------------------------|
| 15:0  | 0xFFFF           | Represents the limit field for this segment. Ignored in long mode, but best set to max value in case you support compatability mode in the future.
| 31:16 | TSS address bits 15:0 | Contains the lowest 16 bits of the tss address. |
| 39:32 | TSS address bits 23:16 | Contains the next 8 bits of the tss address. |
| 47:40 | 0b10001001 | Sets the type of GDT descriptor, this magic value indicates it's a valid TSS descriptor. If you're curious as to how this value was created, see the manual or the section on the GDT. |
| 55:48 | 0b10000 | Additional fields for the TSS entry. This bit means the TSS is `available`, it's generally unused in long mode, but has some side effects if you enable compatability mode. |
| 63:56 | TSS address bits 31:24 | Contains the next 8 bits of the tss address. |
| 95:64 | TSS address bits 63:32 | Contains the upper 32 bits of the tss address. |

Now for the third step, telling the cpu to load our TSS. As mentioned above, the TSS is stored in a special cpu register called the *task register* (TR). This register can be thought of like the segment registers (`CS`, `SS`, etc ...) in that we don't load it with a value directly. We give it a selector (byte offset) in the GDT, and the cpu will load the values stored in a descriptor into the register for us.

To load TR, we can do it using the `ltr` instruction. It only takes one operand, the selector we want to use. For the example below, we'll assume that our TSS descriptor is at offset 0x28 in the GDT.

```x86asm
#at&t syntax
ltr $0x28
```

It's that simple! Now the cpu knows where to find our TSS. It's worth noting that you only need to reload the task register if the TSS has moved in memory. Ideally your TSS should never move, and so should only be loaded once. Since the TSS is laid out in memory, if you ever update the values (changing the `rsp0` stack for example) the cpu will see those updated values when it needs them. 

### Putting It All Together
Now that we have a TSS, lets review what happens when an interrupt occurs, and the cpu is in user mode:

- The cpu receives the interrupt, and finds the entry in the IDT.
- The cpu switches the CS register to the selector field in the IDT entry.
- If the new ring is less than the previous ring (lower = more privileged), the cpu loads the new stack from the corresponding `rsp` field. E.g. if switching to ring 0, `rsp0` is loaded.
- The cpu pushes the iret frame onto the new stack.
- The cpu now jumps to the handler function stored in the IDT entry.
- Your interrupt handler runs on the new stack.

### The TSS and SMP
Something to be aware of if you support multiple cores is that the TSS has no way of ensuring exclusivity. Meaning is core 0 loads the `rsp0` stack and begins to use it for an interrupt, and core 1 gets an interrupt it will also happily load `rsp0` from the same TSS. This ultimately leads to much hair pulling and confusing stack corruption bugs.

The easiest way to handle this is to have a separate TSS per core. Now you can ensure that each core only accesses it's own TSS and the stacks within. However we've created a new problem here: Each TSS needs it's own entry in the GDT to be loaded, and we can't know how many cores (and TSSs) we'll need ahead of time.

There's a few ways to go about this:

- Each core has a separate GDT, allowing you to use the same selector in each GDT for that core's TSS. This option uses the most memory, but is the most straightforward to implement.
- Have a single GDT shared between all cores, but each core gets a separate TSS selector. This would require some logic to decide which core uses which selector.
- Have a single GDT and a single TSS descriptor within it. This works because the task register caches the values it loads from the GDT until it is next reloaded. Since the TR is never changed by the cpu, if we never change it ourselves, we are free to change the TSS descriptor after using it to load the TR. This would require logic to determine which core can use the TSS descriptor to load it's own TSS. Uses the least memory, but the most code of the three options.

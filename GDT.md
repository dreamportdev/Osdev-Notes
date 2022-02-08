# The Global Descriptor Table

## Overview

The GDT is an x86(_64) structure that contains a series of descriptors. In a general sense, each of these descriptors tell the cpu about different things it should do. To refer to a GDT descriptor a selector is used, which is simply the byte offset from the beginning of the GDT where that descriptor starts.

It's important to separate the idea of the bit-width of the cpu (16-bit, 32-bit, 64-bit) from the current mode (real mode, protected mode, long mode). Real mode is generally 16 bit, protected mode is generally 32 bit, and long mode is usually 64-bit, but this is not always the case. The GDT decides the bit-width (affecting how instructions are decoded, and how stack operations work for example), while CR0 and EFER affect the mode the cpu is in.

Most descriptors are 8 bytes wide, usually resulting in the selectors looking like the following:
- null descriptor: selector 0x0
- first descriptor: selector 0x8
- second descriptor: selector 0x10
- third descritor: selector 0x18
- etc ...

There is one exception to the 8-byte-per-descriptor rule, the TSS descriptor, which is used by the `ltr` instruction to load the task register with a task state segment. It's a 16-byte wide descriptor.

Usually these selectors are for code (CS) and data (DS, SS), which tell the cpu where it's allowed to fetch instructions from, and what regions of memory it can read/write to. There are other selectors, for example the first entry in the GDT must be all zeroes (called the null descriptor).

The null selector is mainly used for edge cases, and is usually treated as 'ignore segmentation', although it can lead to #GP faults if certain instructions are issued. Its usage only occurs with more advanced parts of x86, so you'll known to look out for it.

The code and data descriptors are what they sound like: the code descriptor tells the cpu what region of memory it can fetch instructions from, and how to interpret them. Code selectors can be either 16-bit or 32-bit, or if running in long mode 64-bit or 32-bit.

To illustrate this point, you could run 32 bit code in 2 ways:
- in long mode, with a compatability (32-bit) segment loaded. Paging is required to be used here as we're in long mode (4 or 5 levels used), and segmentation is also enabled due to compatability mode. SSE/SSE2 and various other long mode features are always available too.
- in protected mode, with a 32-bit segment loaded. Segmentation is mandatory here, and paging is optional (available as 2 or 3 levels). SSE/SSE2 is an optional cpu extension, and may not be supported.

### GDT Changes in Long Mode

Long mode throws away most of the uses of descriptors (segmentation), instead only using descriptors for determining the current ring to operate in (ring 0 = kernel with full hardware access, ring 3 = user, limimted access, rings 1/2 generally unused) and the current bit-width of the cpu.

The cpu treats all segments as having a base of 0, and an infinite limit. Meaning all of memory is visible from every segment.

## Terminology
- Descriptor: an entry in the GDT (can also refer to the LDT/local descriptor table, or IDT).
- Selector: byte offset into the GDT, refers to a descriptor.
- Segment: the region of memory described by the base address and limit of a descriptor.
- Segment Register: where the currently in use segments are stored.

The various segment registers:
- CS: Code selector, defines where instructions can be fetched from.
- DS: Data selector, where general memory access can happen.
- SS: Stack selector, where push/pop operations can happen.
- ES: Extra selector, intended for use with string operations, no specific purpose.
- FS: F selector, no specific purpose. Sys V ABI uses it for thread local storage.
- GS: G selector, no specific purpose. Sys V ABI uses it for process local storage, commonly used for cpu-local storage in kernels due to `swapgs` instruction.

Address types:
- Logical address: addresses the programmer deals with.
- Linear address: logical address after translation through segmentation (logical_address + selector_base).
- Physical address: linear address translated through paging, maps to an actual memory location in RAM.

It's worth noting if segmentation is ignored, logical and linear addresses are the same. <br>
If paging is disabled, linear and physical addresses are the same.

## Segmentation

Segmentation is a mechanism for separating regions of memory into code and data, to help secure operating systems and hardware against potential security issues, and simplifies running multiple processes.

How it works is pretty simple, each GDT descriptor defines a 'segment' in memory, using a base address and limit. 
When a descriptor is loaded into the appropriate segment register, it creates a window into memory with the specified permissions. All memory outside of this segment has no permissions (read, write, execute) unless specified by another segment.

The idea is to place code in one region of memory, and then create a descriptor with a base and limit that only expose that region of memory to the cpu. Any attempts to fetch instructions from outside that region will result in a #GP fault being triggered, and the kernel will intervene.

Accessing memory inside a segment is done relative to it's base. Lets say you have a segment with a base of 0x1000,
and some data in memory at address 0x1100.
The data would be accessed at address 0x100 (assuming the segment is the active DS), as addressed are translated as `segment_base + offset`. In this case the segment base is 0x1000, and the offset is 0x100.

Segments can also be explicitly referenced. To load something at offset 0x100 into the ES region, you can use `mov es:0x100, $rax`. This would perform the translation from logical address to linear address using ES instead of DS (the default for data), a common example is when an interrupt occurs while the cpu is in ring 3, it will switch to ring 0 and load the appropriate descriptors into the segment registers.

### Segment Registers

The various segment registers and their uses are outlined below. There are some tricks to load a descriptor from the GDT into a segment register. They can't be mov'd into directly, so you'll need to use a scratch register to change their value. The cpu will also automatically reload segment registers on certain events (see the manual for these). 

To load any of the data registers, use the following:
```
#at&t syntax

#example: load ds with the first descriptor
mov $0x8, %ax       #any register will do, ax is used for the example here
mov %ax, %ds

#example: load ss with second descriptor
mov $0x10, %ax
mov %ax, %ss
```

Changing CS (code segment) is a little trickier, as it can't be written to directly, instead it requires a far jump:
```
#at&t syntax

reload_cs:
    pop %rdi        #call instruction pushes return address on to stack, preserve it in rdi (or edi if 32 bit)
    push $0x8       #the code selector is 0x8 in this case (the first non-null descriptor in the GDT)
    push %rdi       #the stack now looks like cs:rip, which is what a far jump expects.
    retfq           #pops the cs:rip from the stack, loads the new code segment, and begins executing at that address.
```

## Segmentation and Paging

When segmentation and paging are used together, segmentation is applied first, then paging.
The process of translation an address is as follows:
- Calculate linear address: `logical_address + segment_base`.
- Traverse paging structure for physical address, using linear address.
- Access memory at physical address.

## Segment Descriptors

There are various kinds of segment descriptors, they can be classified a sort of binary tree:

Is it a system descriptor? If yes, it's a TSS, IDT (not valid in GDT), or gate-type descriptor (unused in long mode, should be ignored).
If no, it's a code or data descriptor.

These are further distinguished with the `type` field, as outlined below.

| Start (in bits) | Length (in bits) | Description |
|----------------|------------------|-------------|
| 0 | 16 | Limit bits 15:0 |
| 15 | 16 | Base address bits 15:0 |
| 32 | 8 | Base address bits 23:16 |
| 40 | 4 | Selector type |
| 44 | 1 | Is system-type selector |
| 45 | 2 | DPL: code ring that is allowed to use this descriptor |
| 47 | 1 | Present bit. If not set, descriptor is ignored |
| 48 | 4 | Limit bits 19:16 |
| 52 | 1 | Available: for use with hardware task-switching. Can be left as zero |
| 53 | 1 | Long mode: set if descriptor is for long mode (64-bit) |
| 54 | 1 | Misc bit, depends on exact descriptor type. Can be left cleared in long mode |
| 55 | 1 | Granularity: if set, limit is interpreted as 0x1000 sized chunks, otherwise as bytes |
| 56 | 8 | Base address bits 31: 4 |

For system-type descriptors, it's best to consult the manual, the Intel SDM volume 3A chapter 3.5 has the relevent details.

For non-system descriptor types, the MSB (bit 3) is set for code descriptors, and cleared for data descriptors.
The LSB (bit 0) is a flag for the cpu to communicate to the OS that the descriptor has been accessed in someway, but this feature is mostly abandoned, and should not be used.

For a data selector, the remaining two bits are: expand-down (bit 2) - causes the limit to grow downwards, instead of up. Useful for stack selectors. Write-allow (bit 1), allows writing to this region of memory. Region is read-only if cleared.

For a code selector, the remaining bits are: Conforming (bit 2) - a tricky subject to explain. Allow user code to run with kernel selectors under certain circumstances, best left cleared. Read-allow (bit 1), allows for read-only access to code for accessing constants stored near instructions. Otherwise code cannot be read as data, only for instruction fetches.

## Using the GDT

All the theory is great, but how to apply it? 
A simple example is outline just below, for a simple 64-bit long mode setup you'd need
- Selector 0x00: null
- Selector 0x08: kernel code (64-bit, ring 0)
- Selector 0x10: kernel data (64-bit)
- Selector 0x18: user code (64-bit, ring 3)
- Selector 0x20: user data (64-bit)

To populate these entries, we'll use the following:
```c
uint64_t gdt_entries[];

// null descriptor, required.
gdt_entries[0] = 0ul;

//kernel code
uint32_t kernelCodeFlags = 0;
kernelCodeFlags |= 0b1011 << 8;     /* bit 4 says this is a code segment (not a data segment).
                                    bits 0/1/2 are accessed (ignore this), read-allow and conforming bits.
                                    a conforming segment allows for priviledged code to run in lower priviledged rings,
                                    this is a complex area that gets messy rather quickly.
                                    so we'll go with non-conforming for now. This'll result in a #GP fault instead. */

kernelCodeFlags |= (1 << 12);       //its a code/data (not a 'system') descriptor.
kernelCodeFlags |= (0 << 13);       //DPL, or what ring can use this segment. In this case its ring 0.
kernelCodeFlags |= (1 << 15);       //set present bit, lets the cpu know this descriptor is valid
kernelCodeFlags |= (1 << 21);       //it's a long-mode segment
kernelCodeFlags |= (1 << 23);       //when set limit is in 0x1000 units, otherwise interpreted as bytes. Not necessary to set this, easy to forget it later though.
//lowest and highest 8 bytes of flags are parts of limit and 
gdt_entries[1] = kernelCodeFlags << 32;     //lowests 32 bits are base/offset, ignored in long mode

uint32_t kernelDataFlags = 0;
kernelDataFlags |= 0b0011 << 8;     //similar to above, bit 4 is now cleared to indicate this is a data segment.
                                    //bits 0/1/2 are accessed (again, ignore), write-enable, expand-down flags.
                                    //expand-down is useful for stack segments that might increase their limit overtime.
                                    //it indicates that the limit should be subtracted from the base, rather than added.
kernelCodeFlags |= (1 << 12);       //see above for these fields, they're unachanged
kernelCodeFlags |= (0 << 13); 
kernelCodeFlags |= (1 << 15); 
kernelCodeFlags |= (1 << 21); 
kernelCodeFlags |= (1 << 23); 
gdt_entries[2] = kernelDataFlags << 32;

kernelCodeFlags |= (3 << 13); //set DPL to ring 3 (user)
gdt_entries[3] = kernelCodeFlags  << 32; //the rest of the flags remain the same

kernelDataFlags |= (3 << 13); //see above
gdt_entries[4] = kernelDataFlags << 32;
```

A more complex example of a GDT is the one used by the stivale2 boot protocol:
- Selector 0x00: null
- Selector 0x08: kernel code (16-bit, ring 0)
- Selector 0x10: kernel data (16-bit)
- Selector 0x18: kernel code (32-bit, ring 0)
- Selector 0x20: kernel data (32-bit)
- Selector 0x28: kernel code (64-bit, ring 0)
- Selector 0x30: kernel data (64-bit)

To load a new GDT, use the `lgdt` instruction. It takes the address of a GDTR struct, a complete example can be seen below:
```c
uint64_t gdt_entries[]; //populate this as you will

//packed is required here, otherwise the compiler will insert padding, resulting in the cpu getting bad data.
__attribute__((packed))
struct GDTR
{
    uint16_t limit;
    uint64_t address;
};

GDTR exampleGdtr = 
{
    .limit = 5 * sizeof(uint64_t); //assuming we have 5 gdt entries, like the first example setup.
    .address = (uint64_t)gdtEntries;
};

void load_and_flush_gdt()
{
    /*
        We use inline assembly to load the gdtr we created above. 
        the "m" constraint says that its argument must be a memory address (pointer). 
        The compiler will pass in the address of our exampleGdtr from above to satisfy this.
        If you're not familiar with gcc's extended inline asm, %0 means the first arg, which is what "m"() represents.
    */
    asm("lgdt %0" : : "m"(exampleGdtr));

    /*  A number of assumptions are made in the following code:
        - Kernel data selector is 0x10, and kernel code is 0x8. Change this for your system if using a different setup.
        - a call instruction was used to get here, we need the return address to be sitting on the top of the stack.
            - most compilers do this, so not much to worry about. Just be aware of it if calling from assembly.

        The first part of the code below updates the data segment registers with our new data segment.
        The second part turns the existing return address into a far return, to reload the CS register.
    */
    asm("\
            mov $0x10, %ax \n\
            mov %ax, %ds \n\
            mov %ax, %es \n\
            mov %ax, %fs \n\
            mov %ax, %gs \n\
            mov %ax, %ss \n\
            \n\
            pop %rdi \n\
            push $0x8 \n\
            push %rdi \n\
            lretq \n\
        ");

    //at this point we've successfully installed our new gdt, and reloaded the segment registers.
}
```

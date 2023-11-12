# The Global Descriptor Table

## Overview

The GDT is an `x86(_64)` structure that contains a series of descriptors. In a general sense, each of these descriptors tell the cpu about different things it should do. To refer to a GDT descriptor a selector is used, which is simply the byte offset from the beginning of the GDT where that descriptor starts *OR*ed with the ring that selector refers to. The *OR* operation is necessary for legacy reasons, but these mechanisms still exist.

It's important to separate the idea of the bit-width of the cpu (16-bit, 32-bit, 64-bit) from the current mode (real mode, protected mode, long mode). Real mode is generally *16 bit*, protected mode is generally *32 bit*, and long mode is usually *64 bit*, but this is not always the case. The GDT decides the bit-width (affecting how instructions are decoded, and how stack operations work for example), while CR0 and EFER affect the mode the cpu is in.

Most descriptors are 8 bytes wide, usually resulting in the selectors looking like the following:

- null descriptor: selector 0x0
- first descriptor: selector 0x8
- second descriptor: selector 0x10
- third descritor: selector 0x18
- etc ...

There is one exception to the 8-byte-per-descriptor rule, the TSS descriptor, which is used by the `ltr` instruction to load the task register with a task state segment. It's a 16-byte wide descriptor.

Usually these selectors are for code (CS) and data (DS, SS), which tell the cpu where it's allowed to fetch instructions from, and what regions of memory it can read/write to. There are other selectors, for example the first entry in the GDT must be all zeroes (called the null descriptor).

The null selector is mainly used for edge cases, and is usually treated as 'ignore segmentation', although it can lead to #GP faults if certain instructions are issued. Its usage only occurs with more advanced parts of x86, so we'll known to look out for it.

The code and data descriptors are what they sound like: the code descriptor tells the cpu what region of memory it can fetch instructions from, and how to interpret them. Code selectors can be either 16-bit or 32-bit, or if running in long mode 64-bit or 32-bit.

To illustrate this point, is possible to run 32 bit code in 2 ways:
- in long mode, with a compatability (32-bit) segment loaded. Paging is required to be used here as we're in long mode (4 or 5 levels used), and segmentation is also enabled due to compatability mode. SSE/SSE2 and various other long mode features are always available too.
- in protected mode, with a 32-bit segment loaded. Segmentation is mandatory here, and paging is optional (available as 2 or 3 levels). SSE/SSE2 is an optional cpu extension, and may not be supported.

### GDT Changes in Long Mode

Long mode throws away most of the uses of descriptors (segmentation), instead only using descriptors for determining the current ring to operate in (_ring 0 = kernel_ with full hardware access, _ring 3 = user_, limited access, rings 1/2 generally unused) and the current bit-width of the cpu.

The cpu treats all segments as having a base of 0, and an infinite limit. Meaning all of memory is visible from every segment.

## Terminology

- _Descriptor_: an entry in the GDT (can also refer to the LDT/local descriptor table, or IDT).
- _Selector_: byte offset into the GDT, refers to a descriptor. The lower 3 bits contain some extra fields, see below.
- _Segment_: the region of memory described by the base address and limit of a descriptor.
- _Segment Register_: where the currently in use segments are stored. These have a visible portion (the selector loaded), and an invisible portion which contains the cached base and limit fields.

The various segment registers:

- _CS_: Code selector, defines where instructions can be fetched from.
- _DS_: Data selector, where general memory access can happen.
- _SS_: Stack selector, where push/pop operations can happen.
- _ES_: Extra selector, intended for use with string operations, no specific purpose.
- _FS_: F selector, no specific purpose. Sys V ABI uses it for thread local storage.
- _GS_: G selector, no specific purpose. Sys V ABI uses it for process local storage, commonly used for cpu-local storage in kernels due to `swapgs` instruction.

When using a selector to refer to a GDT descriptor, we'll also need to specify the ring we're trying to access. This exists for legacy reasons to solve a few edge cases that have been solved in other ways. If we will need to use these mechanisms, we'll know, otherwise the default (setting to zero) is fine.

A _segment selector_ contains the following information:

* `index` bits 15-3: is the GDT selector.
* `TI` bit 2: is the Table Indicator if clear it means GDT, if set it means LDT, in our case we can leave it to 0.
* `RPL` bits 1 and 0:  is the Requested Priivlege Level, it will be explained later.


Constructing a segment selector is done like so:

```c
uint8_t is_ldt_selector = 0;
uint8_t target_cpu_ring = 0;
uint16_t selector = byte_offset_of_descriptor & ~(uint16_t)0b111;
selector |= (target_cpu_ring & 0b11);
selector |= ((is_ldt_selector & 0b1) << 2);
```

The `is_ldt_selector` field can be set to tell the cpu this selector references the LDT (local descriptor table) instead of the GDT. We're not interested in the LDT, so we will leave this as zero. The `target_cpu_ring` field (called RPL in the manuals), is used to handle some edge cases. This is best set to the same ring the selector refers to (if the selector is for ring 0, set this to 0, if the selector is for ring 3, set this to 3).

It's worth noting that in the early stages of the kernel we only be using the GDT and kernel selectors, meaning these fields are zero. Therefore this calculation is not necessary, we can simply use the byte offset into the GDT as the selector.

This is also the first mention of the LDT (local descriptor table). The LDT uses the same structure as the GDT, but is loaded into a separate register. The idea being that the GDT would hold system descriptors, and the LDT would hold process-specific descriptors. This tied in with the hardware task switching that existed in protected mode. The LDT still exists in long mode, but should be considered deprecated by paging.

Address types:

- _Logical address_: addresses the programmer deals with.
- _Linear address_: logical address after translation through segmentation (logical_address + selector_base).
- _Physical address_: linear address translated through paging, maps to an actual memory location in RAM.

It's worth noting if segmentation is ignored, logical and linear addresses are the same.

If paging is disabled, linear and physical addresses are the same.

## Segmentation

Segmentation is a mechanism for separating regions of memory into code and data, to help secure operating systems and hardware against potential security issues, and simplifies running multiple processes.

How it works is pretty simple, each GDT descriptor defines a _segment_ in memory, using a base address and limit.
When a descriptor is loaded into the appropriate segment register, it creates a window into memory with the specified permissions. All memory outside of this segment has no permissions (read, write, execute) unless specified by another segment.

The idea is to place code in one region of memory, and then create a descriptor with a base and limit that only expose that region of memory to the cpu. Any attempts to fetch instructions from outside that region will result in a #GP fault being triggered, and the kernel will intervene.

Accessing memory inside a segment is done relative to its base. Lets say we have a segment with a base of `0x1000`,
and some data in memory at address `0x1100`.
The data would be accessed at address `0x100` (assuming the segment is the active DS), as addressed are translated as `segment_base + offset`. In this case the segment base is `0x1000`, and the offset is `0x100`.

Segments can also be explicitly referenced. To load something at offset 0x100 into the ES region, an instruction like `mov es:0x100, $rax` can be used. This would perform the translation from logical address to linear address using ES instead of DS (the default for data), a common example is when an interrupt occurs while the cpu is in ring 3, it will switch to ring 0 and load the appropriate descriptors into the segment registers.

### Segment Registers

The various segment registers and their uses are outlined below. There are some tricks to load a descriptor from the GDT into a segment register. They can't be mov'd into directly, so we'll need to use a scratch register to change their value. The cpu will also automatically reload segment registers on certain events (see the manual for these).

To load any of the data registers, use the following:

```x86asm
#example: load ds with the first descriptor
#any register will do, ax is used for the example here
mov $0x8, %ax
mov %ax, %ds

#example: load ss with second descriptor
mov $0x10, %ax
mov %ax, %ss
```

Changing CS (code segment) is a little trickier, as it can't be written to directly, instead it requires a far jump. Or in this case, a far return which performs the same job, it just get its values from the stack instead of from immediate operands.

```x86asm
reload_cs:
    pop %rdi
    push $0x8
    push %rdi
    retfq
```

In the above example we take advantage of the `call` instruction pushing the return address onto the stack before jumping. To reload `%cs` we'll need an address to jump to, so we'll use the saved address on the stack. We need to place the selector we want to load into `%cs` onto the stack *before* the return address though, so we'll briefly store it in `%rdi`, push our example code selector (0x8 in this - the implementation may differ), then push the return address back onto the stack.

We use `retfq` instead of `ret` because we want to do a *far* return, and we want to use the 64-bit (quadword) version of the instruction. Some assemblers have different syntax for this instruction, and it may be called `lretq`.

## Segmentation and Paging

When segmentation and paging are used together, segmentation is applied first, then paging.
The process of translation for an address is as follows:

- Calculate linear address: `logical_address + segment_base`.
- Traverse paging structure for physical address, using linear address.
- Access memory at physical address.

## Segment Descriptors

There are various kinds of segment descriptors, they can be classified a sort of binary tree:

Is it a system descriptor? If yes, it's a TSS, IDT (not valid in GDT), or gate-type descriptor (unused in long mode, should be ignored).
If no, it's a code or data descriptor.

These are further distinguished with the `type` field, as outlined below.

| Start (in bits) | Length (in bits) | Description                                           |
|:----------------|:-----------------|-------------------------------------------------------|
| 0               | 16               | Limit bits 15:0                                       |
| 15              | 16               | Base address bits 15:0                                |
| 32              | 8                | Base address bits 23:16                               |
| 40              | 4                | Selector type                                         |
| 44              | 1                | Is system-type selector                               |
| 45              | 2                | DPL: code ring that is allowed to use this descriptor |
| 47              | 1                | Present bit. If not set, descriptor is ignored        |
| 48              | 4                | Limit bits 19:16                                      |
| 52              | 1                | Available: for use with hardware task-switching. Can be left as zero |
| 53              | 1                | Long mode: set if descriptor is for long mode (64-bit) |
| 54              | 1                | Misc bit, depends on exact descriptor type. Can be left cleared in long mode |
| 55              | 1                | Granularity: if set, limit is interpreted as 0x1000 sized chunks, otherwise as bytes |
| 56              | 8                | Base address bits 31: 4                               |

For system-type descriptors, it's best to consult the manual, the Intel SDM volume 3A chapter 3.5 has the relevent details.

The _Selector Type_ is a multibit field, for non-system descriptor types, the MSB (bit 3) is set for code descriptors, and cleared for data descriptors.
The LSB (bit 0) is a flag for the cpu to communicate to the OS that the descriptor has been accessed in someway, but this feature is mostly abandoned, and should not be used.

For a data selector, the remaining two bits are: expand-down (bit 2) - causes the limit to grow downwards, instead of up. Useful for stack selectors. Write-allow (bit 1), allows writing to this region of memory. Region is read-only if cleared.

For a code selector, the remaining bits are: Conforming (bit 2) - a tricky subject to explain. Allow user code to run with kernel selectors under certain circumstances, best left cleared. Read-allow (bit 1), allows for read-only access to code for accessing constants stored near instructions. Otherwise code cannot be read as data, only for instruction fetches.

## Using the GDT

All the theory is great, but how to apply it?
A simple example is outline just below, for a simple 64-bit long mode setup we'd need

- Selector 0x00: null
- Selector 0x08: kernel code (64-bit, ring 0)
- Selector 0x10: kernel data (64-bit)
- Selector 0x18: user code (64-bit, ring 3)
- Selector 0x20: user data (64-bit)

To create a GDT populated with these entries we'd do something like the following:

```c
uint64_t gdt_entries[];

//null descriptor, required to be here.
gdt_entries[0] = 0;

uint64_t kernel_code = 0;
kernel_code |= 0b1011 << 8; //type of selector
kernel_code |= 1 << 12; //not a system descriptor
kernel_code |= 0 << 13; //DPL field = 0
kernel_code |= 1 << 15; //present
kernel_code |= 1 << 21; //long-mode segment

gdt_entries[1] = kernel_code << 32;
```

For the type field we used the magic value `0b1011`. Bits 0/1/2 are the accessed, read-enable and conforming bits. Conforming selectors are an advanced topic and best left disabled for now. Setting the accessed bit is a small optimization to save the cpu doing it, and the read-enable bit allows the cpu to fetch small bits of data from the instruction stream. This is the default that most compilers will assume, so it's best enabled.

All the flags we've been setting are actually in the *upper* 32-bits of the descriptor, so we left shift by 32 bits before we place the descriptor in the GDT. The lower 32-bits of the descriptor are the limit and part of the offset fields, which are ignored in long mode.

For the kernel data selector we'd doing something similar:

```c
uint64_t kernel_data = 0;
kernel_data |= 0b0011 << 8; //type of selector
kernel_data |= 1 << 12; //not a system descriptor
kernel_data |= 0 << 13; //DPL field = 0
kernel_data |= 1 << 15; //present
kernel_data |= 1 << 21; //long-mode segment
gdt_entries[2] = kernel_data << 32;
```

Most of this descriptor is unchanged, except for the type field. Bit 4 is cleared to indicate this is a data selector. Creating the user mode selectors is even more straightforward, as we'll reuse the existing descriptors and just update their DPL fields (bits 13 and 14).

```c
uint64_t user_code = kernel_code | (3 << 13);
gdt_entries[3] = user_code;

uint64_t user_data = kernel_data | (3 << 13);
gdt_entries[4] = user_data;
```

A more complex example of a GDT is the one used by the stivale2 boot protocol:

- Selector 0x00: null
- Selector 0x08: kernel code (16-bit, ring 0)
- Selector 0x10: kernel data (16-bit)
- Selector 0x18: kernel code (32-bit, ring 0)
- Selector 0x20: kernel data (32-bit)
- Selector 0x28: kernel code (64-bit, ring 0)
- Selector 0x30: kernel data (64-bit)

To load a new GDT, use the `lgdt` instruction. It takes the address of a GDTR struct, a complete example can be seen below. Note the use of the packed attribute on the GDTR struct. If not used, the compiler will insert padding meaning the layout in memory won't be what we expected.

```c
//populate these as you will.
uint64_t num_gdt_entries;
uint64_t gdt_entries[];

struct GDTR
{
    uint16_t limit;
    uint64_t address;
} __attribute__((packed));

GDTR example_gdtr =
{
    .limit = num_gdt_entries * sizeof(uint64_t) - 1;
    .address = (uint64_t)gdt_entries;
};

void load_gdt()
{
    asm("lgdt %0" : : "m"(example_gdtr));
}
```

If not familiar with inline assembly, check the appendix on using inline assembly in C. The short of it is we use the "m" constraint to tell the compiler that `example_gdtr` is a memory address. The `lgdt` instruction loads the new GDT, and all that's left is to reload the current selectors, since they're using cached information from the previous GDT. This is done in the function below:

```c
void flush_gdt()
{
    asm volatile("\
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
}
```

In this example we assume that the kernel code selector is 0x8, and kernel data is 0x10. If these are different in our GDT, change these accordingly.

At this point we've successfully changed the GDT, and reloaded all the segment registers!

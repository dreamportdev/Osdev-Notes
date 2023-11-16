# C Language useful information

## Pointer arithmetic

Memory Addresses are expressed using numbers, so pointers are basically numbers, that means that we can
do some basic arithmetic with them.

With pointers we have 4 basic operations that can be done: `++, +, --` and `-`

For example let's say that we have a variable **ptr** that points to an **uint32_t** location.

```C
uint32_t *ptr;
```

Now for our example let's assume that the base address of ptr is `0x2000`.

This means that we have a 32 bit integer, which is 4 bytes, stored at the address `0x2000`.

Let's see now how does the arithmetic operations above works:

* **ptr++**: increment the pointer to its next value, that is `1 * sizeof(uint32_t) = 4` bytes. That because the pointer is an `uint32_t`. If the pointer is a `char`, the next location is given by: `1 * sizeof(char) = 1` byte
* **ptr+a**, it increment the pointer of `a * sizeof(uint32_t) = a * 4` bytes
* **ptr--** and **ptr-a**: the same rule of the above cases apply for the decrement and subtraction.

The result of the arithmetic operation depends on the size of the variable the pointers point to, and the general rule is:

```c
x * sizeof(variable_type)
```

Pointers can be compared too, with the operators: `==, <=, >=, <, >`, of course the comparison is based  on the address contained in the pointer.

## Inline assembly

The inline assembly instruction has the following format:

```C
asm("assembly_template"
    : output_operand
    : input_operand
    : list of clobbered registers
)
```

* Every line of assembly code should terminate with: **;**
* Clobbered registers can usually be left empty. However if we use an instruction like `rdmsr` which places data in registers without the compiler knowing, we'll want to mark those are clobbered. If we specify eax/edx as output operands, the compiler is smart enough to work this out.
* One special clobber exists: "memory". This is a read/write barrier. It tells the compiler we've accessed memory other than what was specified as input/ouput operands. The cause of many optimization issues!
* For every operand type there can be more than one, in this case they must be comma separated.
* Every operand consists of a constraint and c expression pair. A constrait can also have a modifier itself
* Operands parameters are indicated with an increasing number prefixed by a %, so the first operand declared is %0, the second is %1, etc. And the order they appears in the output/input operands section represent their numbering

Below is the list of the constraint modifiers:

| Symbol |   Meaning               |
|--------|-------------------------|
|   =    | Indicates that this is an output operand, whatever was the previous value, it will be discarded and replaced with something else |
|   +    | It indicates that the operand is both read and written by the instruction. |
|   &    | It indicates that the opreand can be modified before the instruction completion. |
|   %    | It means that the instruction is commutative for this operand and the following, so the copiler may interchange the two opreands |

The constraints are many and they depends the architecture too. Usually they are used to specify where the value should be stored, if in registers or memory, for more details see the useful links section.

The list below contains some constraints that are worth an explanation:

* 0, 1, ..., 9 - when a constraint is a nuber, it is called a *matching_constraint*, and this means that the same use the same register in output as the corresponding input registers.
* m - this constraint indicates to use a memory operand supported by the architecture.
* a, b, c, etc. - The etters usually indicate the registers we want to use, so for example a it means rax (or eax or ax depending on the mode), b means rbx (or ebx or bx), etc.
* g - this consrtaint indicates that a general register, memory or immediate operand is used.
* r - it indicates that it is a register operand is allowed, provided that it is a general purpose register.

An example of an inline assembly instruction of this type is:

```C
asm("movl %2, %%rcx;"
        "rdmsr;"
        : "=a" (low), "=d" (high)
        : "g" (address)
    );
```

*Note here how eax and ecx are clobbered here, but since they're specified as outputs the compiler implicitly knows this.*

Let's dig into the syntax:

* First thing to know is that the order of operands is source, destination
* When a %% is used to identify a register, it means that it is an operand (its value is provided in the operand section), otherwise a single % is used.
* Every operand has it's own constraint, that is the letter in front of the variable referred in the oprand section
* If an operand is output then it will have a "=" in front of constraint (for example "=a")
* The operand variable is specified next to the constraint between bracket
* Even if the example above has only %2, we can say that: %0 is the low varible, %1 is high, and %2 is address.

It is worth mentioning that inline assembly syntax is the At&t syntax, so the usual rules for that apply, for example if we want to use immediate values in an instruction we must prefix them with the `$`, symbol so for example if we want to mov 5 into rcx register:

```C
asm("movl $5, %rcx;");
```

## C +(+) assembly together - Calling Conventions

Different C compilers feature a number of [calling conventions](https://en.wikipedia.org/wiki/X86_calling_conventions),
with different ones having different defaults. GCC and clang follow the system V abi (which includes the calling convention).
This details things like how arguments are passed to functions, how the stack is organised and other requirements.
Other compilers can follow different conventions (MSVC has its own one - not recommended for osdev though), and the calling convention
can be overriden for a specific function using attributes. Although this is not recommended as it can lead to strange bugs!

For x86 (32 bit), function calling convention is pretty simple. All arguments are passed on the stack, with the right-most (last arg),
being pushed first. Stack pushes are 32 bits wide, so smaller values are sign extended. Larger values are pushed as multiple 32 bit components.
Return values are left in `eax`, and functions are expected to be called with the `call` instruction, which pushes the current `rip` onto the stack,
so the callee can use `ret` to pop the saved instruction pointer, and return to caller function.
The callee function also usually creates a new 'stack frame' by pushing `ebp` onto the stack, and then setting `ebp = esp`.
The callee must undo this before returning. This allows things like easily walking a call stack, and looking at the local variables if we have debug info.
The caller is expected to save eax, ecx and edx if they have values stored there. All other functions are expected to be maintained by the callee function if used.

For x86_64 (64 bit), function calling is a little more complicated.
64 bit arguments (or smaller, signed extended values) are passed using `rdi, rsi, rdx, rcx, r8, r9` in that order (left to right).
Floating point or sse sized arguments have their own registers they get passed in, see the sys x x86_64 spec for that.
Any arguments that don't fit in the above registers are passed on the stack, right to left - like in 32 bit x86.

Like in x86, functions are expected to run by using the `call` instruction, which pushes the return instruction pointer onto the stack, so the callee can use `ret` to return.  The callee usually forms a stack frame here as well, however the spec also allows a 128 byte space known as the 'red zone'.
This area is reserved by the compiler for *stuff*. What it does here is unspecified, but its usually for efficiency purposes: i.e running smaller functions in this space without the need for a new stack frame. However this is best disabled in the compiler (using `-mno-red-zone`) as the cpu is unaware of this, and will run interrupt handlers inside of the red zone by accident.

### How to actually use this?
There's 2 parts:

To call c functions from assembly, we'll need to make use of the above info, making sure the correct values are they need to be.
It's worth noting that a pointer argument is just an integer that contains the memory address of what it's pointing to.
These are passed as integer args (registers, than the first if not enough space).

To call an assembly function from C is pretty straight forward. If our assembly function takes arguments in the way described above, we can define a c prototype marked as `extern`,
and call it like any other function. In this case it's worth respecting the calling convention, and creating a new stack frame (`enter/leave` instructions).
Any value placed in `eax/rax` will be returned from the c-function if it has a return type. It is otherwise ignored.

## Use of `volatile`
*__Note from the author of this section__: volatile is always a hot topic from c/c++ developers. The first page of any search involving it will usually have at least a few results like 'use of volatile considered harmful' thoroughly complaining about its existence.
The next page is usually filled with an equal number of results of blog posts by people complaining about the previous people's complaining, and so on.
I'm not interested in that, and instead will explain how I've found it a useful tool.*

### The Why
A bit of background on why it can be necessary first:

Compilers treat our program's source code as a description of what we want the executable to do. As long as the final executable affects external resources in the way that our code describes, the compiler's job is done. It makes certain promises about data layouts in memory (fields are always laid out in the order declared in source), but not about others (what data is cached, stored in a register or stored in cold memory). The exact code that actually runs on the cpu can be as different the compiler deems necessary, as long as the end result is as expected.

Suddenly there's a lot of uncertainties about where data is actually stored at runtime. For example a local variable is likely loaded from ram into a register, and than only accessed in the register for the duration of that chunk of code, before finally being written back to memory when no longer needed. This is done because registers have access times orders of magnitude faster than memory.

Some variables never even exist in memory, and are only stored in registers.

Caching then adds more layers of complexity to this. Of course we can invalidate cache lines manually, however we'll pretty quickly find ourselves fighting our compiler going this route. Best to stick to language constructs if we can.

## The How
`volatile` tells the compiler 'this variable is now observable behaviour', meaning it can still do clever tricks around this variable, but *at any point* the variable must exist in the exact state as described by the source code, in the expected location (ram, not a cpu register). Meaning that updates to the variable are written to memory immediately.

This removes a lot of options for both the compiler and cpu in terms of what they can do with this data, so it's best used with care, and only when needed.

## A Final Note
`volatile` is not always the best tool for a job. Sometimes it is, sometimes there are more precise, but platform specific, solutions to the job.

One example of a good place to use volatile is calibrating the local APIC timer on x86. This is usually done by using the PIT to determine how fast the APIC timer ticks. The usual way this is done is by starting both timers, and then stopping them both after a known number of PIT ticks had passed. Since we know the PITs frequency, we can calculate the APIC timer's frequency.

It would look something like this:
```c
#define APIC_CALIBRATE_MS 25

uint64_t pit_ticks;
//volatile uint64_t pit_ticks;

void pit_interrupt_handler()
{
    pit_ticks++;
    send_eoi();
}

void calibrate_apic_timer()
{
    [ ... ] //setup apic timer to max value, and setup pit to known frequency.

    unmask_pit_and_reset_ticks();
    while (pit_ticks < APIC_CALIBRATE_MS);
    stop_apic_timer();

    [ ... ] //now apic current count register can be used to determine apic timer frequency.
}
```

The issue with this example is that `pit_ticks` is being constantly accessed inside the loop, and we never modify it inside the loop (its modified in unrelated code, the interrupt handler). With optmizations enabled the compiler will deduce that `pit_ticks` will always be its initial value, and will always be its initial value of 0, therefore the loop is infinite. If we change the variable declaration to be `volatile uint64_t pit_ticks` the compiler assumes nothing, and that this variable can be modified at *any time*.

Therefore it must do a valid read from memory each time it accesses the variable. This causes the above code to work as expected, although with increased latency, as memory must be accessed each cycle of the loop.

*__Authors note:__ This is actually not technically true on more modern CPUs, as there are mechanisms for caches to talk to each other, and share fresh data without going to memory. See the MESI protocol. This skips the full roundtrip of going to memory and back.*

----

Another example would be an mmio based framebuffer on x86. Normally this results in a lot of smaller accesses, all nearby (think about drawing a line of pixels for example).
`volatile` could be used to ensure each write to the framebuffer actually happens, and is not cached in a register and written later. This would work perfectly fine, but it also limits the compiler's options.

However in this case, the platform has a built in solution to this problem: write-combine cache mode.

If unfamiliar with caching, each page can have a set of caching attributes applied to it. These are designed to greatly improve performance in certain situations, however they are specific in application.
One of these is write-combine. It works by queueing up writes to nearby areas of memory, until a buffer is full, and then flushing them to main memory in a single access. This is much faster than accessing main memory each write.

However if we're working with an older x86 cpu, or another platform, this solution is not available. Hence `volatile` would do the job.

### Useful Links

* [IBM inline assembly guide](https://www.ibm.com/docs/en/xl-c-and-cpp-linux/13.1.4?topic=compatibility-inline-assembly-statements) This is not gcc related, but the syntax is identical, and it contains useful and concise info on the constraintsa
* [Fedora Inline assembly list of constraints](https://dmalcolm.fedorapeople.org/gcc/2015-08-31/rst-experiment/how-to-use-inline-assembly-language-in-c-code.html#simple-constraints)

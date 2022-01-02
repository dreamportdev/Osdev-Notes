# C Language useful information

## Pointer arithmetic

Memory Addresses are expressed using numbers, so pointers are basically numbers, that means that we can 
do some basic arithmetic with them. 

With pointers we have 4 basic operations that can be done: ++, +, -- and - 

For example let's say that we have a variable **ptr** that points to an **uint32_t** location. 

```C
uint32_t *ptr;
```

Now for our example let's assume that the base address of ptr is 0x2000.

This means that we have a 32 bit integer, which is 4 bytes, stored at the address 0x2000.

Let's see now how does the arithmetic operations above works: 

* **ptr++**: increment the pointer to its next value, that is 1 * sizeof(uint32_t) = 4 bytes. That because the pointer is an uint32_t. If the pointer is a char, the next location is given by: 1 * sizeof(char) = 1 byte
* **ptr+a**, it increment the pointer of a * sizeof(uint32_t) = a * 4 bytes
* **ptr--** and **ptr-a**: the same rule of the above cases apply for the decrement and subtraction.

So basically the result of the arithmetic operation depends on the size of the variable the pointers point to, an the general rule is:

```c
x * sizeof(variable_type)
```

Pointers can be compared too, with the operators: ==, <=, >=, <.>, of course the comparison is based  on the address contained in the pointer. 
## Inline assembly  

The inline assembly instruction has the following format: 

```C
asm("assenmbly_template" 
    : output_operand
    : input_operand
    : list of clobbered registers
)
```

* Every line of assembly code should terminate with: **;&&
* Clobbered registers can be left empty, if done so the compiler optimizator will decide what to use.

An example of an inline assembly instruction of this type is: 

```C
asm("movl %2, %%ecx;" 
        "rdmsr;"
        : "=a" (low), "=d" (high)
        : "g" (address)
    );
```

Let's dig into the syntax: 

* First thing to know is that the order of opreands is source, destination
* When a %% is used to identify a register, it means that it is an operand (it's value is provided in the operand section), otherwise a sinle % is used.
* Every operand has it's own constraint, that is the letter in front of the variable referred in the oprand section
* If an operand is output then it will have a "=" in front of constraint (for example "=a")
* The operand variable is specified next to the constraint between brackets

## C +(+) assembly together - Calling Conventions

Different C compilers feature a number of [calling conventions](https://en.wikipedia.org/wiki/X86_calling_conventions),
with different ones having different defaults. GCC and clang follow the system V abi (which includes the calling convention).
This details things like how arguments are passed to functions, how the stack is organised and other requirements.
Other compilers can follow different conventions (MSVC has it's own one - not recommended for osdev though), and the calling convention
can be overriden for a specific function using attributes. Although this is not recommended as it can lead to strange bugs!

For x86 (32 bit), function calling convention is pretty simple. All arguments are passed on the stack, with the right-most (last arg),
being pushed first. Stack pushes are 32 bits wide, so smaller values are sign extended. Larger values are pushed as multiple 32 bit components.
Return values are left in `eax`, and functions are expected to be called with the `call` instruction, which pushes the current `rip` onto the stack, 
so the callee can use `ret` to pop the saved instruction pointer, and return to caller function.
The callee function also usually creates a new 'stack frame' by pushing `ebp` onto the stack, and then setting `ebp = esp`.
The callee must undo this before returning. This allows things like easily walking a call stack, and looking at the local variables if you have debug info.
The caller is expected to save eax, ecx and edx if they have values stored there. All other functions are expected to be maintained by the callee function if used.

For x86_64 (64 bit), function calling is a little more complicated. 
64 bit arguments (or smaller, signed extended values) are passed using `rdi, rsi, rdx, rcx, r8, r9` in that order (left to right).
Floating point or sse sized arguments have their own registers they get passed in, see the sys x x86_64 spec for that.
Any arguments that dont fit in the above registers are passed on the stack, right to left - like in 32 bit x86.

Like in x86, functions are expected to run by using the `call` instruction, which pushes the return instruction pointer onto the stack, so the callee can use `ret` to return.  The callee usually forms a stack frame here as well, however the spec also allows a 128 byte space known as the 'red zone'.
This area is reserved by the compiler for *stuff*. What it does here is unspecified, but its usually for efficiency purposes: i.e running smaller functions in this space without the need for a new stack frame. However this is best disabled in the compiler (using `-mno-red-zone`) as the cpu is unaware of this, and will run interrupt handlers inside of the red zone by accident.

### How to actually use this?
There's 2 parts: 

To call c functions from assembly, you'll need to make use of the above info, making sure the correct values are they need to be.
It's worth noting that a pointer argument is just an integer that contains the memory address of what it's pointing to. 
These are passed as integer args (registers, than the first if not enough space).

To call an assembly function from C is pretty straight forward. If your assembly function takes arguments in the way described above, you can define a c prototype marked as `extern`, 
and call it like any other function. In this case it's worth respecting the calling convention, and creating a new stack frame (`enter/leave` instructions).
Any value placed in `eax/rax` will be returned from the c-function if it has a return type. It is otherwise ignored.

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


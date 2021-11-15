# C Language useful information

## Pointer arithmetic

TBD

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


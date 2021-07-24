# Some information about NASM

## Macros

There are some cases where some assembly code is preferred/needed to do certain operations (i.e. interrupts handling). 

Nasm has a macro processor that supports conditional assembly, multi-level file inclusion, etc.  
Macros start with the '%' symbol. 

There are 2 types of macros: single line (defined with %define) and multiline defined with %macro. In this document we will se the multi-line macros. 

A multi-line macro is defined as follows: 

```nasm
%macro my_first_macro 1
	push ebp
	mov	ebp, esp
	sub esp %1
%endmacro
```

In order to be accessible from C the macro has a global label has to be added, so the macro above become: 

```nasm
%macro my_first_macro 1
[global my_first_macro_label_%1]
my_first_macro_label_%1:
	push ebp
	mov	ebp, esp
	sub esp %1
%endmacro
```

In the code above we can see few new things: 

* First we said the the label my_first_macro_label_%1 has to be set as global, this is pretty straightforward to understand
* the %1 in the label definition, let us create different label using the first parameter passed in the macro. 

So if now we add a new line with the following code: 

```nasm
my_first_macro 42
```

It creates the global label: *my_first_macro_label_42*, since it is global it will be visible also from our C code (of course if the files are linked) 

Basically defining a macro with nasm is similar to use C define statement, these special "instruction" are evaluated by nasm preprocessor, and transformed at compile time. 

So for example *my_first_macro 42* is transformed in the following statement: 

```nasm
my_first_macro_label_42:
	push ebp
	mov	ebp, esp
	sub esp 42
```


## Nasm macros from C 

In the asm code, if in 64bit mode, a call to *cld* is required before calling an external C function. 

So for example if we want to call the following function from C: 

```C
void my_c_function(unsigned int my_value){
	printf("My shiny function called from nasm worth: %d\n", my_value);
}
```

First thing is to let the compiler know that we want to reference an external function using, and then just before calling the function, add the instruction cld. 

Here an example:  

```nasm
[extern my_c_function]

; Some magic asm stuff that we don't care of...
mov rdi, 42
cld
call my_c_function
; other magic asm stuff that we don't care of...
```

As mentioned in the multiboot document, argument passing from asm to C in 64 bits is little bit different from 32 bits, so the first parameter of a C function is taken from *rdi* (followed by: rsi, rdx, rcx, r8, r9, then the stack), so the *mov rdi, 42* is setting the value of *my_value* parameter to 42.

The output of the printf will be then: 

```
My shiny function called from nasm worth: 42
```

## Struct declaration
Although there is no data structure types in asm, nasm provide a similar mechanism using macros. You can define a data structure in the following way:

```nasm
struc my_struct
	.firstfield:	resb1
	.secondfield:	resb2
endstruc
```

## About sizes

Variable sizes are alway important while programming, but while programming in asm even more important to understand how they works in assembly, and since there is no real type you can't rely on the variable type. 

The important things to know when dealing with assembly code: 
* when moving from memory to register, using the wrong register size will cause wrong value being loaded into the registry. Example: 
```nasm
mov rax, [memory_location_label]
```
is different from: 
```nasm
mov eax, [memory_location_label]
```

And it could potentially lead to two different values in the register. That because the size of rax is 8 bytes, while eax is only 4 bytes, so if we do a move from memory to register in the first case, the processor is going to read 8 memory locations, while in the second case only 4, and of course there can be differences (unless we are lucky enough and the extra 4 bytes are all 0s). 

This is kind of misleading if we usually do mostly register to memory, or value to register, value to memory, where the size is "implicit".

Probably it can be a trivial issue, but it took me couple of hours to figure it out!

## If statement
Maybe there are better ways i'm unaware of, but this is a possible solution to a complex if statement, for example if we have the following if we want to translate in C: 

```C
if ( var1==SOME_VALUE && var2 == SOME_VALUE2){
	//do something
}
```

In asm we can do something like the following: 

```asm
cmp [var1], SOME_VALUE
jne else_label
cmp [var2], SOME_VALUE2
jne .else_label
;here code if both conditions are true
.else_label:
   ;the else part
```

And in a similar way we can have a if statement with a logic OR: 

```C
if (var1 == SOME_VALUE  || var2 == SOME_VALUE){
	//do_something
}
```
it can be implemented in asm in something similar to:
```asm
cmp [var1], SOME_VALUE
je .true_branch
cmp [var2], SOME_VALUE
je .true_branch
.true_branch
jne .else_label
```
## Switch statement 

The usual switch statement in C:
```C
switch(variable){
	case X:
		//do something
		break;
	case Y:
		//do something
		break;
}
```

 can be rendered as: 
 
```asm
cmp [var1], SOME_VALUE
je .value1_case
cmp [var1], SOME_VALUE2
je .value2_case
cmp [var1], SOME_VALUE3
je .value3_case
.value1_case
	;do stuff for value1
	jmp .item_not_needed
.value2_case
	;do stuff for value2
	jmp	.item_not_needed
.value3_case:
	;do stuff for value3
.item_not_needed
	;rst of the code
```

## Data structures

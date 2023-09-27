# Some information about NASM

## Macros

There are some cases where writing some assembly code is preferred/needed to do certain operations (i.e. interrupts handling).

Nasm has a macro processor that supports conditional assembly, multi-level file inclusion, etc.
A macro start with the '%' symbol. 

There are two types of macros: _single line_ (defined with `%define`) and _multiline_ wrapped around `%macro` and `%endmacro`. In this paragraph we will explain the multi-line macros. 

A multi-line macro is defined as follows: 

```nasm
%macro my_first_macro 1
	push ebp
	mov	ebp, esp
	sub esp %1
%endmacro
```

A macro can be accessed from C if needed, in this case we need to add a global label to it, for example the macro above will become: 

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

* First we said the the label `my_first_macro_label_%1` has to be set as global, this is pretty straightforward to understand.
* the `%1` in the label definition, let us create different label using the first parameter passed in the macro. 

So if now we add a new line with the following code: 

```nasm
my_first_macro 42
```

It creates the global label: `my_first_macro_label_42`, and since it is global it will be visible also from our C code (of course if the files are linked) 

Basically defining a macro with nasm is similar to use C define statement, these special "instruction" are evaluated by nasm preprocessor, and transformed at compile time. 

So for example *my_first_macro 42* is transformed in the following statement: 

```nasm
my_first_macro_label_42:
	push ebp
	mov	ebp, esp
	sub esp 42
```

## Declaring Variables

In Nasm if we want to declare a "variable" initialized we can use the following directives: 

| Directive | Description                       | 
|-----------|-----------------------------------|
|    DB     | Allocate a byte                   |
|    DW     | Allocate 2 bytes (a word)         |
|    DD     | Allocate 4 bytes (a double word)  |
|    DQ     | Allocate 8 bytes (a quad word)    |

These directive are intended to be used for initialized variables. The syntax is: 

```nasm
single_byte_var:
	db	'y'
word_var:
	dw	54321
double_var:
	dd	-54321
quad_var:
	dq	133.463 ; Example with a real number
```

But what if we want to declare a string? Well in  this case we can use a different syntax for db: 

```nasm
string_var:
	db	"Hello", 10
```
What does it mean? We are simply declaring a variable (string_variable) that starts at 'H', and fill the consecutive bytes with the next letters. But what about the last number? It is just an extra byte, that represents the newline character. So what we are really storing is the string _"Hello\\n"_

Now what we have seen so far is valid for a variable that can be initialized with a value, but what if we don't know the value yet, but we want just to "label" it with a variable name? Well is pretty simple, we have equivalent directives for reserving memory: 

| Directive   | Description                     | 
|-------------|---------------------------------|
|    RESB     | Rserve a byte                   |
|    RESW     | Rserve 2 bytes (a word)         |
|    RESD     | Rserve 4 bytes (a double word)  |
|    RESQ     | Rserve 8 bytes (a quad word)    |

The syntax is similar as the previous examples: 

```nasm
single_byte_var:
	resb	1
word_var:
	resw	2
double_var:
	resd	3
quad_var:
	resq	4
```

One moment! What are those number after the directives? Well it's pretty simple, they indicate how many bytes/word/dword/qword we want to allocate. In the example above: 
* `resb 1` Is reserving one byte
*  `resw 2` Is reserving 2 words, and each word is 2 bytes each, in total 4 bytes
*  `resd 3` Is reserving 3 dwords, again a dword is 4 bytes, in total we have 12 bytes reserved
*  `resq 4` Is reserving... well you should know it now... 

## Calling C from Nasm

In the asm code, if in 64bit mode, a call to *cld* is required before calling an external C function. 

So for example if we want to call the following function from C: 

```C
void my_c_function(unsigned int my_value){
	printf("My shiny function called from nasm worth: %d\n", my_value);
}
```

First thing is to let the compiler know that we want to reference an external function using `extern`, and then just before calling the function, add the instruction cld. 

Here an example:  

```nasm
[extern my_c_function]

; Some magic asm stuff that we don't care of...
mov rdi, 42
cld
call my_c_function
; other magic asm stuff that we don't care of...
```

As mentioned in the multiboot chapter, argument passing from asm to C in 64 bits is little bit different from 32 bits, so the first parameter of a C function is taken from `rdi` (followed by: `rsi`, `rdx`, `rcx`, `r8`, `r9`, then the stack), so the `mov rdi, 42` is setting the value of *my_value* parameter to 42.

The output of the printf will be then: 

```
My shiny function called from nasm worth: 42
```

## About Sizes

Variable sizes are always important while coding, but while coding in asm they are even more important to understand how they works in assembly, and since there is no real type you can't rely on the variable type. 

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

_Authors Note_: Probably it can be a trivial issue, but it took me couple of hours to figure it out!

## If Statement

Below an example showing a possible solution to a complex if statement. Let's assume that we have the following `if` statement in C and we want to translate in assembly: 

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

in asm it can be rendered with the following code

```asm
cmp [var1], SOME_VALUE
je .true_branch
cmp [var2], SOME_VALUE
je .true_branch
.true_branch
jne .else_label
```

## Switch Statement 

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

## Data Structures

Every language supports accessing data as a raw array of bytes, C provides an abstraction over this in the form of structs. NASM also happens to provide us with an abstraction over raw bytes, that is similar to how C does it.

This guide will just introduce quickly how to define a basic struct, for more information and use cases is better to check the netwide assembler official documentation (see the useful links section)

Let's for example assume we have the following C struct:

```c
struct task {
    uint32_t id;
    char name[8];
};
```

How nasm render a struct is basically declaring a list of offset labels, in this way  we can use them to access the field starting from the struct memory location (*Authors note: yeah it is a trick...*)
To create a struct in nasm we use the `struc` and `endstruc` keywords, and the fields are defined between them. 
The example above can be rendered in the following way:

```asm
struc task
    id:         resd    1
    name:       resb    8
endstruc
```

What this code is doing is creating three symbols: id as 0 representing the offset from the beginning of a task structure and name as 4 (still the offset) and the task symbol that is 0 too. This notation has a drawback, it defines the labels as global constants, so you can't have another struct or label declared with same name, to solve this problem you can use the following notation: 

```asm
struc task
    .id:    resd    1
    .name:  resb    8
endstruc
```

Now we can access the fields inside our struct in a familiar way: `struct_name.field_name`. What's really happening here is the assembler will add the offset of field_name to the base address of struct_name to give us the real address of this variable.

Now if we have a memory location or register that contains our structure, for example let's say that we have the pointer to our structure stored in the register rax and we want to copy the id field in the register rbx:

```nasm
mov rbx, dword [(rax + task.id)]
```

This is how to access a struct, besically we add the label representing an offset to its base address.
What if we want to create an instance of it? Well in this case we can use the macros `istruc` and `iend`, and using `at` to access the fields. For example if we want create an instance of task with the values 1 for the id field and "hello123" for the name field, we can use the following syntax: 

```asm
istruc task
    at id   dd  1
    at name db 'hello123'
iend
```

In this way we have declared a `struc`  for the first of the two examples. But again this doesn't work with the second one, because the labels are different. In that case we have to use the full label name (that means adding the prefix task):

```asm
istruc task
    at task.id      dd 1
    at task.name    db 'hello123'
iend
```

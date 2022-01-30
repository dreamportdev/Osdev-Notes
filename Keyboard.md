# Keyboard Driver

## IRQ and IO-Apic

* The Keyboard IRQ is the number 1. This is mapped to the IO Redirection Table 1, at offset 10h and 11h (called IOREDTBL1). 
* In order to enable the Keyboard IRQ, we need to unmask the mask bit on the IRQ Redirection Table, set an IDT entry as vector value, set the destination apic id.
* Refer to the APIC for details on the fields of a IO Redirection table

## Handling Keyboard interrutp

* When a key is pressed the scancode is made available on the keyboard buffer, and the IRQ handler is supposed to read it, if it is not done this prevent subsequents IRQs from the keyboard.
* The scancodes on the buffer can be read using IN/OUT assembly instructions at the port 0x60. The code will look like to something similar: 
```C
    int scancode = inb(0x60);
    do_something_with_the_scancode(scancode);
```
* An irq is raised when a key is pressed, and when it is released too. The bit #7 is 0 when the key is pressed, an 1 otherwise.

*To be Continued...*
### Useful Info

* https://wiki.osdev.org/PS/2_Keyboard 
* https://wiki.osdev.org/IRQ#From_the_keyboard.27s_perspective

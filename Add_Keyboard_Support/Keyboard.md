# Keyboard 

## Driver Information

The ps2 keyboards use two IO Ports for communication with the cpu: 

| IO Port | Access Type | Purpose                                                         |
|---------|-------------|-----------------------------------------------------------------|
|  0x60   | R/W         | Data Port                                                       | 
|  0x64   | R/W         | On read is the Status Register on write is the command register | 

* There are three different sets of scancodes, is a good idea to check with the keyboard what scancode is being used. 
* Usually the PS/2 controller (the one that the OS usually talks to using ports 0x60 and 0x64) convert set2 scancodes into set1 (for legacy reasons)
* To check if the translation is enabled, the command 0x20 must be sent on port 0x64, and then read the byte on 0x60. If the 6th bit is set than the translation is enabled. 
* If we want to disable the translation we need: 
   - Read current controller configuration byte, with the 0x20 command (the byte will be sent on port 0x60)
   - Clear the 6th on the current controller configuration byte
   - Send the command 0x60 (it says that next byte on data port has to be written as the controller configuration byte) on port 0x64, then send the updated configuration byte to port 0x60
* The only scancode set guaranted to be supported by keyboards is the set2. Keep in mind that most of the time the kernel communicate with the 8042_PS2 Controller, and in this case the scancodes can be translated into set1.

## Sending Commands to the keyboard

To send commands to the PS/2 Keyboard, we need to send the bytes directly to the Data Port (instead of the PS/2 controller command port). 

### Get/Set Keyboard Scancode set

The command to get/set the scancode set used by the controller is 0x60 followed by another byte: 

| Value | Description           |
|-------|-----------------------|
|   0   | Get current set       |
|   1   | Set scancode set 1    |
|   2   | Set scancode set 2    |
|   3   | Set scancode set 3    |

Now the keyboard reply with 2 bytes, if we are setting a new scancdoe set the reply will be: 0xFA 0xFE, if reading the current used set the response will be: 0xFA and the second byte value will be one of the followings:

| Value | Description       |
|-------|-------------------|
|   43  | Scancode set 1    |
|   41  | Scancode set 2    |
|   3f  | Scancode set 3    |

### About scancodes 

The scancode set is made by two types of codes: 

* MAKE code that is the scancode generated when a key is pressed 
* BREAK code is generated when a key is released.

The value of those code depends on the set in use.

... TODO: add how to distinguish between MAKE and break on each set. 

## IRQ and IO-Apic

* The Keyboard IRQ is the number 1. This corresponds to pin 1 on the IO Apic, that is controlled by entry 1 in Redirection Table, 
* The entry #1 of the redirection table is accessed as 2x32bit registers where the register number is defined as follows: 
```
redtbl_offset = 0x10 + (entry_number * 2)
```
in this case then we have the offset for our entry at:  12h and 13h (called IOREDTBL1), where 0x12 are the lower 32bits of the table entry. 
* In order to enable the Keyboard IRQ, we need to unmask the mask bit on the IRQ Redirection Table, set an IDT entry as vector value, set the destination apic id.
* Refer to the APIC for details on the fields of a IO Redirection table

## Handling Keyboard interrupt

* When a key is pressed the scancode is made available on the keyboard buffer, and the IRQ handler is supposed to read it, if it is not done this prevent subsequents IRQs from the keyboard.
* The scancodes on the buffer can be read using IN/OUT assembly instructions at the port 0x60. The code will look like to something similar: 
```C
    int scancode = inb(0x60);
    do_something_with_the_scancode(scancode);
```
An irq is raised when a key is pressed or released: 

* If using scancodes set 1: The bit #7 is 0 when the key is pressed, an 1 otherwise.
* If using scancodes set 2: When a key is released the data byte is prefixted by 0XF0
* Once the IRQ is served, remember to send an EOI to the LAPIC, writing 0x0 to the address: 0xFEE00B0

*To be Continued...*
### Useful Info

* https://wiki.osdev.org/PS/2_Keyboard 
* https://wiki.osdev.org/IRQ#From_the_keyboard.27s_perspective
* https://wiki.osdev.org/%228042%22_PS/2_Controller#Translation
* https://www.win.tue.nl/~aeb/linux/kbd/scancodes-10.html#scancodesets

# Handling the keyboard interrupt

Although we can use either PIC or IOAPIC to handle the Keyboard interrupt, for this section we will refer to the IOAPIC implementation, btw the only difference is how to configure the IRQ and send the EOI command, so if you are supporting the PIC most of the information in this guide will still be useful. 

## IRQ and IO-Apic

* The Keyboard IRQ is the number 1. This corresponds to pin 1 on the IO Apic, that is controlled by entry 1 in Redirection Table, 
* The entry #1 of the redirection table is accessed as 2x32bit registers where the register number is defined as follows: a

```
redtbl_offset = 0x10 + (entry_number * 2)
```

in this case then we have the offset for our entry at:  12h and 13h (called IOREDTBL1), where 0x12 are the lower 32bits of the table entry. 

Before unmasking the IRQ bit for the keyboard we need to implement a function (we can leave it empty for now) and set it into the IDT, for this section we will call the function `keyboard_irq_handler`:

```c
void keyboard_irq_handler() {

}
```
 
Then once the function on the IDT vector has been set, we need to unmask the mask bit on the IRQ Redirection Table, and set the destination apic id (Refer to the APIC for details on the fields of a IO Redirection table)


## Driver Information

The ps2 keyboards uses two IO Ports for communication with the cpu: 

| IO Port | Access Type | Purpose                                                         |
|---------|-------------|-----------------------------------------------------------------|
|  0x60   | R/W         | Data Port                                                       | 
|  0x64   | R/W         | On read is the Status Register on write is the command register | 

* There are three different sets of scancodes, is a good idea to check with the keyboard what scancode is being used. 
* Usually the PS/2 controller (the one that the OS usually talks to using ports 0x60 and 0x64) convert set2 scancodes into set1 (for legacy reasons)
* To check if the translation is enabled, the command 0x20 must be sent on port 0x64, and then read the byte on 0x60. If the 6th bit is set than the translation is enabled. 
* If we want to disable the translation we need: 
   - Read current controller configuration byte, with the 0x20 command (the byte will be sent on port 0x60)
   - Clear the 6th bit on the current controller configuration byte
   - Send the command 0x60 (it says that next byte on data port has to be written as the controller configuration byte) on port 0x64, then send the updated configuration byte to port 0x60
   - For our driver we will keep the translation enabled
* The only scancode set guaranted to be supported by keyboards is the set2. Keep in mind that most of the time the kernel communicate with the 8042_PS2 Controller, and in this case the scancodes can be translated into set1.


### Sending Commands to the keyboard

To send commands to the PS/2 Keyboard, we need to send the bytes directly to the Data Port (instead of the PS/2 controller command port). 

## Identifying the scancode set

As mentioned in the introduction to this section the first thing we need to know to implement our keyboard support is what is the scancode being used by our system and eventually do one of the following things:

* If we want to implement the support to all the three sets we will need to tell the driver what is the one being used by the keyboard
* Try to set the keyboard to use a scancode we support (not all keyboard support all the sets, but it worth a try)
* If we are supporting scancode set 1 we can first check if the translation bit is enabled on the PS2 controoler, and eventually  try to enable it, 
* Do nothing if it is the same set supported by our os

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

## Handling Keyboard interrupt

* When a key is pressed or released the scancode is made available on the keyboard buffer, and the IRQ handler is supposed to read it, if it is not done this prevent subsequents IRQs from the keyboard.
* The scancodes on the buffer can be read using IN/OUT assembly instructions at the port 0x60.  

```C
void keyboard_irq_handler() {
    int scancode = inb(0x60);
    //do_something_with_the_scancode(scancode);

    //Let's print the scancode we received for now
    printf("Scancode read: %s\n", scancode);
}

```

* If using scancodes set 1: The bit #7 is 0 when the key is pressed (MAKE), and 1 otherwise (BREAK)
* If using scancodes set 2: When a key is released the data byte is prefixed by 0XF0
* Once the IRQ is served, remember to send an EOI to the LAPIC, writing 0x0 to the address: 0xFEE00B0

Keep in mind that when we have multibyte scancodes (i.e. left ctrl, pause, and others) an irq is raised for every byte placed on the Data buffer.

*To be Continued...*


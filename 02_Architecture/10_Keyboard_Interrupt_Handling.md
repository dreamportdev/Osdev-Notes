# Handling The Keyboard Interrupt

Either the PIC or IOAPIC can be used to set up the keyboard irq. For this chapter we'll use the IOAPIC as it's more modern and the LAPIC + IOAPIC is the evolution of the PIC. However if using the PIC, most of the theory still applies, we'll need to adjust the irq routing code accordingly.

To keep the examples below simple, we'll assume only a single IOAPIC is present in the system. This is true for most desktop systems, and is only something to worry about in server hardware.

## IRQ and IOAPIC

* The ps/2 keyboard is irq 1, this corresponds to pin 1 on the IOAPIC meaning we'll be accessing redirect entry 1.
* Redirection entries are accessed as 2x 32-bit registers, where the register number is defined as follows:

```
redtbl_offset = 0x10 + (entry_number * 2)
```

In this case then we have the offset for our entry at: `0x12` and `0x13` (called IOREDTBL1 in the spec), where `0x12` is the lower 32-bits of the table entry.

Before unmasking the keyboard interrupt, we need an entry in the IDT, and a function (we can leave it empty for now) for the IDT entry to call. We will call the function `keyboard_irq_handler`:

```c
void keyboard_irq_handler() {

}
```

Once we have a valid IDT entry, we can clear the mask bit in the IOAPIC redirect entry for the ps/2 keyboard. Be sure that the destination LAPIC id is set to the cpu we want to handle the keyboard interrupts.
This id can be read from the LAPIC registers.


## Driver Information

The ps2 keyboard uses two IO ports for communication:

| IO Port | Access Type | Purpose                                                         |
|---------|-------------|-----------------------------------------------------------------|
|  0x60   | R/W         | Data Port                                                       |
|  0x64   | R/W         | On read: status register. On Write: command register            |

Since there are three different scancode sets, it's a good idea to check what set the keyboard is currently using.

Usually the PS/2 controller, the device that the OS is actually talking to on ports `0x60` and `0x64`, converts set 2 scancodes into set 1 (for legacy reasons).

We can check if the translation is enabled, by sending the command `0x20` on the command register (port `0x64`), and then read the byte returned on the data port (`0x60`). If the 6th bit is set than the translation is enabled.

We can disable the translation if we want, in that case we need to do the following steps:
   - Read current controller configuration byte, by sending command `0x20` to port `0x64` (the reply byte will be sent on port `0x60`).
   - Clear the 6th bit on the current controller configuration byte.
   - To send the modified config byte back to the controller, send the command `0x60` (to port `0x64`), then send the byte to port `0x60`.

For our driver we will keep the translation enabled, since we'll be using set 1.

The only scancode set guaranted to be supported by keyboards is the set 2. Keep in mind that most of the time the kernel communicate with a controller compatible with the intel 8042 PS2 controller. In this case the scancodes can be translated into set 1.


### Sending Commands To The Keyboard

This can look tricky, but when we are sending command to the PS2 Controller we need to use the port `0x64`, but if we want to send commands directly to the PS/2 keyboard  we need to send the bytes directly to the to the data port `0x60` (instead of the PS/2 controller command port).

## Identifying The Scancode Set

As mentioned in the introduction, what we'll need to know to implement our keyboard support is the scancode set being used by the system, and do one of the following things:

* If we want to implement the support to all the three sets we will need to tell the driver what is the one being used by the keyboard.
* Try to set the keyboard to use a scancode we support (not all keyboard support all the sets, but it worth a try).
* If we're supporting set 1, we can try to enable translation on the PS2 controller.
* Do nothing if it is the same set supported by our os.

The keyboard command to get/set the scancode set used by the controller is `0xF0` followed by another byte:

| Value | Description           |
|-------|-----------------------|
|   0   | Get current set       |
|   1   | Set scancode set 1    |
|   2   | Set scancode set 2    |
|   3   | Set scancode set 3    |

The command has to be sent to the device port (`0x60`), and reply will be composed by two bytes: if we are setting the scancode, the reply will be: `0xFA 0xFE`. If we are reading the current used set the response will be: `0xFA` followed by one of the below values:

| Value | Description       |
|-------|-------------------|
| 0x43  | Scancode set 1    |
| 0x41  | Scancode set 2    |
| 0x3f  | Scancode set 3    |

### About Scancodes

The scancode can be one of the following types:

* A MAKE code, generated when a key is pressed.
* A BREAK code, generated when a key is released.

The value of those code depends on the set in use.

For example if using scancode set 1, the BREAK code is composed by adding `0x80` to the MAKE code.

## Handling Keyboard Interrupts

When a key is pressed/released the keyboard pushes the bytes that make up the scancode into the ps2 controller buffer, then triggers an interrupt. We'll need to read these bytes, and assemble them into a scancode.
If it's a simple scancode, only 1 byte in length then we can get onto the next step.

```C
void keyboard_irq_handler() {
    int scancode = inb(0x60);
    //do_something_with_the_scancode(scancode);

    //Let's print the scancode we received for now
    printf("Scancode read: %s\n", scancode);
}

```

For set 1, the most significant bit of the scancode indicates whether it's a MAKE (MSB = 0) or BREAK (MSB = 1). If not clear why, the answer is pretty simple, the binary for `0x80` is `0b10000000`.
For set 2, a scancode is always a MAKE code, unless prefixed with the byte `0xF0`.

Keep in mind that when we have multibyte scancodes (i.e. left ctrl, pause, and others), an interrupt is raised for every byte placed on the data buffer, this means that we need to handle them within 2 different interrupt calls, this will be explained the next chapter, but for now we are fine with just printing the scancode received.

For now this function is enough and what we should expect from it is:

* If the key pressed use a single byte scancode, it will print only one line of the scancode read (the MAKE code).
* If it uses a multibyte scancode we will see two lines with two different scancodes, if using the set 1 the first byte is usually `0xE0`, the _extended_ byte (the MAKE codes).
* When a single byte key is released it will print a single line with the scancode read, this time will be the BREAK code.
* Again if it is a multibyte key to be released, we will have two lines with the scancode printed. one will still be `0xE0` and the other one is the BREAK code for the key.

As an exercise before implementing the full driver, could be interesting try to implement a logic to identify if the IRQ is about a key being _pressed_ or _released_ (remember it depends on the scancode set used).


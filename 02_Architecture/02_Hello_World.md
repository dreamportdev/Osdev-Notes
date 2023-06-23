# Hello World

During the development of our kernel we will need to debug a lot, and checking a lot of values, but so far our kernel is not capable of doing anything, and having proper video output with scrolling, fonts etc, can take some time, so we need a quick way of getting some text out from our kernel, not necessarily on the screen. 

This is where the serial logging came to an aid, we will use the serial port to output our text and numbers. 

Many emulators have an option to redirect serial data to a file, if we are using QEmu (for more information about it refer to the Appendices section) we need to start it passing the parameter `-serial file:filename`:

```bash
qemu -serial file:filename.log -cdrom yourosiso
```

This will save the serial output on the file called `filename.log`, if we want the serial output directly on the screen, we can use `stdio` instead.

## Printing to Serial

We will use the `inb` and `outb` instruction to communicate with the serial port. But the first thing our kernel should do is do is being able to write to serial ports. To do that we need: 

* for simiplicity and readability two C functions that will make use of the inb/outb asm instructions (luckily they are asm functions so making their c version is very easy)
* initialization of serial communication
* and at least an instruction to send characters and strings to the serial. 

The first step is pretty strightforward, using inline assembly we will create two "one-line" functions for inb and outb: 

```C
extern inline unsigned char inportb (int portnum)
{
  unsigned char data=0;
  __asm__ __volatile__ ("inb %%dx, %%al" : "=a" (data) : "d" (portnum));
  return data;
}

extern inline void outportb (int portnum, unsigned char data)
{
  __asm__ __volatile__ ("outb %%al, %%dx" :: "a" (data),"d" (portnum));
}

```

Where `portnum` is the number of port where we are sending our data (usually is 0x3f8 or 0xe9), and the data is the `char` we want to send in output. 

### Initialization

The second part is pretty simple, we just need to send few configuration command for initializing the serial communication, the code below is copied from https://wiki.osdev.org/Serial_Ports#Initialization:

```C
#define PORT 0x3f8          // COM1
 
static int init_serial() {
   outb(PORT + 1, 0x00);    // Disable all interrupts
   outb(PORT + 3, 0x80);    // Enable DLAB (set baud rate divisor)
   outb(PORT + 0, 0x03);    // Set divisor to 3 (lo byte) 38400 baud
   outb(PORT + 1, 0x00);    //                  (hi byte)
   outb(PORT + 3, 0x03);    // 8 bits, no parity, one stop bit
   outb(PORT + 2, 0xC7);    // Enable FIFO, clear them, with 14-byte threshold
   outb(PORT + 4, 0x0B);    // IRQs enabled, RTS/DSR set
   outb(PORT + 4, 0x1E);    // Set in loopback mode, test the serial chip
   outb(PORT + 0, 0xAE);    // Send a test byte
 
   // Check that we received the same test byte we sent
   if(inb(PORT + 0) != 0xAE) {
      return 1;
   }
 
   // If serial is not faulty set it in normal operation mode:
   // not-loopback with IRQs enabled and OUT#1 and OUT#2 bits enabled
   outb(PORT + 4, 0x0F);
   return 0;
}
```

Notice that usually the com1 port is mapped to address: *0x3f8*. The function above is setting just default values for serial communication. An alternative that does not require any initialization is to use the port `0xe9`, this is also know as the _debugcon_ or the _port e9 hack_ and it still use the `inportb` and `outportb` functions as they are, but is often faster because is a special port that sends data directly to the emulator console output. 

### Sending a string

Last thing to do is to create functions to print string/numbers on the serial. The idea is pretty simple, the current functions we created are handling single bytes/char, what we want is to send strings, so a good idea is to start with a function like: 

```c
void log_to_serial (char *string) {
    // Left as exercise
}
```

The input parameter for this function is a string, so what it will do is looping through the variable `string` and printing each character until the symbol `\0` (End Of String) is found.

This is the first function that we want to implement. 

### Printing Digits

Once we are able to print strings is time to print digits. The basic idea is simple, we read every single digit that compose the number, and print the corresponding character, luckily enough the digits symbols are consecutive in the ascii map, so for example: 

```c
'0' + 1 // will contain the symbol '1'
'0' + 5 // will contain the symbol '5'
```

How to get the single digits will depend on what base we are using (the most common are base 8, 10 and 16), let's assume we want for now just print decimals (base 10). 

To get decimal strings we will use a property of division by 10: _The remainder of any integer number divided by 10 is always the same as the least significant digit._

As an example consider the number 1235:  $1235/10=123.5$ and $1235 \mod 10=5$, remember that in C (and other programming languages) a division between integers will ignore any decimal digit, so this means that $1235/10=123$. And what if now we divide 123 by 10? yes we get 3 as remainder, below the full list of divisions for the number 1235:

* $1235/10 = 123$ and $1235 \mod 10 = 5$
* $123/10 = 12$ and $123 \mod 10 = 3$
* $12/10 = 1$ and $12 \mod10 = 2$
* $1/10 = 0$  and $1 \mod 10 = 1$

And as we can see we got all the digits in reverse order, so now the only thing we need to do is reverse the them. The implementation of this function should be now pretty straightforward, and it will be left as exercise. 

Printing other format like Hex or Octal is little bit different, but the base idea of getting the single number and converting it into a character is similar. The only tricky thing with the hex number is that now we have symbols for numbers between 10 and 15 that are characters, and they are before the digits symbol in the ascii map, but once that is known it is going to be just an if statement in our function. 
 
### Troubleshooting

If the output to serial is not working, there is no output in the log, try to remove the line that set the serial as loopback: 

```C
outb(PORT + 4, 0x1E);    // Set in loopback mode, test the serial chip 
```

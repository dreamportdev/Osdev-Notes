# Debugging

## Qemu Logging 

I think that in early stages of development, this can be a useful option especially when switching from VGA to framebuffer 
to print useful debug information. 

Qemu has an option to redirect serial output to a file, you need to start it passing the parameter *-s filename*:

```bash
qemu -S filename.log -cdrom yourosiso
```

Next thing to do is make our os able to write to serial ports. To do that you need: 

* inb/outb functions (luckily they are asm functions so making their c version is very easy)
* initialization of serial communication
* writing strings to serial. 

For first step, you just need to create the following one-line functions for inb and outb: 

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

The second again is pretty simple, not going into implementation details that are not part of this chapter.
The implementation of this function can be found here: https://wiki.osdev.org/Serial_Ports#Initialization 

The com1 port is mapped to address: *0x3f8*

Last thing to do is to create functions to print string/numbers on the serial. 
This is pretty similar to what has been done for I/O video functions, but in this case you send the text as it is 
using outb instead of writing it on a memory location. 

But probably a good idea is to reuse some of the code of the video functions to convert numbers into strings. 

## Dumping register on exception

If you are using qemu, a good idea is to dump registers when an exception occurs, you just need to add the following option to qemu command: 

```bash
qemu -d int
```

Sometime could be needed to avoid the emulator restart on triple fault, in this case to catch the "offending" exception, just add: 

```bash
qemu -d int -no-reboot
```

## GDB 

### Remote debugging

To connect with qemu/bochs host configure for remote debugging launch gdb, and type the following command in gdb cli: 

```bash
target remote localhost:1234
```

And then you can load the symbols (if you have compiled your os with debugging symbols): 

```bash
symbol-file path/to/kernel.bin
```

### Useful commands

* Show register content: *info register reg* where reg is the register we need
* Set breakpoint to specific address: *break 0xaddress*
* Show memory address content: *x/nfu addr* wher: n is the number of iterations f the format (x = hex) and the addr we want to show
* you can show also the content of pointer stored into a register: *x/h ($rax)* shows the content of memory address pointed by rax

## Useful resources

* https://wiki.osdev.org/Kernel_Debugging
* https://wiki.osdev.org/Serial_Ports
* https://en.wikibooks.org/wiki/QEMU/Debugging_with_QEMU

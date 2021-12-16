# Debugging

## Serial Logging 

I think that in early stages of development, this can be a useful option especially when switching from VGA to framebuffer 
to print useful debug information. 

Many emulaors has an option to redirect serial output to a file, you need to start it passing the parameter *-s filename*:

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

The second again is pretty simple, the code below is copied from https://wiki.osdev.org/Serial_Ports#Initialization:

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
   outb(PORT + 0, 0xAE);    // Test serial chip (send byte 0xAE and check if serial returns same byte)
 
   // Check if serial is faulty (i.e: not same byte as sent)
   if(inb(PORT + 0) != 0xAE) {
      return 1;
   }
 
   // If serial is not faulty set it in normal operation mode
   // (not-loopback with IRQs enabled and OUT#1 and OUT#2 bits enabled)
   outb(PORT + 4, 0x0F);
   return 0;
}
```

The com1 port is mapped to address: *0x3f8*

Last thing to do is to create functions to print string/numbers on the serial. 
This is pretty similar to what has been done for I/O video functions, but in this case you send the text as it is 
using outb instead of writing it on a memory location. 

But probably a good idea is to reuse some of the code of the video functions to convert numbers into strings. 

### Troubleshooting

If the output to serial is not working, there is no output in the log, try to remove the line that set the serial as loopback: 

```C
outb(PORT + 4, 0x1E);    // Set in loopback mode, test the serial chip 
```

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

## Virtual Box

### Virtualbox command line useful commands

* To list the available machine using command line use the following command:

```bash
vboxmanage list vms
```

It will show for every virtual machine, its label and its UUID

* To launch a VM from command line: 

```bash
virtualboxvm --startvm vmname
 ```

You can use either the Virtual Machine name, or its uuid. 
### Run a vm with debug enabled

To run a VM with debug you need two things: 

* The first one is either the VBOX_GUI_DBG_ENABLED or VBOX_GUI_DBG_AUTO_SHOW set to true 
* Launch the virtual machine with the --debug option: 

```bash
virtualboxvm --startvm vmname --debug
```

this will open the Virtual Machine with the Debugger command line and ui. 

## QEmu 

### Qemu monitor

Qemu monitor is a tool used to send complex commands to the qemu emulator, is useful to for example add/remove media images to the system, freeze/unfreeze the VM, and to inspect the state of the Virtual machine without using an external debugger. 

One way to start Qemu monitor on a unix system is using the following parameter when starting qemu: 

```bash
qemu-system-i386 [..other params..] -monitor unix:qemu-monitor-socket,server,nowait
```

then on another shell, on the same folder where you started the emulator launch the following command: 

```bash
socat -,echo=0,icanon=0 unix-connect:qemu-monitor-socket
``` 

This will prompt with a shell similar to the following: 

```bash
username@host:~/yourpojectpath/$ socat -,echo=0,icanon=0 unix-connect:qemu-monitor-socket
QEMU 6.1.0 monitor - type 'help' for more information
(qemu) 

``` 

From here you can send commands directly to the emulator, below a list of useful commands:

* **help** Well this is the first command to get some help on how to use the monitor
## Useful resources

* https://wiki.osdev.org/Kernel_Debugging
* https://wiki.osdev.org/Serial_Ports
* https://en.wikibooks.org/wiki/QEMU/Debugging_with_QEMU

# Debugging


## Dumping register on exception

If you are using qemu, a good idea is to dump registers when an exception occurs, you just need to add the following option to qemu command: 

```bash
qemu -d int
```

Sometime could be needed to avoid the emulator restart on triple fault, in this case to catch the "offending" exception, just add: 

```bash
qemu -d int -no-reboot
```

While debugging with gdb, we may want to keep qemu hanging after a triple fault (when the cpu should reset), to do some more investigation, in this case we need to add also `-no-shutdown` (along with) `-no-reboot`

### Start Qemu for remote Debugging

To start Qemu to accepts connections from gdb, you need to add *-s* and *-S*  flags to the command, where: 

* **-s** is a shortand for **-gdb tcp::1234** 
* **-S** instead tells the emulator to halt before starting the CPU, in this way you have time to connect the debugger before the OS start.

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

Below a list of some useful gdb commands 

* Show register content: *info register reg* where reg is the register we need
* Set breakpoint to specific address: *break 0xaddress*
* Show memory address content: *x/nfu addr* wher: n is the number of iterations f the format (x = hex) and the addr we want to show
* you can show also the content of pointer stored into a register: *x/h ($rax)* shows the content of memory address pointed by rax

### Navigation

* `c/continue` can be used to continue the program until the next breakpoint is reached.
* `fin/finish` will run until the end of the current function.
* `s/step` will run the next line of code, and if the next line is a function call, it will 'step into' it. This will leave you on the first line on the new function.
* `n/next` similar to step, but will 'step over' any function calls, treating them like the rest of the lines of code.
* `si/ni` step instruction/next instruction. These are like step and next, but work on instructions, rather than lines of code.

### Print and Examine memory

`p/print symbol` can be used to used to print almost anything that makes sense in your program.
Lets say you have an integer variable i, `p i` will disable what i currently is. This takes a c-like syntax, 
so if you print a pointer, gdb will simply tell you its address. To view it's contents you would need to use `p *i`, like in c.
`x address` is similar to print, but takes a memory address instead of a symbol.

Both commands accept 'format specifiers' which change the output. For example `p/x i` will print i, formatted as hexadecimal number.
There are a number of other ones `/i` will format the output as cpu instructions, `/u` will output unsigned, and `/d` signed decimal numbers.
`/c` will interpret an ASCII character, and `/s` will interpret it as a null terminated ASCII string (just a c string).

The format specifier can be prefixed with a number of repeats. For example if you wanted to examine 10 instructions at address 0x1234, you could do:
`x/10i 0x1234`, and gdb would show you that.


### How did I get here?

Here a collection of useful command to keep track of the call stack.

* `bt/backtrace/info stack` will show you the current call stack, with lower numbers meaning deeper (current breakpoint is stack frame 0).
* `up/down` can be used to move up and down the callstack.
* `frame x` will jump directly to frame number x (view frame numbers with `bt`)
* `info args` will display the arguments passed into the function. It's worth nothing that the first few instructions of a function set up the stack frame, 
so you may need to `si` a few times when entering a function for this to return correct values.
* `info locals` displays local variables (on the stack). Any variables that have no yet been declared in the source code will have junk values (keep this in mind!).
* `info variables` is similar to info global and static variables
* `info args` list the arguments of the current stack frame, name and values.

### Breakpoints

A breakpoint can be set in a variety of ways! The command is `b/break symbol`, where symbol can be a number of things:

* a function entry: `break init` or `break init()` will break at *any* function named init.
* a file/line number: `break main.c:42` will break just before the first instruction of line 42 (in main.c) is executed.
* an address in memory: `break 0x1234` will break whenever the cpu's next instruction is at address 0x1234. 

Breakpoints can be enabled/disabled at runtime with `enable x`/`disable x` where x is the breakpoint number (displayed when you first it it).

Breakpoints can also take conditions if you're trying to debug a commonly-run function. The syntax follows a c-like style, and is pretty forgiving.
For example: `break main if i == 0` would break at the function main() whenever the variable `i` is equal to 0.
This syntax supports all sorts of things, like casts and working with pointers.

Breakpoints can also be issued contextually too! If you're at a breakpoint `main.c:123`, you can simply use `b 234` to break at line 234 in the same file.

It is possible at any time to print the list of breakpoints using the command: `info breakpoint`

And finally breakpoints can be deleted as well using `delete [breakpoints]`

It's worth noting if you're debugging a kernel running with kvm, you wont be able to use software breakpoints (above) like normal. 
GDB does support hardware breakpoints using `hb` instead of `b` for above, although their functionality can be limited, depending on what the hardware supports.
Best to do serious debugging without kvm, and only use hardware debugging when absolutely necessary.

### TUI - Text User Interface
This area of gdb is hilariously undocumented, but still really useful. It can be entered in a number of ways:

* `layout xyz`, will drop into a 1 window tui with the specified data in the main window. This can be 'src' for the source code, 'regs' for registers, or 'asm' for assembly.
* Control-X + 1 will enter a 1 window tui, Control-X 2 will enter a 2 window tui. Pressing these will cycle window layouts. Trying is easier than explaining here!
* `tui enable` will do the same the first option, but defaults to asm layout. 

Tui layouts can be switched at any time, or you can return to your regular shell at any time using `tui disable`, or exiting gdb.

The layouts offer little interaction besides the usual terminal in/out, but can be useful for quickly referencing things, or examining exactly what instructions are running.

If you are using debian, you most-likely need to install the *gdb* package, because by default *gdb-minimal* is being installed, which doesn't contain the TUI.

Currently these are the type of tui layouts available in gdb:

* asm - shows the asm code being executed
* src - shows the actual source code line executed
* regs - shows the content of the cpu registers
* split - generate a split view that shows theasm and the src layout

When in a view with multiple windows, you can use focus xyz to change which window has the current focus. Most key combinations are directed to the currently focused window, so if something isn't working as expected, that might be why. For example to get back the focus to the command view just type: `focus cmd`

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

* The first one is either the `VBOX_GUI_DBG_ENABLED` or `VBOX_GUI_DBG_AUTO_SHOW` set to true 
* Launch the virtual machine with the `--debug` option: 

```bash
virtualboxvm --startvm vmname --debug
```

this will open the Virtual Machine with the Debugger command line and ui. 

## QEmu 

### QEmu monitor

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
* **info xxxx** It will print several information, depending on xxxx for example: *info lapic* will show the current status of the local apic
* **x/cf address** where c is the number of items we want to display in decimal, f is the format (`x` for hex, `c` for char, etc) display the content of c virtual memory locations starting from address
* **xp/cf address** same as above, but for physical memory


### Debugcon

Qemu (and several other emulators - bochs for example) support something called debugcon.
It's an extremely simple protocol, similar to serial - but with no config, where anything written to port 0xE9 in the VM will appear byte-for-byte at where you tell qemu to put it.
Same is true with input (although this is quite buggy, best to use serial for this).
To enable it in qemu add this to your qemu flags `-debugcon where`. Where can be anything really, a log file for example. You can even use `-debugcon /dev/stdout` to have the output appear on the current terminal.

It's worth noting that because this is just a binary stream, and not a serial device emulation, its much faster than usual port io. And there's no state management or device setup to worry about.

## Useful resources

* https://wiki.osdev.org/Kernel_Debugging
* https://wiki.osdev.org/Serial_Ports
* https://en.wikibooks.org/wiki/QEMU/Debugging_with_QEMU

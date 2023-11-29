# Debugging

## GDB

### Remote Debugging

First thing Qemu needs to be launched telling it to accepts connections from gdb, it needs the parameters: *-s* and *-S*  added to the command, where:

* **-s** is a shortand for **-gdb tcp::1234**
* **-S** instead tells the emulator to halt before starting the CPU, in this way we have time to connect the debugger before the OS start.
To connect with qemu/bochs host configure for remote debugging launch gdb, and type the following command in gdb cli:

```bash
target remote localhost:1234
```

And then we can load the symbols (if we have compiled our os with debugging symbols):

```bash
symbol-file path/to/kernel.bin
```

### Useful Commands

Below a list of some useful gdb commands

* Show register content: *info register reg* where reg is the register we need
* Set breakpoint to specific address: *break 0xaddress*
* Show memory address content: *x/nfu addr* wher: n is the number of iterations f the format (x = hex) and the addr we want to show
* We can show also the content of pointer stored into a register: *x/h ($rax)* shows the content of memory address pointed by rax

### Navigation

* `c/continue` can be used to continue the program until the next breakpoint is reached.
* `fin/finish` will run until the end of the current function.
* `s/step` will run the next line of code, and if the next line is a function call, it will 'step into' it. This will leave us on the first line on the new function.
* `n/next` similar to step, but will 'step over' any function calls, treating them like the rest of the lines of code.
* `si/ni` step instruction/next instruction. These are like step and next, but work on instructions, rather than lines of code.

### Print and Examine Memory

* `p/print symbol` can be used to used to print almost anything that makes sense in our program.
Lets say we have an integer variable i, `p i` will print what i currently is. This takes a c-like syntax,
so if we print a pointer, gdb will simply tell us its address. To view its contents we would need to use `p *i`, like in c.
* `x address` is similar to print, but takes a memory address instead of a symbol.

Both commands accept _format specifiers_ which change the output. For example `p/x i` will print i, formatted as hexadecimal number.
There are a number of other ones `/i` will format the output as cpu instructions, `/u` will output unsigned, and `/d` signed decimal numbers.
`/c` will interpret an ASCII character, and `/s` will interpret it as a null terminated ASCII string (just a c string).

The format specifier can be prefixed with a number of repeats. For example if we want to examine 10 instructions at address 0x1234, we could do:
`x/10i 0x1234`, and gdb would show us that (i is the identifier for the instruction format), this is pretty useful if we want to look at raw areas of memory. In case we need to print raw memory insted we can use `x/10xb 0x1234`(where _x_ is the format (hexadecimal) and _b_ the size (bytes).

### How Did I Get Here?

Here a collection of useful command to keep track of the call stack.

* `bt/backtrace/info stack` will show us the current call stack, with lower numbers meaning deeper (current breakpoint is stack frame 0).
* `up/down` can be used to move up and down the callstack.
* `frame x` will jump directly to frame number x (view frame numbers with `bt`)
* `info args` will display the arguments passed into the function. It's worth nothing that the first few instructions of a function set up the stack frame,
so we may need to `si` a few times when entering a function for this to return correct values.
* `info locals` displays local variables (on the stack). Any variables that have no yet been declared in the source code will have junk values (keep this in mind!).
* `info variables` is similar to info global and static variables
* `info args` list the arguments of the current stack frame, name and values.

### Breakpoints

A breakpoint can be set in a variety of ways! The command is `b/break symbol`, where symbol can be a number of things:

* a function entry: `break init` or `break init()` will break at *any* function named init.
* a file/line number: `break main.c:42` will break just before the first instruction of line 42 (in main.c) is executed.
* an address in memory: `break 0x1234` will break whenever the cpu's next instruction is at address 0x1234.

Breakpoints can be enabled/disabled at runtime with `enable x`/`disable x` where x is the breakpoint number (displayed when we first set it).

Breakpoints can also take conditions if we're trying to debug a commonly-run function. The syntax follows a c-like style, and is pretty forgiving.
For example: `break main if i == 0` would break at the function `main()` whenever the variable `i` is equal to 0.
This syntax supports all sorts of things, like casts and working with pointers.

Breakpoints can also be issued contextually too! If we're at a breakpoint `main.c:123`, we can simply use `b 234` to break at line 234 in the same file.

It is possible at any time to print the list of breakpoints using the command: `info breakpoint`

And finally breakpoints can be deleted as well using `delete [breakpoints]`

It's worth noting if debugging a kernel running with kvm, is not possible to use software breakpoints (above) like normal.
GDB does support hardware breakpoints using `hb` instead of `b` for above, although their functionality can be limited, depending on what the hardware supports.
Best to do serious debugging without kvm, and only use hardware debugging when absolutely necessary.

In case we want to watch the behaviour of a variable, and interrupt the code every time the variable changes, we can use `watchpoints` they are similar to breakpoints, but instead of being set for lines of code or functions, they are set to watch variable behaviour.

For example imagine to have the following simple function:

```c
int myVar2 = 3;
int test_function() {
    int myVar = 0;
    myVar = 5;
    myVar2 = myVar
    return myVar;
}
```

If we want to interrupt the execution when myVar2 changes value this can be easily done with:

```
watch myVar2
```

As soon as `myVar2` changes from 0 to 5, the execution will stop. This works pretty well for global variables. But what about local variables? Like `myVar`, the workflow is pretty similar but to catch the watchpoint we need first to set a breakpoint when the variable is _in-scope_ (inside the test_function).

We can use conditions on watchpoint too, in the same way they are used for breakpoints.

### Variables

While debugging with gdb, we can change the value of the variables in the code being executed. To do that we just need the command:

```gdb
set variable_name=value
```

where `variable_name` is a variable present in the code being debugged. This is extermely useful in the cases where we want to test some edge cases, that are hard to reproduce.

### TUI - Text User Interface

This area of gdb is hilariously undocumented, but still really useful. It can be entered in a number of ways:

* `layout xyz`, will drop into a 1 window tui with the specified data in the main window. This can be 'src' for the source code, 'regs' for registers, or 'asm' for assembly.
* Control-X + 1 will enter a 1 window tui, Control-X 2 will enter a 2 window tui. Pressing these will cycle window layouts. Trying is easier than explaining here!
* `tui enable` will do the same the first option, but defaults to asm layout.

Tui layouts can be switched at any time, or we can return to our regular shell at any time using `tui disable`, or exiting gdb.

The layouts offer little interaction besides the usual terminal in/out, but can be useful for quickly referencing things, or examining exactly what instructions are running.

If we are using debian, we most-likely need to install the *gdb* package, because by default *gdb-minimal* is being installed, which doesn't contain the TUI.

Currently these are the type of tui layouts available in gdb:

* asm - shows the asm code being executed
* src - shows the actual source code line executed
* regs - shows the content of the cpu registers
* split - generate a split view that shows theasm and the src layout

When in a view with multiple windows, the command `focus xyz` can be used to change which window has the current focus. Most key combinations are directed to the currently focused window, so if something isn't working as expected, that might be why. For example to get back the focus to the command view just type: `focus cmd`

## Virtual Box

### Useful Commands

* To list the available machine using command line use the following command:

```bash
vboxmanage list vms
```

It will show for every virtual machine, its label and its UUID

* To launch a VM from command line:

```bash
virtualboxvm --startvm vmname
 ```

The virtual machine name, or its uuid can be used.

### Debugging a Virtual Machine

To run a VM with debug two things are needed:

* The first one is either the `VBOX_GUI_DBG_ENABLED` or `VBOX_GUI_DBG_AUTO_SHOW` set to true
* Launch the virtual machine with the `--debug` option:

```bash
virtualboxvm --startvm vmname --debug
```

this will open the Virtual Machine with the Debugger command line and ui.

## Qemu

## Qemu Interrupt Log

If using qemu, a good idea is to dump registers when an exception occurs, we just need to add the following option to qemu command:

```bash
qemu -d int
```

Sometime could be needed to avoid the emulator restart on triple fault, in this case to catch the "offending" exception, just add:

```bash
qemu -d int -no-reboot
```

While debugging with gdb, we may want to keep qemu hanging after a triple fault (when the cpu should reset), to do some more investigation, in this case we need to add also `-no-shutdown` (along with) `-no-reboot`

### Qemu Monitor

Qemu monitor is a tool used to send complex commands to the qemu emulator, is useful to for example add/remove media images to the system, freeze/unfreeze the VM, and to inspect the state of the Virtual machine without using an external debugger.

One way to start Qemu monitor on a unix system is using the following parameter when starting qemu:

```bash
qemu-system-i386 [..other params..] -monitor unix:qemu-monitor-socket,server,nowait
```

then on another shell, on the same folder where we started the emulator launch the following command:

```bash
socat -,echo=0,icanon=0 unix-connect:qemu-monitor-socket
```

This will prompt with a shell similar to the following:

```bash
username@host:~/yourpojectpath/$ socat -,echo=0,icanon=0 unix-connect:qemu-monitor-socket
QEMU 6.1.0 monitor - type 'help' for more information
(qemu)

```

From here is possible to send commands directly to the emulator, below a list of useful commands:

* **help** Well this is the first command to get some help on how to use the monitor.
* **info xxxx** It will print several information, depending on xxxx for example: *info lapic* will show the current status of the local apic, *info mem* will print current virtual memory mappings, *info registers* will print the registers content.
* **x/cf address** where c is the number of items we want to display in decimal, f is the format (`x` for hex, `c` for char, etc) display the content of c virtual memory locations starting from address.
* **xp/cf address** same as above, but for physical memory.

#### Info mem & Info tlb

These commands are very useful when we need to debug memory related issues, the first command `info mem` will print the list of active virtual memory mappings, the output format depends on the architecture, for exmple on `x86-64`, it will be similar to the following:

```
info mem
ffff800000000000-ffff800100491000 0000000100491000 -rw
ffff800100491000-ffff800100498000 0000000000007000 -r-
ffff800100498000-ffff80010157a000 00000000010e2000 -rw
ffffffff80000000-ffffffff80057000 0000000000057000 -r-
ffffffff80057000-ffffffff8006b000 0000000000014000 -rw
```

Where every line describes a single virtual memory mapping. The fields are (ordered left to right): base address, limit, size and the three common flags (user, read, write).

The other command, `info tlb`, shows the state of the translation lookaside buffer. In qemu this is shown as individual address translations, and can be quite verbose. An example of what the output might look like is shown below:

```
info tlb
ffffffff80062000: 000000000994a000 XG------W
ffffffff80063000: 000000000994b000 XG------W
ffffffff80064000: 000000000994c000 XG--A---W
ffffffff80065000: 000000000994d000 XG-DA---W
ffffffff80066000: 000000000994e000 XG-DA---W
ffffffff80067000: 000000000994f000 XG-DA---W
ffffffff80068000: 0000000009950000 XG-DA---W
ffffffff80069000: 0000000009951000 XG-DA---W
ffffffff8006a000: 0000000009952000 XG-DA---W
```

In this case the line contains: _virtualaddress: physicaladdress flags_. The command is not available on all architecture, so if developing on an architecture different from `x86-64` it could not be available.

### Debugcon

Qemu (and several other emulators - bochs for example) support something called debugcon.
It's an extremely simple protocol, similar to serial - but with no config, where anything written to port 0xE9 in the VM will appear byte-for-byte at where we tell qemu to put it.
Same is true with input (although this is quite buggy, best to use serial for this).
To enable it in qemu add this to the qemu flags `-debugcon where`. Where can be anything really, a log file for example. We can even use `-debugcon /dev/stdout` to have the output appear on the current terminal.

It's worth noting that because this is just a binary stream, and not a serial device emulation, its much faster than usual port io. And there's no state management or device setup to worry about.


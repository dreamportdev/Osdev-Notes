# Troubleshooting

A collection of unrelated potential issues.

## Unexpected UD/Undefined Opcode exception in x86_64

This is a not a definitive solution, but it's an easy to run into.
This can commonly be caused by the compiler generating sse (or sse2, 3dnow, or even mmx - I'm just going to refer to them as sse for now) instructions.
If the cpu hasn't been setup to handle extended state, it will fault and trigger an #UD.

To determine if this is happening, step through your code with gdb, paying attention to any operations that involve an `%xmm` register.
If you have the qemu logs of the crash, you can also examine the kernel binary near the address of the exception RIP.

### Why does this happen?

These extensions existed before x86_64, but they were optional. The OS had to support them, and then initialize the hardware into a valid state for these
instructions to run. This actually includes the x87 floating point unit as well, and any attempts to use it before executing `finit` will result in #UD.
Now if you're used to programming with more recent cpu extensions, like avx512 for example, you normally have to enable these features explicitly before
the compiler will generate instructions. Not so here.
The important thing to note is that when AMD create x86_64, they wanted to reduce the fragmentation of cpu feature sets, so they made these extensions *architectural*. Every x86_64 cpu is required to support them.
This means the XMM (sse 128 bit wide registers) are always present, and your compiler knows this. Hence it might use them for storing data,
which results in the #UD.

Any operation that touches the extended cpu registers, extended control registers, or uses an extension opcode will result in #UD.

### The easy solution

Tell your compiler not to generate these instructions, simply add these flags to your favourite gcc/clang compiler of choice:
`-mno-80387 -mno-sse -mno-sse2 -mno-3dnow -mno-mmx`

### The hard solution

Disclaimer here, I've never tested this, but I see no reason it *shouldnt* work.

If your kernel begins in an assembly stub, you could setup the cpu for these extended states before executing any compiler-generated code.
The x87 fpu and SSE are the main ones, most compilers wont output 3dnow or mmx, especially since sse replaces most of their functionality.
First you'll went to set some flags in cr0 for the fpu:

* Bit 1 = MP/Monitor processor - required
* Bit 2 = Must be cleared (if set means you want to emulate the fpu - you don't).
* Bit 4 = Hardwired to 1 (but not always in some emulator versions!). If set means use 387 protocol, otherwise 287.
* Bit 5 = NE/Native exceptions - required.

You'll likely want to ensure bit 3 is clear. This is the TS/task swiched bit, which if set will generate a #NM/device missing exception when the cpu thinks you've switched tasks. Not worth the hassle.
The FPU can now be initializaed by a simple `finit` instruction.

SSE is a little trickier, but still straight forward enough
You'll want to set the following bits in cr4:

* Bit 9 = OSFDSR, tell the cpu our os knows to use the fxsave/fxrstor instructions for saving/restoring extended cpu state.
* Bit 10 = OSXMMEXCPT, tell the cpu it can issue #XM (simd/sse exceptions), and we'll handle them.

If the cpu supports XSAVE (check cpuid), you can also set bit 18 here to enable it, otherwise leave it as is. 
There is more work to setting up xsave as well, for running in a single-task state where you don't care about saving/loading registers, not having xsave setup is fine.

That's it, that should enable your compiler-generated code with sse instructions to work.

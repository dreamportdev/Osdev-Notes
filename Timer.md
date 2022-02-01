# Timer

## Types 

There are different sources when talking about timers on modern computer, this document will be focused on the PIT and the Apic Timer. 

Mostly in the second, it will use the first just for calibration purposes.

## Few words about the PIT

Even if we are going to use the PIT timer only for calibrating the APIC timer, is worth spending few words on it. Especially to understand why we are going to use certain values. 

First the PIT has basically 4 communication ports: 

| I/O Port | Description          |
|----------|----------------------|
|  0x40    | Channel 0 data Port  |
|  0x41    | Channel 1 data Port  |
|  0x42    | Channel 2 data Port  |
|  0x43    | Mode/Command register| 

The PIT 8253/4 Chips has a strange clock rate, that is 1,193,180 Hz that is more or less 1,19Mhz, the reason behind it is again some legacy from the past, you can read it on the OSDEV Wiki page about the PIT (See the useful links section). Reminder: 1 Hz is number of cycles per second. 

The pit counter is 16bits, this means it can't count up to 1 second, because the clock rate is more than 16 bits. So we must count to fractions of it.

Everytime the the counter reaches 0, an irq is generated. So let's say for example we want to create an interrupt every millisecond (1/1000 of second) to know how many cycles are needed we need to divide the clock rate by the duration we want (1ms): 

```
1,193180 (clock rate) / 1000 (1ms) = 1193.18 (cycles in 1m̀s)
```

Now one problem is that we can't use decimal number so we need to round up to the closer integer, that is in this case 1193. 
but that means that we lose accuracy... Yeah, and there is not much that can be done about it.

The programming of the PIT is pretty straightforward, there is only one configuration byte, and basically just one command to send. For more information about programming the PIT please refer to the useful links section, here i will give a very short explain of the configuration byte, and what we values are we going to set for our calibration purpose.

The table below shows theocnfiguration byte: 

| Bits   | Description                                                                                                          |
|--------|----------------------------------------------------------------------------------------------------------------------|
|  0     | It describe how the channel will operate if in Binary mode or BCD Mode, for our purpose we will use Binary mode.     |
| 1 - 3  | Operating Mode there are basically 5 operating modes, we are going to use the "rate generator", identified by 010    |
| 4 - 5  | Access mode it tells how the channel how to read/write the counter register. It can be: low/high/low first then high |
| 6 - 7  | Select the channel we want to use, consider that channel 1 is unavailable. We are going to use channel 0             |

Again for more details on the byte in our case we want: 

* Binary Mode (0)
* Operating mode 2: (010)
* Access mode: Low first then high (11)
* channel 0: (00)

That translates into byte:  00110100. 

With that byte now we must: 

* Write it into the pit using Mode command register  the port (0x43)
* Send two consecutive writes to the channel 0 data port (0x40), with the two bytes for the counter (low first then high), the value of the counter depends on how much time you want between IRQs, for example if we want 1ms of delay between each IRQ then we need to write the value 1193, in hexadecimal: 0x4A9, so we will send the lower byte First 0xA9 followed by the higher byte: 0x04.

And remember: we need to set an IRQ handler for the PIT Irqs, for how to do this please refer to the [APIC](APIC.md) chapter 

## IRQ 

The PIT timer is connect to the old PIC8259 IRQ0 pin, now if we are using the APIC, this line is connected to the Redirection Table entry number #2 (offset: 14h and 15h).

While the APIC timer irq is always using  the lapic LVT entry 0. 

## Steps for calibration

These are at a high level the steps that we need to do to calibrate the APIC timer: 

1. Configure the PIT Timer
2. Configure the APIC timer 
3. Reset the APIC counter
4. Wait some time that is measured using another timing source (in our case the PIT)
5. Compute the number of ticks from the APIC counter
6. Adjust it to a Second
7. Divide it by the divider chosen, use this value to raise an interrupt every x ticks
8. Mask the PIT Timer IRQ
### Configure the PIT Timer (1)
 
## Useful links

* [Ehtereality osdev Notes - Apic/Timing/Context Switching](https://ethv.net/workshops/osdev/notes/notes-4.html)
* [OSdev Wiki - Pit page](https://wiki.osdev.org/Programmable_Interval_Timer)
* [Brokern Thron Osdev Series](http://www.brokenthorn.com/Resources/OSDev16.html)

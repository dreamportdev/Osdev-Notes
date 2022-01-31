# Timer

## Types 

There are different sources when talking about timers on modern computer, this document will be focused on the PIT and the Apic Timer. 

Mostly in the second, it will use the first just for calibration purposes.

## Few words about the PIT

Even if we are going to use the PIT timer only for calibrating the APIC timer, is worth spending few words on it. Especially to understand why we are going to use certain values. 

The PIT 8253/4 Chips has a strange clock rate, that is 1,193,180 Hz that is more or less 1,19Mhz, the reason behind it is again some legacy from the past, you can read it on the OSDEV Wiki page about the PIT (See the useful links section). Reminder: 1 Hz is number of cycles per second. 

The pit counter is 16bits, this means it can't count up to 1 second, because the clock rate is more than 16 bits. 

Everytime the the counter reaches 0, an irq is generated. So let's say for example we want to create an interrupt every millisecond (1/1000 of second) to know how many cycles are needed we need to divide the clock rate by the duration we want (1ms): 

```
1,193180 (clock rate) / 1000 (1ms) = 1193.18 (cycles in 1m̀s)
```

Now one problem is that we can't use decimal number so we need to round up to the closer integer, that is in this case 1193. 
but that means that we lose accuracy... Yeah, and there is not much that can be done about it.


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

### Configure the PIT Timer (1)
 
## Useful links

* https://ethv.net/workshops/osdev/notes/notes-4.html
* https://wiki.osdev.org/Programmable_Interval_Timer

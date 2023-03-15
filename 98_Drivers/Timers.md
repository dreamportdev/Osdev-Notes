# Timer

Timers are useful for all sorts of things, from keeping track of real-world time to forcing entry into the kernel to allow for pre-emptive multitasking. There are many timers available, some standard and some not.

In this chapter we're going to take a look at the main timers used on x86 and what they're useful for.

## Types and Characteristics

At a high level, there a few things we might want from a timer: 

- Can it generate interrupts? And does it support a periodic mode?
- Can we poll it to determine how much time has passed?
- Does the main clock count up or down?
- What kind of accuracy, precision and latency does it have?

At first most of these questions might seem unnecessary, as all we really need is a periodic timer to generate interrupts for the scheduler right? Well that can certainly work, but as you do more things with the timer you may want to accurately determine the length of time between two points of execution. This is hard to do with interrupts, and it's easier to do with polling. A periodic mode is also not always available, and sometimes you are stuck with a one-shot timer.

For x86, the common timers are:

- The PIT: it can generate interrupts (both periodic and one-shot) and is pollable. When active it counts down from a reload value to 0. It has a fixed frequency and is very useful for calibrating other timers we don't know the frequency of. However it does come with some latency due to operating over port IO, and it's frequency is low compared to the other timers available.
- The local APIC timer: it is also capable of generating interrupts (periodic and oneshot) and is pollable. It operates in a similar manner to the PIT where it counts down from a reload value towards 0. It's often low latency due to operating over MMIO and comes with the benefit of being per-core. This means each core can have it's own private timer, and more cores means more timers.
- The HPET: capable of polling with a massive 64-bit main counter, and can generate interrupts with a number of comparators. These comparators always support one-shot operation and may optionally support a periodic mode. It's main clock is count-up, and it is often cited as being high-latency. It's frequency can be determined by parsing an ACPI table, and thus it serves as a more accurate alternative to the PIT for calibrating other timers.
- The TSC: the timestamp-counter is tied to the core clock of the cpu, and increments once per cycle. It can be polled and has a count-up timer. It can also be used with the local APIC to generate interrupts, but only one-shot mode is available. It is often the most precise and accurate timer out of the above options.

We're going to focus on setting up the local APIC timer, and calibrating it with either the PIT or HPET. We'll also have a look at a how you could also use the TSC with the local APIC to generate interrupts.

### Calibrating Timers

There are some timers that we arent told the frequency of, and must determine this ourselves. The local APIC timer and TSC (up until recently) are examples of this. In order to use these, we have to know how fast each 'tick' is in real-world time, and the easiest way to do this is with another time that we do know the frequency of.

This is where timers like the PIT can still be useful: even though it's very simple and not very flexible, it can used to calibrate more advanced timers like the local APIC timer. Commonly the HPET is also used for calibration purposes if it's available, since we can know it's frequency without calibration.

Actually calibrating a timer is straightforward. We'll refer to the timer we know the frequency of as the reference timer and the one we're calibrating as the target timer. This isn't common terminology, it's just useful for the following description.

- Ensure both timers are stopped.
- If the target timer is counts down, set it the maximum allowed value. If it counts up, set it to zero.
- Choose how long you want to calibrate for. This should be long enougn to allow a good number of ticks to pass on the reference timer, because more ticks passing will mean a more accurate calibration. This time shouldn't be too long however, because if one of the timer counters rolls over then we'll trouble determining the results. A good starting place is 5-10ms.
- Start both timers, and poll the reference timer until the calibration time has passed.
- Stop both timers, and we look at how many ticks has passed for the target timer. If it's a count-down timer, we can determine this by subtracting the current value from the maximum value for the counter.
- Now we know that a certain amount of time (the calibration time) is equal to a certain number of ticks for our target timer.

Sometimes running your kernel in a virtual machine, or on less-stable hardware can give varying results, so it can be useful to calibrate a timer multiple times and compare the results. If some results are odd, dont use them. It can also be helpful to continuously calibrate timers while you're using them, which will help correct small errors over time.

## Programmable Interval Timer (PIT)

The PIT is actually from the original IBM PC, and has remained as a standard device all these years. Of course these days we don't have a real PIT in our computers, rather the device is emulated by newer hardware that pretends to be the PIT until configured otherwise. Often this hardware is the HPET (see below).

On the original PC the PIT also had other uses, like providing the clock for the RAM and the oscillator for the speaker. Each of these functions is provided by a 'channel', with channel 0 being the timer (channels 1 and 2 are the other functions). On modern PITs it's likely that only channel 0 exists, so the other channels are best left untouched.

Despite it being so old the PIT is still useful because it provides several useful modes and a known frequency. This means we can use it to calibrate the other timers in our system, which we dont always know the frequency of.

The PIT itself provides several modes of operation, although we only really care about a few of them:

- Mode 0: provides a one-shot timer.
- Mode 2: provides a periodic timer.

To access we PIT we use a handful of IO ports:

| I/O Port | Description          |
|----------|----------------------|
|  0x40    | Channel 0 data Port  |
|  0x41    | Channel 1 data Port  |
|  0x42    | Channel 2 data Port  |
|  0x43    | Mode/Command register|

### Theory Of Operation

As mentioned the PIT runs at a fixed frequency of 1.19318MHz. This is an awkward number but it makes sense in the context of the original PC. The PIT contains a pair of registers per channel: the count and reload count. When the PIT is started the count register is set to value of the reload count, and then every time the main clock ticks (at 1.19318MHz) the count is decremented by 1. When the count register reaches 0 the PIT sends an interrupt. Depending on the mode the PIT may then set the count register to the reload register again (in mode 2 - periodic operation), or simple stay idle (mode 0 - one shot operation).

The PIT's counters are only 16-bits, this means that the PIT can't count up to 1 second. If you wish to have timers with a long duration like that, you will need some software assistance by chaining time-outs together.

### Example

As an example let's say we want the PIT to trigger an interrupt every 1ms (1ms = 1/1000 of a second). To figure out what to set the reload register to (how many cycles of the PIT's clock) we divide the clock rate by the duration we want:

```
1,193,180 (clock frequency) / 1000 (duration wanted) = 1193.18 (Hz for duration)
```

One problem is that we can't use floating point numbers for these counters so we truncate the result to 1193. This does introduce some error, and you can correct for this over a long time if you want. However for our purposes it's small enough to ignore, for now.

To actually program the PIT with this value is pretty straightfoward, we first send a configuration byte to the command port (0x43) and then the reload value to the channel port (0x40).

The configuration byte is actually a bitfield with the following layout:

| Bits   | Description                                                                                                          |
|--------|----------------------------------------------------------------------------------------------------------------------|
| 0      | Selects BCD/binary coded decimal (1) or binary (0) encoding. If you're unsure, leave this as zero. |
| 1 - 3  | Selects the mode to use for this channel. |
| 4 - 5  | Select the access mode for the channel: generally you want 0b11 which means we send the low byte, then the high byte of the 16-bit register. |
| 6 - 7  | Select the channel we want to use, we always want channel 0. |

For our example we're going to use binary encoding, mode 2 and channel 0 with the low byte/high byte access mode. This results in the following config byte: `0b00110100`.

Now it's a matter of sending the config byte and reload value to the PIT over the IO ports, like so:

```c
void set_pit_periodic(uint16_t count) {
    outb(0x43, 0b00110100);
    outb(0x40, count & 0xFF); //low-byte
    outb(0x40, count >> 8); //high-byte
}
```

Now we should be getting an interrupt from the PIT every millisecond! By default the PIT appears on irq0, which may be remapped to irq2 on modern (UEFI-based) systems. Also be aware that the PIT is system-wide device, and if you're using the APIC you will need to program the IO APIC to route the interrupt to one of the LAPICs.

## High Precision Event Timer (HPET)

The HPET was meant to be the successor to the PIT as a system-wide timer, with more options however it's design has been plagued with latency issues and occasional glitches. With all that said it's still a much more accurate and precise timer than the PIT, and provides more features. It's also worth noting the HPET is not available on every system, and can sometimes be disabled via firmware.

### Discovery

To determine if the HPET is available you'll need access to the ACPI tables. Handling these is covered in a separate chapter, but we're after one particular SDT with the signature of 'HPET'. If you're not familiar with ACPI tables yet, feel free to come back to the HPET later.

This SDT has the standard header, followed by the following fields:

```c
struct HpetSdt {
    ACPISDTHeader header;
    uint32_t event_timer_block_id;
    uint32_t reserved;
    uint64_t address;
    uint8_t id;
    uint16_t min_ticks;
    uint8_t page_protection;
}__attribute__((packed));
```

*Authors note: the reserved field before the address field is actually some type information describing the address space where the HPET registers are located. In the ACPI table this reserved field is the first part of a 'generic address structure', however we can safely ignore this info because the HPET spec requires the registers to be memory mapped (thus in memory space).*

We're mainly interested in the `address` field which gives us the physical address of the HPET registers. The other fields are explained in the HPET specification but are not needed for our purposes right now.

As with any MMIO you will need to map this physical address into the virtual address space so we can access the registers with paging enabled.

### Theory Of Operation

The HPET consists of a single main counter (that counts up) with some global configuration, and a number of comparators that can trigger interrupts when certain conditions are met in relation to the main counter. The HPET will always have at least 3 comparators, but may have up to 32.

The HPET is similar to the PIT in that we are told the frequency of it's clock. Unlike the PIT, the HPET spec does not give us the frequency directly, we have to read it from the HPET registers. 

Each register is accessed by adding an offset to the base address we obtained before. The main registers we're interested in are:

- General capabilities: offset 0x0.
- General configuration: offset 0x10.
- Main counter value: 0xF0.

We can read the main counter at any time, which is measured in in timer ticks. We can convert these ticks into realtime by multiplying them with the timer period in the general capabilities register. Bits 63:32 of the general capabilities register contain the number of femtoseconds for each tick. A nanosecond is 1000 femtoseconds, and 1 second is 1'000'000'000 femtoseconds.

We can also write to the main counter, usually you would write a 0 here when initializing the HPET in order to be able to determine uptime, but this is not really necessary.

The general capabilities register contains some other useful information, like whether the main counter is 32 or 64 bits wide, and the number of comparators (which are used to generate interrupts). These are all detailed in the public spec, and you can explore these at your leisure.

In order for the main counter to actually begin counting, we need to enable it. This is done by setting bit 0 of the general configuration register. Once this bit is set, the main counter will increment by one every time it's internal clock ticks. The period of this clock is what's specified in the general capabilities register (bits 63:32).

### Comparators

The main counter is only suitable for polling the time, but it cannot generate interrupts. For that we have to use one of the comparators. The HPET will always have at least three comparators, but may have up to 32. In reality most vendors use the stock intel chip which comes with 3 comparators, although some older and more exotic hardware may provide more.

By default the first two comparators are set up to mimic the PIT and RTC clocks, but they can be configured like the others.

It's worth noting that all comparators support one-shot mode, but periodic mode is optional. Testing if a comparator supports periodic mode can be done by checking if bit 4 is set in the capabilities register for that comparator.

Speaking of which: each comparator has it's own set of registers to control it. These registers are accessed as an offset from the HPET base. There are two registers we're interested in: the comparator config and capability registger (accessed at offset 0x100 + N * 0x20), and the comparator value register (at offset 0x108 + N * 0x20). In those equations `N` is the comparator number you want. As an example to access the config and capability register for comparator 2, we would determine it's location as: `0x100 + 2 * 0x20 = 0x140`. Meaning we would access the register at offset `0x140` from the HPET mmio base address.

The config and capabilities register for a comparator also contains some other useful fields to be aware of:

- Bits 63:32: This is a bitfield indicating which interrupts this comparator can trigger. If a bit is set, the comparator can trigger that interrupt. This maps directly to GSIs, which are the inputs to the IO APIC. If there is only a single IO APIC in the system, then these interrupt numbers map directly to the IO APIC input pins. For example if bits 2/3/4 are set, then we could trigger the IO APIC pins 2/3/4 from this comparator.
- Bits 13:9: Write the integer value of the interrupt you want this comparator to trigger here. It's recommended to read this register back after writing to verify the comparator accepted the interrupt number you wrote.
- Bits 3 and 4: Bit 4 is set if the comparator supports periodic mode. Bit 3 is used to select periodic mode if it's supported. If either bit is cleared, the comparator operates as a one-shot.
- Bit 2: Enables the comparator to generate interrupts. Even if this is cleared the comparator will still operate, and set the interrupt pending bit, but no interrupt will be sent to the IO APIC. This bit acts in reverse to how a mask bit would: if this bit is set, interrupts are generated.

### Example

Let's look at two examples of using the HPET timer: polling the main counter and setting up a one-shot timer. If you want a periodic timer you'll have to do a bit more work, and check that a comparator supports periodic mode.

We're going to assume you have the HPET registers mapped into virtual memory, and that address is stored in a variable `void* hpet_regs`.

Polling the main counter is very straightforward:

```c
uint64_t poll_hpet() {
    volatile uint64_t* caps_reg = hpet_regs;
    uint32_t period = *caps_reg >> 32;
    
    volatile uint64_t* counter_reg = hpet_regs + 0xF0;
    return *counter_reg * period;
}
```

This function returns the main counter of the hpet as a number of femtoseconds since it was last reset. You may want to convert this to a more management unit like nano or even microseconds.

Next let's look at setting up an interrupt timer. This requires the use of a comparator, and a bit of logic. You'll also need the IO APIC set up, and we're going to use some dummy functions to show what you'd need to do. We're going to use comparator 0, but this could be any comparator.

```c
#define COMPARATOR_0_REGS 0x100

void arm_hpet_interrupt_timer(size_t femtos) {
    volatile uint64_t* config_reg = hpet_regs + COMPARATOR_0_REGS;

    //first determine allowed IO APIC routing
    uint32_t allowed_routes = *config_reg >> 32;
    size_t used_route = 0;
    while ((allowed_routes & 1) == 0) {
        used_route++;
        allowed_routes >>= 1;
    }

    //set route and enable interrupts
    *config_reg &= ~(0xFul << 9);
    *config_reg |= used_route << 9;
    *config_reg |= 1ul << 2;
    //you should configure the io apic routing here.
    //this interrupt will appear on the pin `used_route`.

    volatile uint64_t* counter_reg = hpet_regs + 0xF0;
    uint64_t target = *counter_reg + (femtos / hpet_period);
    volatile uint64_t* compare_reg = hpet_regs + COMPARATOR_0_REGS + 8;
    *compare_reg = target;
}
```

## Local APIC Timer

The next timer on our list is the local APIC timer. This timer is a bit special as a processor can only access it's local timer, and each core gets a dedicated timer. Very cool! Historically these timers have been quite good, as they're built as part of the CPU, meaning they get the same treatment as the rest of that silicon.

However not all local APIC timers are created equal! There are a few feature flags to check for before using them:

- ARAT/Always Running APIC Timer: cpuid leaf 6, eax bit 2. If the cpu hasn't set this bit the APIC timer may stop in lower power states. This is okay for a hobby OS, but if you do begin managing system power states later on, it's good to be aware of this.

The timer is managed by registers within the local APIC MMIO area. The base address for this can be obtained from the lapic MSR (MSR 0x1B). See the APIC chapter for more info on this. We're interested in three registers for the timer: the divisor (offset 0x3E0), initial count (offset 0x380) and timer entry in the LVT (offset 0x320). There is also a current count register, but we don't need ot access that right now.

Unfortunately we're not told the frequency of this timer (except for some very new cpus which include this in cpuid), so we'll need to calibrate this timer against one we already know the speed of. Other than this, using the local APIC is very simple: simply set the mode you want in the LVT entry, set the divisor and initial count and it should work.

### Example

Calibrating a timer is explained above, so we're going to assume you have a function called `lapic_ms_to_ticks` that converts a number of milliseconds into the number of local APIC timer ticks. You may not need this function yourself, but it serves for the example.

It's also important to note that the lapic timer waits for the initial count to be written after we change the mode of the timer.

```c
void arm_lapic_interrupt_timer(size_t millis) {
    volatile uint32_t* lvt_reg = lapic_regs + 0x320;
    TODO:

    uint32_t ticks = lapic_ms_to_ticks(millis);
}
```

## Timestamp Counter (TSC)
TODO: TSC how to, calibration

## Useful Timer Functions
TODO: polled_sleep()
TODO: arm_interrupt_timer()
//--- PREV CONTENT BELOW ---

### Configure the APIC Timer (2)

This step is just an initialization step for the apic, before proceeding make sure that the timer is stopped, to do that just write 0 to the Initial Count Register. 

The APIC Timer has 3 main register: 

* The Initial Count Register at Address 0xFEEO 0380 (this has to be loaded with the initial value of the timer counter, every time time the counter it reaches 0 it will generate an Interrupt
* The current Count Register at Address 0xFEE0 0390 (current value of the counter)
* The Divide Configuration register at 0xFEE0 03E0 The Timer divider.


In this step we need first to configure the timer registers: 

* The Initial Count register should start from the highest value possible. Since all the apic registers are 32 bit, the maximum value possible is: (0xFFFFFFFF)
* The Current Count register doesn't need to be set, it is set automatically when we initialize the initial count. This register basically is a countdown register.
* The divider configuration register it's up to us (i used 2)

### Wait some time (4)

In this step we just need to make an active waiting, basically something like: 

```c
while(pitTicks < TIME_WE_WANT_TO_WAIT) {
    // Do nothing...
}
```

pitTicks is a global variable set to be increased every time an IRQ from the PIT has been fired, and that depends on how the PIT is configured. So if we configured it to generate an IRQ every 1ms, and we want for example 15ms, will need the vlaue for `TIME_WE_WANT_TO_WAIT` will be 15. 

### Compute the number of ticks from the APIC Counter and obtain the calibrated value  (5,6,7)

That step is pretty easy, we need to read the APIC current count register (offset: 390). 

This register will tell us how many ticks are left before the register reaches 0. So to geth the number of ticks done so far we need to:

```c
apic_ticks_done = initial_count_reg_value - current_count_reg_value
````

this number tells us how many apic ticks were done in the `TIME_WE_WANT_TO_WAIT`. Now if we do the following division:

```c
apic_ticks_done / TIME_WE_WANT_TO_WAIT;
```

we will get the ticks done in unit of time. This value can be used for the initial count register as it is (or in multiple depending on what frequency we want the timer interrupt to be fired)

This is the last step of the calibration, we can start the apic timer immediately with the new calibrated value for the initial count, or do something else before. But at this point the PIT can be disabled, and no longer used. 


## Useful links

* [Ehtereality osdev Notes - Apic/Timing/Context Switching](https//ethv.net/workshops/osdev/notes/notes-4.html)
* [OSdev Wiki - Pit page](https://wiki.osdev.org/Programmable_Interval_Timer)
* [Brokern Thron Osdev Series](http://www.brokenthorn.com/Resources/OSDev16.html)

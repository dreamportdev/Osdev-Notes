# APIC 

## What is APIC

APIC stands for *Advanced Programmable Interrupt Controller*, and it is used to handles interrupt received from the processor, it is a replacement of the old PIC8259 (that remains still available), but it offers more functionalities, especially when dealing with SMP, in fact one of the limitations of the PIC was that it was able to deal with only one cpu at time, and this is also the main reason why the APIC was firstly introduced. 

Every core has it's own LAPIC (Local APIC), while usually there is a single IOAPIC.

## Types of APIC

There are mainly two types of APIC:

* _Local APIC_: it is present in every cpu/core, it is responsible of handling cpu specific interrupts, and is also responsible for handling the IPI (Inter Processor Interrupt) in multicore systems. It can also generate some interrutps, by itself, controlled by the Local Vectore Table, one of the interesting one is the Timer interrupt (we will see in another chapter). 
* _IO/APIC_: Usually there is only one IO/Apic, and it is responsible of routing hardware interrupts to cpus. 

## Local APIC

When a system boots up, for "legacy" reasons the cpu starts in PIC8259A emulation mode, this simply means that instead of having the LAPIC/IO-APIC up and running, we have them working to emulate the old interrupt controller, so before we can use them properly  we should to disable the PIC8259 emulator.

### Disabling the pic8259

This part should be pretty straightforward, and we will not go deep into explaining the meaning of all command sent to it, the sequence of commands is: 

```c
void disable_pic() {
    outportb(PIC_COMMAND_MASTER, ICW_1);
    outportb(PIC_COMMAND_SLAVE, ICW_1);
    outportb(PIC_DATA_MASTER, ICW_2_M);
    outportb(PIC_DATA_SLAVE, ICW_2_S);
    outportb(PIC_DATA_MASTER, ICW_3_M);
    outportb(PIC_DATA_SLAVE, ICW_3_S);
    outportb(PIC_DATA_MASTER, ICW_4);
    outportb(PIC_DATA_SLAVE, ICW_4);
    outportb(PIC_DATA_MASTER, 0xFF);
    outportb(PIC_DATA_SLAVE, 0xFF);
}
```

The old x86 architecture had two PIC processor, and they were called "master" and "slave", and each of them has it's own data port and command port:

* Master PIC command port: 0x20 and data port: 0x21
* Slave PIC command port: 0xA0 and data port 0xA1

The ICW values are initialization commands (ICW stands for Initialization Command Words), every command word is one byte, and their meaning is: 

* ICW_1 (value 0x11) is a word that indicates a start of inizialization sequence, it is the same for both the master and slave pic. 
* ICW_2 (value 0x20 for master, and 0x28 for slave) are just the interrupt vector address value (IDT entries), since the first 31 interrupts are used by the exceptions/reserved, we need to use entries above this value (remember that each pic has 8 different irqs that can handle.
* ICW_3 (value 0x2 for master, 0x4 for slave) Is is used to indicate if the pin has a slave or not (since the slave pic will be connected to one of the interrupt pins of the master we need to indicate which one is), or in case of a slave device the value will be it's id. On x86 architectures the master irq pin connected to the slave is the second, this is why the value of ICW_M is 2
* ICW_4 contains some configuration bits for the mode of operation, in our case we just tell that we are going to use the 8086 mode. 
* Finally 0xFF is masking all interrupts for the pic.

### Getting local apic information

You need to read the IA32_APIC_BASE MSR register, using the __rdmsr__ command. The value for this register is 1Bh. 

This register contains the following information: 

* Bits 0:7 Are reserved
* Bit 8 if set it means that the processor is the Bootstrap Processor (BSP)
* Bits 9:10 Are reserved
* Bit 11 APIC Global Enable if is set it means the APIC is enabled.
* Bits 12:31 Are the base address of the APIC (Apic Base Address)
* Bits 32:63 Are reserved.

The Apic Registers are all mapped in one Page of memory. Please be aware that if you have paging enabled, you will probably need to map the IOAPIC Base address on the page dirs table. 

### Local vector table

there are 6 items in the Local Vector Table (LVT):

* *Timer* this entry is specifically used for the APIC Timer interrupt. Offset: 320h
* *Thermal Monitor* Used by the thermal sensor to generate an interrupt. Offset: 330h
* *Performance Counter Register* When a performan counter generates an interrupt on overflow will use this entry. Offset: 340h
* *LINT0* Specifies the interrupt delivery when an interrupt is signaled on LINT0 Pin. Offset: 350h
* *LINT1* Specifies the interrupt delivery when an interrupt is signaled on LINT1 Pin. Offset: 360h
* *Error*  This used to signal an interrupt when the APIC detects an internal error. Offset 370h

Every entry of the LVT has the following information:

| Bit      |  Description                                                                                 |
|----------|----------------------------------------------------------------------------------------------|
| 0:7      |  Interrupt Vector. This is the IDT entry containing the information for this interrupt       |
| 8:10     |  Delivery mode (for more information about the modes available check the paragraph below)    |
| 11       |  Desitnation Mode It can be either Physical or Logic                                         |
| 12       |  Delivery Status **(Read Only)** It is the current status of the delivery for this Interrupt |       
| 13       |  Interrupt input polarity pin: 0 is high active, 1 is low active                             |
| 14       |  Remote IRR **(Read Only)** used for level triggered interrupts.                             |
| 15       |  Trigger mode, it can be 1=level sensitive or or Edge Sensitive interrupt                    |
| 16       |  Interrupt mask, if it is 1 the interrupt is disabled, if 0 is enabled                       |

With some exceptions, listed below: 

* Bits from 13 to 15 on an LVT entry are only available for LINT0 and LINT1, and are reserved for all other entries.
* The bits 8 to 10 (Delivery mode) are Reserved for the Timer, and the Error entries.
* The Timer entry use an extra bit, number 17, to specify the timer mode: if is 0 it means is one shot, than when the timer has signaled an interrupt stops there until resetted, if instead is set to 1 it means Periodic, so everytime the interrupt is signaled the internal counter reset and it starts a new countdown, this means that it will keep generating interrupts until manually stopped.

### X2Apic

The x2Apic is an extension of the APIC, that has some key differences:

* The registers are no longer accessed via Memory Mapped I/O, but using the MSR registers.

**..It will continue...**

### Serving interrupts

Once an Interrupt from the APIC is served (from both LAPIC and IOAPIC), an EOI must be sent, to do that just write the value 0x0 to the EOI Register. The address for this register is 0xFEE00B0 (unless the lapic has been relocated somewhere else)

There are few exceptions where the EOI is not needed: NMI, SMI, INIT, ExtInt, Init-Deassert delivery mode.

The EOI must sent before returning from interrupt with IRET. 

## IOAPIC

### Configure the IO-APIC

To configure the IO-APIC we need to: 

1. Get the IO-APIC base address from the MADT
2. Read the IO-APIC Interrupt Source Override table
3. Initialize the IO Redirection table entries for the interrupt we want to enable

### Getting IO-APIC address

Read IO-APIC information from MADT table (the MADT table is available within the RSDT data (please refer here: https://github.com/dreamos82/Osdev-Notes/blob/master/RSDP_and_RSDT.md), you need to search for the MADT Table item type 1). The content of the MADT Table for the IO_APIC type is: 

| Offset | Length | Description                  |
|--------|--------|------------------------------|
| 2      | 1      | I/O Apic ID's                |
| 3      | 1      | Reserved (should be 0)       |
| 4      | 4      | I/O Apic Address             |
| 8      | 4      | Global System Interrupt Base |

The IO APIC ID field is mostly fluff, as you'll be accessing the io apic by it's mmio address, not it's ID.

The Global System Interrupt Base is the first interrupt number that the I/O Apic handles. In the case of most systems, with only a single IO APIC, this will be 0. 

To check the number of inputs an IO APIC supports:

```c
uint32_t ioapicver = read_io_apic_register(IOAPICVER);
size_t number_of_inputs = ((ioapicver >> 16) & 0xFF) + 1;
```

The number of inputs is encoded as bits 23:16 of the IOAPICVER register, minus one. 


### IO-APIC Registers

The IO-APIC has 2 memory mapped registers for accessing the other IO-APIC registers: 

| Memory Address | Mnemonic Name | Register Name      | Description                                  |
|----------------|---------------|--------------------|----------------------------------------------|
|   FEC0 0000h   | IOREGSEL      | I/O Register Select| Is used to select the I/O Register to access |
|   FEC0 0010h   | IOWIN         | I/O Window (data)  | Used to access data selected by IOREGSEL     |

And then there are 4 I/O Registers that can be accessed using the two above: 

| Name      | Offset   | Description                                            | Attribute | 
|:------------:|----------|--------------------------------------------------------|-----------|
| IOAPICID  | 00h      | Identification register for the IOAPIC                 |  R/W      |
| IOAPICVER | 01h      | IO APIC Version                                        |  RO       |
| IOAPICARB | 02h      | It contains the BUS arbitration priority for the IOAPIC|  RO       |
| IOREDTBL  | 03h-3fh  | The redirection tables (see the IOREDTBL paragraph)    |  RW       |


### Reading data from IO-APIC

There are basically two addresses that we need to use in order to write/read data from apic registers and they are: 

* IO_APIC_BASE address, that is the base address of the IOAPIC, called *register select* (or IOREGSEL)  and used to select the offset of the register we want to read
* IO_APIC_BASE + 0x10, called *i/o window register* (or IOWIN), is the memory location mapped to the register we intend to read/write specified by the contents of the *Register Select*

The format of the IOREGSEL is: 

| Bit     | Description                                                                                                          |
|---------|----------------------------------------------------------------------------------------------------------------------|
| 31:8    | Reserved                                                                                                             |
| 7:0     | APIC Register Address, they specifies the IOAPIC Registers to be read or written via the IOWIN Register              |

So basically if we want to read/write a register of the IOAPIC we need to: 

1. write the register index in the IOREGSEL register
2. read/write the content of the register selected in IOWIN register

The actual read or write operation is performed when IOWIN is accessed.
Accessing IOREGSEL has no side effects.

### Interrupt source overrides
They contain differences between the IA-PC standard and the dual 8250 interrupt definitions. The isa interrupts should be identity mapped into the first IO-APIC sources, but most of the time there will be at least one exception. This table contains those exceptions. 

An example is the PIT Timer is connected to ISA IRQ 0, but when apic is enabled it is connected to the IO-APIC interrupt input pin 2, so in this case we need an interrupt source override where the Source entry (bus source) is 0 and the global system interrupt is 2
The values stored in the IO Apic Interrupt source overrides in the MADT are:

| Offset | Length | Description                  |
|--------|--------|------------------------------|
| 2      | 1      | bus source (it should be 0)  |
| 3      | 1      | irq source                   |
| 4      | 4      | Global System Interrupt      |
| 8      | 2      | Flags                        |

* Bus source usually is constant and is 0 (is the ISA irq source), starting from ACPI v2 it is also a reserved field. 
* Irq source is the source IRQ pin
* Global system interrupt is the target IRQ on the APIC

Flags are defined as follows: 

* Polarity (*Lenght*: **2 bits**, *Offset*: *0*  of the APIC/IO input signals, possible values are:
    * 00 Use the default settings is active-low for level-triggered interrupts)
    * 01 Active High
    * 10 Reserved
    * 11 Active Low
* Trigger Mode (*Length*: **2 bits**, *Offset*: *2*) Trigger mode of the APIC I/O Input signals:
    * 00 Use the default settiungs (in the ISA is edge-triggered)
    * 01 Edge-triggered
    * 10 Reserved
    * 11 Level-Triggered
* Reserved (*Length*: **12 bits**, *Offset*: **4**) this must be 0


### IO Redirection Table (IOREDTBL)

TODO **DRAFT**

They can be accessed vie memory mapped registers. Each entry is composed of 2 registers (starting from offset 10h). So for example the first entry will be composed by registers 10h and 11h.

The content of each entry is:

* The lower double word is basically an LVT entry, so for their definition check the LVT entry definition
* The upper double word contains:
    - Bits 17 to 55 are Reserved
    - Bits 56 to 63 are the Destitnation Field, In physical addressing mode (se the destination bit of the entry) it is the local apic id to forward the interrupts to, for more information read the IO-APIC datasheet.

The number of items is stored in the IO-APIC MADT entry, but usually on modern architectures is 24. 


#### Delivery modes

 TBD

## Useful Resources

* Intel Software developer's manual Vol 3A APIC Chapter
* IOAPIC Datasheet https://pdos.csail.mit.edu/6.828/2016/readings/ia32/ioapic.pdf
* http://www.brokenthorn.com/Resources/OSDevPic.html 

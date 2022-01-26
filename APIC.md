# APIC 

## Types of APIC

There are mainly two types of APIC:

* Local APIC
* IO/APIC


## Local APIC
 
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

Every entry of the local APIC has the following information:

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

With few exceptions:

* TBD...

## IOAPIC

### Configure the IO-APIC

TODO

To configure the IO-APIC we need to: 

(To check if the steps are accurate...)

1. Get the IO-APIC base address from the MADT
2. Read the IO-APIC Interrupt Source Override table
3. Initialize the IO Redirection table entries for the interrupt we want to enable

### Getting IO-APIC address

TODO

1. Read IO-APIC information from MADT table (the MADT table is available within the RSDT data (please refer here: https://github.com/dreamos82/Osdev-Notes/blob/master/RSDP_and_RSDT.md), you need to search for the MADT Table item type 1). The content of the MADT Table for the IO_APIC type is: 

| Offset | Length | Description                  |
|--------|--------|------------------------------|
| 2      | 1      | I/O Apic ID's                |
| 3      | 1      | Reserved (should be 0)       |
| 4      | 4      | I/O Apic Address             |
| 8      | 4      | Global System Interrupt Base |

The Global System Interrupt Base is the first interrupt number that the I/O Apic handles, to check how many interrupt the IO/APIC handle you can read this information from the IOAPICVER Register


### IO-APIC Registers
The IO-APIC has 2 memory mapped registers for accessing the other IO-APIC registers: 

| Memory Address | Mnemonic Name | Register Name      | Description                                  |
|----------------|---------------|--------------------|----------------------------------------------|
|   FEC0 0000h   | IOREGSEL      | I/O Register Select| Is used to select the I/O Register to access |
|   FEC0 0010h   | IOWIN         | I/O Window (data)  | USed to access data selected by IOREGSEL     |

And then there are 4 I/O Registers that can be accessed using the two above: 

| Name      | Offset   | Description                                                        | Attribute | 
|-----------|----------|--------------------------------------------------------------------|-----------|
| IOAPICID  | 00h      | Identification register for the IOAPIC                             |  R/W      |
| IOAPICVER | 01h      | It identify the IO APIC Version                                    |  RO       |
| IOAPICARB | 02h      | It contains the BUS arbitration priority for the IOAPIC            |  RO       |
| IOREDTBL  | 03h-3fh  | These are the redirection tables (refer to the IOREDTBL paragraph) |  RW       |


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

### Interrupt source overrides
They contains differences between the IA-PC standard and the dual 8250 interrupt definitions. The isa interrupts should be identity mapped into the first IO-APIC sources, but most of the time there will be at least one exception. This table contains those exceptions. 
An example is the PIT Timer is connected to ISA IRQ 0, but when apic is enabled it is connected to the IO-APIC interrupt input pin 2, so in this case we need an interrupt source override where the Source entry (bus source) is 0 and the global system interrupt is 2
The values stored in the IO Apic Interrupt source overrides in the MADT are:

| Offset | Length | Description                  |
|--------|--------|------------------------------|
| 2      | 1      | bus source (it should be 0)  |
| 3      | 1      | irq source                   |
| 4      | 4      | Global System Interrupt      |
| 8      | 2      | Flags                        |

* Bus source usually is constant and is 0 (is the ISA irq source)
* Irq source is ...

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


### IO Redirection Table

TODO **DRAFT**

They can be accessed vie memory mapped registers. Each entry is composed of 2 registers (starting from offset 10h). So for example the first entry will be composed by registers 10h and 11h.

The content of each entry is:

* The lower double word is basically an LVT entry, so for their definition check the LVT entry definition
  

The number of items is stored in the IO-APIC MADT entry, but usually on modern architectures is 24. 

####Delivery modes

 TBD

## Useful Resources

* Intel Software developer's manual Vol 3A APIC Chapter
* IOAPIC Datasheet https://pdos.csail.mit.edu/6.828/2016/readings/ia32/ioapic.pdf

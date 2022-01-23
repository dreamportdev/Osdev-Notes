# APIC 

## Types of APIC

There are mainly two types of APIC:

* Local APIC
* IO/APIC


## Getting local apic information

You need to read the IA32_APIC_BASE MSR register, using the __rdmsr__ command. The value for this register is 1Bh. 

This register contains the following information: 

* Bits 0:7 Are reserved
* Bit 8 if set it means that the processor is the Bootstrap Processor (BSP)
* Bits 9:10 Are reserved
* Bit 11 APIC Global Enable if is set it means the APIC is enabled.
* Bits 12:31 Are the base address of the APIC (Apic Base Address)
* Bits 32:63 Are reserved.

The Apic Registers are all mapped in one Page of memory. Please be aware that if you have paging enabled, you will probably need to map the IOAPIC Base address on the page dirs table. 

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

The actual read or write operation is performed when IOWIN is accessed.
Accessing IOREGSEL has no side effects.

### IOREDTBL

TODO

## Useful Resources

* Intel Software developer's manual Vol 3A APIC Chapter
* IOAPIC Datasheet https://pdos.csail.mit.edu/6.828/2016/readings/ia32/ioapic.pdf

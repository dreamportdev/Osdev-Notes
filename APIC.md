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

The Apic Registers are all mapped in one Page of memory. Please be aware that if you have pagination enabled, you will probably need to map the IOAPIC Base address on the page dirs table. 

## IOAPIC

### Getting IO-APIC address

### Reading data from IO-APIC

There are basically two addresses that we need to use in order to write/read data from apic registers and they are: 

* IO_APIC_BASE address, that is the base address of the IOAPIC, called *register select* (or IOREGSEL)  and used to select the offset of the register we want to read
* IO_APIC_BASAE + 0x10, called *i/o window register* (or IOWIN), is the memory location mapped to the register we intend to read/write specified by the ocntents of the *Register Select*

The format of the IOREGSEL is: 

| Bit     | Description                                                                                                          |
|---------|----------------------------------------------------------------------------------------------------------------------|
| 31:8    | Reserved                                                                                                             |
| 7:0     | APIC Register Address, they specifies the IOAPIC Registers to be read or wrttne via the IOWIN Register               |
|
## Useful Resources

* Intel Software developer's manual Vol 3A APIC Chapter

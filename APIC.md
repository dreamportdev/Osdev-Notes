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

The Apic Registers are all mapped in one Page of memory.  

## Useful Resources

* Intel Software developer's manual Vol 3A Chapter 8

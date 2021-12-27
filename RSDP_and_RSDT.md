# RSDP and RSDT/XSDT

## RSDP

The RSDP is the pointer to the RSDT (Root System Descriptor Table) the full structure is depending if the version of ACPI used is 1 or 2, the newer version is just extending the previous one.
The newer version is backward compatible with the older

### RSDP Structure
Basic data structure for RSDP v1 is: 

```C
struct RSDPDescriptor {
 char Signature[8];
 uint8_t Checksum;
 char OEMID[6];
 uint8_t Revision;
 uint32_t RsdtAddress;
} __attribute__ ((packed));
```

Where the fields are: 

* *Signature*: Is an 8 byte string, that must contain: "RSDT PTR " **P.S. The string is not null terminated** 
* *Checksum*: The value to add to all the other bytes (of the Version 1.0 table) to calculate the Checksum of the table. If this value added to all the others and casted to byte isn't equal to 0, the table must be ignored.
* *OEMID*: Is a string that identifies the OEM 
* *Revision*: Is the revision number
* *RSDTAddress*: The address of the RSDT Table

(TODO: Add XSDT info)
## RSDT Data structure and filelds

RSDT (Root System Description Table) is a data structure used in the ACPI programming interface. This table contains pointers many different table descriptors.

The Rsdt is the root of other many different Descriptor tables (SDT), all of them may be splitted in two parts: 

* the first part is the header, common between all the SDTs with the following structure:
```C
struct ACPISDTHeader {
  char Signature[4];
  uint32_t Length;
  uint8_t Revision;
  uint8_t Checksum;
  char OEMID[6];
  char OEMTableID[8];
  uint32_t OEMRevision;
  uint32_t CreatorID;
  uint32_t CreatorRevision;
};
```
* The secon part is the table itself, every SDT has it's own table


## Some useful infos

*  Be aware that the Signature in the RSD*  structure is not null terminated. This means that if you try to print it, you will most likely end up in printing garbage in the best case scenario.
*  The RSDT Data is an array of uint32_t addresses. The number of items in the RSDT can be computed in the following way:
```C
uint32_t number_of_items = (rsdt->header.Length - sizeof(header)) / 4
```
(Formula to be checked)

### Useful links

* Osdev wiki page for RSDP: https://wiki.osdev.org/RSDP
* Osdev wiki page for RSDT: https://wiki.osdev.org/RSDT


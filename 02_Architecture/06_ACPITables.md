# ACPI Tables

ACPI (Advanced Configuration and Power Interface) is a Power Management and configuration standard for the PC, it allows operating systems to control many different hardware features, like the amount of power on each device, thermal zones, fan control, IRQs, battery levels, etc.

We need to access the ACPI Tables in order to read the IO-APIC information, used to receive hardware interrupts (it will be explained later).

## RSDP and RSDT/XSDT

Most of the information is organized and accessible through different data structures, but since the ACPI spec is quite big, and covers so many different components, we focus only on what we need to get the information about the APIC.

Before proceeding, let's keep in mind that all address described below are physical, so if we we have enabled paging, we need to ensure they are properly mapped in the virtual memory space.

### RSDP

The RSDP (Root System Description Pointer) used in the ACPI programming interface is the pointer to the RSDT (Root System Descriptor Table), the full structure depends if the version of ACPI used is 1 or 2, the newer version is just extending the previous one.

The newer version is backward compatible with the older.

#### Accessing the RSDP

Accessing the RSDP register depends on the boot system used, if we are using grub, we get a copy of the RSDT/XSDT in one of the multiboot2 header tags. The specs contains two possible tags for the RSDP value, which one is used depend on the version:

* For the version 1 the MULTIBOOT_TAG_TYPE_ACPI_OLD is used (type 14)
* For the version 2 the MULTIBOOT_TAG_TYPE_ACPI_NEW is used (type 15)

Both headers are identical, with the only difference being in the type value, they are composed of just two fields:

* The type field that can be 14 or 15 depending on the version
* The size of the RSDP

And is followed by the RSDP itself.

#### RSDP Structure

As already mentioned there are two different version of RSDP, basic data structure for RSDP v1 is:

```c
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

The structure for the v2 header is an extension of the previous one, so the fields above are still valid, but in addition it has also the following extra-fields:

```c
struct RSDP2Descriptor {
    //v1 fields
    uint32_t Length;
    uint64_t XSDTAddress;
    uint8_t ExtendedChecksum;
    uint8_t Reserved[3];
};
```

* *Length*: is the length of this data and its data, meaning the xsdt + all the other SDTs.
* *XSDTAddress*: Address of the XSDT table. If this is non-zero, the RSDT address **must** be ignored and the XSDT is to be used instead.
* *ExtendedChecksum*: Same as the previous checksum, just includes the new fields.

#### RSDP Validation

Before proceeding, let's explain a little bit better the validation. For both version what we need to check is that the sum of all bytes composing the descriptor structure have last byte equals to 0. How is possible to achieve that, and keep the same function for both? That is pretty easy, we just need cast the `RSDP*Descriptor` to a char pointer, and pass the size of the correct struct. Once we have done that is just matter of cycling a byte array. Here the example code:

```c
bool validate_RSDP(char *byte_array, size_t size) {
    uint32_t sum = 0;
    for(int i = 0; i < size; i++) {
        sum += byte_array[i];
    }
    return (sum & 0xFF) == 0;
}
```

Having last byte means that `result mod 0x100` is 0. Now there are two ways to test it:

* Using the `mod` instruction, and check the result, if is 0 the structure is valid, otherwise it should be ignored.
* Just checking the last byte of the result it can be achieved in several ways: for example is possible  cast the result to `uint_8` if the content after casting is 0 the struct is valid, or use bitwise AND with `0xFF` value (`0xFF` is equivalent to the `0b11111111` byte) `sum & 0xFF`, if it is 0 the struct is valid otherwise it has to be ignored.

The function above works perfectly with both versions of descriptors.
In the XSDT, since it has more fields, the previous checksum field won't offset them properly (because it doesn't know about them), so this is why an extended checksum field is added.

### RSDT Data structure and fields

RSDT (Root System Description Table) is a data structure used in the ACPI programming interface. This table contains pointers to many different table descriptor (SDTs). Explaining all the tables is beyond of the scope of these notes, and for our purpose we are going to need only one of those table (the APIC table that we will encounter later).

Since every SDT table contains different type of information, they are all different from each other, we can define an RSDT table by the composition of two parts:

* The first part is the header, common between all the SDTs with the following structure:

```c
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
* The second part is the table itself, every SDT has its own table

#### RSDT vs XSDT

These 2 tables have the same purpose and are mutually exclusive. If the latter exists, the former is to be ignored, otherwise use the former.

The RSDT is an SDT header followed by an array of `uint32_t`s, representing the address of another SDT header.

The XSDT is the same, except the array is of `uint64_t`s.

```c
struct RSDP {
    ACPISDTHeader sdtHeader; //signature "RSDP"
    uint32_t sdtAddresses[];
};

struct XSDT {
    ACPISDTHeader sdtHeader; //signature "XSDT"
    uint64_t sdtAddresses[];
};
```

This means that if we want to get the n-th SDT table we just need to acces the corresponding item in the *SDT array:

```c
//to get the sdt header at n index
ACPISDTHeader* header = (ACPISDTHeader*)(use_xsdt ? xsdt->sdtAddresses[n] : (uint64_t)rsdt->sdtAddresses[n]);
```

### Some useful infos

*  Be aware that the Signature in the RSD*  structure is not null terminated. This means that if we try to print it, you will most likely end up in printing garbage in the best case scenario.
*  The RSDT Data is an array of uint32_t addresses while the XSDT data is an array of uint64_t addresses. The number of items in the RSDT and XSDT can be computed in the following way:

```c
//for the RSDT
size_t number_of_items = (rsdt->sdtHeader.Length - sizeof(ACPISDTheader)) / 4;
//for the XSDT
size_t number_of_items = (xsdt->sdtHeader.Length - sizeof(ACPISDTHeader)) / 8;
```

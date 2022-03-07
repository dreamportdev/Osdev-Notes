# FACP

The FADT, of which the signature is FACP, refers to the Fixed ACPI Description Table and is pointed by the RSDT.
FACP can be used for ACPI shutdown etc.
ACPI shutdown via FACP can be done both in Virtual Machines and Real PCs.

So how can I find the FACP?
The RSDT has entries that point to ACPI, FADT and more.
The entries are 4 in number, and each of them are pointing to the tables.
FACP is one of them and could be found by strncmp like functions.
Here is the example code:
```c
if(strncmp(header->Signature, "FACP", 4)==0){
	printf("FACP found\n");
}
```
The address of the FADT can be found by comparing the 4 bytes of the signature field with the text "FADT". This is the same as how other SDT headers are found.
They aren't null terminated, so it would be better using memorystring compare than string comapare.

## Structure of the FACP
The structure of it is basically: 

```C
struct facp {
  acpi_header_t head;
  uint32_t firmware_ctrl;
  uint32_t dsdt;
  uint8_t reserved;
  uint8_t pref_pm_prof;
  uint16_t sci_int;
  uint32_t smi_cmd;
  uint8_t acpi_enable;
  uint8_t acpi_disable;
  uint8_t pstate_cnt;
  uint32_t PM1a_EVT_BLK;
  uint32_t PM1b_EVT_BLK;
  uint32_t PM1a_CNT_BLK;
  uint32_t PM1b_CNT_BLK;
  uint32_t PM2_CNT_BLK;
  uint32_t PM_TMR_BLK;
  uint32_t GPE0_BLK;
  uint32_t GPE1_BLK;
  uint8_t PM1_EVT_len;
  uint8_t PM1_CNT_len;
  uint8_t PM2_CNT_LEN;
  uint8_t PM_TMR_LEN;
  uint8_t GPE0_BLK_LEN;
  uint8_t GPE1_BLK_LEN;
  uint8_t GPE1_BASE;
  uint8_t CST_CNT;
  uint16_t P_LVL2_LAT;
  uint16_t P_LVL3_LAT;
  uint16_t FLUSH_SIZE;
  uint16_t FLUSH_STRIDE;
  uint8_t duty_offset;
  uint8_t duty_width;
  uint8_t day_alrn;
  uint8_t mon_alrm;
  uint8_t century;
  uint16_t iapc_boot_arch;
  uint8_t reservedi;
  uint32_t flags;
  addr_type_t reset_reg;
  uint8_t reset_value;
  uint16_t arm_boot_arch;
  uint8_t fadt_minor_version;
  uint64_t x_firmware_ctrl;
  uint64_t x_dsdt;
  addr_type_t X_PM1a_EVT_BLK;
  addr_type_t X_PM1b_EVT_BLK;
  addr_type_t X_PM1a_CNT_BLK;
  addr_type_t X_PM1b_CNT_BLK;
  addr_type_t X_PM2_CNT_BLK;
  addr_type_t X_PM_TMR_BLK;
  addr_type_t X_GPE0_BLK;
  addr_type_t X_GPE1_BLK;
  addr_type_t SLEEP_CONTROL_REG;
  addr_type_t SLEEP_STATUS_REG;
  uint64_t hv_vendor_identity;
  //More going to be added
}
```
.

It contains the header, the DSDT pointer, and blocks.
The blocks will be used for shutdown.

## Shutdown via FACP
The ACPI shutdown is known as easy as several couple lines, however, enablement and initialization is neccessary for the shutdown code.

### I. Enabling the ACPI

Enabling the ACPI is done with the following steps:

1. Check if ACPI is enabled
2. Check if ACPI is enabled
3. If not-->enable ACPI, If yes-->stop because it is already
4. Check if ACPI is enabled
5. If yes-->Enable ACPI, If no-->send error

The first check, step 1, could be done by comparing inw PM1a CNT Block &(AND operator) SCI_EN and 0

Code: `inw((uint16_t) PM1a_CNT_BLK) & (uint16_t) SCI_EN) == 0`

The next check can be done by checking if smi cmd and acpi enable is 0

If yes, the ACPI is already enabled for you, if not, it isn't.

Code again: `smi_cmd != 0 && acpi_enable != 0`

Now it's time to enable the ACPI with a single line of code:

`outb((uint16_t) smi_cmd, acpi_enable);`

It outbytes data acpi enable to smi cmd port

and finally we need to check if it enabled the ACPI. It can be done by 3 steps:

1. For the PM1a CNT Block: Could it work?
```c
int i;
for(i = 0; i < 300; i++){
	if(inw((uint16_t) PM1a_CNT_BLK & (uint16_t) SCI_EN) == 1){
		break;
	}
		// If else, you can sleep a bit and continue again!!
}
```
2. Do the same thing for the pm2b cnt block.
3. Give error if not, give success message if is.

### II. ACPI initialization

You must have found the FACP and have the header.

S5 Address can be found by several lines of code basically doing a while

But you need to first add 36 from the DSDT as the address, get the dsdt length as the following code, and finally do a while until DSDT Length -- is greater than 0
The code below performs a check at every byte, looking for a sequence of 4 characters, you should compare the first 4 characters via memcmp like functions and when you find it, you'll break and continue to the next step. Don't forget to add 1 every time to the address or you will not get the loop properly.
```c
	uint8_t* s5_addr = (uint8_t*) facp->dsdt + 36;
	int dsdt_len = *(facp->dsdt + 1) - 36;
	while(0 < dsdt_len--){
		if(memcmp(s5_addr, "_S5_", 4)==0){
			break;
		}
		s5_addr++;
	}
```
Now that you have found the S5 addr then you will go make the init acpi function.

All the stuff explained below will happen given that the DSDT length is greater than 0, which mean it has any data so you might want to get a while for this thing.

First you need to check if AML is valid.

You need to check if everything is in the right place.

Your check to make it valid needs information below:

| Encoding name | Encoding value | 
| --------------|----------------|
|   NameOp    |  0x08        |
|   Byteprefix    |  0x0A        |
|   Byteprefix    |  0x12        |

Figure 1

|               | PackageOP	 | Package Length | NumElements	   | Byteprefix#    | Byteprefix#    | Byteprefix#    | Byteprefix#    |
| --------------|----------------|----------------|----------------|----------------|----------------|----------------|----------------|
|   Data        |                |                |                | SLP_TYPa       | SLP_TYPb       | Res.           | Res.           |
|   Enc. Val.   |                |                |  0x04          |                |                |                |                |

Figure 2

Figure 1 and 2 explains the encoding value of the encoding name and how all these look like repectively as a photo.

An example of the explaination:
```c
if((*(s5_addr - 1) == 0x08 || ( *(s5_addr - 2) == 0x08 && *(s5_addr - 1) == '\\') ) && *(s5_addr + 4) == 0x12){
	s5_addr += 5;
	s5_addr += ((*s5_addr & 0xC0) >> 6) + 2;
	
	if (*s5_addr == 0x0A){
		s5_addr++;
	}
	SLP_TYPa = *(s5_addr) << 10;
	s5_addr++;
			
	if (*s5_addr == 0x0A){
		s5_addr++;
	}
	SLP_TYPb = *(s5_addr) << 10;
```

Next, make all the defined data the same as the one of the FACP.

### III. The shutdown via ACPI

Now we've got everything done.

You first need to enable the ACPI, and then do the following code:
```c
outw((uint16_t)PM1a_CNT_BLK, SLP_TYPa | SLP_EN );
if (PM1b_CNT_BLK != 0){
	outw((uint16_t)PM1b_CNT_BLK, SLP_TYPb | SLP_EN );
}
```

Now we have the ACPI shutdown here.

## Useful Resouces

- ACPI spec https://uefi.org/specs/ACPI/6.4/index.html#

- OSDev wiki FACP https://wiki.osdev.org/FADT

- OSDev wiki Shutdown https://wiki.osdev.org/Shutdown

- OSDev forum Shutdown via FACP https://forum.osdev.org/viewtopic.php?t=16990

- Example code (AhnTriOS) https://github.com/AhnJihwan/AhnTri/blob/main/drivers/acpi.c#L194

- OSDev wiki AML https://wiki.osdev.org/AML


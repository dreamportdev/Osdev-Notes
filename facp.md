# FACP

The FADT, of which the signiture is FACP, refers to the Fixed ACPI Description Table, and is pointed by the RSDT.
FACP can be used for ACPI shutdown etc.
ACPI shutdown via FACP can be done both in Virtual Machines and Real PCs.

So how can I find the FACP?
The RSDT has entries that point to ACPI, FADT and more.
The entries are 4 in number, and each of them are pointing to the tables.
FACP is one of them, and could be found by strncmp like functions.
Here is the example code:
```c
if(strncmp(header->Signature, "FACP", 4)==0){
	printf("FACP found\n");
}
```
One can find the address of it via comparing strings.

### Structure of the FACP
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

More... Comming soon...

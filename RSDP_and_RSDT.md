# RSDP and RSDT

## RSDT Data structure and filelds

(ToDo)

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


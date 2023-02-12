# Framebuffer

One way to enable framebuffer is asking grub to do it. 

## Setting framebuffer using grub

To enable framebuffer using grub, you need to add the relevant tag in the multiboot2 header. 
So in the tag section you need to add: 

```assembly
framebuffer_tag_start:
    dw  0x05    ;Type: framebuffer
    dw  0x01    ;Optional tag
    dd  framebuffer_tag_end - framebuffer_tag_start ;size
    dd  0   ;Width - if 0 we let the bootloader decide
    dd  0   ;Height - same as above
    dd  0   ;Depth  - same as above
framebuffer_tag_end:
```

The comments are self explanatory. 

## Accessing the framebuffer from the kernel

Once the framebuffer is set in the multiboot header, when grub loads the kernel it should add  a new tag: the framebuffer info tag. As explained in the Multiboot paragraph, if you are 
using the header provided in the documentation, you should already have a *struct multiboot_tag_framebuffer*, otherwise you should create your own.  

The basic structure of the framebuffer info tag is: 

| Size    | Description        |
|---------|--------------------|
| u32     | type = 8           |
| u32     | size               |
| u64     | framebuffer_addr   |
| u32     | framebuffer_pitch  |
| u32     | framebuffer_width  |
| u32     | framebuffer_height |
| u8      | framebuffer_bpp    |
| u8      | framebuffer_type   |
| u8      | reserved           |
| varies  | color_info         |
        
Where: 

* *type* is the type of the tag being read, and 8 means that it is a Framebuffer info tag.
* *size* it indicates the size of the tag (header info included)
* *framebuffer_addr* it contains the current address of the framebuffer
* *framebuffer_pitch* contains the pitch in bytes
* *framebuffer_width* contains the fb width
* *framebuffer_height* contains the fb height
* *framebuffer_bpp* it contains the number of bits per pixel (is the depth in the multiboot request tag)
* *framebuffer_type* it indicates the current type of FB, and the content of color_index
* *reserved* is always 0 and should be ignored.
* *color_info*  it depends on the framebuffer type. 

**Pitch** is the number of bytes on each row
**bpp** is same as depths

## Framebuffer type

Depending on the framebuffer_type value you have different values for color_info field.

* If frambuffer_type is 0 this means indexed colors, this means that the color-info field has the following values:

| Size    | Description                    |
|---------|--------------------------------|
| u32     | framebuffer_palette_num_colors |
| varies  | framebuffer_palette            |

The framebuffer_palette_num_colors is the number of colors available in the palette, and the framebuffer plaette is an array of colour descriptors, where every colour has the following structure:

| Size    | Description                    |
|---------|--------------------------------|
| u8      | red_val                        |
| u8      | green_val                      |
| u8      | blue_val                       |

    
* If it is 1 it means direct RGB color, then the color_type is defined as follows: 	

Size   | Description					  |
-------|----------------------------------|
u8     | framebuffer_red_field_position   |
u8     | framebuffer_red_mask_size        |
u8     | framebuffer_green_field_position |
u8     | framebuffer_green_mask_size      |
u8     | framebuffer_blue_field_position  |
u8     | framebuffer_blue_mask_size       |

Where framebuffer_XXX_field_position is the starting bit of the color XXX, and the framebuffer_XXX_mask_size is the size in bits of the color XXX. Usually the format is 0xRRGGBB (is the same format used in HTML).

* If it is 2, it means EGA text, so the width and height are specified in characters and not pixels, framebuffer-bpp = 16 and framebuffer_pitch is expressed in byte text per line.

### Plotting a pixel

Everything that we see on the screen with the framebuffer enabled will be done by the function that plot pixels. 

Plotting a pixel is pretty easy, we just need to fill the value of a specific address with the colour we want for that pixel. What we need for drawing pixel then is: 

* Position in the screen (x and y coordinates)
* Colour we want to use (we can pass the color code or just get the rgb value and compose it)
* The framebuffer base address

The first thing we need to do when we want to plot a pixel is to compute the address of the pixel at row y and column x is how many bytes are in one row, and how many bytes are in one pixel. These information are present in the multiboot framebuffer info tag: 

* The field *framebuffer_pitch*, that is number of bytes in each row
* The field *bpp* is the number of bits on a pixel

If we want to know the actual row offset we need then to: 

```math
row = y * framebuffer_pitch
```

and similarly for the column we need to: 

```math
column = x * bpp
```

Now we have the offset in byte for both the row and column byte, to compute the absolute address of our pixel we need just need to add row and column to the base address: 

```math
pixel_position = base_address + column + row
```

This address is the location where we are going to write a colour value and it will be displayed on our screen. 

**Please be aware that the framebuffer base_address is an absolute phisical address, and on the early stages of our OS is totally fine, but remember that when/if we are going to enable virtual memory, the framebuffer address will need to be mapped somewhere. And the base_address could change, depending on design decisions, this will be explained later**

### Useful resources
* https://jmnl.xyz/window-manager/

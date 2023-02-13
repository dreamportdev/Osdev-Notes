# Video Output and Framebuffer

One of the first thing we want to do is make our Operating System capable of producing some kind of screen output, even if not strictly necessary (there can be different ways to debug our OS behaviour while developing), it can be useful sometime to visualize something in real time, and probably especially if at the beginning of our project, is probably very motivating having our os print a nice logo, or write some fancy text.

As per many other parts there are different way to produce output on the screen, in this book we are covering only the framebuffer, but below is a short list of some of the available modes

* If you are in real mode (16 bits) there is an interrupt that can be used print characters/strings, and you have the possibility to use other interrupts to draw pixels and ui on the screen.
* The legacy VGA driver, if your os is targeting old hardware (ie x86-32) and don't care to have a gui, this is probably the simplest and easiest approach. It's very easy to implement, the VGA memory starts at 0xb800, and the screen is composed by 80 columns and 25 rows, each cell contains one character. Each characters is represented by two bytes, one for the ascii code of the character, and the other for the color.
* On many systems (old and modern)  the framebuffer can be used, that is covered by this chapter
* If the operating system is using UEFI, the GOP mode can be used.

In this guide we cover the Framebuffer, since it is probably the one most widely supported on systems that are at least 32bits.


## Setting framebuffer (using grub)

One way to enable framebuffer is asking grub to do it (this can be done also using uefi but it is not covered in this chapter). 

To enable it, you need to add the relevant tag in the multiboot2 header. 
Simply we just need to add in the tag section a new item, like the one below, to request to grub to enable the framebuffer if avaiable, with the requested configuration:

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

Once the framebuffer is set in the multiboot header, when grub loads the kernel it should add  a new tag: the `framebuffer_info` tag. As explained in the Multiboot paragraph, if you are 
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

* If frambuffer_type is 0 this means indexed colors, and that the color-info field has the following values:

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

    
* If it is 1 it means direct RGB color, then the `color_type` is defined as follows: 	

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

## Plotting a pixel

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

### Drawing an image

Now that we have a plot pixel function is time to draw something nice on the screen. Usually to do this we should have a file system supported, and at least an image format implemented. But some graphic tools, like *The Gimp* provide an option to save an image into `C source code header`, or `C source code`. 

If we save the image as C source header code, we get a `.h` file with a variable `static char* header_data`, and few extra attribute variables that contains the width and height of the image, and also a helper function called `HEADER_PIXEL` that extract the pixel and move to the next at every call: 

The helper function is called in the following way: 

```c
HEADER_PIXEL(logo_data, pixel)
```

where `logo_data` is a pointer to the image content and `pixel` is an array of 4 chars, that will contain the pixel values.

Now since each pixel is identified by 3 colors and we have 4 elements into an array, we know that the last element (`pixel[3]`) is always zero. The color is encoded in RGB format with Blue being the least significant byte, and to plot that pixel we need to fill a 32 bit address, so the array need to be converted into a `uint32_t` variable, this can easily be done with some bitwise operatory: 

```c
char *pixel[4];
HEADER_PIXEL(logo_data, pixel)
pixel[3] = 0;
uint32_t num = (uint32_t) pixel[0] << 24 |
    (uint32_t)pixel[1] << 16 |
    (uint32_t)pixel[2] << 8  |
    (uint32_t)pixel[3];

```

as you can see we are making sure that the value of `pixel[3] is zero, since the `HEADER_PIXEL` function is not touching it. Now the value of `num` will be the colour of the pixel to be plotted. 

With this value we can call the function we have created to plot the pixel with the color indicated by `num`. 

Using width and height given by the gimp header, and a given staring position x, y to draw an image we just need to iterate through the pixels using a nested for loop, to iterate through rows (x) and columns (y) using height and width as limits.

### Useful resources

* https://jmnl.xyz/window-manager/

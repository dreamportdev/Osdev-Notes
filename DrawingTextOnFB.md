# Drawing fonts

When framebuffer is enabled, the hardware bios video memory is no longer accessible, and the only things that we can do now is drawing pixels. 

So in order to write text we need first to have at least one font available to our operating system and how to store it.

The font can be one of many different available (ttf, psf, etc.) in this tutorial we will use Pc Screen Font v2 aka PSF (keep in mind that v1 has some differences in the header, if you want to support that as well, you need to adapt the code)

**How** the font is stored depends on the status of your operating system, there are several way: 

* Store it in memory (if your OS doesn't support a file sytem yet)
* In case you already have a file system, it could be better to store them in a file
* You can also get a copy of the VGA Fonts in memory, using grub.

If you are running on linux you can find some nearly ready to use fonts in */usr/share/consolefonts*

Once you got your the font, it needs first to be converted into a ELF binary file that can be linked to our kernel. 

To do that you can use the following command: 

```bash
objcopy -O elf64-x86-64 -B i386 -I binary font.psf font.o
```

The parameters are: 
* -O the output format (in my case was elf64-x86-64) 
* -B is the binary architecture 
* -I the inpurt target

Once converted into binary elf, we can link it to the kernel like any other compiled file, to do that just add the output file to the linker command: 

```bash
ld -n -o build/kernel.bin -T src/linker.ld <other_kernel_files> font.o -Map build/kernel.map
```

With the font linked, we will have access to 3 new variables, like in the following example: 

```bash
readelf -s font.o

Symbol table '.symtab' contains 5 entries:
   Num:    Value          Size Type    Bind   Vis      Ndx Name
     0: 0000000000000000     0 NOTYPE  LOCAL  DEFAULT  UND 
     1: 0000000000000000     0 SECTION LOCAL  DEFAULT    1 
     2: 0000000000000000     0 NOTYPE  GLOBAL DEFAULT    1 _binary_font_psf_start
     3: 0000000000008020     0 NOTYPE  GLOBAL DEFAULT    1 _binary_font_psf_end
     4: 0000000000008020     0 NOTYPE  GLOBAL DEFAULT  ABS _binary_font_psf_size
```
(the variable name depends on the font name). 

The psf structure header has a fixed size of 32 bytes, with the following information: 

* *magic* a magic value, that is: 0x864ab572
* *version* is 0
* *headersize* it should always be 32
* *flags* 0 indicates there is no unicode table)
* *numglyphs* The number of glyphs available
* *bytesperglyph* Number of bytes per each glyph
* *height* Height of each glyph in pixels
* *width* Width in pixels of each glyph. 

All the fields are 4 bytes in size, so creating a structure that can hold it is pretty trivial.

Let's assume from now on that we have a data structure called PSF_font with all the fields specified above. The first thing that we need of course, is to access to this variable: 

```C
// We have linked _binary_font_psf_start from another .o file so we must specify that we are dealing
// with an external variable 
extern char _binary_font_psf_start; 
PSF_font *default_font = (PSF_font *)&_binary_font_psf_start
```

## Glyph

Now that we have access to our PSF font, we can work with "Glyphs"
Every character (Glyph) is stored in a bitmap. Each bitmap is *WidthxHeight* pixel . If for example the glyph is 8x16, it will be 16 bytes long, every byte encode a row of the glyph. 
Below an example of how a glyph is stored:

```
00000000b  byte  0
00000000b  byte  1
00000000b  byte  2
00010000b  byte  3
00111000b  byte  4
01101100b  byte  5
11000110b  byte  6
11000110b  byte  7
11111110b  byte  8
11000110b  byte  9
11000110b  byte 10
11000110b  byte 11
11000110b  byte 12
00000000b  byte 13
00000000b  byte 14
00000000b  byte 15
```
(This is the letter A).

The glyphs start right after the psf header, the address of the first character will be then: 

```C
uint8_t* first_glyph = (uint8_t*) &_binary_font_psf_start + default_font->headersize
```

Since we know that every glyph has the same size, and this is available in the PSF_Header, if we want to access the *i-th* character, we just need to do the following: 

```C
uint8_t* selected_glyph = (uint8_t*) &_binary_font_psf_start + default_font->headersize + (i * default_font->bytesperglyph);
```

If we want to write a function to display a character on the framebuffer, what parameters it should expect? 

* The symbol we want to print (to be more precise: the index of the symbol in the glyph map)
* The position in the screen where we want to place the character (x and y), 
* The foreground color and the character color

Before proceeding let's talk about the position parameters. Now what they are depends also if we are implementing a gui or not, but let's assume that for now we want only to print text on the screen, in this case X and Y do not represent the pixel coordinates, but characters for example x=0 y=1 it goes to the column 0 (x) and to the row y is down 1 * font->height pixel

So our function header will be something like that: 

```C
void fb_putchar( char symbol, uint16_t x, uint16_t y, uint32_t fg, uint32_t bg)
```

Clearly what it should do is read the glyph stored in the position given by symbol, and draw it at row x and column y (don't forget they are "character" coordinates) using colors fg for foreground color and bg for background (we draw the foreground color when the bit in the bitmap is 1, and the bg color when is 0). 

We already saw above how to get the selected glyph, but now how we compute the position in the screen? In this case we need first to know: 

For the vertical coordinate: 

* The number of bytes in each line, or: how many pixelxs we need to go down exactly one pixel, expressed in bytes
* How many pixels is the glyph height

For the horizontal coordinate: 

* The width of the character 
* How many bytes are in a pixel

For the number of bytes in each line, assuming that you are using grub and you configured the framebuffer via the multiboot header, is in the *multiboot_tag_framebuffer*, the *framebuffer_pitch* value. 

## Useful resources

* https://wiki.osdev.org/PC_Screen_Font
* gbdfed - Tool to inspect PSF files
* https://www.win.tue.nl/~aeb/linux/kbd/font-formats-1.html
* https://forum.osdev.org/viewtopic.php?f=1&t=41549

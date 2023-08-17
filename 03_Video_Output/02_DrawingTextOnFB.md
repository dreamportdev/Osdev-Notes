# Drawing Fonts

When framebuffer is enabled, the hardware bios video memory is no longer accessible, and the only things that we can do now is drawing pixels.

So in order to write text we need first to have at least one font available to our operating system and how to store it.

The font can be one of many different available (ttf, psf, etc.) in this tutorial we will use Pc Screen Font v2 aka PSF (keep in mind that v1 has some differences in the header, if we want to support that as well, the code needs to be adapted)

**How** the font is stored depends on the status of the operating system, there are several way:

* Store it in memory (if the OS doesn't support a file sytem yet)
* In case a file system has been already implemented, it could be better to store them in a file
* We can also get a copy of the VGA Fonts in memory, using grub.

If running on linux there are some nearly ready to use fonts in */usr/share/kbd/consolefonts* (path can change slightly depending on the linux distribution)

In this chapter we are going to see how to use a font that has been stored into memory.

The steps involved are:

1. Find a suitable PSF font
2. Add it to the kernel
3. When the kernel is loading identify the PSF version and parse it accordingly
4. Write functions to: pick the glyph (a single character) and draw it on the screen

## Embedding a PSF File In The Kernel


As already said the best place to look for a font if running on linux is to look into the folder `/usr/share/kbd/consolefonts`, to know the psf version the tool *gbdfed* can be used, just import the font with it (use the File->Import->console font menu), and then go to *View->Messages*, there should be a message similar to the following:

```
Font converted from PSF1 to BDF.
```

Once we got the font, it needs first to be converted into an ELF binary file that can be linked to our kernel.

That can be done using the command objcopy (on linux, if on a different operating system search for a suitable alternative):

```bash
objcopy -O elf64-x86-64 -B i386 -I binary font.psf font.o
```

The `objcopy` command is a tool that copy a source file into another, and can change its format.
The parameters used in the example above are:

* -O the output format (in this case is elf64-x86-64)
* -B is the binary architecture
* -I the inpurt target

Once converted into binary elf, it can be linked to the kernel like any other compiled file, in this case we just need to add the output file to the linker command:

```bash
ld -n -o build/kernel.bin -T src/linker.ld <other_kernel_files> font.o -Map build/kernel.map
```

With the font linked, now is possible to access to 3 new variables, like in the following example:

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
(the variable name depends on the font file name).

## Parsing the PSF

Since there are two different version of PSF fonts available, identified with v1, and v2, to know what is the version of the font loaded we need to check the magic number first:

* If the version is 1 the magic number is two bytes:

```c
#define PSF1_MAGIC0     0x36
#define PSF1_MAGIC1     0x04
```
* Instead if we are using version 2 of psf the magic number has 4 bytes:

```c
#define PSF2_MAGIC0     0x72
#define PSF2_MAGIC1     0xb5
#define PSF2_MAGIC2     0x4a
#define PSF2_MAGIC3     0x86
```

The magic number is stored from the least significant byte (0) to the more significant (2 or 4 depending on the version)

### PSF v1 Structure

For version 1 of the psf, the data structure is pretty simple and contains only three fields:

* *magic* number: the value as already seen above, that is 0x0436
* *mode*: they are flags. If the value is 0x01 it means that the font will have 512 characters (there are few other values that can be checked here [https://www.win.tue.nl/~aeb/linux/kbd/font-formats-1.html](https://www.win.tue.nl/~aeb/linux/kbd/font-formats-1.html))
* *charsize* The character size in bytes

All the fields above are declared as `unsigned char` variables, except for the magic number that is an array of 2 unsigned char. For version 1 fonts there are few values that are always the same:

* *width* is always 8 (1 byte)
* *height* since width is  exactly 1 byte, this means that *height* == *charsize*
* *number of glyphs* is always 256 unless the mode field is set to 1, in this case it means that the font will have 512 characters

The font data starts right after the header.

### PSF v2 Structure

The psf structure header has a fixed size of 32 bytes, with the following information:

* *magic* a magic value, that is: 0x864ab572
* *version* is 0
* *headersize* it should always be 32
* *flags* 0 indicates there is no unicode table)
* *numglyphs* The number of glyphs available
* *bytesperglyph* Number of bytes per each glyph
* *height* Height of each glyph in pixels
* *width* Width in pixels of each glyph.

All the fields are 4 bytes in size, so creating a structure that can hold it is pretty trivial, except for the magic number that is an array of 4 usnigned char.

Let's assume from now on that we have a data structure called `PSF_font` with all the fields specified above. The first thing that we need of course, is to access to this variable:

```C
// We have linked _binary_font_psf_start from another .o file so we must
// specify that we are dealing with an external variable.
extern char _binary_font_psf_start;
PSF_font *default_font = (PSF_font *)&_binary_font_psf_start
```

## Glyph

Now that we have access to our PSF font, we can work with "Glyphs".
Every character (Glyph) is stored in a bitmap. Each bitmap is `WIDTH x HEIGHT` pixel . If for example the glyph is 8x16, it will be 16 bytes long, every byte encode a row of the glyph.
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
uint8_t* first_glyph = (uint8_t*) &_binary_font_psf_start +
    default_font->headersize
```

Since we know that every glyph has the same size, and this is available in the `PSF_Header`, if we want to access the *i-th* character, we just need to do the following:

```C
uint8_t* selected_glyph_v1 = (uint8_t*) &_binary_font_psf_start +
    sizeof(PSFv1_Header_Struct) + (i * default_font->bytesperglyph);

uint8_t* selected_glyph_v2 = (uint8_t*) &_binary_font_psf_start +
    default_font->headersize + (i * default_font->bytesperglyph);
```

Where in  the v1 case, `PSFv1_Header_Struct` is just the name of the struct containing the PSFv1 definition.

If we want to write a function to display a character on the framebuffer, what parameters it should expect?

* The symbol we want to print (to be more precise: the index of the symbol in the glyph map)
* The position in the screen where we want to place the character (`x` and `y`),
* The foreground color and the character color

Before proceeding let's talk about the position parameters. Now what they are depends also if we are implementing a gui or not, but let's assume that for now we want only to print text on the screen, in this case X and Y do not represent the pixel coordinates, but characters for example `x=0`, `y=1` it goes to the column 0 (x) and to the row y is down `1 * font->height pixel`

So our function header will be something like that:

```C
void fb_putchar( char symbol, uint16_t x, uint16_t y, uint32_t fg, uint32_t bg)
```

Clearly what it should do is read the glyph stored in the position given by symbol, and draw it at row x and column y (don't forget they are "character" coordinates) using colors fg for foreground color and bg for background (we draw the foreground color when the bit in the bitmap is 1, and the bg color when is 0).

We already saw above how to get the selected glyph, but now how we compute the position in the screen? In this case we need first to know:

* For the vertical coordinate:
    * The number of bytes in each line, or: how many pixels we need to go down exactly one pixel, expressed in bytes
    * How many pixels is the glyph height

* For the horizontal coordinate:
    * The width of the character
    * How many bytes are in a pixel

The number of bytes in each line, assuming that we are using grub and the framebuffer is configured via the multiboot header, is available in the *multiboot_tag_framebuffer* structure, the field is *framebuffer_pitch*.

Implementing the function above should be pretty simple and is left as exercise.


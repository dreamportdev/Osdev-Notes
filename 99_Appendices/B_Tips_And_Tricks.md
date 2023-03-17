# Tips and Tricks

## don't forget about unions
Unions may not see as much use as structs (or classes), but they can be useful.
For example if you have a packed struct of 8 uint8_ts that are from a single hardware register.
Rather than reading a uint64_t, and then breaking it up into the various fields of a struct, use a union!
```c
uint64_t read_register();

struct BadIdea
{
    uint8_t a;
    uint8_t b;
    uint8_t c;
    uint8_t d;

    uint8_t e;
    uint8_t f;
    uint8_t g;
    uint8_t h;
};

uint64_t reg = read_register();
BadIdea bi;
bi.a = reg & 0xFF;
bi.b = (reg >> 8) & 0xFF;
bi.c = (reg >> 16) & 0xFF; //yes the AND is not necessary, but it makes the point.
etc...
```

```c
union GoodIdea
{
    //each item inside of union shares the same memory.
    //using an anonymous struct ensures these fields are treated as 'a single item'.
    struct
    {
        uint8_t a;
        uint8_t b;
        uint8_t c;
        uint8_t d;

        uint8_t e;
        uint8_t f;
        uint8_t g;
        uint8_t h;
    };

    uint64_t squished;
};

GoodIdea gi;
gi.squished = read_register();
//now the fields in gi will represent what they would in the register.
//assuming a is bits 7:0, b is bits 16:8, etc ...
```

## Bitfields? More like minefields.

```c
__attribute__((packed))
struct BitfieldExample
{
    uint8_t _3bits : 3;
    uint8_t _5bits : 5;

    uint8_t _6bits : 6;
    uint8_t _2bits : 2;
};
```
Bitfields can be very useful, as they allow access to oddly sized bits of data. However there's big issue that can lead to unexpected bugs:

Consider the example above. This struct would form 16bits of data in memory, and while `_3bits` and `_5bits` would share 1 byte, same with `_6bits` and `_2bits`, the compiler makes no guaren'tees about which field occupies the least or most significant bits.
Byte order of fields is always guaren'teed by the spec to be in the order they were declared in the source file.
Bitwise order is not.

It is worth noting that relying on this is *usually* okay, most compilers will do the right thing, but optimizations can get a little weird sometimes. Especially -O2 and above.

### The solution?
There's no easy replacement for bitfields. Personally I'd suggest doing the maths yourself, and just store data in a uint8_t or whatever size is appropriate. Until the day some compiler extensions come along to resolve this.

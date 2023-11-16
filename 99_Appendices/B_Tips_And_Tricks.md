# Tips and Tricks

## Don't Forget About Unions

Unions may not see as much use as structs (or classes), but they can be useful.
For example if we have a packed struct of 8 `uint8_t`s that are from a single hardware register.
Rather than reading a `uint64_t`, and then breaking it up into the various fields of a struct, use a union.

Let's look at some examples and see how they can be useful. While this technique is useful, it has to be used carefully. If accessing MMIO using a `volatile` instance of a union, be sure to read about access requirements for the underlying hardware. For example a device may expose a 64-bit register, consisting of 8 8-bit fields. However the device may *require* that perform 64-bit reads and writes to the register, in which we will have to read the whole register, and create the union from that value. If the device doesn't have such a requirement, we could instead use a `volatile` union and access it normally.

Imagine we have a function that reads a register and returns its value as `uint64_t`:

```c
uint64_t read_register();
```

If we want to use a struct and populate it with the value returned by the function, we will have something similar to the following code:

```c
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
bi.c = (reg >> 16) & 0xFF; //T AND is not necessary, but it makes the point.
etc...
```

Now let's see what happens instead if we are using a union approach:

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

In this way we moved the struct declaration inside the union. This means that now that the struct and the union share the same memory location, using an anonymous structure it ensures that the fields are treated as a _single item_

In this way we can either access the `uint64_t` value of the register _squished_, or the single fields _a, b, ..., h_.


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

Consider the example above. This struct would form 16bits of data in memory, and while `_3bits` and `_5bits` would share 1 byte, same with `_6bits` and `_2bits`, the compiler makes no guarentees about which field occupies the least or most significant bits.
Byte order of fields is always guarenteed by the spec to be in the order they were declared in the source file.
Bitwise order is not.

It is worth noting that relying on this is *usually* okay, most compilers will do the right thing, but optimizations can get a little weird sometimes. Especially -O2 and above.

### The solution?

There's no easy replacement for bitfields. A suggestion is doing the maths by ourselves, and store data in a `uint8_t` or whatever size is appropriate. Until the day some compiler extensions come along to resolve this.

# Building GCC From Source
The fist step is to download the source code for [binutils](https://ftp.gnu.org/gnu/binutils/) and [GCC](https://ftp.gnu.org/gnu/gcc/). 
After extracting the downloaded files, you'll need to install a few build dependencies:
- a host compiler (GCC).
- GNU make
- Texinfo
- Bison
- Flex
- GMP
- MPC
- MPFR

These should all be available in your distribution of choice's repositories. For the exact package names check [this table](https://wiki.osdev.org/GCC_Cross-Compiler#Installing_Dependencies) on the osdev wiki.

//TODO: explain how to build gcc from source
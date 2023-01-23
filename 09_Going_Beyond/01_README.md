# Going Beyond

## Introduction

If you have reached that far in this guide this means that your kernel should have all the basic components to start to add new features to it, and probably to make it more interactive with the users. In this chapter we are going to explore some features that can be added to our operating system (not only the kernel). It is going to be just a very high level overview explaining what are the prerequisites and a short explanation of the process involved for developing it.

But at this point of development any feature can be added, and it is up to you what direction your kernel should take, so what you find here are just ideas, but then it's up to you. 

## CLI

One of the way to interact with users is through a CLI (Command Line Interface), that is usually presented by a blinking underscore symbol, waiting for some user input (usually via keyboard). 

The user provide a command, and the CLI executes it, providing output if necessary. Exampleis of CLI are \*nix Bash, zsh, Windows command line prompt, etc. A command line basically receives input in the form of line/s of text, the commands usually are either builtin within the cli (this means functions in the code), or executable files that are somewhere in a file system. 

### Prerequisites

To implement a we need at least the following parts of the kernel implemented:

* A video output (either using framebuffer, or legacy vga driver)
* Keyboard driver implemented with at least one layout working
* From a library point of view string input, comparisons and manipulating functions are needed. 

If you want to run executables files too, and not only builtin commands then you need also:

* The VFS layer implemented
* At least a file system supported (if you have followed this guide so far, you should have the USTar format implemented)
* Support for at least one type of executable files

Ideally when most of the commands are executed by the shell should spawn a new process/thread to be executed, so it could  be useful to have a fork/exec (or equivalent) mechanism implemented.

### Implementing a cli

The basic idea of a command line is pretty simple, it takes a string in input, parse it and execute it if possible. Usually the workflow involves three steps: 

* The first one is splitting the string, to separate the command from the arguments (the command is always the first word on the line
* Then check if the string is builtin, if yes it executes the function associated
* Otherwise search it in the FS, usually a shell will have a list of places to search for executables (i.e. the PATH variable in unix environment) and if an executable with the command name is found executes it, otherwise an error is returned (most likely: `command not found`)

Now probably our cli will have several builtin-command, so they should be stored somewhere, depending on the number of them we can simply use an array and search it looking for the command, otherwise another idea could be implementing a hashmap in this way we don't need to search the entire array for every command entered. Implementing a hashmap is beyond the scope of this book, but if you are not familiar with this kind of structure, the idea is that every command will be converte into a number using a custom hash function, and the number will indicate the index into an array.

## Graphical User Interface

## Libc

## Network

## Any other thing we can add?

## Few final words



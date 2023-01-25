# Going Beyond

## Introduction

If you have reached that far in this guide this means that your kernel should have all the basic components to start to add new features to it, and probably to make it more interactive with the users. In this chapter we are going to explore some features that can be added to our operating system (not only the kernel). It is going to be just a very high level overview explaining what are the prerequisites and a short explanation of the process involved for developing it.

But at this point of development any feature can be added, and it is up to you what direction your kernel should take, so what you find here are just ideas, but then it's up to you. 

## CLI

One of the way to interact with users is through a CLI (Command Line Interface), that is usually presented by a blinking underscore symbol, waiting for some user input (usually via keyboard). 

The user provide a command, and the CLI executes it, providing output if necessary. Exampleis of CLI are \*nix Bash, zsh, Windows command line prompt, etc. A command line basically receives input in the form of line/s of text, the commands usually are either builtin within the cli (this means functions in the code), or executable files that are somewhere in a file system. 

### Prerequisites

To implement a shell we need at least the following parts of the kernel implemented:

* A video output (either using framebuffer, or legacy vga driver)
* Keyboard driver implemented with at least one layout working
* From a library point of view string input, comparisons and manipulating functions are needed. 

If you want to run executables files too, and not only builtin commands then you need also:

* The VFS layer implemented
* At least a file system supported (if you have followed this guide so far, you should have the USTar format implemented)
* Support for at least one type of executable files and functions to execute them.

Ideally when most of the commands are executed by the shell should spawn a new process/thread to be executed, so it could  be useful to have a fork/exec (or equivalent) mechanism implemented.

### Implementing a cli

The basic idea of a command line is pretty simple, it takes a string in input, parse it and execute it if possible. Usually the workflow involves three steps: 

* The first one is splitting the string, to separate the command from the arguments (the command is always the first word on the line
* Then check if the string is builtin, if yes it executes the function associated
* Otherwise search it in the FS, usually a shell will have a list of places to search for executables (i.e. the PATH variable in unix environment) and if an executable with the command name is found executes it, otherwise an error is returned (most likely: `command not found`)

Now probably our cli will have several builtin-command, so they should be stored somewhere, depending on the number of them we can simply use an array and search it looking for the command, otherwise another idea could be implementing a hashmap in this way we don't need to search the entire array for every command entered. Implementing a hashmap is beyond the scope of this book, but if you are not familiar with this kind of structure, the idea is that every command will be converted into a number using a custom hash function, and the number will indicate the index into an array. A good idea to represent a command is to use a simple data structure that contains at least two informations: the command name, and the function it points to. 

So if the command is found, we can just call the function associated with it, but if not now we need to search for it on the file system. Now in this case there are two scenarios: 

* The input command is an absolute path, so we just need to search for the file on the given path, and execute it (returning an error if the file is not present)
* It is just a command, with no path, so in this case we can decide wheter to return an error or, like many other shells do, search for it in the current directory first, and then into one or more folders where the shell expects to find them, and only if it is not found in any of them return an error. 

For the second point we can decide to have the paths hardcoded in the code, or a good idea is to add a support for some environment variables mechanism. Environment variables are just named variables used to store some information useful to the process or the shell, they are not mandatory to be implemented, and usually they are external to the shell (they are implemented normally in the process/threads). The form of env variables is similar to: 

```
NAME_OF_VARIABLE=value
```

an example is the output of the `env` command in linux. 

## Graphical User Interface

## Libc

## Network

## Any other thing we can add?

## Few final words



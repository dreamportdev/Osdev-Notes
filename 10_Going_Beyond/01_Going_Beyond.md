# Going Beyond

## Introduction

If you have reached this far in the book, your kernel should have all the basic components needed to start adding some of the more exciting features. This means turning your project from a kernel and into an *operating system*: i.e. making it more useful and interactive. In this chapter we are going to explore some features that can be added to our operating system. This will be a high level overview, and not as in-depth as the previous parts.

At this point in development any feature can be added, and it's up to you what direction your kernel goes. While we're going to list a few suggestions of where you might want to explore next, they are merely that: suggestions.

## Command Line Interface

One of the way to interact with users is through a CLI (command line interface). This is usually presented by a blinking cursor (usually in the shape of an underscore) and waiting for some user input (usually via keyboard).

The user inputs a command and the CLI executes it, providing output if necessary. Examples of CLI are \*nix Bash, zsh, Windows command line prompt, etc. A command line basically receives input in the form of line/s of text. The commands are either built into the CLI itself, or extern programs located somewhere in a filesystem.

### Prerequisites

To implement a shell we need at least the following parts of the kernel implemented:

* A video output (either using framebuffer, or legacy vga driver).
* A keyboard driver implemented with at least one layout working.
* Functions for working with strings: the common comparison and manipulation ones.

In order to run external programs, you will also need:

* The VFS layer implemented.
* At least one file system supported. If you've been following along you'll have a tempfs that uses USTar which provides everything you need.
* A program loader capable of loading executable files and running them.

Typically when a command is executed by the shell it will run in a newly spawned process, so it can be useful to have fork and exec (or something equivalent) implemented.

### Implementing a CLI

The basic idea of a command line is pretty simple, it takes a string in input, parse it and execute it if possible. Usually the workflow involves three steps:

* The first one is splitting the string, to separate the command from the arguments (the command is always the first word on the line
* Then check if the string is builtin, and execute the internal function if it is.
* Otherwise search for it as a program within the VFS. Usually a shell will have a list of places to search for executables (i.e. the PATH variable in unix environment) and if an executable with the command name is found executes it, otherwise an error is returned (most likely: `command not found`).

Now our cli will probably have several builtin commands, so these should be stored somewhere. Depending on the number of them we can simply use an array, but a more advanced solution would be to use a hashmap for more consistent lookup times. Implementing a hashmap is beyond the scope of this book, but if you are not familiar with this kind of structure the idea is that every command will be converted into a hash (a special number) using a custom hash function. This number can then be used as an index into an array. A good idea to represent a command is to use a simple data structure that contains at least two pieces of information: the command name, and the function it points to.

If the command is found we can just call the function associated with it. If it's not found, then we have to search the filesystem. In this case there are two scenarios:

* The input command is an absolute path, so we just need to search for the file on the given path, and execute it (returning an error if the file is not present).
* It is just a command, with no path, so in this case we can decide wheter to return an error or, like many other shells do, search for it in the current directory first, and then into one or more folders where the shell expects to find them, and only if it is not found in any of them return an error.

For the second point we can decide to have the paths hardcoded in the code, or a good idea is to add a support for a mechanism that allows the user to set these paths: environment variables.

Environment variables are just named bits of data used to store some information useful to the current process. They are not mandatory to be implemented, and usually they are external to the shell (they are implemented normally in the process/threads). The form of env variables is similar to:

```
NAME_OF_VARIABLE=value
```

An example of what environment variables look like is the output of the `env` command in most unix shells.

## Graphical User Interface

A graphical user interface (aka GUI) is probably one of the most eye catching features of an os. While not required for an operating system, it's possibly one of the most desirable features for amateur osdevers.

The brutal truth is that a GUI is one of the most complex parts of modern operating systems! A good graphical shell can turn into a project as large and complex as a kernel, if not more so. However your first pass doesn't need to be this complex, and with proper design a simple GUI can be implemented and expanded over time.

While not strictly necessary, it's best to run your graphical shell in userspace, and we'll be making use of multiple programs, so you'll need at least userspace and IPC implemented. Ideally you would also have a few hardware drivers in order to have a framebuffer, keyboard and mouse support. These hardware devices should exported to userspace programs through an abstract API so that the underlying drivers are irrelevent to the GUI. This all implies that you also have system calls set up and working too.

In this section we'll assume you have all these things, and if you don't they can be easily achieved. Your bootloader should provide you with a framebuffer, and we've already taken a look at how to add support for a PS/2 keyboard. All that remains is a mouse, and a PS/2 mouse is a fine place to start. If you're on a platform without PS/2 peripherals there are always the virtio devices, at least inside of an emulator.

### Implementing A GUI

As mentioned above a graphical shell is not usually part of the kernel. You certainly can implement it that way, but this is an excellent way to test your userspace and system calls. The GUI should be treated as a separate entity (you may wish to organise this into a separate project, or directory), separate from the kernel.

Of course there are many ways you could architect a GUI, but the approach followed by most developers these days consists of a protocol, client and a server:

- A client is any application that wants to perform operations on the graphical shell, like creating/destroying a window. In this case the client uses the method described in the protocol to send a request to the server, and receives a response. The client can then perform any operations it likes in this manner and now we have a working system!
- A protocol. Think of the X window protocol (or wayland), this is how other applications can interact with the shell and perform operations. Things like asking the shell for a new window (with its own framebuffer), minimizing/maximizing the window, or perhaps receiving input into a window from the shell. This is similar to an ABI (like your system calls use) and should be documented as such. The protocol defines how the clients and server communicate.
- The server is where the bulk of the work happens. The server is what we've been referring to as the GUI or graphical shell, as it's the program responsible for ultimately drawing to the screen or passing input along to the focused window. The server may is usually also responsible for drawing window decorations and any UI elements that aren't part of a specific window like the task bar and the start menu. Although this can also be exposed via the protocol and a separate program can handle those.

Ok it's a little more complex than that, but those are the key parts! You'll likely want to provide a static (or dynamic, if you support that yet) library for your client programs that contains code for communicating with the server. You could wrap the IPC calls and shuffling data in and out of buffers into nice functions that are easier to work with.

### Private Framebuffers

When it comes to rendering, we expect each client window to be able to render to a framebuffer specific to that window, and not access any other framebuffers it's not meant to. This means we can't simply pass around the real framebuffer provided by the kernel.

Instead it's recommended to create a new framebuffer for each window. If you don't have hardware acceleration for your GPU (which is okay!) this can just be a buffer in memory big enough to hold the pixels. This buffer should be created by the server program but shared with the client program. The idea here is that the client can write as much data as it wants into the framebuffer, and then send a single IPC message to the server to tell it the window framebuffer has been updated. At this point the server would copy the updated region of the window's framebuffer onto the real framebuffer, taking into account the window's position and size (maybe part of the window is offsreen, so not visible).

This is much more efficient than sending the entire framebuffer over an IPC message and fits very naturally with how you might expect to use a framebuffer, only now you will need the additional step of flushing the framebuffer (by sending an IPC message to the server).

Another efficiency you might see used is the idea of 'damage rectangles'. This is simply tracking *where* on the framebuffer something has changed, and often when flushing a framebuffer you can pass this information along with the call. For example say we have a mouse cursor that is 10x10 pixels, and we move the cursor 1 pixel to the right. In total we have only modified 11x10 pixels, so there is no need to copy *the entire window framebuffer*. Hopefully you can see how this information is useful for performance.

Another useful tool for rendering is called a quad-tree. We won't delve into too much detail here, but it can greatly increase rendering speed if used correctly, very beneficial for software rendering.

#### Client and Client Library

As mentioned above it can be useful to provide a library for client programs to link against. It can also be nice to include a framework for managing and rendering various UI elements in this library. This makes it easy for programs to use them and gives your shell a consistent look and feel by default. Of course programs can (and do, in the real world) choose to ignore this and render their own elements.

These UI elements are often built with inheritence. If you're programming in a language that doesn't natively support this don't worry, you can achieve the same effect with function pointers and by linking structures together. Typically you have a 'base element' that has no functionality by itself but contains data and functions that all other elements use.

For example you might have the following base struct:

```c
enum ui_element_type {
    button,
    textbox,
    ...
};

typedef struct {
    struct { size_t x, size_t y } position;
    struct { size_t w, size_t h } size;

    bool render; //visible to user
    bool active; //responds to key/mouse events
    ui_element_type type;
    void* type_data;

    void (*render)(framebuffer_t* fb, ui_element_base* elem);
    void (*handle_click)(ui_element_base* base);
    void (*handle_key)(key_t key, keypress_data data)
} ui_element_base;
```

This isn't comprehensive of course, like you should pass the click position and button clicked to `handle_click`. Next up we let's look at how we'd extend this to implement a button:

```c
typedef struct {
    bool clicked;
    bool toggle;
} ui_element_button;

void render_button(framebuffer_t* fb, ui_element_base* elem) {
    ui_element_button* btn_data = (ui_element_button*)elem->type_data;

    //made-up rendering functions, include your own.
    if (btn_data->clicked)
        draw_rect(elem->position, elem.size, green);
    else
        draw_rect(elem->position, elem.size, red);
}

void handle_click_button(ui_element_base* base) {
    ui_element_button* btn = (ui_element_button*)btn->type_data;
    btn->pressed = !btn->pressed;
}

ui_element_base* create_button(bool is_toggle) {
    ui_element_base* base = malloc();
    base->type = button;
    base->render = render_button;
    base->handle_click = handle_click_button;
    base->handle_key = NULL; //don't handle keypresses

    ui_element_button* btn = malloc();
    btn->toggle = is_toggle;
    btn->pressed = false;
    btn->type_data = btn;

    return base;
}
```

You can see in `create_button()` how we can create a button element and populate the functions pointers we care about.

All that remains is a core loop that calls the various functions on each element as needed. This means calling `elem->render()` when you want to render an element to the framebuffer! Now you can combine these calls however you like, but the core concept is that the framework is flexible to allow adding custom elements of any kind, and they just work with the rest of them!

Don't forget to flush the window's framebuffer once you are done rendering.

#### The Server

The server is where most of the code will live. This is where you would handle windows being moved, managing the memory behind the framebuffers and deal with passing input to the currently focused window. The server also usually draws window decorations like the window frame/border and titlebar decoations (buttons and text).

The server is also responsible for dealing with the devices exposed by the kernel. For example say a new monitor is connected to the system, the server is responsible for handling that and making the screen space available to client applications.

#### The Protocol

Now we have the client and server programs, but how do they communicate? Well this is where your protocol comes in.

While you could just write the code and say "thats the protocol, go read it" that's error prone and not practical if working with multiple developers or on a complex project. The protocol specifies how certain operations are performed, like sending data to the server and how you receive responses. It should also specify what data you can send, how to send a command like `flush` and how to format the damage rectangle into what bytes.

Other things the protocol should cover are how clients are notified of a framebuffer resize (like the window being resized) or other hardware events like keypresses. What happens if there is no focused window, what do the key presses or clicks do then (right clicking on the desktop). It might also expose ways for clients to add things to context menus, or the start menu if you add these things to your design.

### In Conclusion...

Like we've said this is no small task, and requires a fairly complete kernel. However it can be a good project for testing lots of parts of the kernel all working together. It's also worth considering that if your shell server is designed carefully you can write it to run under an existing operating system. This allows you to test your server, protocol, and clients in an easily debuggable environment. Later on you can then just port the system calls used by your existing server.

## Libc (A Standard Library)

While you can write your kernel (or any program) any language of your choice, C is the *lingua franca* of systems programming. A lot of common programs you may want to port (like bash) are written in C, and require the C standard library.

At some point you'll want to provide a libc for your own operating system, whether its for porting these programs or just to say you've done it!

There are a few options when it comes, let's quickly look at the common ones:

- *Write your own*: This route is not recommended for beginners as a standard library is heavily stressed code (more so than the kernel at times), and it's easy to introduce subtle bugs. A standard library is again an entirely separate project that rival the size of your kernel. However if you do go this route, you have an excellent reference: the C programming standard! This document (or collection of them) describes what is and isn't legal in C, as well as defines what functionality the standard library needs to be provide. Most standard libraries assume your kernel provides a POSIX-like interface to userspace, if your kernel does not then this may be your best option.
- *Glibc*: The GNU libc is arguably one of the most feature complete (as is the LLVM equivalent) C standard libraries out there. It also boasts a broad range of compatability across multiple architectures. However all this comes at the cost of complexity, and that includes the requirements of the kernel hosting it. Porting Glibc requires a nearly complete POSIX-like kernel, often with linux systems in some places. This is a better option than writing your own, but it does require a bit of work. Porting glibc or llvm-libc does provide the most compatability.
- *Mlibc*: This libc is written and maintained by the team behind the managarm kernel. It was also built with hobby operating systems in mind and designed to be quite modular. As a result it is quite easy to port and several projects have done so and had their changes merged upstream. This makes porting it to other systems even easier as you can see what other developers have done for their projects. The caveat is that mlibc is quite new and there are occasional compatibility issues with particular library calls. Most software is fine, but more esoteric code can break, especially code that takes advantage of bugs in existing standard libraries that have become semi-standard.

There are also other options for porting a libc that deserve a mention, like newlib and musl.

### Porting A Libc

The exact process depends on the library you've chosen to port. The best instructions will always be the ones coming from the library's vendor, but for a general overview you'll want to take roughly the following steps:

- Get a copy of the source code, integrate building the libc into your project's build system.
- Once you have it attempting to build, see what dependencies are required. Larger libraries like Glibc will require much more, but there are often options to disable extra functionality to lower the number of dependencies.
- When you can build your libc, try write a simple program that links against it. Load this program from your kernel and see what system calls the libc tries to perform. This will give you an indication of what you need to support.
- Now begins the process of implementing these syscalls. Hopefully most of these are things you have support for, but if you don't you may need to add extra functionality to your kernel.

### Hosted Cross Compiler

After porting a standard library to your OS, you'll also want to build *another* cross compiler, but this time instead of targetting bare-metal you target your operating system.

Similar to how linux targets are built with the target triplet of something like `x86_64-linux-elf` you would build a toolchain that targets `x86_64-your_os_here-elf`. This is actually very exciting as it means you can use this compiler for any program that can be built just using the standard library!

## Networking

Networking is another inportant feature for modern operating systems, it lets our project no longer to be confined into our emulator/machine and talk to other computers. Not only computers on our local network, but also servers on the internet.

Once implemented we can write some simple clients like an irc or email client, and use them to show how cool we are; chatting from a client written by us, on an os written by us.

Like a graphical shell this is another big task with many moving parts. Network is not just one protocol, it requires a whole stack of various protocols, layered on top of each other. The (in)famous TCP/IP is often described as requiring 7 layers.

### Prerequisites

What we need already implemented for the networking are:

* Memory management: we'll need the usual dynamic memory management (malloc and free), but also a capable VMM for writing networking drivers.
* Inter process communication: processes need to be informed if there is some data they have received from the network.
* Interrupt infrastructure: we'll need to be able to handle interrupts from network cards.
* PCI support: any reasonable network interface card is managed through PCI.

Unlike a framebuffer which is often provided to us by the bootloader, we'll need to write drivers for each network card we want to support. Fortunately a lot of network cards use the same chipset, which means we can use the same driver for more than just a single card.

A good place to start is with the Intel e1000 driver (or the e1000e extended version). This card is supported by most emulators and is used as the basis for almost all intel networking chipsets. Even some non-intel chipsets are compatible with it! The osdev wiki has documentation for several different chipsets that can be implemented.

#### Implementation

Once the driver is in place this means we are able to send and receive data through a network, we can start implementing a communication protocol. Although there are different protocols available nowadays, we most likely want to implement the TCP/IP one, since it is basically used by every internet service.

The TCP/IP protocol is composed by 7 levels divided into 4 different layers:

1. The Link layer - The lower one, usually it is the one responsible of communicating the data through the network (usually part of the implementation done within the network interface driver)
2. Internet - It move packets from source to destination over the network
3. Transport - This provide a reliable message delivery between processes in the system
4. Application -  It is at the top, and is the one used by processes to communicate with the network, all major internet communication protocols are at this layer of the stack (i.e. ftp, http, etc.)

As mentioned above each layer is comprised of one or more levels. Implementing a TCP/IP stack is beyond our scope and also require a good knowledge of it. This paragraph is just a general overview of what are the layers and what we should expect to implement.

Usually the network levels should be pretty easy to implement, since it reflect the hardware part of the network. Every layer/level is built on top of the previous, so a packet that is received by a host in the network will traverse the stack and at every level some of the information it contains will be read, stripped from it and the result passed to the level below. The same is true also for sending a packet (but in this case at every level some information will be added).

The internet layer is responsible of moving datagrams (packets) in the network, it provides a uniform networking interface that hides the actual topology of the network, or the network connections. This is the layer that estabilishes the `inter-networking` and defines the addressing of the netwrok (IP), at this layer we have implemented ICMP and IGMP protocols.

At the Transport layer we have the host to host communication this is where the TCP and UDP protocol are implemented, and those are responsible of the routing of our packets.

The Application layer instead are usually the protocols we want to implement, so for example FTP, HTTP, POP, DNS are all application level protocols.

When we want to send data, we start from the topmost layer (the application) and go down the whole stack until the network layer adding some extra information on each level. The extra information is the layer header and footer (if needed), so when the data has reached the last level it will have all the tehcnical information for each level. This is described in the picture below.

On the other way a packet received from the network will observe the opposite path, so it will start as a big packet containing headers/footers for each layer, and while it is traversing the stack upwards, at every layer it will have the layer's header stripped, so when it will reach the Application Layer it will be the information we are looking for (you can just look  at the picture from bottom to top.

![TCP/IP Layers](/Images/tcpip.png)

Like for the GUI implementing a TCP/IP stack is not a quick task, neither trivial, since networking is composed by many different components, but the biggest difference is that most of what we need to implement is very well standardized, and we just need to follow the documentation and the implementation part should be less difficult.

## Few final words

Now we're really at the end of our kernel development notes. We tried to cover all the topics so that you can have a bare but complete-enough kernel. We had an overview on all the core components of an operating system explaining how they should be implemented, and what are the key concepts to be understood. We tried to stay focused on the implementation part of the development, using theory only when it was strictly necessary. We provided lot of code examples to help explain some of the trickier parts of the kernel. At the same time the purpose was not to provide some ready-to-use code, our intention was to give the readers enough knowledge to get started implementing it themselves.

The solutions proposed are optimized for the simplicity of the explanation. You will likely find ways to improve the code in your implementation! Finding better (or perhaps more interesting) solutions is all a part of your kernel development journey.

If you're still reading and are wondering what's next, it's up to you. If you've followed all the previous chapters you may wish to take a look at some of the topics mentioned in this chapter, implement some more device drivers (for more hardware compatibility) or rewrite a core system with renewed understanding. A CLI and then libC will greatly boost what you can do with your kernel, making it less of a toy and more of a tool.

We've also provided some appendices with some extra information that you might find useful. These are things we wanted to include that didn't fit elsewhere. We hope you found our notes useful and enjoyed reading them.

If you find any errors/issues (or horrors) with the notes please feel free to open a PR to fix them, or create an issue and let us fix it.

Thanks again!

Ivan G. and Dean T.



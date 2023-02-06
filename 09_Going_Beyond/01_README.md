# Going Beyond

## Introduction

If you have reached that far in this guide this means that your kernel should have all the basic components to start to add new features to it, and probably to make it more interactive with the users. In this chapter we are going to explore some features that can be added to our operating system (not only the kernel). It is going to be just a very high level overview explaining what are the prerequisites and a short explanation of the process involved for developing it.

But at this point of development any feature can be added, and it is up to you what direction your kernel should take, so what you find here are just ideas, but then it's up to you. 

## CLI

One of the way to interact with users is through a CLI (Command Line Interface), that is usually presented by a blinking underscore symbol, waiting for some user input (usually via keyboard). 

The user provide a command, and the CLI executes it, providing output if necessary. Examples of CLI are \*nix Bash, zsh, Windows command line prompt, etc. A command line basically receives input in the form of line/s of text, the commands usually are either builtin within the cli (this means functions in the code), or executable files that are somewhere in a file system. 

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

A graphical user interface (aka GUI) is probably one of the most eye catching features of an os. While not required for an operating system, it's possibly one of the most desirable features for amateur osdevers.

The brutal truth is that a GUI is one of the most complex parts of modern operating systems! A good graphical shell can turn into a project as large and complex as a kernel, if not more so. However your first pass doesn't need to be this complex, and with proper design a simple GUI can be implemented and expanded over time.

While not strictly necessary, it's best to run your graphical shell in userspace, and we'll be making use of multiple programs, so you'll need at least userspace and IPC implemented. Ideally you would also have a few hardware drivers in order to have a framebuffer, keyboard and mouse support. These hardware devices should exported to userspace programs through an abstract API so that the underlying drivers are irrelevent to the GUI. This all implies that you also have system calls set up and working too.

In this section we'll assume you have all these things, and if you don't they can be easily achieved. Your bootloader should provide you with a framebuffer, and we've already taken a look at how to add support for a PS/2 keyboard. All that remains is a mouse, and a PS/2 mouse is a fine place to start. If you're on a platform without PS/2 peripherals there are always the virtio devices, at least inside of an emulator.

### Implementing A GUI

As mentioned above a graphical shell is not usually part of the kernel. You certainly can implement it that way, but this is an excellent way to test your userspace and system calls. The GUI should be treated as a separate entity (you may wish to organise this into a separate project, or directory), separate from the kernel.

Of course there are many ways you could architect a GUI, but the approach followed by most developers these days consists of a protocol, client and a server:

- A client is any application that wants to perform operations on the graphical shell, like creating/destroying a window. In this case the client uses the method described in the protocol to send a request to the server, and receives a response. The client can then perform any operations it likes in this manner and now we have a working system! 
- A protocol. Think of the X window protocol (or wayland), this is how other applications can interact with the shell and perform operations. Things like asking the shell for a new window (with it's own framebuffer), minimizing/maximizing the window, or perhaps receiving input into a window from the shell. This is similar to an ABI (like your system calls use) and should be documented as such. The protocol defines how the clients and server communicate.
- The server is where the bulk of the work happens. The server is what we've been referring to as the GUI or graphical shell, as it's the program responsible for ultimately drawing to the screen or passing input along to the focused window. The server may is usually also responsible for drawing window decorations and any UI elements that aren't part of a specific window like the task bar and the start menu. Although this can also be exposed via the protocol and a separate program can handle those.

Ok it's a little more complex than that, but those are the key parts! You'll likely want to provide a static (or dynamic, if you support that yet) library for your client programs that contains code for communicating with the server. You could wrap the IPC calls and shuffling data in and out of buffers into nice functions that are easier to work with.

### Private Framebuffers

When it comes to rendering, we expect each client window to be able to render to a framebuffer specific to that window, and not access any other framebuffers it's not meant. This means we can't simply pass around the real framebuffer provided by the kernel. 

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
    base->handle_key = NULL; //dont handle keypresses

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

## Libc

TBD - by @DT

## Networking

Networking is another inportant feature for modern operating systems, that lets our project no longer to be confined into our emulator/machine and talks to other computers, not only the local network but the internet. 

Once implemented we can write some simple clients like an irc  or email client, and use them how cool we are, chatting from a client written by us on an os written by us too..

But like the GUI this is another big task, and the networking is not made of only one protocol, there are many, and most of the time with different layers that needs o be implemented, for example the TCP/IP is composed by 7 layers. 

What we need already implemented for the networking are: 

* Memory management: we are going to do a lot of malloc/free call 
* Inter Process communication: processes need to be informed if there is some data they have received from the network
* Hardware IRQ: the network cards use IRQ to communicate with the operating system

In this case we don't have a framebuffer like way to access the network cards, so we need to actually implement drivers for chipsets we are going to use, even if there are many chipsets available, usually implementing driver for add support of many cards that are using that chipset. 

A good advice is to start with the Intel IE1000 driver since is the card supported by many emulators. The osdev wiki has documentatio for several different chipset that can be implemented. 

Once the driver is in place this means we are able to send and receive data through a network, we can start implementing a communication protocol, although there are different protocols available nowadays, we most likely want to implement the TCP/IP one, since it is basically used by every internet service. 

The TCP/IP protocol is composed by 7 levels divided into 4 different layers:

1. The Link layer - The lower one, usually it is the one responsible of communicating the data through the network (usually part of the implementation done within the network interface driver)
2. Internet - It move packets from source to destination over the network
3. Transport - This provide a reliable message delivery between processes in the system 
4. Application -  It allow the access to network resources. 

As mentioned above each layer is comprised of one or more levels. Implementing a TCP/IP stack is beyond our scope and also require a good knowledge of it. This paragraph is just a general overview of what are the layers and what we should expect to implement. 

Usually the Network levels should be pretty easy to implement, since it reflect the hardware part of the network. Every layer/level is built on top of the previous, so a packet that is received by a host in the network will climb down the stack and at every level some of the information it contains will be read, stripped from it and the result passed to the level below. The same is true also for sending a packet.

The internet layer is responsible of moving datagrams (packets) in the network, it provides a uniform networking interface that hides the actual topology of the network, or the network connections. This is the layer that estabilishes the `inter-networking` and defines the addressing of the netwrok (IP), at this layer we have implemented ICMP and IGMP protocols.

At the Transport layer we have the host to host communication this is where the TCP and UDP protocol are implemented, and those are responsible of the routing of our packets.

The Application layer instead are usually the protocols we want to implement, so for example FTP, HTTP, POP, DNS are all application level protocols. 

When we want to send data, we start from the topmost layer (the application) and go down the whole stack until the network layer adding some extra information on each level. The extra information is the layer header and footer (if needed), so when the data has reached the last level it will have all the tehcnical information for each level. This is described in the picture below.

On the other way a packet received from the network will observe the opposite path, so it will start as a big packet containing headers/footers for each layer, and while it is traversing the stack upwards, at every layer it will have the layer's header stripped, so when it will reach the Application layer it will be the information we are looking for (you can just look  at the previous picture from bottom to top.

![TCP/IP Layers](/Images/tcpip.png)  


## Few final words



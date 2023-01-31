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

The Graphical User Interface (aka GUI) is probably one of the most eye catching features of an os, not strictly part of an OS, but probably one of the moste desirable feature by many amateur osdevers. The brutal truth is that a GUI is another huge task and it can be easily a project of it's own as complex as the kernel,  if you think that things are already that bad, they are even worse, in fact while a basic kernel doesn't need many drivers to work, a ui on the other is using a graphic card, and there are many available on the market, every one of them requires its own driver and not all the chipset have open specs, or are easy to implement.

But there is a good news at least, there are few ways we can have graphical user interface without to have to implement different device drivers. The two most common ways are: 

* Using the Vesa feataures from the 16bit mode enabling the real mode emultaion with all its limitations. 
* Using the framebuffer (that we already covered in this book) this offer a decent compromise, and even if it will not support highest resolution it will let us achieve more than decent results

In this section the method chosen for implementing a gui is the framebuffer, since we already explained it in the earlier chapters, and let us achieve good results with decent resolutions.

### Prerequisites

In this paragraph we are going to assume that we are going to use the framebuffer, so most of the prerequisites should be met by following the Framebuffer chapters of this book. 

To implement a GUI our kernel requires: 

* To have a working graphic mode enabled. The `framebuffer` in our case (usually it is implemented by the bootloader)
* To have functions to plot at least pixels, and probably basic shapes.
* We must  have at least a font loaded and parsed, in order to be able to print some messages, and of course we need functions to print them. 
* We need to have support for either keyboard or mouse (most probably we want to have a mouse driver), and for the mouse is advisable to have a cursor pointer symbol loaded somewhere in memory. 
* Having syscalls and user mode is strongly suggested unless we want to have the ui work fully in supervisor mode (that is not advisable), in the explanation below we will assume that they are implemented.
* IPC should be implemented, even if technically not really necessary, they are useful for handling ui changes across programs. 

### Implementing the GUI

As mentioned above the User Interface is not technically part of a kernel, and should be treated as a separated entity (sometime a whole separate project). Usually it should run as much as it can in user level, so having implemented user space is advisable, but not strictly necessary. 

There are several ways to implemnt a user interface, but usually there are at least two parts the we need to implements:

* A set of primitive functions to create and draw windows, buttons, textboxes, labels, rendering texts. 
* A protocol that will handle all the hardware events (i.e. mouse click, keypress), and decide what are the correct actions to take


#### The primitives

As mentioned above they will take care of handling the basic graphic objects needed for our ui, like Buttons, Windows, Labels, etc. These functions should usually need at least the coordinates of where we want to draw them a size, and at least a name to identify it (and sometime a text can be needed in case of buttons or windows for example). Usually the function will return a pointer to a data structure containing all information about it. 

Usually creation of a button object and its drawing are two separate steps, that can be done separately (for example: what if we already have crated a Label and we just want to update it?)

So a good idea is to have a separate rendering function for each ui object. Usually the rendering function is the one that will work with primitive shapes, and font rendering functions to make it visible to the user, so for example to render a button we will have something like: 

```c
void *renderButton(Button* button) {
    drawRectangle(button->posx, button->posy, button->sizex, button->sizey);
    fillRectangle(cbutton->olor);
    drawText(button->posx, button->posy, texttorender);
}
```

This function can either be called within a `createButton` function, or not, this totally depends on how the protocol is organized. And even the rendering could not mean that the object is rendered on the screen yet, but this will be more clear soon, when we will explain the protocol. 

Another thing that every type of object should 

This step should not be particularly hard to implement once we have decided what type of graphics object we want to display (windows, labels, buttons, etc) we need basically to draft a data structure to contain the definition of the ui object and the functions 

#### The Protocol

Once we have primitives to create gui components and render it, we can start to implement our protocol, here there are no standard, and probably there are many different ways to implement it, for example linux usually use either X or Wayland for it's graphic environment, windows has it's own (WinUI), QNX has the photon microGUI, etc. 

Technically nothing forbid us to create a full ui within the kernel and have all the UI calls made in supervisor mode, but this is not advisable for few reasons: 

* The UI component will have access to the whole hardware, even what it doesn't need. 
* A bug in the UI can panic the kernel
* Is not safe from a security point of view. 

For the reasons above the UI should be implemented as a separate program that will run in user mode, and will avail of syscalls only to make changes to the framebuffer. 

What is the protocol going to handle? 

* It is responsible of handling all the hardware events and decide wheter or not they are going to make changes to the ui, for example a mouse move will most likely update the cursor position, a keyboard press can sometime trigger a program or ui component to be displayed.
* It is also responsible of making the actual UI updates whenever they are needed, and also can use IPC to communicate with other UI processes. 
* It is keeping track of the various windows state, and routing all messages/action through the correct window
* The protocol is the only one that has access to the framebuffer. While the windows will have their own copy of it.

Usually this is implemented using a Client/Server arhcitecture. The clients are the program windows, that communicate with the server, the server is the one doing all the above stuff. 

So the server needs to keep track of the windows opened (Client windows), to do this it will need to store them into a List-like structure, where every item will be an istance of a `Window` object, since we are using C probably is going to be a `Window` type, that is declared in the Primitives section. 

As already said, the windows should not have access to the framebuffer directly and the only one doing it is the server, so a solution can be to have a copy of the framebuffer for every window, and when a window change something it will inform the server of the changes, and the server will decide when it is time to do them. 

When an hardware event is triggered, for example after  a mouse click the server will do the following: 

* Grab click coordinats
* Search for the list of windows for the window that is at those coordinates 
* If there is no window this means that it was probably directed to the desktop, and in this case it will act according to the server design decision (i.e. right  click on the desktop usually triggers a menu with access to some quick settings/shortcuts)
* If there is a window now we have two cases: one case is the window is not the active one, so we want probably to activate it, if it is the active window, we need to perform the action associated within the window object 
* There is also another case when we have overlapping windows: there are more than one window at the same coordinate, in this case we first search for an active window, if there is we just perform the action like the step above, but if there isn't we will activate one of the windows that are below the cursor, if there are multiple non active windows a mechanism to select the top one is expected to be implemented. 

Sometime some events can ask the window to change it's state, this is still managed by the server, and usually done exchanging messages (i.e. window minimizing, resuming, or maybe just a text change somewhere etc), this means we need implement a communication protocolo between client windows and the server, this is done usually through IPC. 

And finally only the Server is accessing the framebuffer, this means it is the only one able to actually make graphical changes, so whenever a window change its aspect the Server will be notified of the update, and it will reflect it on the screen.

### In conclusion...

Making a GUI as already said few times can be a project of it's own, and it require a lot of kernel part already implemented and working (if you have followed these notes you should have everything needed for it). Once we created the primitives to handle, create and render windows and basic shapes we need to design the protocol, with lot of decision to be made like what structure to use to keep the list of windows, what set of messages, how to handle windows updates. 

And also we will probably need a framework of functions to draw all ui components, and render them on our system, handling actions (if multiple actions are supposed), function to create Buttons, Menu, Radio Buttons, Label, etc. 

But it is definetely one of the most eye catching feature to have! 

## Libc

## Network

## Any other thing we can add?

## Few final words



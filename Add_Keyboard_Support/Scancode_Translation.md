# Handling scancodes

Handling the keyboard interrupt was pretty simple, we just basically needed to add an irq to the APIC and read the scancode. But at the end of that is just a number we want it to be eventually translated into a character. 

This section will try to explain what is needed to translate them and what needs to be taken into account while developing a keyboard driver.

As already mentioned there are 3 different scancode sets, we will focus on just one (the set 1, since most of the keyboard even if using a different set will have the controller that automatically translates the scancode to that), by the way we will try to implement a generic way to translate, so when eventually a new set needs to be added the changes needed will be very little. 

Now let's see what are the problem we need to solve when developing a keyboard driver: 

* The first thing is of course to translate the scancode into a human readable character
* There are some special keys also that needs to be handled, and some combinations that we should handle (shift or alt or ctrl  key pressed, are one example)
* Handle the press/release status if needed (we don't care much when we release a normal key, but probably we should take care when we release a key like shift or similars)
* Try to not lose sequence of key pressed/released
* Handle the caps, num, screen locks (with the leds)

From now on we will assume that the scancode translation is enabled, so no matter what set is being used it will be translate to set 1. 

## High Level Overview

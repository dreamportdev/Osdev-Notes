# Makefiles
There's a million and one excellent resources on makefiles out there, so this article is less of a tutorial and more of a collection of interesting things.

## GNUMakefile vs Makefile
There's multiple different make-like programs out there, a lot of them share a common base, usually the one specified in posix. GNU make also has a bunch of custom extensions it adds, which can be quite useful. These will render your makefiles only usable for gnu make, which is the most common version. So this is fine, but if you care about being fully portable between make versions, you'll have to avoid these.

If you do use gnu make extensions, you now have a makefile that wont run under every version of make. Fortunately the folks at gnu allow you to name your makefile `GNUMakefile` instead, and this will run as normal. However other versions of make won't see this file, meaning they wont try to run it.

## GNU Make Extensions

## Simple Makefile Example
- barebones example

## Complex Makefile Example (with recursion!)
- northport is a good case study

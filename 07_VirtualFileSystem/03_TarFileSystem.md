# The Tar File System

In the previous chapter we have implemented the VFS layer. that will provide us with a common interface to access files and directories across different file systems on different devices. In this chapter we are going to implement our first file system and try to access it's content using the VFS function. As already anticipated we will implement the (US)TAR format.

## Introduction

The Tar (standing for Tape ARchive)  format is not a file system (sorry i lied!), it is a a unix's tape archive format. and the acronym USTar is used to identify the posix standard version of it. Although is not a real fs it can be easily used as one in read-only mode. 

It was first released on 1979 in Version 7 Unix, there are different tar formats (including historical and current ones) two are codified into standards: *ustar* (the one we will implement), and "pax", also still widely used but not standardized there is the GNU Tar format. 

A *tar* archive consists of a series of file objects, and each one of them includes any file of data and is preceded by a fixed size header (512 bytes) record, the file data is written as it is, but its size is rounded to a multiple of 512 bytes. Usually the padding bytes are filled extra zeros. The end of an archived is marked by at least two consecutive zero filled records.

## Implementation

### The Header

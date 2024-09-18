ZigBlobs
Johan Rimez - 2024

This is an open source project featuring:
* ZIG programming language (www.ziglang.org)
* SDL2 - Simple DirectMedia Layer (www.libsdl.org)

This program is intended to demonstrate graphics programming for a simple but fully working coding example using ZIG & SDL.
Moreover, this project is intended to be as flexible as possible towards:
* Coding and compiling in and for WindowsOS & VS Code
* Coding and compiling in and for Linux & VS Codium
* Coding and compiling in Windows for Linux as target
The original idea for the program came from this coding tutorial:

The Coding Train - Coding challenge #28 - Metaballs
https://thecodingtrain.com/challenges/28-metaballs

USAGE:

<any key> quits the application

CODING:

In order for VS Code/Codium to run smoothly with the Zig Language Server (ZLS) in both Windows and Linux, the C-library and the SDL-library header files
are first exported to a common import file "cImport.zig" (important: UTF-8) as a preparatory step (you may want to locate the header files first and 
adapt the below commands first). I consider this file to be put in the source directory.

target specific:
(Windows) zig translate-c C:\Users\Public\Includes\SDL2\include\sdl.h -lc > cImport.zig
(Linux)   zig translate-c /usr/include/SDL2/SDL.h -lc -target x86_64-linux-gnu -I/usr/include -I/usr/include/x86_64-linux-gnu > cImport.zig

COMPILING:

The build.zig build file is configured for these scenarios:
* Building in windows for windows
* Building in windows for linux (.a & .so libraries need to be provided in the root project directory)
* Building in linux for linux

VS CODE:

the json-build and launch tasks are configured for windows.

RUNNING:

Windows users need to put the path to the SDL2.dll SDL2_image.dll libraries into their PATH or have them in the same folder as the executable.

REMARK:

The main calculation loop is done with thread pool (just as an exercise).

Kind regards
Johan*


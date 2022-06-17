# Luxtre

Luxtre is a fully portable dialect of [Lua 5.2](http://www.lua.org/) which compiles back into native code, written entirely in native Lua. It adds helpful additions and changes to Lua's default syntax and enables useful macros and preprocessing. 

Advanced users can leverage the existing toolchain and make use of their own custom grammars, allowing them to extend the existing features or even create their own transpiled languages from scratch.

Luxtre is compatible with all major versions of Lua (5.1+ and JIT), but does not backport newer syntax. Existing Lua code will largely work in Luxtre without modification, but some changes may be required ([see the changes to global variables](/docs/language_reference.md#assignment-changes)).

> WARNING: Features you see here are entirely subject to change. Luxtre is still a work in progress, and forward-compatibility is not guaranteed.

## Current Status:
Luxtre is in a mostly complete state. The core functionality is finished and polished (though not production tested), although not all planned grammar is currently in place. While code evaluation is noticably slow the generated code should not introduce any loss of performance, meaning in most cases files can be precompiled or file loading can be frontloaded prior to performance-critical sections. As long as a future-stable API is not required Luxtre should be

Current plans for future versions involve creating command-line tools for standalone code evaluation and compilation, adding further syntax constructs to the base language, and rewriting the parser to make code generation faster.


# How to Use
```lua
local luxtre = require "luxtre.loader"

-- Set up Luxtre to run .lux files through require
luxtre.register()
-- This will now load the file "foo.lux"
require("foo")

-- load/dofile equivalents for .lux files
local chunk = luxtre.loadfile("file")
luxtre.dofile("file")

-- load/dostring equivalents for the new syntax
local chunk = luxtre.loadstring(code_string)
luxtre.dostring("return -> print('hello world')")
```

[**See the documentation for more information.**](docs)

# Command-line Use
Luxtre offers an extremely basic method for running code directly from a command line which is targeted for Linux but should work in any bash shell.

Add the `luxtre/bin` folder to your path and run `lux`, or run `luxtre/bin/lux` directly from a bash prompt. If a filename is given, `lux` will attempt to load that file. If run with no arguments, `lux` will open a simple repl.

Within the repl ending a line with `\` will extend input capture onto the following line, and the function `exit()` will exit the repl loop.
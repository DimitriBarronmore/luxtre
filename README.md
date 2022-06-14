# Luxtre

Luxtre is a fully portable dialect of [Lua 5.2](http://www.lua.org/) which compiles back into native code, written entirely in native Lua. It adds helpful additions and changes to Lua's default syntax and enables useful macros and preprocessing. 

Advanced users can leverage the existing toolchain and make use of their own custom grammars, allowing them to extend the existing features or even create their own transpiled languages from scratch.

Luxtre is compatible with all major versions of Lua (5.1+ and JIT), but does not backport newer syntax. Existing Lua code will largely work in Luxtre without modification, but some changes may be required. (See <link here>)

## Current Status:
Luxtre is mostly complete. The core functionality is finished and polished (if not production tested), and further changes to the preprocessor/transpiler are not currently planned.

Further pre-1.0 versions will be dedicated to improving Luxtre's broader usability (such as introducing better command-line tools) and adding more pieces of syntax, but in this current state it should now be safe to use for production code.

> WARNING: Features you see here are entirely subject to change. Luxtre is still a work in progress, and forward-compatibility is not yet guaranteed.

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
Lux currently offers an extremely basic method for running files directly from a commandline in linux. Add the `bin` folder to your path, and call `lux <filename>` to run a .lux file. 

Note that it expects the `bin` folder to be adjacent to the `luxtre` folder; you cannot move it to a separate location.
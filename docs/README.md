# Basic Setup
```lua
-- Drop Luxtre into your project files, and initialize it.
local luxtre = require("luxtre.init")

-- Enable Luxtre to load .lux files directly through require.
luxtre.register()

-- Note that all functions support periods as file separators, and do not require extensions.

-- Luxtre provides implementations of Lua's standard loading functions.
-- These work just as you would expect.
luxtre.loadfile(filename, env)
luxtre.dofile(filename, env)
luxtre.loadstring(string, env)
luxtre.dostring(string, env)

-- You can compile a .lux file to a .lua file of the same name from code.
luxtre.compile_file(filename)

--[[ 
As a way to ease final compilation, you can enable/disable automatically compiling files to .lua
When a file is loaded through require (but only require), it will be compiled before loading. 
Later, you can remove "luxtre.register()" and the compiled files will take over.
This feature is turned off by default to prevent spurious files. 
--]]
luxtre.auto_compile(boolean)

--[[
It's possible to create your own loader tables.
These have all the same functionality as above, but you can use different grammars and file extensions.
See "How to Write a Custom Grammar"
--]]

local loaders = luxtre.create_loaders(file_extension, {grammars})

-- For example, you can make the example metagrammar parse itself:
local loaders = luxtre.create_loaders(".luxg", { "docs.examples.metagrammar" })W
loaders.compile_file("docs.examples.metagrammar")
```

# Language Reference
[Preprocessing](language_reference.md#preprocessing)
[Syntax Guide](language_reference.md#syntax-reference)

# Custom Grammars
[How to Write A Custom Grammar](writing_grammars.md)
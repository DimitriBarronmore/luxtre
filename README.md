# Luxtre

Luxtre is a small dialect of [Lua 5.2](http://www.lua.org/) which compiles back into native code, written entirely in native Lua. It adds a handful of helpful additions to the syntax and enables simple macro preprocessing.

Luxtre is compatible with Lua JIT, Lua 5.1, Lua 5.2, Lua 5.3, and Lua 5.4, but does not currently backport newer syntax. Existing Lua code will work in Luxtre without modification.

**Current Status:** 
Luxtre executes and outputs files properly, but is not yet complete. Future versions will have further syntax changes/additions and the ability to add new ones, as well as better error location redirection and better formatted output.

**How to Use:**

```lua
local luxtre = require "luxtre.loader"

-- Set up Luxtre to run .lux files through require
luxtre.register()
-- This will now load the file "foo.lux"
require("foo")

-- load/dofile equivalents for .lux files
local chunk = luxtre.loadfile("file")
luxtre.dofile("file")

-- load or execute strings of luxtre code
local chunk = luxtre.loadstring(code_string)
luxtre.dostring("return -> print('hello world')")

---[[ Syntax Changes ]]--
-- Table constructors can use colon-syntax.
local tab = {foo: 1, bar: 2, buzz: 3}
-- >> local tab = {foo = 1, bar = 2, buzz = 3}

-- Table constructors are automatically wrapped in parentheses when treated like a variable.
{1, 2, 3}[1];  "string":rep(5)
-- >> ({1, 2, 3})[1];  ("string"):rep(5)


-- Augmented assignment: +=, -=, *=, /=, %=, ^=
bar += 2 * 5 - funcall()
-- >> bar = bar + (2 * 5 - funcall())

-- Simple Iterator
-- Works as a standalone statement only.
i++
-- >> i = i + 1

-- Moonscript-style arrow lambdas
-- Usable as anonymous function constructors, or as a function declaration. 
-- Fat arrows (=>) insert a self parameter.
func (args) -> print(args)
-- >> func = function(args) print(args) end

-- Function decorators
@decorator
function somefunc(arguments, ...)
    print(whatever)
end
--[[ >>
	somefunc = decorator(
        function(arguments, ...)
            print(whatever)
        end )
--]]

---[[ MACROS ]]---
-- If the first thing on a line is a #define statment, a c-style macro will be created.
-- Macros cannot terminate strings or begin comments.
-- Format:
#define macroname this is the result
-- When 'macroname' appears in the input, 
-- it will be replaced with the remainder of the line.
#define advanced(arg1, arg2, ...) print(arg1, arg2, ...)
-- When a macro takes arguments, those arguments will be replaced 
-- with the passed values in thr right-hand side.


```


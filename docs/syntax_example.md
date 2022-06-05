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

-- Table constructors and string literals are automatically wrapped
-- in parentheses when treated like expressions.
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

-- The argument list is entirely optional.
-- Also, arrow lambdas will implicitly return single expressions.
func -> "hello"
-- >> func = function() return "hello" end

-- You can expand a lambda to multiple expressions using a do-end block.
clear_table (tab) -> do
    for k,_ in pairs(tab) do
        tab[k] = nil
    end
end
--[[ >>
    clear_table = function(tab)
        do
            for k,_ in pairs(tab) do
                tab[k] = nil
            end
        end
    end
--]]

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
```

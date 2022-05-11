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
```


## Preprocessing
Before the file is compiled, lines which begin with '#' are run in the preprocessor (ignoring trailing whitespace, shebangs, and multi-line strings/comments). The preprocessor executes these lines top-to-bottom as lua code.

The preprocessor is not yet complete, but in the current state it can be used to determine what is written to the final file as well as define macros.

### Conditional Lines

Within a preprocessor `do`, `if`, `while`, `repeat`, or `for` block, input lines will only be written to the output dependent on the surrounding preprocessor code. 
For example:
```lua
# if hello then
    print("hello world")
# else
    print("goodbye world")
# end
-- Outputs one line or the other depending on the value of the variable 'hello'

print(
#local count = 0
#repeat
#   count = count + 1
    "the end is never" .. 
#until count == 10
"" )
-- The final result concatenates "the end is never" with itself ten times. 
```

### Macros
Macros can be defined as string keyed values in the `macros` table. 
If the value give is a string, all instances of the key in the file will be replaced with the string. 
If the value is a function, calls to the function will be replaced with the returned string.

The macro can be blanked out entirely by setting the result to an empty string.
```lua
-- Simple Macro
# macros.constant = "1000"
print(constant) --> 'print(1000)'

-- Wacky characters work as well.
# macros["😂"] = ":joy:"
print("😂") -- > 'print(":joy:")

-- **WARNING:** Instances of '%' in a macro output MUST be 
-- escaped as '%%' if you don't to get strange errors.

-- Function Macro
# macros["reverse"] = function(arg1, arg2)
#   return arg2 .. " " .. arg1
print("reverse("world", "hello")") --> 'print("hello world")'

-- Keep in mind that function macro detection is rather simple.
-- Arguments cannot contain an unmatched right parens, or things will break.
print( "reverse(')', '(')" ) --> ERROR: unfinished string near <eof>

-- Note that function macros are executed entirely in the preprocessor.
-- Any varable names given as arguments will evaluate to those variables
-- in the preprocessor code.
# example_msg = "hi there"
# macros.print_var = function(name)
#   return name
# end
print( "print_var(example_msg)" ) --> 'print( "hi there" )'

-- Simple macros can be defined more easily with #define syntax.
-- If the line ends with at least two spaces, the macro will be blanked.
-- #define <name> <result>
# define fizzbuzz "1 2 fizz 4 buzz fizz 7 8 fizz buzz"
# define blank  
            --^^ note the spaces
print(fizzbuzz) --> 'print("1 2 fizz 4 buzz fizz 7 8 fizz buzz")'
print(blank)    --> 'print()'
```

# Command-line Use
Lux currently offers an extremely basic method for running files directly from a commandline in linux. Add the `bin` folder to your path, and call `lux <filename>` to run a .lux file. 

Note that it expects the `bin` folder to be adjacent to the `luxtre` folder; you cannot move it to a separate location.
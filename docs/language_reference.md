# Table of Contents
- [File Preprocessor](#preprocessing)
    - [Constant Variables](#constant-variables)
    - [Conditional Lines](#conditional-lines)
    - [Macros](#macros)
    - [Headers](#including-headers)
    - [Adding New Syntax](#extending-the-current-grammar)
- [New Syntax](#syntax-reference)
    - [Minor Tweaks](#minor-tweaks)
    - [Assignment Changes](#assignment-changes)
    - [Let Assignment](#let-declaration)
    - [Augmented Assignment](#augmented-assignment)
    - [Lambda Functions](#lambda-functions)
    - [Function Decorators](#function-decorators)

# Preprocessing
Before the file is compiled, lines which begin with '#' are run in the preprocessor (ignoring trailing whitespace, shebangs, and multi-line strings/comments). The preprocessor executes these lines top-to-bottom as lua code.

## Constant Variables
- filename: the full path of the current file, or an empty string if the code came from loading a string.
    - for example:  `print(filename) --> folder.example.lux`

## Conditional Lines

Within an unclosed preprocessor block (`do`, `if`, `while`, `repeat`, `for`, or inside function definitions), input lines will only be written to the output dependent on the surrounding preprocessor code. 
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
    "the end is never " .. 
#until count == 10
"" )
-- The final result concatenates "the end is never" with itself ten times. 
```
## Macros
Macros can be defined as string keyed values in the `macros` table. There are three types of macro: simple, function-like, and callback.

Macros are always evaluated in the order they were originally added, regardless of whether they have since been changed. This means that macros are fully deterministic in how they interact with each other.
```lua
-- Simple macros are simply a string key and a result.
# macros.constant = "1000"
print(constant) --> 'print(1000)'

-- Wacky characters work as well.
# macros["😂"] = ":joy:"
print("😂") -- > 'print(":joy:")

-- Function-like macros have pathethesised arguments in the key.
# macros["reverse(arg1, arg2)"] = "arg2 arg1"
print("reverse(world, hello)") --> 'print("hello world")'

-- Function-like macros support '...' as a catchall last argument.
-- The arguments collected are separated by a comma and a space, for use in function calls.
# macros["discardfirst(first, ...)"] = "..."
print(discardfirst(1,2,3)) --> 'print(2, 3)'

-- Callback macros are executed entirely in the preprocessor.
-- Any variable names passed will evaluate to preprocessor values.
-- The return value of the function is cast to a string and replaces the original text.
# example_msg = "hi there"
# macros.print_var = function(name)
#   return name
# end
print( "print_var(example_msg)" ) --> 'print( "hi there" )'

-- All macros will delete themselves from the input if they return a blank string.
# macros["<blank>"] = ""
print(<blank>) --> 'print()'

-- This can be useful when combined with conditional logic.
# if debug == "true" then
#   macros["log(...)"] = "print(...)"
# else
#   macros["log(...)"] = ""

-- Simple and Function-Like macros can be defined more easily with #define syntax.
-- #define <name>[parens] <result>
# define fizzbuzz "1 2 fizz 4 buzz fizz 7 8 fizz buzz"
# define add_bark(arg) barkargbark
# define blank

print(fizzbuzz)         --> 'print("1 2 fizz 4 buzz fizz 7 8 fizz buzz")'
print("add_bark(woof)") --> 'print("barkwoofbark")'
print(blank)            --> 'print()'
```

## Including Headers
You can include a header file using the `include(filename)` function. This takes the input of the file "`filename`.luxh" and inserts it into the current file beginning with the next line.
```lua
-- [[header.luxh]]
# print "foobar"

-- [[ some other file ]]
# print "before"
# include "header"
# print "after"
--[[
   >> # print "before"
   >> # print "foobar"
   >> # print "after"
--]]

-- note that you can use the filename variable to load adjacent grammars.
-- assuming the current file is "folder/foobar.lux", this includes folder/header.luxh
# local path = filename:gsub("foobar", "")
# include(path .. "header")

```

## Extending the Current Grammar
The `add_grammar(filename)` function allows you to extend the current file's syntax with the given `.luxg` grammar definition. Grammars added this way are loaded in order.
```lua
-- loads the file "folder.extension.luxg"
-- in order to make the syntax consistent with require,
-- dots in the path are converted to "/"
# add_grammar "folder.extension"

-- note that you can use the filename variable to load adjacent grammars.
-- assuming the current file is "folder/foobar.lux":
# local path = filename:gsub("foobar", "")
# add_grammar(path .. "extension")
```


# Syntax Reference

## Minor Tweaks
`!=` works as an alias to `~=`, allowing conditionals to be written in the same way as most other languages.
```lua
print(true != false) --> true
```

Table literals and strings can have methods used on them directly, without the need to wrap them in parentheses. 
```lua
print("string":rep(5)) --> stringstringstringstringstring
```

Table literals wrap square-brackets around booleans, numbers, and strings on the left hand of an assignment automatically, meaning things such as string-keyed tables are easier to write.

Table literals also allow `:` to be used instead of `=` for assignment.
```lua
table = {a:1, "b":2, 3:3}       | local table = {a = 1, ["b"] = 2, [3] = 3}
```


## Assignment Changes
Unlike base Lua, assignment to an undeclared variable will cause the new variable to be initialized as local. To create a global variable, you need to use the new `global` keyword.

Luxtre allows global variables to shadow local ones by prepending access to global variables with "`_ENV.`". This has the side effect of essentially backporting Lua 5.2's environment system to Lua 5.1 and LuaJIT.

```lua
foo, bar = 1, 2               | local foo, bar = 1, 2
global fizz, buzz = 3, 4      | _ENV.fizz, _ENV.buzz = 3, 4

-- You can shadow global variables as expected with explicit local.
local fizz, buzz = 5, 6       | local fizz, buzz = 5, 6
print(fizz, buzz)             | _ENV.print(fizz, buzz)
    >> 5   6
```

## Let Declaration
Declaring with the `let` keyword is similar to declaring with `local`, but the variable is declared before the assignment. This allows functions access to the variable within the initial declaration. It can also be used as a shorter way to explicitly declare local variables.

```lua
let func = function()          | local func
    print(func)                | func = function()
end                            |    _ENV.print(func)
func()                         | end
                               | func()
                               | --> function: 0x7f774f184ba8
```

## Augmented Assignment
The operators `+=`, `-=`, `/=`, `*=`, `%=`, `^=`, and `..=` allow you to easily perform arithmetic on a variable. They expand to longhand assignment as you would expect.

Augmented assignment does not change the scope of the variables being assigned to.

`%=` and `|=` are also provided for assignment with `and` and `or`.

```lua
local foo                      | local foo
foo, bar += 1 * 5, 2 + 4       | foo, _ENV.bar = foo + (1 * 5), _ENV.bar + (2 + 4)
function(fizz)                 | local function(fizz)
    fizz |= "buzz"             |    fizz = fizz or ("buzz")
end                            | end
```

## Lambda Functions
Short anonymous functions can be created using coffeescript/moonscript-style arrows. They will capture only a single statement.
```lua
func = -> print("hello")       | local func = function() _ENV.print("hello") end
```
Lambdas with arguments can be made by putting the arguments before the arrow.
```lua
-- Be very careful of ambiguity! Statements will very quickly escape.
add = (x, y) -> x = x + y     | local add = function(x, y) x = x end + y
-- You can use parentheses to contain the statement.
add = (x, y) -> (x = x + y)   | local add = function(x, y) x = x + y end

-- It's possible to expand the reach of a lambda by using a do-end block.
pow_x = (x) -> do             | local pow_x = function(x)
    y = x * x                 |     local y = x * x
    return y                  |     return y
end                           | end
```
If a lambda is made with a fat arrow (`=>`), the argument list will include an implicit self parameter.
```lua
object.print_name = => print(self.name)
--> 
object.print_name = function(self) _ENV.print(self.name) end
```
Lambdas also have a shortened definition format similar to functions.
```lua
greet(name) -> print("hello" .. name)
person.greet() => print("hello" .. self.name)
```

## Function Decorators
Taken directly from Python, function decorators allow you to wrap additional functionality around a function as it's being applied.

In essence, a decorator is a function which takes in another function as the only argument, does some stuff, and optionally returns a value to take the original function's place. Decorator syntax automates the process of passing a newly created function to a decorator.

Decorators can be nested. Nested decorators are applied bottom to top.

```lua
function decorate(func)
	return function()
		print "hallo"
		func()
	end
end
function decorate2(func)
	return function()
		print "world"
		func()
	end
end
function decorate3(func)
	return function()
		print ":3"
		func()
	end
end

@decorate
@decorate2
@decorate3
function bruh() 
    print("original message") 
end
--- >>
local bruh = decorate3 ( function()
    _ENV. print ( "original message" )
end )
bruh = decorate2 ( bruh )
bruh = decorate ( bruh )
--- >> 
bruh()

>> hallo
>> world
>> :3
>> original message
```
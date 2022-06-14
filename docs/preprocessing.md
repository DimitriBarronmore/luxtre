# Preprocessing
Before the file is compiled, lines which begin with '#' are run in the preprocessor (ignoring trailing whitespace, shebangs, and multi-line strings/comments). The preprocessor executes these lines top-to-bottom as lua code.

The preprocessor is not yet complete, but in the current state it can be used to determine what is written to the final file as well as define macros.

## Constant Variables
- filename: the full path of the current file, or an empty string if the code came from loading a string.
    - for example:  `print(filename) --> folder.example.lux`

## Conditional Lines

Within an unclosed preprocessor block (`do`, `if`, `while`, `repeat`, or `for`), input lines will only be written to the output dependent on the surrounding preprocessor code. 
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
-- assuming the current file is "folder/foobar.lux", this imports folder/header.luxh
# local path = filename:gsub("foobar", "")
# import(path .. "header")

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
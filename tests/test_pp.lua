
local pp = require "luxtre.preprocess"

local str = [==[
#! shebang

normalline
# dbg = false
# define bwah bwehehe
# define stuff stuffz
# macros["stuffz"] = "bwah"
# define stuff nyehz
# define 😂 :joy:

# macros["functest(arg1, arg2)"] = "arg2, arg1"


stuff
bwah
functest("adhjk", 9, 49)
print("functest(world, hello)")

# if dbg then
    hello world
# else
    goodbye world 😂
# end

# debug = false
# if debug then
#   define log(...) print(...)
# else
#   define log(...)
# end

log(h,b,c,d)

------
print(
#local count = 0
#repeat
    #count = count + 1
    "the end is never" .. 
#until count == 10

"" )

# example_msg = "hi there"
# macros.print_var = function(name)
#   -- print(name)
#   return name
# end

print("print_var(example_msg)")

# define fizzbuzz "1 2 fizz 4 buzz fizz 7 8 fizz buzz"
print(fizzbuzz)

# macros["[^$()%.[]*+-?]"] = "test%"
[^$()%.[]*+-?]

# macros["discardfirst(first, ...)"] = "..."
discardfirst(1, 2, 3)

# define add_bark(arg) barkargbark
print("add_bark(woof)")


]==]

-- local str = [==[


-- #define help(args1, argsd2, argys3, ...) argys3, argsd2, args1, ...
-- help(111, 222, 3, 4, 5, 6) 

-- #define log(...) print(...)
-- #define log(...)
-- log("asghjkl", 1, 2, 3, 4, 5, 6)

-- #macros["getvar"] = function(name) return name end
-- #foo = "hi"
-- getvar(foo)

-- ]==]

local txt = pp.compile_lines(str)

for i, line in ipairs(txt._output) do
    print(i, txt._linemap[i], line)
end
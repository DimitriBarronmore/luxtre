
local pp = require "luxtre.preprocess"

local txt = pp.compile_lines([==[
#! shebang

normalline
# dbg = false
# define bwah bwehehe
# define stuff stuffz
# macros["stuffz"] = "bwah"
# define stuff nyehz
# define 😂 :joy:

# macros["functest"] = function(arg, arg2)
#   return arg2 .. " " .. arg
# end


stuff
bwah
functest("adhjk", 9, 49)
print("functest("world", "hello")")

# if dbg then
    hello world
# else
    goodbye world 😂
# end

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

]==])

for i, line in ipairs(txt._output) do
    print(i, txt._linemap[i], line)
end

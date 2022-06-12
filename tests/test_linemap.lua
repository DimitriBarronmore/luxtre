local newGrammar = require("luxtre.parser.grammar")
local tokenate = require "luxtre.parser.tokenate"
local loader = require "luxtre.loader"

-- local grammar = newGrammar()
local str = 



[==[
-- #! shebang

--     # dbg = true
--     # if dbg then
--        print "hello world"
--     # else
--        print "goodbye world 😂"
--     # end
    
--     ------
--     print(
--     #local count = 0
--     #repeat
--         #count = count + 1
--         "the end is never " ..
--         #
--         #
--     #until count == 10
--  "" )

--print(noexist.foo)

 -- bleh bleh bleh

 name -> "bleh"

 print(name())

return "a", "b", "c", "d"
    ]==]

chunk = loader.loadstring(str)
-- chunk = loader.loadfile("txt")
print(chunk())

-- local inpstr = tokenate.inputstream_from_text(str, "arithm")
-- local tokstr = tokenate.new_tokenstream()
-- tokstr:tokenate_stream(inpstr, grammar)
-- tokstr:_debug()
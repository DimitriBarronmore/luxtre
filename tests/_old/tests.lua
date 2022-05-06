--- Grammars ---

local newGrammar = require("grammar")
local tokenate = require "tokenate"
local parse = require "parse"

local keys = {
    "break",
    "goto",
    "do",
    "end",
    "while",
    "repeat",
    "until",
    "if",
    "then",
    "elseif",
    "else",
    "for",
    "function",
    "local",
    "return",
    "nil",
    "false",
    "true",
    "and",
    "or",
    "not"
  }
local ops = {
    '==',
    '<=',
    '>=',
    '~=',
    '::',
    '...',
    '..',
    -- '+=',
    -- '-=',
    -- '/=',
    -- '*=',
    -- '%=',
    -- '^=',
  }

local grammar = newGrammar()
-- grammar:addKeywords(keys)
-- grammar:addOperators(ops)
-- grammar:addRule("tok", "Name Number Name '...' true String other")
-- grammar:addRule("tok", "Number Number tok")
-- grammar:addRule("tok", "")

-- grammar:addRules("tok2", {"list","o","stuff"}, function() print"pp" end)

-- local rules = {
--   {"foo", "1 2 3"},
--   {"bar", "4 5 6"},
--   {"fizbuzz", "7 8 9"},
--   {"fizbuzz", "fizz buzz"},
--   {"fizbuzz", "3 and 3"}
-- }

local function sumprint1(self)
  return (self.children[1]:print() .. " + " .. self.children[3]:print())
end
local function sumprint2(self)
  return (self.children[1]:print() .. " - " .. self.children[3]:print())
end
local function sumprint3(self)
  return (self.children[1]:print())
end
local function prodprint1(self)
  return (self.children[1]:print() .. " * " .. self.children[3]:print())
end
local function prodprint2(self)
  return (self.children[1]:print() .. " / " .. self.children[3]:print())
end
local function prodprint3(self)
  return (self.children[1]:print())
end
local function facprint1(self)
  return ("( " .. self.children[2]:print() .. " )")
end
local function facprint2(self)
  return (self.children[1]:print())
end


local rules = {
  {"sum", "sum '+' product",        [[$1 .. " + " .. $3]]},
  {"sum", "sum '-' product",        [[$1 .. " - " .. $3]]},
  {"sum", "product",                [[$1]]},
  {"product", "product '*' factor", [[$1 .. " * " .. $3]]},
  {"product", "product '/' factor", [[$1 .. " / " .. $3]]},
  {"product", "factor",             [[$1]]},
  {"factor", "'(' sum ')'",         [["( " .. $2 .. " )"]]},
  {"factor", "Number",              [[$1]]}
}

grammar:addRules(rules)

-- print("\n\n\n\n")
grammar:_debug("test grammar")

-- print("\n===stream\n")

-- local str = "1+(2*3-4)/(5+10)-3"
local str = "1+(2*3-4)"
local inpstr = tokenate.inputstream_from_text(str, "arithm")
local tokstr = tokenate.new_tokenstream()
tokstr:tokenate_stream(inpstr, grammar)
-- tokstr:_debug()

print("\n===earley\n")

-- print(#tokstr.tokens)

local ptree = parse.earley_parse(grammar, tokstr, "sum")

-- ptree:_debug("reverse")
local ast = parse.extract_parsetree(ptree)
-- print("\n\n=====\n")
ast:_debug()
print(ast.tree:print())


-- local egram = newGrammar()
-- egram:addRules{
--   {"A", ""},
--   -- {"A", "C A"},
--   {"A", "B"},
--   {"B", "A"},
--   -- {"C", ""}
-- }

-- local einp = tokenate.inputstream_from_text("    ")
-- local etoks = tokenate.new_tokenstream()
-- etoks:tokenate_stream(einp, egram)
-- local epars = parse.earley_parse(egram, etoks, "A")
-- epars:_debug()

-- local set = new_earleyset(0)
-- set:predict_items(grammar, "fizbuzz")
-- set:predict_items(grammar, "fizbuzz")

-- for k,v in ipairs(set.predicted) do
--   print(k, v.result, v.production_rule, v.begins_at)
-- end

--- Tokenation ---

-- local tokens = require "tokenate"

-- local time = os.clock()

-- local inps = tokens.inputstream_from_file("test_macros.txt")
-- local tstr = tokens.new_tokenstream()
-- -- tstr.macros["word"] = {type = "simple", result = "macro insertion"}
-- -- tstr.macros["debug"] = {type = "complex", result = "print(arg1, arg2)", args = {"arg1", "arg2"}}

-- tstr:tokenate_stream(inps, grammar)
-- print("---debug---")
-- tstr:_debug()
-- -- inps:_debug()

-- local alltoks = {}
-- for _, tok in ipairs(tstr.tokens) do
--   table.insert(alltoks, tok.value)
-- end
-- print(table.concat(alltoks, " "))

-- print("time taken: " .. tostring(os.clock() - time))
-- -- print(string.byte("🗿"))
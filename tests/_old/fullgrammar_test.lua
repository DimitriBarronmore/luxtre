local newGrammar = require("luxtre.parser.grammar")
local tokenate = require "luxtre.parser.tokenate"
local parse = require "luxtre.parser.parse"

local keys = {
    "break",
    "goto",
    "do",
    "end",
    "while",
    "repeat",
    "until",
    "in",
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
    '->',
    '=>',
    '+=',
    '-=',
    '/=',
    '*=',
    '%=',
    '^=',
    '++',
  }

local grammar = newGrammar()
grammar:addKeywords(keys)
grammar:addOperators(ops)

local rules = {

    --blocks

    {"block", "block_2 block_3"},
    {"block_2", "block_2 stat"},
    {"block_2", ""},
    {"block_3", "return_stat"},
    {"block_3", ""},

    -- statements

    {"stat", "';'"},
    {"stat", "var_list '=' exp_list"},
    {"stat", "functioncall"},
    {"stat", "label"},
    {"stat", "break"},
    {"stat", "goto Name"},
    {"stat", "do block end"},
    {"stat", "while exp do block end"},
    {"stat", "repeat block until exp"},

    {"stat", "if exp then block elseif_block else_block end"},
    {"elseif_block", "elseif exp then block elseif_block" },
    {"elseif_block", ""},
    {"else_block", "else block" },
    {"else_block", ""},

    {"stat","for Name '=' exp ',' exp forstat_2 do block end"},
    {"forstat_2","',' exp"},
    {"forstat_2",""},

    {"stat","for name_list in exp_list do block end"},
    {"stat","function funcname funcbody"},
    {"stat","local function Name funcbody"},
    {"stat","local name_list assignstat_2"},
    {"assignstat_2","'=' exp_list"},
    {"assignstat_2",""},

    {"return_stat", "'return' return_stat_2 return_stat_3"},
    {"return_stat_2", "exp_list"},
    {"return_stat_2", ""},
    {"return_stat_3", "';'"},
    {"return_stat_3", ""},

    --assorted

    {"label", "'::' Name '::'"},

    {"funcname", "Name funcname_2 funcname_3"},
    {"funcname_2", "'.' Name funcname_2"},
    {"funcname_2", ""},
    {"funcname_3", "':' Name"},
    {"funcname_3", ""},

    {"var_list", "var var_list_2"},
    {"var_list_2", "',' var var_list_2"},
    {"var_list_2", ""},

    {"var", "Name"},
    {"var", "prefixexp '[' exp ']'"},
    {"var", "prefixexp '.' Name"},
    
    
    {"var", "tableconstructor", [["(" .. $1 .. ")"]] },
    {"var", "String", [["(" .. $1 .. ")"]] },

    {"name_list", "Name name_list_2"},
    {"name_list_2", "',' Name name_list_2"},
    {"name_list_2", ""},

    {"exp_list", "exp exp_list_2"},
    {"exp_list_2", "',' exp exp_list_2"},
    {"exp_list_2", ""},

    --expressions

    {"exp", "nil"},
    {"exp", "false"},
    {"exp", "true"},
    {"exp", "Number"},
    {"exp", "String"},
    {"exp", "'...'"},
    {"exp", "functiondef"},
    {"exp", "prefixexp"},
    {"exp", "tableconstructor"},
    {"exp", "exp binop exp"},
    {"exp", "unop exp", [[$1 .. $2]]},

    -- augmented assignment

    {"stat", "exp '+=' exp", [[$1 .. " = " .. $1 .. " + (" .. $3 .. ")"]]},
    {"stat", "exp '-=' exp", [[$1 .. " = " .. $1 .. " - (" .. $3 .. ")"]]},
    {"stat", "exp '*=' exp", [[$1 .. " = " .. $1 .. " * (" .. $3 .. ")"]]},
    {"stat", "exp '/=' exp", [[$1 .. " = " .. $1 .. " / (" .. $3 .. ")"]]},
    {"stat", "exp '%=' exp", [[$1 .. " = " .. $1 .. " % (" .. $3 .. ")"]]},
    {"stat", "exp '^=' exp", [[$1 .. " = " .. $1 .. " ^ (" .. $3 .. ")"]]},
    {"stat", "var '++'", [[$1 .. " = " .. $1 .. " + 1"]]},

    --functions

    {"prefixexp", "var"},
    {"prefixexp", "functioncall"},
    {"prefixexp", "'(' exp ')'"},

    {"functioncall", "prefixexp ':' Name args"},
    {"functioncall", "prefixexp args"},

    {"args", "'(' exp_list ')'"},
    {"args", "'(' ')'"},
    {"args", "tableconstructor"},
    {"args", "String"},

    {"functiondef", "function funcbody"},

    {"funcbody", "'(' paramlist ')' block end"},
    {"funcbody", "'(' ')' block end"},

    {"paramlist", "name_list"},
    {"paramlist", "name_list ',' '...'"},
    {"paramlist", "'...'"},

    -- arrow functions
    {"exp", "arrowdef"},
    {"exp", "fatarrowdef"},

    {"stat","var arrowdef", [[$1 .. " = " .. $2]]},
    {"stat","local Name arrowdef", [["local " .. $2 .. " = " .. $3]]},
    {"stat","var fatarrowdef", [[$1 .. " = " .. $2]]},
    {"stat","local Name fatarrowdef", [["local " .. $2 .. " = " .. $3]]},
    

    {"arrowdef", "args '->' stat", [["function" .. $1 .. " " .. $3 .. " end"]]},
    {"arrowdef", "'->' stat", [["function() ".. $2 .. " end"]]},

    {"shorthandargs", "'(' exp_list ')'", [[$2]] },
    {"emptyargs", "'(' ')'", "" },
    {"fatarrowdef", "shorthandargs '=>' stat", [["function(self," .. $1 .. ") " .. $3 .. " end"]]},
    {"fatarrowdef", "emptyargs '=>' stat", [["function(self) " .. $3 .. " end"]]},
    {"fatarrowdef", "'=>' stat", [["function(self) ".. $2 .. " end"]]},

    --function decorators
    -- {"funcdecorator", "'@' funcname"},
    {"decoratedfunc", "'@' funcname function funcname funcbody",
        [[$4 .. " = " .. $2 .. "(function" .. $5 .. ")"]]},

    {"decoratedfunc", "'@' funcname local function funcname funcbody",
        [["local " .. $5 .. " = " .. $2 .. "(function" .. $6 .. ")"]]},

    {"decoratedfunc", "'@' funcname var arrowdef",
      [[$3 .. " = " .. $2 .. "( " .. $4 .. " )" ]]},

    {"decoratedfunc", "'@' funcname local Name arrowdef",
      [["local " .. $4 .. " = " .. $2 .. "( " .. $5 .. " )" ]]},

    {"decoratedfunc", "'@' funcname var fatarrowdef",
      [[$3 .. " = " .. $2 .. "( " .. $4 .. " )" ]]},

    {"decoratedfunc", "'@' funcname local Name fatarrowdef",
      [["local " .. $4 .. " = " .. $2 .. "( " .. $5 .. " )" ]]},


    {"stat", "decoratedfunc"},

    -- {"stat","function funcname funcbody"},
    --   {"stat","local function Name funcbody"},

    --tables

    {"tableconstructor", "'{' fieldlist '}'"},
   
    {"fieldlist", "field fieldlist_2 fieldlist_3"},
    {"fieldlist", ""},
    {"fieldlist_2", "fieldsep field fieldlist_2"},
    {"fieldlist_2", ""},
    {"fieldlist_3", "fieldsep"},
    {"fieldlist_3", ""},

    {"field", "'[' exp ']' fieldass exp"},
    {"field", "Name fieldass exp"},
    {"field", "exp"},
    
    {"fieldass", "'='"},
    {"fieldass", "':'", [[" ="]]},

    {"fieldsep", "','"},
    {"fieldsep", "';'"},

    --basics

    {"binop", "'+'"},
    {"binop", "'-'"},
    {"binop", "'*'"},
    {"binop", "'/'"},
    {"binop", "'^'"},
    {"binop", "'%'"},
    {"binop", "'..'"},
    {"binop", "'<'"},
    {"binop", "'<='"},
    {"binop", "'>'"},
    {"binop", "'>='"},
    {"binop", "'=='"},
    {"binop", "'~='"},
    {"binop", "'and'"},
    {"binop", "'or'"},

    {"unop", "'-'"},
    {"unop", "not", [["not "]]},
    {"unop", "'#'"}
}

grammar:addRules(rules)
-- grammar :_generate_nullable()

-- grammar:_debug(true)

-- local str = [[
-- {
--     one:  '==',
--     two: '<=',
--     '>=',
--     '~=',
--     '::',
--     '...',
--     '..',
--   }
-- ]]

str = [[

  local tab = {foo: 1, bar: 2, buzz: 3}
  tab.printfoo => print(self.foo)

  a (name) -> print("hello" .. name)

  bar += 2 * 5 - funcall()
  bar -= 5 * 5
  bar *= 5 * 5
  bar /= 5 * 5
  bar %= 5 * 5
  bar ^= 5 * 5

  bar++
  
  @decorator
  function somefunc(arguments, ...)
    print(whatever)
  end

  @decorator
  local function somefunc(arguments, ...)
    print(whatever)
  end

  @decorator 
  name (args) -> print(whatever)

  @decorator 
  local name (args) -> print(whatever)

  @decorator 
  name (args) => print(whatever)

  @decorator 
  local name (args) => print(whatever)

  long_func -> do
    print "a"
    print "b"
  end

]]

--str = [[
--print({1,2,3}[2],  "string":len())
--]]

local inpstr = tokenate.inputstream_from_text(str, "tabl")
-- local inpstr = tokenate.inputstream_from_file("parse.lua")
local tokstr = tokenate.new_tokenstream()
tokstr:tokenate_stream(inpstr, grammar)
-- tokstr:_debug()

-- print("\n===earley\n")
-- local time = os.clock()
local ptree = parse.earley_parse(grammar, tokstr, "block")

-- print(#tokstr.tokens, #ptree)

-- ptree:_debug("all")

-- for i,v in ipairs(ptree[33]) do
--   print(i,v:_debug())
-- end


local ast = parse.extract_parsetree(ptree)

-- print("\n\n=====\n")
-- ast:_debug()
-- -- -- print("input:\n" .. str)
print(ast.tree:print())
-- local time2 = os.clock()
-- print(time2 - time)
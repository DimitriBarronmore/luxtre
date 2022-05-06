
--[[
    module name: luxtre

    luxtre.loadfile(filename) > loads file/returns chunk
    luxtre.dofile(filename) > runs file
    luxtre.loadstring / dostring > same as above with string input
    luxtre.compile_file(filename) > compiles file to .lua

    include require loader for .lux file extension
--]]
local path = (...):gsub("loader", "")

local newGrammar = require(path .. "grammar")
local tokenate = require(path .. "tokenate")
local parse = require(path .. "parse")

local module = {}

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

local grammar = newGrammar()
grammar:addKeywords(keys)
grammar:addOperators(ops)
grammar:addRules(rules)
grammar :_generate_nullable()

local function generic_load(inputstream)
    local tokenstream = tokenate.new_tokenstream()
    tokenstream:tokenate_stream(inputstream, grammar)
    local status, res = pcall(parse.earley_parse, grammar, tokenstream, "block")
    if status == false then
        local msg_start = string.find(res, "%d:", 1)
        error(string.sub(res, msg_start + 3), 3)
    end
    local ast = parse.extract_parsetree(res)
    return ast.tree:print()
end

local load_string_function, default_env
if _VERSION > "Lua 5.1" then
    load_string_function = load
    default_env = _G
else
    load_string_function = loadstring
end

---@param filename string
---@param env table | nil
---Loads a .lux file by the given name and returns a chunk.
function module.loadfile(filename, env)
    env = env or default_env
    if type(filename) ~= "string" then
        error("filename must be a string", 2)
    end
    local filename = filename .. ".lux"
    local status,res = pcall(tokenate.inputstream_from_file, filename)
    if status == false then
        error("file '" .. filename .. "' does not exist", 2)
    end
    local output = generic_load(res)
    output = load_string_function(output, filename, "t", env)
    return output
end

---@param filename string
---@param env table | nil
---Runs a .lux file by the given name.
function module.dofile(filename, env)
    env = env or default_env
    local status, res = pcall(module.loadfile, filename, env)
    if status == false then
        error(res, 2)
    end
    return res()
end

---@param str string
---@param env table | nil
---Loads a string as luxtre coae.
function module.loadstring(str, env)
    env = env or default_env
    if type(str) ~= "string" then
        error("input must be a string", 2)
    end
    local tokenstream = tokenate.inputstream_from_text(str)
    local output = generic_load(tokenstream)
    output = load_string_function(output, str, "t", env)
    return output
end

---@param str string
---@param env table | nil
---Runs a string as luxtre code.
function module.dostring(str, env)
    env = env or default_env
    local status, res = pcall(module.loadstring, str, env)
    if status == false then
        error(res, 2)
    end
    return res()
end

function module.compile_file(filename)
    if type(filename) ~= "string" then
        error("filename must be a string", 2)
    end
    local filename_lux = filename .. ".lux"

    local status,res = pcall(tokenate.inputstream_from_file, filename_lux)
    if status == false then
        error("file '" .. filename_lux .. "' does not exist", 2)
    end
    local text = generic_load(res)

    local file = io.open(filename .. ".lua", "w+")
    file:write(text)
    file:flush()
    file:close()
end

local function filepath_search(filepath)
    for path in package.path:gmatch("[^;]+") do
        local fixed_path = path:gsub("%.lua", ".lux"):gsub("%?", (filepath:gsub("%.", "/")))
        local file = io.open(fixed_path)
        if file then file:close() return fixed_path end
    end
end

-- Based partially on code from Candran
-- Thanks for having an implementation to reference
-- https://github.com/Reuh/candran

local function luxtre_searcher(modulepath)
    local filepath = filepath_search(modulepath)
    if filepath then
        return function (filepath)
            local status, res = pcall(module.loadfile, filepath)
            if status == true then
                return res(modulepath)
            else
                error("error loading luxtre module '" .. modulepath .. "'\n" .. res, 3)
            end
        end
    else
        local err = ("no luxtre file '%s' in package.path"):format(modulepath)
        if _VERSION < "Lua 5.4" then
            err = "\n\t" .. err
        end
        return err
    end
end

function module.register()
	local searchers 
    if _VERSION == "Lua 5.1" then
		searchers = package.loaders
	else
		searchers = package.searchers
	end
    for _, s in ipairs(searchers) do
        if s == luxtre_searcher then
            return
        end
    end
    table.insert(searchers, 1, luxtre_searcher)
end

return module
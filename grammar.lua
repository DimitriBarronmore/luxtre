--[[
rule structure:
  terminals:
    {type = "match_type", value = "typename"}
    {type = "match_keyw", value = "keyword"}
    {type = "match_syms", value = "..."}
  nonterminals:
    {type = "match_rule", value = "rulename"}
]]

local function generate_pattern(str, grammar)
    local split_str = {}
    for w in string.gmatch(str, "%S+") do
        table.insert(split_str, w)
    end

    local full_pattern = {}
    local split_pos = 1
    while split_pos <= #split_str do
        local v = split_str[split_pos]
        local subrule = {}

        if v == 'Name'
        or v == 'Number'
        or v == 'String'
        then
            subrule.type = "match_type"
            subrule.value = v

        elseif grammar._keywords[v] then
          subrule.type = "match_keyw"
          subrule.value = v

        elseif string.sub(v,1,1) == "'" and string.sub(v,-1,-1) == "'" then
            subrule.type = "match_syms"
            subrule.value = string.sub(v,2,-2)
        else
            subrule.type = "match_rule"
            subrule.value = v
        end
        table.insert(full_pattern, subrule)

        split_pos = split_pos + 1
    end
    return full_pattern
end


--[[
grammar:
  _keywords: -set of keywords
  _operators: -list of multi-character operators, sorted by length
  _list:
    <token_name>:
      array of lists:
        {1: rule, 2: postprocessing function}
]]

---@class Grammar
---@field _keywords table
---@field _operators table
---@field _list table
local grammar_core = {}
grammar_core.__index = grammar_core


local add_rule = function(gram, name, rule, post)
  if not gram._list[name] then
    gram._list[name] = {}
  end
  table.insert(gram._list[name], {generate_pattern(rule, gram), post})
end

---@param input string | table
---@param rule? string
---@param post? function
--Add one or more rules to the grammar.
--If the first argument is a table of tables, the elements of each sub-table are used as arguments for individual calls.
function grammar_core:addRules(input, rule, post)
  if type(input) == "table" then
    for _,v in ipairs(input) do
      add_rule(self, v[1], v[2], v[3])
    end
  elseif type(input) == "string" then
    add_rule(self, input, rule, post)
  else
    error("first argument must be a string or list of rules",2)
  end
end

---@param keyw string | table
--Add one or more keywords to the grammar.
--If given a table of strings, all keywords will be added.
function grammar_core:addKeywords(keyw)
  if type(keyw) == "string" then
    self._keywords[keyw] = true
  elseif type(keyw) == "table" then
    for _,v in ipairs(keyw) do
      if type(v) == "string" then
        self._keywords[v] = true
      else
        error("given table contains non-string argument " .. tostring(v),2)
      end
    end
  else
    error("given argument must be a string or a list of strings",2)
  end
end

---@param oper string | table
--Add one or more multi-character operators to the grammar.
--If given a table of strings, all operators will be added.
function grammar_core:addOperators(oper)
  if type(oper) == "string" then
    table.insert(self._operators, oper)
    table.sort(self._operators, function(a,b) return #b < #a end)
  elseif type(oper) == "table" then
    for _,v in ipairs(oper) do
      if type(v) == "string" then
        table.insert(self._operators, v)
      else
        error("given table contains non-string argument " .. tostring(v),2)
      end
    end
    table.sort(self._operators, function(a,b) return #b < #a end)
  else
    error("given argument must be a string or a list of strings",2)
  end
end

---@param label string
--Prints all the keywords, operators, and rules contained in the grammar to stdout.
function grammar_core:_debug(label)
  local final_label = (label and ("'%s'"):format(label)) or ""
  print("dumping grammar " .. final_label)
  print("---keywords---")
  for i,v in pairs(self._keywords) do
    print(i,v)
  end
  print("---operators---")
  for i,v in ipairs(self._operators) do
    print(i,v)
  end
  print("---rules---")
  for name,list in pairs(self._list) do
    print("  " .. name)
    for num,rule in ipairs(list) do
      print(string.format("    %s: | length %s", num, #rule[1]))
      for _, tok in ipairs(rule[1]) do
        print(string.format("      type: %s | value: %s", tok.type, tok.value))
      end
    end
  end
end

---@return Grammar
--Creates a blank grammar object.
local function newGrammar()
  local output = setmetatable({}, grammar_core)
  output._keywords = {}
  output._operators = {}
  output._list = {}

  return output
end

return newGrammar

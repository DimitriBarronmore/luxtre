---[[ Earley Sets & Earley Items ]]---
--[[


--]]

local export = {}

---@class earley_item
---@field result string
---@field production_rule table
---@field current_index number
---@field begins_at number
---@field ends_at number
---@field postprocess function | nil
local earley_item_base = {}
earley_item_base.__index = earley_item_base

function earley_item_base:next_symbol()
  return self.production_rule[self.current_index]
end

function earley_item_base:advance()
  self.current_index = self.current_index + 1
end

function earley_item_base:clone()
  local clone = {}
  for k,v in pairs(self) do
    clone[k] = v
  end
  return setmetatable(clone, earley_item_base)
end

local function new_earleyitem(production_rule, result, begins_at)
  local tab = {}
  tab.production_rule = production_rule
  tab.result = result
  tab.begins_at = begins_at
  tab.current_index = 1
  return setmetatable(tab, earley_item_base)
end

---@class earley_set
---@field complete earley_item[]
---@field index number
local earley_set_base = {}
earley_set_base.__index = earley_set_base

function earley_set_base:predict_items(grammar, rulename)
  print(rulename)
  local productions_list = grammar._list[rulename]
  if not productions_list then
    error(("rule '%s' not found in grammar"):format(rulename), 4)
  end

  print( "predicting items for " .. rulename)
  for _,rule in ipairs(productions_list) do
    print("attempting to predict pattern " .. rule.pattern)
    local addrule = true
    for _,item in ipairs(self) do
      if item.production_rule == rule then
        addrule = false
        break
      end
    end
    if addrule then
      print("added to list")
      table.insert(self, new_earleyitem(rule, rulename, self.index))
    else print "duplicate found; item not added"
    end
  end
end

local function new_earleyset(index)
  return setmetatable({complete = {}, index = index}, earley_set_base)
end

---@class earley_array
---@field grammar lux_grammar
---@field tokenstr lux_tokenstream
local earley_array_base = {}
earley_array_base.__index = earley_array_base

function earley_array_base:predict_in(index, rulename)
  if not self[index] then
    self[index] = new_earleyset(index)
  end
  self[index]:predict_items(self.grammar, rulename)
end

function earley_array_base:add_to(index, item)
  if not self[index] then
    self[index] = new_earleyset(index)
  end
  table.insert(self[index], item)
end

local function new_earleyarray(grammar, tokenstr)
  return setmetatable({grammar = grammar, tokenstr = tokenstr}, earley_array_base)
end

local function print_items_in_set(set, reverse)
  local longest_pattern, longest_result = 0, 0
  for i,item in ipairs(set) do
    local rlen = item.result:len()
    local plen = item.production_rule.pattern:len()
    if rlen > longest_result then longest_result = rlen end
    if plen > longest_pattern then longest_pattern = plen end
  end
  for i, item in ipairs(set) do
    local tmp_concat = {}
      for w in string.gmatch(item.production_rule.pattern, "%S+") do
        table.insert(tmp_concat, w)
      end
      table.insert(tmp_concat, item.current_index, "●" )
      local index
      if reverse == true then
        index = item.ends_at
      else
        index = item.begins_at
      end
      local tmp_msg = ("  %s %s::>  %s %s (%s)"):format(item.result, string.rep(" ", longest_result - item.result:len()), table.concat(tmp_concat, " "),
          string.rep(" ", longest_pattern - item.production_rule.pattern:len()), index)
      print(tmp_msg)
  end
end

local function reverse_array(array)
  local newarray = {}
  for i = 1, #array do
    table.insert(newarray, {})

    local compset = array[i].complete
    for _,item in ipairs(compset) do
      local revitem = item:clone()
      revitem.ends_at = i
      table.insert(newarray[item.begins_at], revitem)
    end
  end
  return newarray
end

function earley_array_base:_debug()
  for i,set in ipairs(self) do
    print("set " .. i .. ":")
    print_items_in_set(set)
  end
  print("\n\n--complete\n")
  for i,set in ipairs(self) do
    print("set " .. i .. ":")
    local longest_result = 0
    for _,item in ipairs(set.complete) do
      local len = item.result:len()
      if len > longest_result then longest_result = len end
    end
  print("\n\n--reverse\n")
  local revarray = reverse_array(self)
  for i,set in ipairs(revarray) do
    print("set " .. i .. ":")
    print_items_in_set(set, true)
  end
end

-- function earley_array_base:

--big parser
function export.earley_parse(grammar, tokenstr, start_rule)
  if type(start_rule) ~= "string" then
    error(("invalid starting rule '%s'"):format(start_rule),2)
  end

  local array = new_earleyarray(grammar, tokenstr)
  array:predict_in(1, start_rule) -- initial block

  local current_set = 1
  while true do
    print("\n\n------")
    print(("current set: '%s'"):format(current_set))
    ---@type earley_set
    local set = array[current_set]
    if not set then break end

    local current_item = 1
    while true do
      print("\n\n=====")
      print(("current item: '%s'"):format(current_item))

      ---@type earley_item
      local item = set[current_item]
      if not item then break end

      print("item: " .. item.production_rule.pattern)

      -- check the next action to try
      local nextsym = item:next_symbol()
      if nextsym then print("nextrule: " .. nextsym.type .. " " .. nextsym.value) end

      if nextsym == nil then -- completion
        print("\nattempting completion")
        item.ends_at = current_set
        table.insert(array[current_set].complete, item)
        local startset = array[item.begins_at]

        for _, checkitem in ipairs(startset) do
          local checktoken = checkitem:next_symbol()
          if checktoken and checktoken.type == "match_rule" and checktoken.value == item.result then
            print("completed item " .. checkitem.result .. ": " .. checkitem.production_rule["pattern"])
            local new_item = checkitem:clone()
            new_item:advance()
            array:add_to(current_set, new_item)
          end
        end

      elseif nextsym.type == "match_rule" then -- prediction
        print("\nattempting prediction")
        
        local precompleted = false
        for _, compitem in ipairs(array[current_set].complete) do
          if compitem.result == nextsym.value then
            precompleted = true
            break
          end
        end
        if precompleted then
          local new_item = item:clone()
          new_item:advance()
          array:add_to(current_set, new_item)
        else
          set:predict_items(grammar, nextsym.value)
        end
      else -- scan
        print("\nattempting scan")
        ---@type lux_token
        local next_token = tokenstr.tokens[current_set]
        print(nextsym.type, nextsym.value)
        if not next_token then
          print("end of input: skipped scan")
        else
          print(next_token.type, next_token.value)
          if nextsym.type == "match_type" and nextsym.value == next_token.type
          or nextsym.type == "match_keyw" and nextsym.value == next_token.value
          or nextsym.type == "match_syms" and nextsym.value == next_token.value then
            --successful scan
            local new_item = item:clone()
            new_item:advance()
            array:add_to(current_set + 1, new_item)
            print "\nscan succeeded"
          else print "\nscan failed"
          end
        end
      end

      current_item = current_item + 1
    end
    current_set = current_set + 1
  end

  local success = true
  local errmsg
  if #array < #tokenstr.tokens+1 then
    -- print('failed to parse full input')
    -- print(#array, #tokenstr.tokens)
    local last_token = tokenstr.tokens[#array]
    success = false
    errmsg = "failed to parse full input\n" .. last_token.position[1] .. ":" .. last_token.position[2] .. "  "
    errmsg = errmsg .. string.sub(tokenstr._lines[last_token.position[1]],1,last_token.position[2]) .. "  <<<"
  else
    local hasstart = false
    for _,item in ipairs(array[#array].complete) do
      if item.result == start_rule and item.begins_at == 1 then
        hasstart = true
      end
    end
    if not hasstart then
      success = false
      errmsg = "failed to obtain a complete parse"
    end
  end

  if success == false then
    error(errmsg)
  end
  return array
    -- return array
  -- else
  --   print("failed to parse full input")
  --   print(#array, #tokenstr.tokens)
  --   return array
  -- end

end

return export

local debug = false

local function log(...)
  if debug == true then
    print(...)
  end
end

---[[ Earley Items ]]---


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

function earley_item_base:_debug(reverse, longest_pattern, longest_result)
  longest_pattern = longest_pattern or 2
  longest_result = longest_result or 2
  local tmp_concat = {}
  for w in string.gmatch(self.production_rule.pattern, "%S+") do
    table.insert(tmp_concat, w)
  end
  table.insert(tmp_concat, self.current_index, "●" )
  local index
  if reverse == true then
    index = self.ends_at
  else
    index = self.begins_at
  end
  local tmp_msg = ("  %s %s::>  %s %s (%s)"):format(self.result, string.rep(" ", longest_result - self.result:len()), table.concat(tmp_concat, " "),
      string.rep(" ", longest_pattern - self.production_rule.pattern:len()), index)
  return tmp_msg
end

local function new_earleyitem(production_rule, result, begins_at)
  local tab = {}
  tab.production_rule = production_rule
  tab.result = result
  tab.begins_at = begins_at
  tab.current_index = 1
  return setmetatable(tab, earley_item_base)
end


--- [[ Earley Sets ]] ---


---@class earley_set
---@field complete earley_item[]
---@field index number
local earley_set_base = {}
earley_set_base.__index = earley_set_base

function earley_set_base:predict_items(grammar, rulename)
  log(rulename)
  local productions_list = grammar._list[rulename]
  if not productions_list then
    error(("rule '%s' not found in grammar"):format(rulename), 4)
  end

  log( "predicting items for " .. rulename)
  for _,rule in ipairs(productions_list) do
    log("attempting to predict pattern " .. rule.pattern)
    local addrule = true
    for _,item in ipairs(self) do
      if item.production_rule == rule then
        addrule = false
        break
      end
    end
    if addrule then
      log("added to list")
      table.insert(self, new_earleyitem(rule, rulename, self.index))
    else log "duplicate found; item not added"
    end
  end
end

local function new_earleyset(index)
  return setmetatable({complete = {}, index = index}, earley_set_base)
end


--- [[ Earley Arrays ]] ---


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

local function reverse_array(array)
  local newarray = {}
  newarray.grammar = array.grammar
  newarray.tokenstr = array.tokenstr
  for i = 1, #array do
    table.insert(newarray, {})

    local compset = array[i].complete
    for _,item in ipairs(compset) do
      local revitem = item:clone()
      revitem.ends_at = i
      table.insert(newarray[item.begins_at], revitem)
    end
  end
  for _,set in ipairs(newarray) do
    table.sort(set, function(a,b) return a.ends_at > b.ends_at end)
  end

  return newarray
end


--- [[ Array Debug ]] ---


local function print_items_in_set(set, reverse)
  local longest_pattern, longest_result = 0, 0
  for i,item in ipairs(set) do
    local rlen = item.result:len()
    local plen = item.production_rule.pattern:len()
    if rlen > longest_result then longest_result = rlen end
    if plen > longest_pattern then longest_pattern = plen end
  end
  for i, item in ipairs(set) do
    print(item:_debug(reverse, longest_pattern, longest_result))
  end
end


function earley_array_base:_debug(ptype)
  ptype = ptype or "all"
  if ptype == "full" or ptype == "all" then
    print("\n--full\n")
    for i,set in ipairs(self) do
      print("set " .. i .. ":")
      print_items_in_set(set)
    end
  end
  if ptype == "all" or ptype == "complete" then
    print("\n--complete\n")
    for i,set in ipairs(self) do
      print("set " .. i .. ":")
      print_items_in_set(set.complete)
    end
  end
  if ptype == "all" or ptype == "reverse" then
    print("\n--reverse\n")
    local revarray = reverse_array(self)
    for i,set in ipairs(revarray) do
      print("set " .. i .. ":")
      print_items_in_set(set, true)
    end
  end
end



-- [[ Earley Recognizer & Parse Extractor ]] --


local function testscan(nextsym, next_token)
  return (nextsym.type == "match_type" and nextsym.value == next_token.type)
      or (nextsym.type == "match_keyw" and nextsym.value == next_token.value)
      or (nextsym.type == "match_syms" and nextsym.value == next_token.value)
end

--big parser
function export.earley_parse(grammar, tokenstr, start_rule)
  if type(start_rule) ~= "string" then
    error(("invalid starting rule '%s'"):format(start_rule),2)
  end

  local array = new_earleyarray(grammar, tokenstr)
  array:predict_in(1, start_rule) -- initial block

  local current_set = 1
  while true do
    log("\n\n------")
    log(("current set: '%s'"):format(current_set))
    ---@type earley_set
    local set = array[current_set]
    if not set then break end

    local current_item = 1
    while true do
      log("\n\n=====")
      log(("current item: '%s'"):format(current_item))

      ---@type earley_item
      local item = set[current_item]
      if not item then log "end of set" break end

      log("item: " .. item.production_rule.pattern)

      -- check the next action to try
      local nextsym = item:next_symbol()
      if nextsym then log("nextrule: " .. nextsym.type .. " " .. nextsym.value) end

      if nextsym == nil then -- completion
        log("\nattempting completion")
        
        local duplicate = false
        for _,r in ipairs(array[current_set].complete) do
          if r.production_rule == item.production_rule
          and r.begins_at == item.begins_at then
            duplicate = true
            log("duplicate completion found")
            break
          end
        end

        if not duplicate then
          table.insert(array[current_set].complete, item)
          local startset = array[item.begins_at]

          for _, checkitem in ipairs(startset) do
            local checktoken = checkitem:next_symbol()
            if checktoken and checktoken.type == "match_rule" and checktoken.value == item.result then
              log("completed item " .. checkitem.result .. ": " .. checkitem.production_rule["pattern"])
              local new_item = checkitem:clone()
              new_item:advance()
              array:add_to(current_set, new_item)
            end
          end
        end

      elseif nextsym.type == "match_rule" then -- prediction
        log("\nattempting prediction")

        local precompleted = false -- early completion
        for _, compitem in ipairs(array[current_set].complete) do
          if compitem.result == nextsym.value then
            precompleted = true
            break
          end
        end
        if precompleted then
          log("precompleted")
          local new_item = item:clone()
          new_item:advance()
          array:add_to(current_set, new_item)
        else
          set:predict_items(grammar, nextsym.value)
        end
      else -- scan
        log("\nattempting scan")
        ---@type lux_token
        local next_token = tokenstr.tokens[current_set]
        log(nextsym.type, nextsym.value)
        if not next_token then
          log("end of input: skipped scan")
        else
          log(next_token.type, next_token.value)
          if testscan(nextsym, next_token) then
            --successful scan
            local new_item = item:clone()
            new_item:advance()
            array:add_to(current_set + 1, new_item)
            log "\nscan succeeded"
          else log "\nscan failed"
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
    -- log('failed to parse full input')
    -- log(#array, #tokenstr.tokens)
    local last_token = tokenstr.tokens[#array]
    success = false
    errmsg = "failed to parse full input\n" .. last_token.position[1] .. ":" .. last_token.position[2] .. "  "
    errmsg = errmsg .. string.sub(tokenstr._lines[last_token.position[1]],1,last_token.position[2]) .. "  <<<"
  else
    local hasstart = false
    for _,item in ipairs(array[#array].complete) do
      if item.result == start_rule and item.begins_at == 1 then
        hasstart = true
        array.final_item = item
        break
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
  --   log("failed to parse full input")
  --   log(#array, #tokenstr.tokens)
  --   return array
  -- end

end

--- [[ AST GENERATION ]] ---

local stackmt = {}
stackmt.__index = stackmt
function stackmt:pop()
  table.remove(self, #self)
end
function stackmt:push(val)
  table.insert(self, #self+1, val)
end
function stackmt:gettop()
  return self[#self]
end
local function newstack()
  return setmetatable({}, stackmt)
end

local function extract_rule_components(revarray, item)
  local prule = item.production_rule
  local start_index = item.begins_at
  local end_index = item.ends_at
  local stack = newstack()
  local discovered = {}
  for i = 0, #prule do
    discovered[i] = {}
  end

  -- local current_index = 1
  while #stack < #prule do
    local topitem = stack:gettop()
    local index = topitem and topitem.ends_at or start_index

    local e_index
    if #stack == #prule - 1 then
      e_index = end_index
    else
      e_index = nil
    end

    log('---')
    local piece = prule[#stack+1]
    log(piece.value)
    log("stacklen " .. #stack)

    if index >= end_index then
      log("index went too far; backing up")
      discovered[#stack] = {}
      stack:pop()
    
    elseif piece.type == "match_rule" then
      ---@type earley_item[]
      log("matching rule " .. piece.value)
      log("index " .. index)
      local compset = revarray[index]
      local founditem = false
      for _, item in ipairs(compset) do
        if not discovered[#stack][item] then
          discovered[#stack][item] = true
          if item.result == piece.value
          and (e_index and item.ends_at == e_index or true) then
            log("found item", item:_debug(true))
            stack:push({type = "item", value = item, ends_at = item.ends_at})
            founditem = true
            break
          end
        end
      end
      if not founditem then
        log("did not find item; backing up")
        discovered[#stack] = {}
        stack:pop()
      end

    else --scan
      local checktoken = revarray.tokenstr.tokens[index]
      log("scanning for " .. piece.value)
      log("chktk", checktoken)
      log("index " .. index)
      if testscan(piece, checktoken) then
        stack:push({type = "scan", value = checktoken.value, ends_at = index + 1})
        log("scan success")
      else
        log("scan failure; backing up")
        discovered[#stack] = {}
        stack:pop()
      end
    end

  end
  return stack
end

local expand_tree
expand_tree = function (array, tree, items)
  for i,v in ipairs(items) do
    if v.type == "item" then
      local nbranch = {type = "branch", value = v.value}
      table.insert(tree, nbranch)
      local nitems = extract_rule_components(array, v.value)
      expand_tree(array, nbranch, nitems)
    else
      table.insert(tree,v)
    end
      
  end
end

local print_items
print_items = function(branch, indent)
  indent = indent or 0
  local indentstr = (" "):rep(indent)
  for i,v in ipairs(branch) do
    if v.type == "branch" then
      print(indentstr .. "item: " .. v.value.result)
      -- print("item: " .. i ..  indentstr .. v.item:_debug())
      print_items(v, indent + 4)
    else
      print(indentstr .. v.type .. ": " .. v.value)
    end
  end
end

function export.extract_parsetree(array)

  local revarray = reverse_array(array)

  local search_rule = array.final_item
  search_rule.ends_at = #array
  local stk = extract_rule_components(revarray, search_rule)

  local tree = {_debug = print_items}
  expand_tree(revarray, tree, stk)
 
  return tree

end

return export

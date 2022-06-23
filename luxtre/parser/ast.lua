
local path = (...):gsub("ast", "")
local parse = require(path .. "parse")
local reverse_array = parse.reverse_array

local ipairs = ipairs
local table_remove = table.remove
local table_insert = table.insert

--- [[ AST GENERATION ]] ---

local function testscan(nextsym, next_token)
    return (nextsym.type == "match_type" and nextsym.value == next_token.type)
        or (nextsym.type == "match_keyw" and nextsym.value == next_token.value)
        or (nextsym.type == "match_syms" and nextsym.value == next_token.value)
  end

local export = {}

local stackmt = {}
stackmt.__index = stackmt
function stackmt:pop()
  local val = self[#self]
  table_remove(self, #self)
  return val
end
function stackmt:push(val)
  table_insert(self, #self+1, val)
end
function stackmt:gettop()
  return self[#self]
end
local function newstack()
  return setmetatable({}, stackmt)
end

local function grab_children(leaf)
  local children = {}
  while leaf[3] do
    table_insert(children, 1, leaf[4])
    leaf = leaf[3]
  end
  return children
end

local ipairs = ipairs

--[[
procedure DFS(G, v) is
    label v as discovered
    for all directed edges from v to w that are in G.adjacentEdges(v) do
        if vertex w is not labeled as discovered then
            recursively call DFS(G, w)
--]]
-- local function get_edges(set, rule, count)

-- end

-- local dfs
-- local function dfs(array, item, start, discovered)
--   discovered[start] = true
--   local edges = get_edges(start)
--   for _, end in ipairs(edges) do
    
--   end
-- end

-- local function extract_rule_components(revarray, item, discovered)
--   local s_node, e_node = item.begins_at, item.ends_at
--   local rule, count = item.production_rule, 1
--   local discovered = discovered or {}


-- end

local st_push = stackmt.push
local st_pop = stackmt.pop
local st_top = stackmt.gettop
local function extract_rule_components(revarray, item)
  local prule = item.production_rule
  local start_node = item.begins_at
  local end_node = item.ends_at
  -- local stack = newstack()
  local stack = {}
  local discovered = {}

  if #prule == 0 then
    return {}
  end

  st_push(stack, {start_node, 1, nil, {type = "root", value = "nil"}}) -- node, depth
  while #stack > 0 do
    local current_node = st_pop(stack)
    -- Get the children
    local check_rule = prule[current_node[2]]
    local children = {}

    -- Edges
    if check_rule.type == "match_rule" then
      local node_set = revarray[current_node[1]]
      for _, edge in ipairs(node_set) do
        if edge.result == check_rule.value and not discovered[edge.ends_at] then
          local new_node = edge.ends_at
          if new_node == end_node and current_node[2] == #prule then
            local info = {type = "non-terminal", value = edge, rule = check_rule.value}
            return grab_children({new_node, current_node[2] + 1, current_node, info})
          elseif current_node[2] + 1 <= #prule then
            local info = {type = "non-terminal", value = edge, rule = check_rule.value}
            st_push(stack, {new_node, current_node[2] + 1, current_node, info})
          end
        end
      end

    -- Scans
    else
      local checktoken = revarray.tokenstr.tokens[current_node[1]]
      if testscan(check_rule, checktoken)
      or ( check_rule.type == "match_eof" and revarray.tokenstr.tokens[current_node[1] + 1] == nil ) then -- successful scan
        local new_node = current_node[1] + 1
        if check_rule.type == "match_eof" then
          checktoken = {value = "", _before = ""}
        end
        if new_node == end_node and current_node[2] == #prule then
          local info = {type = "terminal", value = checktoken.value, _before = checktoken._before,
                         position = checktoken.position, rule = checktoken.type}
          return grab_children({new_node, current_node[2] + 1, current_node, info})
        elseif current_node[2] + 1 <= #prule then
          local info = {type = "terminal", value = checktoken.value, _before = checktoken._before,
                         position = checktoken.position, rule = checktoken.type}
          st_push(stack, {new_node, current_node[2] + 1, current_node, info} )
        end
      end
    end
    
  end
  -- if execution gets here then nothing was found
  error(item:_debug() .. " no path found")

end

local print_items
print_items = function(branch, indent)
  indent = indent or 0
  local indentstr = (" "):rep(indent)
  for i,v in ipairs(branch.children) do
    if v.type == "non-terminal" then
      print(indentstr .. v.value:_debug())
      print_items(v, indent + 4)
    else
      print(indentstr .. v.type .. ": " .. v.value .. " | " .. v.position[1] )
    end
  end
end

local generic_print = function(self, outp)
  outp:line():append(self.value, self.position[1])
end
-- local generic_print = function(self) return (self._before or "") .. self.value end
--- take in an item in the format, expand it
local recurse_tree
recurse_tree = function(revarray, start)
  local rule = start.value
  start.print = start.value.production_rule.post
  start.children = extract_rule_components(revarray, rule)
  for _, child in ipairs(start.children) do
    if child.type ~= "non-terminal" then
      child.print = generic_print
    else
      recurse_tree(revarray, child)
    end
  end
end

function export.earley_extract(array)
  local stime = os.clock()
  local revarray = reverse_array(array)

  ---@type earley_item
  local search_rule = array.final_item
  search_rule.ends_at = #array

  ---@type lux_ast
  local tree = {
    output = {},
    posmap = {},
    tree = {}
  }
  tree._debug = function() print_items(tree.tree) end
  ---@type lux_ast_item
  local root_item = { type = "non-terminal",
                      value = search_rule, }

  tree.tree = root_item

  recurse_tree(revarray, root_item)

  local etime = os.clock()
  print("astt", etime - stime)
  return tree

end

return export
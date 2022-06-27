
local path = (...):gsub("ast", "")
local parse = require(path .. "parse")
local reverse_array = parse.reverse_array

local ipairs = ipairs
local pairs = pairs
local table_remove = table.remove
local table_insert = table.insert

--- [[ AST GENERATION ]] ---

local function testscan(nextsym, next_token)
  if next_token then
    return (nextsym.type == "match_type" and nextsym.value == next_token.type)
        or (nextsym.type == "match_keyw" and nextsym.value == next_token.value)
        or (nextsym.type == "match_syms" and nextsym.value == next_token.value)
  else
     return (nextsym.type == "match_eof")
  end
end

local export = {}

local function grab_children(leaf)
  local children = {}
  while leaf[3] do
    table_insert(children, 1, leaf[4])
    leaf = leaf[3]
  end
  return children
end

local pairs = pairs

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

function export.old_earley_extract(array)
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


local function grab_children(leaf)
  local children = {}
  while leaf[3] do
    table_insert(children, 1, leaf[4])
    leaf = leaf[3]
  end
  return children
end


-----==================

local stackmt = {}
stackmt.__index = stackmt
function stackmt:pop()
  local val = self[#self]
  table_remove(self, #self)
  return val
end
function stackmt:push(val)
  self[#self+1] = val
end
function stackmt:gettop()
  return self[#self]
end
local function newstack()
  return setmetatable({}, stackmt)
end

local st_push = stackmt.push
local st_pop = stackmt.pop
local st_top = stackmt.gettop

local queuemt = {}
queuemt.__index = queuemt

function queuemt:pop()
  local val = self[1]
  table_remove(self, 1)
  return val
end
function queuemt:push(val)
 self[#self+1] = val
end

function queuemt:gettop()
  return self[#self]
end
local function newqueue()
  return setmetatable({}, queuemt)
end

--[[
 1  procedure BFS(G, root) is
 2      let Q be a queue
 3      label root as explored
 4      Q.enqueue(root)
 5      while Q is not empty do
 6          v := Q.dequeue()
 7          if v is the goal then
 8              return v
 9          for all edges from v to w in G.adjacentEdges(v) do
10              if w is not labeled as explored then
11                  label w as explored
12                  Q.enqueue(w)
--]]


local function bfs_find(array, root)
  -- local queue = newstack()
  local queue = {}
  -- print("qu", queue)
  local explored = {}
  local prod_rule = root.production_rule
  local start, goal = root.begins_at, root.ends_at

  if #prod_rule == 0 then
    -- print("empty rule")
    return {start, 1, {"nil", {type = "nil", value = ""}}, {1, 1, {"rule", root}} }
  end

  --table format: {node, depth, item, parent}
  -- print"rootitems"
  -- for i,v in pairs(root) do print(i,v) end
  queue[#queue + 1] = {start, 1, {"rule", root} }
  explored[start] = true

  -- print("\n\nbfs_find starting")
  while #queue > 0 do
    -- local task = st_pop(queue)
    local task = queue[#queue]
    queue[#queue] = nil
    -- print("gdepth", task[1], goal)
    if task[1] == goal and task[2] == #prod_rule + 1 then
      -- print(task[2], (task[3]), task[1])
      -- print "goal found"
      return task
    end
    local next_path = prod_rule[task[2]]
    -- print("pdepth", #prod_rule, task[2])
    
    if next_path then
      -- print("np", next_path.value, next_path.type, (task[3][1] == "rule" and task[3][2]:_debug()), task[1])
      -- print "--"
      if next_path.type == "match_rule" then
        local linkset = array.links[task[1]][next_path.value]
        -- print("val", next_path.value)
        -- print("lset", linkset)
        if linkset then
          if not explored[linkset] then
            explored[linkset] = true
          end
          -- for _,edge in ipairs(linkset) do
          for i = 1, #linkset do
            local edge = linkset[i]
            if not explored[edge] then
              explored[edge] = true
              local e, r = edge[2], edge[1]
              -- print(_, edge[1]:_debug(), edge[2])
                -- print("adding,", e, r, r:_debug())
              queue[#queue + 1] = {e, task[2] + 1, {"rule", r}, task}
            end
          end
        end
      else
        -- print "ran into scan"
        local current_token = array.tokenstr.tokens[task[1]]
        -- print("tok", task[1], current_token and current_token.value, next_path.value)
        local matches = testscan(next_path, current_token)
        -- print("matches?", matches)
        if matches then
          -- print("m", current_token)
          queue[#queue + 1] = {task[1] + 1, task[2] + 1, {"scan", current_token}, task}
        end

      end
      -- print "======"
    else
      -- print "no next path"
    end
  end
  -- print "goal not found"
end

--[[
        {type = "non-terminal", value = edge, rule = check_rule.value}

        {type = "terminal", value = checktoken.value, _before = checktoken._before,
            position = checktoken.position, rule = checktoken.type}

              start.print = start.value.production_rule.post
]]

local generic_print = function(self, outp)
  outp:line():append(self.value, self.position and self.position[1])
end

local function bfs_iterate(revarray, root)
  local count = 0
  -- local findqueue = newqueue()
  local roottask = {type = "root", rule = root, children = {}, print = root.production_rule.post }
  local findqueue = {roottask}
  -- findqueue:push(roottask)
  while #findqueue > 0 do
    -- local task = findqueue:pop()
    count = count + 1
    local task = findqueue[#findqueue]
    findqueue[#findqueue] = nil
    -- print("task", task)
    local found = bfs_find(revarray, task.rule)

    if found then
      -- print("\n\n--debugging", task.rule:_debug())
      local items = {}
      repeat
        -- count = count + 1; print("c", count)
      --   for i,v in pairs(found) do print(i,v) end
      --   for i,v in pairs(found[3]) do print(">", i,v) end
      --   for i,v in pairs(found[3][2]) do print(">>", i,v) end
        -- print(found[3][2], task)
        table_insert(items, 1, found[3])
        found = found[4]
      until (not found) or found[3][2] == task.rule

      -- for i,v in ipairs(items) do
      for i = 1, #items do
        local v = items[i]
        -- print(i,v)
        -- table_insert(task.children, v)
        if v[1] == "rule" then
          -- print("pushing", i, v[2], v[2]:_debug())

          local pushrule = {type = "non-terminal", rule = v[2], children = {}, print = v[2].production_rule.post }
          -- table_insert(task.children, pushrule)
          task.children[#task.children+1] = pushrule
       
          -- findqueue:push( pushrule )
          findqueue[#findqueue+1] = pushrule
        elseif v[1] == "scan" then
          -- print("v")
          -- print(v[2])
          if v[2] then
            -- print("scan", v[2].value)
            -- for j,k in ipairs(v) do print("it", j,k) end
            task.children[#task.children+1] = {type = "terminal", value = v[2].value, rule = v[2].type, 
                                        position = v[2].position, print = generic_print}
          end
        elseif v[1] == "nil" then
          task.children[#task.children + 1] = {type = "nil", value = "", print = generic_print}
          -- print "nil'd"
        end
      end
    end
  end
  print("count", count)
  return roottask

--   for i,v in pairs(roottask.children) do print(i,v) end
--   print ">"
--     for i,v in pairs(roottask.children[1]) do print(i,v) end
--   print ">>"
--     for i,v in pairs(roottask.children[1][1]) do print(i,v) end
--     print ">>c"
--     for i,v in pairs(roottask.children[1].children) do print(i,v) end
end

function export.earley_extract(array)
  local stime = os.clock()

  local revarray = reverse_array(array)

  -- -- debug section
  -- for _,set in ipairs(revarray.links) do
  --   print("set", _)
  --   for _, subset in pairs(set) do
  --     print("subset", _)
  --     for i,v in ipairs(subset) do
  --       print(i,v[1]:_debug(), v[2])
  --     end
  --     print "==="
  --   end
  -- end
  -- print("\n\n")
  -- -- end debug

  array.final_item.ends_at = #array
  -- local task = bfs_find(revarray, array.final_item)
  local roottask = bfs_iterate(revarray, array.final_item)

  -- roottask:print()

  -- print("\n\n--")
  -- local items = {}
  -- repeat
  --   print("items", task)
  --   for i,v in ipairs(task) do print(i,v) end
  --   table_insert(items, 1, task[3])
  --   print("ntask", task, task[4])
  --   task = task[4]
  -- until task == nil
  -- print("----")
  -- for i,v in ipairs(items) do print(i,v, v:_debug()) end
  


  
  local etime = os.clock()
  print("\n\nastt", etime - stime)
  -- error "--"

  return roottask
end




return export
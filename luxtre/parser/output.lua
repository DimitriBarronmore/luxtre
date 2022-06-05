--[[
    - **scoped data**
    - get/manipulate scope on top
	- add scope to stack
	- pop scope from stack

alter function signature; sneak in extra info
	token:print( out, line = out.line)
	children are in array part of self
	access to vars:
		out - the relevant output class

**output class:**
	:do_once() - do the specified thing only the first time the token matches
	.scope - the current topmost scope 
		:push() - add new layer to stack
		:pop() - remove top layer from stack
	.line - the current line object (note: may span multiple lines of real output)
		:add_before() - add and return a line before the one being edited
		:add_after() - add and return a line after the one being edited
		:add_top() - add and return a line at the top of the file
		:add_bottom() - add and return a line at the bottom of the file
        :newline() - replace the current working line
		:write(str: text) - add text to the line object
		:write(leaf_obj) - run the leaf's print in given line
		- all functions return object for chaining
--]]

--[[
        CONCEPT: SECOND DRAFT
    File output is split into three sections:
    The HEADER, BODY, and FOOTER.

    The HEADER is a collection of single lines at the very top of the file.
    This section is used for things such as resolving pre-declared values
      (such as the _export table) or executing specific shared code.

    The FOOTER is the same as the header, but at the very bottom of the file.
    This section is used for final wrap-up, such as returning the file's exported values.

    Grammars can declare special header/footer lines which will always be
      inserted at the very beginning or end of the file, suitable for things
      such as locking a file into a sandbox or forcing it to return a module.

    The BODY is the main content of the code, and the main concern of the grammar.
    BODY lines are executed in CHUNKS, collections of a few related lines at a time.

    Within a CHUNK, lines to edit are stored on a stack. Output rules have the ability
      to create new header and footer lines, create new lines positioned before/after the
      current working line, in the chunk, and push/pop lines to the stack to change the
      current working line.

    Output is always written to the current working line, and rules are responsible for
      managing the stack responsibly and cleaning up after themselves.

    When a chunk is complete, the lines are added to the compiled BODY and a new chunk
      is put in position for editing.
    When the end of the file is reached, the HEADER, BODY, and FOOTER are added together
      and the final lines written to the output.

    Most rules will not need to create new lines. When a line/chunk is created, the creating rule is
      responsible for assigning the source line number.
]]

---@class outp_line
---@field __chunk lux_output
local line = {}
line.__index = line

function line:append(text)
    table.insert(self, tostring(text))
    return self
end

function line:pop()
    self.__chunk:pop()
    -- table.remove(self.__chunk.stack)
end

--[[
	This function comes directly from a stackoverflow answer by islet8.
	https://stackoverflow.com/a/16077650
--]]
local deepcopy
function deepcopy(o, seen)
    seen = seen or {}
    if o == nil then return nil end
    if seen[o] then return seen[o] end
  
    local no = {}
    seen[o] = no
    setmetatable(no, deepcopy(getmetatable(o), seen))
  
    for k, v in next, o, nil do
      k = (type(k) == 'table') and deepcopy(k, seen) or k
      v = (type(v) == 'table') and deepcopy(v, seen) or v
      no[k] = v
    end
    return no
  end

---@class lux_output_scope
---@field __chunk lux_output
---@field __parent outp_line
local scope = {}
scope.__index = scope
local new_scope

function scope:push()
    local ch = self.__chunk
    local newscope = new_scope(ch, self)
    newscope.__parent = self
    ch.scope = newscope
end

function scope:pop()
    local ch = self.__chunk
    ch.scope = self.__parent
end

function new_scope(output, prev)
    if not prev then
        prev = setmetatable({}, scope)
    end
    local tab = deepcopy(prev)
    tab.__chunk = output
    return tab
end






---@class lux_output
---@field _header table
---@field _footer table
---@field _body table
---@field _stack table
---@field _array table
---@field scope table
---@field data table
local output = {}
output.__index = output

---@return outp_line
function output:_new_line()
    local ln = {}
    ln._chunk = self
    return setmetatable(ln, line)
end 

function output:push_prior()
    local index = 1
    for i, v in ipairs(self._array) do
        if v == self._stack[#self._stack] then
            index = i
        end
    end
    local line = self:_new_line()
    self:_push(line, index)
    -- table.insert(self._array, index, line)
    return line
end

function output:push_next()
    local index = 1
    for i, v in ipairs(self._array) do
        if v == self._stack[#self._stack] then
            index = i + 1
        end
    end
    local line = self:_new_line()
    self:_push(line, index)
    -- table.insert(self._array, index, line)
    return line
end

function output:push_header()
    local line = self:_new_line()
    table.insert(self._header, line)
    table.insert(self._stack, line)
    return line
end

function output:push_footer()
    local line = self:_new_line()
    table.insert(self._footer, line)
    table.insert(self._stack, line)
    return line
end

function output:_push(line, index)
    line = line or self:_new_line()
    index = index or #self._array + 1
    table.insert(self._array, index, line)
    table.insert(self._stack, line)

    return line
end

function output:pop()
    table.remove(self._stack)
    return self._stack[#self._stack]
end

function output:line()
    return self._stack[#self._stack]
end

function output:flush()
    table.insert(self._body, self._array)
    self._array = {}
    self._stack = {}
    self:_push()
end

function output:print()
    self:flush()
    local concat = {}
    for _, line in ipairs(self._header) do
        table.insert(concat,(table.concat(line, " ")))
    end
    table.insert(concat,"----")
    for _, chunk in ipairs(self._body) do
        for _, line in ipairs(chunk) do
            table.insert(concat,(table.concat(line, " ")))
        end
    end
    table.insert(concat,"---")
    for _, line in ipairs(self._footer) do
        table.insert(concat,(table.concat(line, " ")))
    end
    return table.concat(concat, "\n")
end


---@return lux_output
local function new_output()
    local out = {}
    out._header = {}
    out._footer = {}
    out._body = {}

    out._stack = {}
    out._array = {}
    out.data = {}
    setmetatable(out, output)

    out.scope = new_scope(out)
    out:_push()
    return out
end

-- local ch = new_output()
-- ch:line():append("hi"):append("world")
-- ch.scope.test = "ttt"
-- ch:line():append(ch.scope.test)

-- local line2 = ch:push_prior():append("pre")

-- ch:push_next()
-- ch.scope:push()
-- ch.scope.test = " innit"
-- ch:line():append("lovely day" .. ch.scope.test)
-- ch:pop()
-- ch.scope:pop()
-- ch:line():append("pre2")

-- ch:push_header():append("header 1")
-- ch:line():append("boop " .. ch.scope.test):pop()
-- ch:push_footer():append("footer 1"):pop()
-- ch:push_header():append("header 2"):pop()
-- ch:push_footer():append("footer 2"):pop()


-- print(ch:print())


return new_output
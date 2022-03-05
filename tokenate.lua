
---@module "grammar"
--local grammar

local export = {}

--[[
  Class for reading through the input
    - iterate through individual lines until line is empty
--]]

---@class lux_inputstream
---@field current_line number
---@field current_index number
---@field lines string[]
local inputstream_base = {}
inputstream_base.__index = inputstream_base

---@param x? number The number of characters to peek ahead. Default 1.
---@return string | boolean
--Looks ahead within the current line without consuming characters.
--Returns nil if there are not enough remaining characters.
function inputstream_base:peek(x)
    if x == nil then x = 1 end
    local cline_str = self.lines[self.current_line]
    local cline_len = string.len(cline_str)
    if self.current_index + (x-1) > cline_len then
        return nil
    else
        return string.sub(cline_str, self.current_index, self.current_index + (x-1))
    end
end

---@param x? number The number of characters to peek ahead. Default 1.
---@return string | boolean
--Looks at the character x-1 ahead in the current line.
--Returns nil if there are not enough remaining characters.
function inputstream_base:peekAt(x)
    if x == nil then x = 1 end
    local cline_str = self.lines[self.current_line]
    local cline_len = string.len(cline_str)
    if self.current_index + (x-1) > cline_len then
        return nil
    else
        return string.sub(cline_str, self.current_index + (x-1), self.current_index + (x-1))
    end
end

---@param x? number The number of characters to consume. Default 1.
---@return string consumed_characters
---@return table position
--Consumes characters within the current line, removing them from the stream.
function inputstream_base:consume(x)
    local out_str = self:peek(x)
    if out_str then
        local out_pos = {self.current_line, self.current_index}
        self.current_index = self.current_index + x
        return out_str, out_pos
    end
end

---@return boolean
--Attempts to move on to the next line.
--Returns true if successful, false if there are no more lines.
function inputstream_base:nextLine()
    -- if self.current_line + 1 <= #self.lines then
        self.current_line = self.current_line + 1
        self.current_index = 0
    --     return true
    -- else
    --     return false
    -- end
end

---@param text string
--shoves the given string into the input text
function inputstream_base:splice(text)
    local current_line = self.lines[self.current_line]
    local before_line = current_line:sub(1, self.current_index)
    local after_line = current_line:sub(self.current_index, -1)
    self.lines[self.current_line] = table.concat({before_line, text, after_line}, " ")
end


---@param text string
---@return lux_inputstream
function export.inputstream_from_text(text)
    text = text:gsub('\r\n?', "\n")
    ---@type lux_inputstream
    local inpstr = { lines = {} }
    for line in text:gmatch("[^\n]+\n?") do
        if line:sub(-1) == "\n" then line = line:sub(1,-2) end
        print(line)
        table.insert(inpstr.lines, line)
    end
    inpstr.current_line = math.min(1, #inpstr.lines)
    inpstr.current_index = 1
    setmetatable(inpstr, inputstream_base)
    return inpstr
end

---@param filename string
---@return lux_inputstream
function export.inputstream_from_file(filename)
    local concat = {}
    for line in io.lines(filename) do
        table.insert(concat, line)
    end
    return export.inputstream_from_text(table.concat(concat,"\n"))
end

function inputstream_base:_debug()
    local concat = {}
    for _,v in pairs(self.lines) do
        table.insert(concat, v)
    end
    print(table.concat(concat, "\n"))
end

--[[
    Class for creating a stream of tokens
--]]

---@class lux_token
---@field type string
---@field value string
---@field position number[]
local token_base = {}
token_base.__index = token_base
local function newToken(type,value,position)
    return setmetatable({type = type, value = value, position = position}, token_base)
end

---@class lux_tokenstream
---@field tokens lux_token[]
---@field macros table
local tokenstream_base = {}
tokenstream_base.__index = tokenstream_base
function export.new_tokenstream()
    local out = {}
    out.tokens = {}
    out.macros = {}
    return setmetatable(out, tokenstream_base)
end

function tokenstream_base:insertToken(type,value,position)
    local token = newToken(type, value, position)
    table.insert(self.tokens, token)
end

function tokenstream_base:_debug()
    for k,v in ipairs(self.tokens) do
        local msg = "%d | type: %s | value: %s | position: %d:%d"
        msg = msg:format(k, v.type, v.value, v.position[1], v.position[2])
        print(msg)
    end
end

function tokenstream_base:create_macro(name, result, complex)
    local macro = {type = "simple", result = result}
    if complex then macro.type = "complex" end
    self.macros[name] = macro
end

---@param inpstr lux_inputstream
---@param grammar Grammar
---@return lux_tokenstream
function tokenstream_base:tokenate_stream(inpstr, grammar)
    while inpstr.current_line <= #inpstr.lines do
        local this_line = inpstr.lines[inpstr.current_line]
        local next_char, position = inpstr:consume(1)

        --detect start-of-line directives
        if next_char == "#" and position[2] == 1 then
            print("directive here", position[1], position[2])
            ---HANDLE directive
            -- do
            -- end
            inpstr:nextLine()
            goto continue
        end

        -- end of line detection
        if next_char == nil then
            inpstr:nextLine()
            goto continue
        end
        --ignore spaces
        if next_char == " " then
            goto continue
        end

        --test for words
        do
            local s, e = string.find(this_line, "[%a_][%a%d_]*", position[2])
            if s == position[2] then --match
                -- print("word:" .. next_char .. inpstr:consume(e-s))
                local name = next_char .. inpstr:consume(e-s)
                local type = "name"
                -- check against macros
                if self.macros[name] then
                   local macrodef = self.macros[name]
                   if macrodef.type == "simple" then
                    --ignore the word; splice in more text
                    inpstr:splice(macrodef.result)
                    goto continue
                   elseif macrodef.type == "complex" then
                       --find arguments and use them
                       local after_word = position[2]+#name
                       print(after_word)
                       local s2, e2, in_parens = string.find(this_line, " *(%b())")
                       print(position[1], s2)
                        if s2 == after_word then
                            inpstr:consume(e2-s2)
                            print(in_parens)
                            in_parens = in_parens:sub(2,-2)
                            local args = {}
                            -- for arg in in_parens:gmatch("[^|]*[^\\|]|?") do
                            for arg in in_parens:gmatch("[^|]*|?") do
                                table.insert(args, arg:match("[^|]*"))
                            end
                            print("args",table.concat(args, ","))
                            print("splicoe", macrodef.result:format(unpack(args)))
                            inpstr:splice(macrodef.result:format(unpack(args)))
                            goto continue
                        else
                            --error, no parens found
                            print("no parens found for complex macro")
                            goto continue
                        end
                   end
                end
                if grammar._keywords[name] then
                    type = "keyword"
                end
                self:insertToken(type, name, position)
                goto continue
            end
        end

        ::continue::
        -- if next_char and next_char ~= "" and next_char ~= " " then --testing
        --     self:insertToken("test", next_char, position)
        -- end
        -- print("nextchar", next_char)
        -- print(position[1],position[2])
        -- ::continue2::
    end
end


-- 	-- ignore spaces
-- 	if next_char == " " then
-- 		goto continue
-- 	end
-- 	--detect start-of-line directives
-- 	if next_char == "#" and position[2] == 1 then
-- 		<handle directive in some way>
-- 		inpstr:nextLine()
-- 		goto continue
-- 	end
--
-- 	--detect comments
-- 	if next_char == "-" then
-- 		if inpstr:peek(1) == "-" then
-- 			-- comments confirmed; check for multiline comments
-- 			if <confirmation of multiline> then
-- 				<find multiline>
-- 			else
-- 				inpstr:nextLine()
-- 				goto continue
-- 			end
-- 		end
-- 	end
--
-- 	::continue::
-- end


--- TESTING


--local st, sy = inps:consume(2)
--print(st,sy[1],sy[2])
--st, sy = inps:consume(4)
--print(st,sy[1],sy[2])
--inps:nextLine()
--st, sy = inps:consume(4)
--print(st,sy[1],sy[2])

return export
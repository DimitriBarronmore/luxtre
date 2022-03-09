
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
---@field name string
---@field source string
local inputstream_base = {}
inputstream_base.__index = inputstream_base

---@param x? number The number of characters to peek ahead. Default 1.
---@return string | boolean
--Looks ahead within the current line without consuming characters and concatenates to the end.
--Returns nil if there are not enough remaining characters.
function inputstream_base:peekTo(x)
    if x == nil then x = 1 end
    local out_pos = {self.current_line, self.current_index}
    local cline_str = self.lines[self.current_line]
    local cline_len = string.len(cline_str)
    if self.current_index + (x-1) > cline_len then
        return nil, {self.current_line, "<eol>"}
    else
        return string.sub(cline_str, self.current_index, self.current_index + (x-1)), out_pos
    end
end

---@param x? number The number of characters to peek ahead. Default 1.
---@return string | boolean
--Looks at the character x-1 ahead in the current line.
--Returns nil if there are not enough remaining characters.
function inputstream_base:peek(x)
    if x == nil then x = 1 end
    local out_pos = {self.current_line, self.current_index}
    local cline_str = self.lines[self.current_line]
    local cline_len = string.len(cline_str)
    if self.current_index + (x-1) > cline_len then
        return nil, {self.current_line, "<eol>"}
    else
        return string.sub(cline_str, self.current_index + (x-1), self.current_index + (x-1)), out_pos
    end
end

---@param x? number The number of characters to consume. Default 1.
---@return string consumed_characters
---@return table position
--Consumes characters within the current line, removing them from the stream.
function inputstream_base:advance(x)
    x = x or 1
    self.current_index = self.current_index + x
    -- local out_str = self:peek(x)
    -- if out_str then
    --     local out_pos = {self.current_line, self.current_index}
    --     self.current_index = self.current_index + x
    --     return out_str, out_pos
    -- end
end

function inputstream_base:throw(errmsg, position)
    local msgpre = "luxtre: error loading module '%s' from %s:\n"
    msgpre = msgpre:format(self.name, self.source)
    local msgpos = ("%s:%s:%s "):format(self.name, tostring(position[1]), tostring(position[2]))
    local msgpost = msgpos .. errmsg

    error(msgpre .. msgpost, 0) -- TODO: change error level once full framework is in place
end

---@return boolean
--Attempts to move on to the next line.
--Returns true if successful, false if there are no more lines.
function inputstream_base:nextLine()
    -- if self.current_line + 1 <= #self.lines then
        self.current_line = self.current_line + 1
        self.current_index = 1
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
function export.inputstream_from_text(text, name)
    text = text:gsub('\r\n?', "\n")
    ---@type lux_inputstream
    local inpstr = { lines = {} }
    for line in text:gmatch("[^\n]*\n?") do
        if line:sub(-1) == "\n" then line = line:sub(1,-2) end
        -- print(line)
        table.insert(inpstr.lines, line)
    end
    inpstr.current_line = math.min(1, #inpstr.lines)
    inpstr.current_index = 1
    inpstr.name = name or "<unknown>"
    inpstr.source = "text"
    setmetatable(inpstr, inputstream_base)
    return inpstr
end

---@param filename string
---@return lux_inputstream
function export.inputstream_from_file(filename, name)
    local concat = {}
    for line in io.lines(filename) do
        table.insert(concat, line)
    end
    local inpstr = export.inputstream_from_text(table.concat(concat,"\n"), name)
    inpstr.source = ("file '%s'"):format(filename)
    return inpstr
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
    if complex then
        macro.type = "complex"
        macro.args = complex
    end
    self.macros[name] = macro
end

local function skip_to_significant(inpstr)
    while true do
        local next_char = inpstr:peek()
        if next_char == nil then
            inpstr:nextLine()
            if inpstr.current_line > #inpstr.lines then
                return false
            end
        elseif next_char == " " then
            inpstr:advance()
        else
            return true
        end
    end
end

local function handle_string(inpstr)
    local quotetype = '"'
    if inpstr:peek() == "'" then
        quotetype = "'"
    end
    local pos = 1
    while true do
        pos = pos + 1
        local char = inpstr:peek(pos)
        if char == nil then
            return false
        elseif char == quotetype and inpstr:peek(pos-1) ~= [[\]] then
            -- tokstr:insertToken("string", inpstr:peekTo(pos), position)
            -- inpstr:advance(pos)
            -- break
            return true, inpstr:peekTo(pos)
        end
    end
end

local function handle_multilinestr(pos, inpstr)
    local eqcount = 0
    while true do
        pos = pos + 1
        local char = inpstr:peek(pos)
        if char == "=" then
            eqcount = eqcount + 1
        elseif char == "[" then
            break
        else -- not a multiline string
            return
        end
    end
    -- by this point we know for certain to begin a multiline string
    local chars = {}
    table.insert(chars, (inpstr:peekTo(pos)))
    inpstr:advance(pos)
    local isnewline = false
    while true do
        -- pos = pos + 1
        local char = inpstr:peek()
        if char == "]" then --begin search for closing brackets
            local passedeqs = true
            if eqcount > 0 then
                for i = 1, eqcount do
                    local char = inpstr:peek(i + 1)
                    if char ~= "=" then
                        passedeqs = false
                        break
                    end
                end
            end
            if passedeqs == true then
                if inpstr:peek(eqcount + 2) == "]" then
                    table.insert(chars, (inpstr:peekTo(eqcount + 2)) )
                    inpstr:advance(eqcount + 2)
                    return true, table.concat(chars)
                else
                    table.insert(chars, char)
                end
            else
                table.insert(chars, char)
            end
        elseif char == nil then
            table.insert(chars, "\n")
            inpstr:nextLine()
  
            isnewline = true
            if inpstr.current_line > #inpstr.lines then
                return false
            end
        else
            table.insert(chars, char)
        end
        if not isnewline then inpstr:advance() end
        isnewline = false
    end
end

local function grab_args(inpstr, position)
    local args = {}
    local chars = {}
    local isnewline = false
    while true do
        if not isnewline then
            inpstr:advance()
        end
        isnewline = false
        local char = inpstr:peek()
        if char == nil then
            inpstr:nextLine()
            if inpstr.current_line > #inpstr.lines then
                inpstr:throw("unterminated argument list", position)
            end
            isnewline = true
        elseif char:match("['\"]") then
            local status, arg = handle_string(inpstr)
            if status == false then
                inpstr:throw("unfinished string", position)
            elseif status == true then
                table.insert(chars, arg)
                inpstr:advance(arg:len()-1)
            end
        elseif char == "[" then
            local status, arg = handle_multilinestr(1, inpstr)
            if status == true then
                table.insert(chars, arg)
            elseif status == false then
                inpstr:throw("unterminated multiline string", position)
            elseif status == nil then
                table.insert(chars, arg)
            end
        elseif char == "," then
            local fullarg = table.concat(chars)
            table.insert(args, fullarg)
            chars = {}
        elseif char == ')' then
            local fullarg = table.concat(chars)
            table.insert(args, fullarg)
            inpstr:advance()
            break
        else
            table.insert(chars, char)
        end
    end
    return args
end 

local function handle_directive(tokstr, inpstr, position)
    local chars = {}
    while true do -- find first word
        inpstr:advance()
        local char, position = inpstr:peek()
        if char == nil then
            if #chars > 0 then
                -- inpstr:throw("incomplete directive", position)
                break
            else
                inpstr:nextLine()
                return
            end
        elseif char:match("[%a%d_]") then
            table.insert(chars, char)
        elseif char == " " then
            if #chars > 0 then
                break
            end
        else
            inpstr:throw(("invalid character '%s' in directive"):format(char), position)
        end
    end
    local command = table.concat(chars)

    if command == "define" then -- Macros
        chars = {}
        local type = "simple"
        while true do
            inpstr:advance()
            local char, position = inpstr:peek()
            if char == " " then
                if #chars > 0 then
                    break
                end
            elseif char == nil then
                inpstr:throw("unfinished macro definition", position)
            elseif char:match("[%a%d_]") then
                table.insert(chars, char)
            elseif char == "(" then
                type = "complex"
                break
            else
            inpstr:throw(("invalid character '%s' in macro definition"):format(char), position)
            end
        end
        local macroname = table.concat(chars)

        if type == "simple" then
            while true do 
                inpstr:advance()
                local char, position = inpstr:peek()
                if char == nil then
                    inpstr:throw("unfinished macro definition", position)
                elseif char == "(" then
                    type = "complex"
                    break
                -- elseif inpstr:peekTo(2) == "as" then
                elseif char ~= " " then
                    break
                end
            end
        end

        local args = {}
        local used_args = {}
        if type == "complex" then -- grab args
            chars = {}
            local postspace = false
            local postvararg = false
            local postchar = false
            while true do
                inpstr:advance()
                local char, position = inpstr:peek()
                if char == nil then
                    inpstr:throw("unterminated argument list", position)
                elseif char == "," then
                    if postvararg then
                        inpstr:throw("unexpected character ',' after '...'", position)
                    end
                    local fullarg = table.concat(chars)
                    if used_args[fullarg] then
                        inpstr:throw("argument name used multiple times", position)
                    end
                    table.insert(args, fullarg)
                    used_args[fullarg] = true
                    chars = {}
                    postspace = false
                    postchar = false
                elseif char == ')' then
                    local fullarg = table.concat(chars)
                    if used_args[fullarg] then
                        inpstr:throw("argument name used multiple times", position)
                    end
                    table.insert(args, fullarg)
                    used_args[fullarg] = true
                    inpstr:advance()
                    break

                elseif char:match("[%a%d_]") then
                    postchar = true
                    if postvararg then
                        inpstr:throw(("unexpected character '%s' after '...'"):format(char), position)
                    end
                    if not postspace then
                        table.insert(chars, char)
                    else
                        inpstr:throw("expected ',' in argument list", position)
                    end
                elseif char == " " then
                    if #chars > 0 then
                        postspace = true
                    end
                elseif inpstr:peekTo(3) == "..." and postchar == false then
                    postvararg = true
                    table.insert(args, "...")
                    inpstr:advance(2)
                else
                    inpstr:throw(("unexpected character '%s' in argument name"):format(char), position)
                end
            end
        end
        -- print("args;", unpack(args))

        chars = {}
        -- if type == "simple" then --- grab result
            while true do
                local char, position = inpstr:peek()
                if char == nil then
                    if #chars == 0 then
                        inpstr:throw("unfinished macro definition", position)
                    else
                        local result = table.concat(chars)
                        if type == "complex" then
                            tokstr:create_macro(macroname, result, args)
                        else
                            tokstr:create_macro(macroname, result)
                        end
                        return
                    end
                elseif char == " " then
                    if #chars > 0 then
                        table.insert(chars, char)
                    end
                else
                    table.insert(chars, char)
                end
                inpstr:advance()
            end
    else
        inpstr:throw(("unimplemented directive '%s'"):format(command), position)

    end

end

local function handle_macro(tokstr, inpstr, name, position)
    local macrodef = tokstr.macros[name]
    if macrodef.type == "simple" then
        inpstr:advance(name:len())
        inpstr:splice(macrodef.result)
    else
        inpstr:advance(name:len())
        local char, position = inpstr:peek()
        while char == " " do
            inpstr:advance()
            char, position = inpstr:peek()
        end
        if char ~= "(" then
            inpstr:throw("macro '" .. name .. "' requires arguments", position)
        end
        local args = grab_args(inpstr, position)
        local outstring = macrodef.result
        for i,arg in ipairs(macrodef.args) do
            if arg == "..." then
                local remaining = {unpack(args, i)}
                outstring = outstring:gsub("%.%.%.", table.concat(remaining, ", "))
            else
                outstring = outstring:gsub(arg, args[i] or "")
            end
        end
        inpstr:splice(outstring)
    end
end


---@param inpstr lux_inputstream
---@param grammar Grammar
---@return lux_tokenstream
function tokenstream_base:tokenate_stream(inpstr, grammar)
    while true do
        local status = skip_to_significant(inpstr)
        if status == false then
            break
        end
        local check_symbol = false

        -- local this_line = inpstr.lines[inpstr.current_line]
        local next_char, position = inpstr:peek(1)


        if next_char == "#" and position[2] == 1 then -- Directive
            handle_directive(self, inpstr, position)

        elseif next_char:match("[%a_]") then -- Name / Macros / Keyword
            local pos = 2
            while true do
                local char = inpstr:peek(pos)
                if char == nil then
                    break
                elseif not char:match("[%a%d_]") then
                    break
                end
                pos = pos + 1
            end
            local name = inpstr:peekTo(pos-1)
            local type = "name"
            if self.macros[name] then
                handle_macro(self, inpstr, name, position)
            else
                if grammar._keywords[name] then
                    type = "keyword"
                end
                self:insertToken(type, name, position)
                -- print("word " .. name .. "|")
                inpstr:advance(pos-1)
            end

        elseif next_char:match("[%d.]") then -- Numbers
            local postdecimal = false
            local has_numbers = false
            if next_char:match("%.") then
                postdecimal = true
            else
                has_numbers = true
            end
            local pos = 1
            local continue = true
            local malformed = false
            while continue do
                pos = pos + 1
                local char = inpstr:peek(pos)
                if char == nil then
                    break
                elseif char == "." then
                    if postdecimal == false then
                        postdecimal = true
                    else
                        malformed = true
                    end
                elseif char:match("%d") then
                    has_numbers = true
                elseif not char:match("%d") then
                    break
                end
            end
            if malformed and has_numbers then  -- malformed number error
                local errmsg = ("malformed number '%s'"):format(inpstr:peekTo(pos-1))
                inpstr:throw(errmsg, position)
            elseif not has_numbers then
                check_symbol = true
            elseif not malformed and has_numbers then
                self:insertToken("number", inpstr:peekTo(pos-1), position)
                inpstr:advance(pos-1)
            end


        elseif next_char:match("['\"]") then -- single-line strings
            local status, str = handle_string(inpstr)
            if status == false then
                inpstr:throw("unfinished string", position)
            elseif status == true then
                self:insertToken("string", str, position)
                inpstr:advance(str:len())
            end

            
        elseif next_char == "[" then -- multiline strings
            local status, str = handle_multilinestr(1, inpstr)
            if status == true then
                self:insertToken("string", str, position)
            elseif status == false then
                inpstr:throw("unterminated multiline string", position)
            elseif status == nil then
                check_symbol = true
                -- self:insertToken("symbol", "[", position)
                -- inpstr:advance()
            end

        elseif inpstr:peekTo(2) == "--" then -- comments
            local status, str
            if inpstr:peek(3) == "[" then
                status, str = handle_multilinestr(3, inpstr)
            end
            if status == false then
                inpstr:throw("unterminated multiline comment", position)
            elseif status == nil then
                inpstr:nextLine()
            end

        else
            check_symbol = true
        end
        if check_symbol then
            local value = next_char
            local advance_to = 1
            for _,oper in ipairs(grammar._operators) do
                if inpstr:peekTo(oper:len()) == oper then
                    value = oper
                    advance_to = oper:len()
                    break
                end
            end
            self:insertToken("symbol", value, position)
            inpstr:advance(advance_to)
        end
    end
end

return export
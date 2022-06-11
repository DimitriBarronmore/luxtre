local path = (...):gsub("parser[./\\]preprocess", "")

local load_func = require(path .. "utils.safeload")

local new_sandbox = require(path .. "utils.sandbox")

local export = {}

--states:
-- need_left_parens (look for leftparen)
-- between_args (ignore spaces)
-- non_string (match chars and split on commas)
-- in_string (try to exit the string)
-- gather_multiline (for gathering the brackets)
-- gather_multiline_closing
-- in_multiline (try to exit the string)
local function extract_args(iter_str)
    local args = {}
    local curr_arg = {}
    local full_iter = {}
    local current_state = "need_left_parens"
    local string_type, last_char
    local eq_count = 0
    for char in iter_str:gmatch(".") do
        table.insert(full_iter, char)
        -- print(char)
        if current_state == "need_left_parens" then
            if not ( char:match("%s") or (char == "(") ) then
                return false
            elseif char == "(" then
                current_state = "non_string"
            end

        elseif current_state == "inbetween_args" then
            if not char:match("%s") then
                current_state = "non_string"
                    -- hotpatch in main state behavior
                    if char == "," then
                        table.insert(args, table.concat(curr_arg) or "")
                        curr_arg = {}
                        current_state = "inbetween_args"
                    elseif char == ")" then
                        table.insert(args, table.concat(curr_arg) or "")
                        return args, table.concat(full_iter)
                    elseif char == '"' or char == "'" then
                        current_state = "in_string"
                        string_type = char
                        table.insert(curr_arg, char)
                    elseif char == "[" then
                        string_type = 0
                        current_state = "gather_multiline"
                        table.insert(curr_arg, char)
                    else
                        table.insert(curr_arg, char)
                    end
            end

        elseif current_state == "non_string" then
            if char == "," then
                table.insert(args, table.concat(curr_arg) or "")
                curr_arg = {}
                current_state = "inbetween_args"
            elseif char == ")" then
                table.insert(args, table.concat(curr_arg) or "")
                return args, table.concat(full_iter)
            elseif char == '"' or char == "'" then
                current_state = "in_string"
                string_type = char
                table.insert(curr_arg, char)
            elseif char == "[" then
                string_type = 0
                current_state = "gather_multiline"
                table.insert(curr_arg, char)
            else
                table.insert(curr_arg, char)
            end

        elseif current_state == "in_string" then
            table.insert(curr_arg, char)
            if char == string_type then
                if last_char ~= "\\" then
                    current_state = "non_string"
                end
            end

        elseif current_state == "gather_multiline" then
            if char == "=" then
                string_type = string_type + 1
                table.insert(curr_arg, char)
            elseif char == "[" then
                current_state = "in_multiline"
                table.insert(curr_arg, char)
            else
                current_state = "non_string" -- quickpatch main state behavior
                if char == "," then
                    table.insert(args, table.concat(curr_arg) or "")
                    curr_arg = {}
                    current_state = "inbetween_args"
                elseif char == ")" then
                    table.insert(args, table.concat(curr_arg) or "")
                    return args
                elseif char == '"' or char == "'" then
                    current_state = "in_string"
                    string_type = char
                    table.insert(curr_arg, char)
                else
                    table.insert(curr_arg, char)
                end
            end

        elseif current_state == "in_multiline" then
            if char == "]" and last_char ~= "\\" then
                current_state = "gather_multiline_closing"
            end
            table.insert(curr_arg, char)

        elseif current_state == "gather_multiline_closing" then
            if char == "=" then
                eq_count = eq_count + 1
                if eq_count > string_type then
                    eq_count = 0
                    current_state = "in_multiline"
                end
            elseif char == "]" then
                if eq_count == string_type then
                    current_state = "non_string"
                    eq_count = 0
                else
                    current_state = "in_multiline"
                end
            end
            table.insert(curr_arg, char)
        end
        last_char = char
    end
    -- print("end of input")
end

local function change_macros(ppenv, line, count, name)
    for _, macro in ipairs(ppenv.macros.__listed) do
        local res = ppenv.macros[macro]
        local fixedmacro = macro:gsub("([%^$()%.[%]*+%-%?%%])", "%%%1")

        if type(res) == "string" then
            line = line:gsub(fixedmacro, ( res:gsub("%%", "%%%%")) )

        elseif type(res) == "table" then
            local s, e = 1,1
            repeat
                s, e = string.find(line, fixedmacro .. "%s*%(", e)
                if s then
                    local after = line:sub(e, -1)
                    local args, full = extract_args(after)
                    if args then
                        -- print('args found')
                        local fulltext = (fixedmacro .. full:gsub("([%^$()%.[%]*+%-%?%%])", "%%%1"))
                        line = line:gsub(fulltext, function()
                           local result = res._res
                        --    print(result)
                            if #args < # res._args then
                                for i = 1, #res._args - #args do
                                    args[#args+1] = ""
                                end
                            end
                            for i, argument in ipairs(args) do
                                local argname = res._args[i]
                                if argname and argname ~= "..." then
                                    result = result:gsub(argname, (argument:gsub("%%","%%%%")) )
                                elseif argname == "..." then
                                    result = result:gsub("%.%.%.", table.concat(args, ", ", i))
                                end
                            end
                           e = 1
                           return result
                        end)

                    end
                end
            until s == nil

        elseif type(res) == "function" then
            local s, e = 1,1
            repeat
                s, e = string.find(line, fixedmacro .. "%s*%(", e)
                if s then
                    local after = line:sub(e, -1)
                    local args, full = extract_args(after)
                    if args then
                        local full_match = fixedmacro .. full:gsub("([%^$()%.[%]*+%-%?%%])", "%%%1")
                        line = line:gsub(full_match, function()
                            local chunk = string.rep("\n", count) .. string.format("return macros[\"%s\"]( %s )", macro, table.concat(args, ", "))
                            local f, err = load_func(chunk, name .. " (preprocessor", "t", ppenv)
                            if err then
                                error(err,2)
                            end
                            local res = tostring(f())
                            if res == "" or res == nil then
                                res = " "
                            end
                            return res
                        end)
                    end
                end
            until s == nil
        end

    end
    return line
end

local macros_mt = {
    __newindex = function(t,k,v)
        local s, e, parens = k:find("(%b())$")
        if s then
            k = k:sub(1, s-1)
            -- print(k)
            parens = parens:sub(2,-1)
            -- print(parens)
            local argnames = {}

            for arg in parens:gmatch("%s*([%a%d_ %.]+)[,)]") do
                -- print(arg)
                table.insert(argnames, arg)
            end
            v = {_args = argnames, _res = v}
            -- print(v._res)
        end

        table.insert(t.__listed, k)
        rawset(t,k,v)
    end
}

local function setup_sandbox(name)
    name = name or ""
    local sandbox = new_sandbox()
    sandbox.macros = setmetatable({__listed = {}}, macros_mt)
    sandbox._output = {}
    sandbox._write_lines = {}
    sandbox._linemap = {}

    sandbox._write = function(num)
        table.insert(sandbox._output, sandbox._write_lines[num])
        sandbox._linemap[#sandbox._output] = num
    end

    return sandbox
end

local function multiline_status(line, in_string, eqs)
    local s, e = 1, nil
    repeat
        if not in_string then
            s, e, eqs = line:find("%[(=*)%[", s)
            if s then
                in_string = true
            end
        else
            s, e = line:find(("]%s]"):format(eqs), s, true)
            if s then
                in_string = false
                eqs = ""
            end
        end
    until s == nil
    return in_string, eqs
end

local function check_conditional(line, hanging_conditional)
    local s = 1
    repeat
    if not hanging_conditional then
        local r1 = {line:find("then", s)}
        local r2 = {line:find("else", s)}
        local r3 = {line:find("do", s)}
        local r4 = {line:find("repeat", s)}
        local result = (r1[1] and r1)
                    or (r2[1] and r2)
                    or (r3[1] and r3)
                    or (r4[1] and r4)
                    or nil
        if result then
            hanging_conditional = true
            s = result[2]
        else
            s = nil
        end
    else
        local s1,e1 = line:find("end", s)
        local s2,e2 = line:find("until", s)
        if s1 then
            s = e1
            hanging_conditional = false
        elseif s2 then
            s = e2
            hanging_conditional = false
        else
            s = nil
        end
    end
    until s == nil
    return hanging_conditional
end

function export.compile_lines(text, name)
	name = name or "<lux input>"

    local ppenv = setup_sandbox(name)
    local count = 0
    local in_string, eqs = false, ""
    local hanging_conditional = false
    local direc_lines = {}
    
    for line in (text .. "\n"):gmatch(".-\n") do
        line = line:gsub("\n", "")
        count = count + 1
        if count == 1 and line:match("^#!") then
            table.insert(ppenv._output, "")
            ppenv._linemap[#ppenv._output] = count
        elseif line:match("^%s*#")
          and not in_string then -- DIRECTIVES  

            -- Special Directives
            -- #define syntax
            line = line:gsub("^%s*#%s*define%s+([^%s()]+)%s+(.+)$", "macros[\"%1\"] = [===[%2]===]")
            -- function-like define
            line = line:gsub("^%s*#%s*define%s+([^%s]+%b())%s+(.+)$", "macros[\"%1\"] = [===[%2]===]")
            -- blank define
            line = line:gsub("^%s*#%s*define%s+([^%s()]+)%s*$", "macros[\"%1\"] = ''")
            line = line:gsub("^%s*#%s*define%s+([^%s]+%b())%s*$", "macros[\"%1\"] = ''")

            -- print(line)

            -- if-elseif-else chain handling
            hanging_conditional = check_conditional(line, hanging_conditional)
            local stripped = line:gsub("^%s*#", "")
            table.insert(direc_lines, stripped)
            table.insert(ppenv._output, "")
            ppenv._linemap[#ppenv._output] = count

        else --normal lines
            
            -- write blocks
            if hanging_conditional then
                line = change_macros(ppenv, line, count, name)
                ppenv._write_lines[count] = line
                table.insert(direc_lines,("_write(%d)"):format(count))
                table.insert(ppenv._output, "")
                ppenv._linemap[#ppenv._output] = count
            else
            	if #direc_lines > 0 then -- execution
					local chunk = string.rep("\n", count-1-#direc_lines) .. table.concat(direc_lines, "\n")
					direc_lines = {}
                    local func, err = load_func(chunk, name .. " (preprocessor)", "t", ppenv)
                    if err then
                        error(err,2)
                    end
                    func()

				end

                line = change_macros(ppenv, line, count, name)
                in_string, eqs = multiline_status(line, in_string, eqs)
                table.insert(ppenv._output, line)
                ppenv._linemap[#ppenv._output] = count
            end
        end
    end
    return ppenv
    -- print(table.concat(ppenv._output, "-\n"))

    -- return table.concat(direc_lines), write_lines
end

return export
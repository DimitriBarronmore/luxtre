local path = (...):gsub("preprocess", "")

local load_func = require(path .. "safeload")

local unpack = unpack
if _VERSION > "Lua 5.1" then
    unpack = table.unpack
end

local export = {}

local function copy(tab)
    local newtab = {}
    for key, value in pairs(tab) do
        if type(value) == "table" then
            newtab[key] = copy(value)
        else
            newtab[key] = value
        end
    end
    return newtab
end
  
  -- A safe sandbox for directives.
  -- This will be copied anew for each new file being processed.
  local sandbox_blueprint = {
      _VERSION = _VERSION,
      coroutine = copy(coroutine),
      io = copy(io),
      math = copy(math),
      string = copy(string),
      table = copy(table),
      assert = assert,
      error = error,
      ipairs = ipairs,
      next = next,
      pairs = pairs,
      pcall = pcall,
      print = print,
      select = select,
      tonumber = tonumber,
      tostring = tostring,
      type = type,
      unpack = unpack,
      xpcall = xpcall
}

local function change_macros(ppenv, line, count, name)
    for _, macro in ipairs(ppenv.macros.__listed) do
        local res = ppenv.macros[macro]
        if type(res) == "string" then
            line = line:gsub(macro, res)
        elseif type(res) == "function" then
            line = line:gsub(macro .. "%s-(%b())", function(args)
                local chunk = string.rep("\n", count) .. string.format("return macros[\"%s\"]%s", macro, args)
                local f, err = load_func(chunk, name .. " (preprocessor", "t", ppenv)
                if err then
                    error(err,2)
                end
                local res = f()
                if res == "" or res == nil then
                    res = " "
                end
                return res
            end)
        end
    end
    return line
end

local macros_mt = {
    __newindex = function(t,k,v)
        table.insert(t.__listed, k)
        rawset(t,k,v)
    end
}

local function setup_sandbox(name)
    name = name or ""
    local sandbox = copy(sandbox_blueprint)
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
        if line:match("^%s*#") 
          and not line:match("^#!")
          and not in_string then -- DIRECTIVES  

            -- Special Directives
            -- #define syntax
            line = line:gsub("^%s*#%s*define%s+([^%s()]+)%s+(.+)$", "macros[\"%1\"] = [===[%2]===]")

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
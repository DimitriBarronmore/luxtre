local path = (...):gsub("preprocess", "")

local load_func = require(path .. "safeload")

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

local function setup_sandbox(name)
    name = name or ""
    local sandbox = copy(sandbox_blueprint)
    sandbox.macros = {}
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

local function check_conditional(line)
    return line:find("then%s*$")
        or line:find("else%s*$")
        or line:find("do%s*$")
        or line:find("repeat%s*$")
end

local function compile_lines(text, name)
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
            
            -- if-elseif-else chain handling
            hanging_conditional = check_conditional(line)
            local stripped = line:gsub("^%s*#", "")
            table.insert(direc_lines, stripped)
            table.insert(ppenv._output, "")
            ppenv._linemap[#ppenv._output] = count

        else --normal lines
            if hanging_conditional then
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

--------------------

-- local txt = compile_lines([==[

-- #! shebang

-- normline
-- #line1
-- #line2 if then
-- #cont
-- # then
-- [=[ ]=] --[[
--     #   line3 ]]
--     nor,a;
-- hhhhh
-- # else
--    # line4

-- 9
-- ]==])
local txt = compile_lines([==[
#! shebang

normalline
# dbg = false

stuff
stuff
# if dbg then
    hello world
# else
    goodbye world
# end

#local count = 0
#repeat
    hhh
    iii
#count = count + 1
#until count == 4
bye
]==])

for i, line in ipairs(txt._output) do
    print(i, txt._linemap[i], line)
end

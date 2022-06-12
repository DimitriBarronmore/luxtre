---@diagnostic disable: need-check-nil

local path = (...):gsub("grammars[./\\]generate_loaders", "")

local newGrammar = require(path .. "parser.grammar")
local tokenate = require(path .. "parser.tokenate")
local parse = require(path .. "parser.parse")
local ast = require(path .. "parser.ast")
local new_output = require(path .. "parser.output")

local load_func = require(path .. "utils.safeload")
local deepcopy = require(path .. "utils.deepcopy")

local std_grammar = require(path .. "grammars.std")


-- [ file loading ] --

local function create_grammar(apply_grammars)
    local grammar = newGrammar()
    -- if not apply_grammars[1] then
    --     apply_grammars[1] = std_grammar
    -- end
    for _, gfunc in ipairs(apply_grammars) do
        gfunc(grammar)
    end

    return grammar
end


local function generic_compile(inputstream, grammars)
    local grammar = create_grammar(grammars)
    local tokenstream = tokenate.new_tokenstream()
    tokenstream:tokenate_stream(inputstream, grammar)

    local status, res = pcall(parse.earley_parse, grammar, tokenstream, "START")
    if status == false then
        local msg_start = string.find(res, "%d:", 1)
        error(string.sub(res, (msg_start or 0)  + 3), 3)
    end

    local f_ast = ast.earley_extract(res)
    local output = new_output()
    f_ast.tree:print(output)
    return output:print()
end

local function wrap_errors(output, outputchunk) -- change later
    local check_err = function(...)
        local status = { pcall(outputchunk, ...) }
        if status[1] == false then
            local err = status[2]
            --print("ERROR")
            local _,_,cap = string.find(err, "%]:(%d+):")
            local count = 0
            local realline
            for line in (output .. "\n"):gmatch(".-\n") do
                count = count + 1
                if tostring(count) == cap then
                    realline = line
                    break
                end
            end
            err = err .. "\noriginal line:\n\t" .. realline:sub(1,-2)
            error(err, 0)
        else
            return unpack(status, 2)
        end
    end
    return check_err
end

local function fix_filename(filename, filetype)
    if type(filename) ~= "string" then
        error("filename must be a string", 3)
    end
    filename = filename .. filetype
    return filename
end

local function create_inpstream(filename)
    local status,res = pcall(tokenate.inputstream_from_file, filename)
    if status == false then
        error("file '" .. filename .. "' does not exist", 3)
    end
    return res
end

local function load_chunk(compiled_text, filename, env)
    local chunk, err = load_func(compiled_text, filename, "t", env)
    if err then
        error(err, 0)
    end
    local safe_chunk = wrap_errors(compiled_text, chunk)
    return safe_chunk
end

local function filepath_search(filepath, filetype)
    for path in package.path:gmatch("[^;]+") do
        local fixed_path = path:gsub("%.lua", filetype):gsub("%?", (filepath:gsub("%.", "/")))
        local file = io.open(fixed_path)
        if file then file:close() return fixed_path end
    end
end

---@param filetype string
---The file extension (including dot) to search for.
---@param grammars table
---A table of grammars to apply
-- Take a list of grammars and make a set of load funcs for them
local function create_loaders(filetype, grammars)
    filetype = filetype or ".lux"
    grammars = grammars or {std_grammar}
    local loaders = {}

    loaders.loadfile = function(filename, env)
        filename = fix_filename(filename, filetype)
        local inputstream = create_inpstream(filename)
        local compiled_text = generic_compile(inputstream, grammars)
        local chunk = load_chunk(compiled_text, filename, env)
        return chunk
    end

    loaders.dofile = function(filename, env)
        local status, res = pcall(loaders.loadfile, filename, env)
        if status == false then
            error(res, 2)
        end
        return res()
    end

    loaders.loadstring = function (str, env)
        if type(str) ~= "string" then
            error("input must be a string", 2)
        end
        local inputstream = tokenate.inputstream_from_text(str)
        local compiled_text = generic_compile(inputstream, grammars)
        local chunk = load_chunk(compiled_text, str, env)
        return chunk
    end

    loaders.dostring = function(str, env)
        local status, res = pcall(loaders.loadstring, str, env)
        if status == false then
            error(res, 2)
        end
        return res()
    end

    loaders.compile_file = function(filename, outputname)
        outputname = outputname or filename .. ".lua"
        local adjusted_filename = fix_filename(filename, filetype)
        local inputstream = create_inpstream(adjusted_filename)
        local compiled_text = generic_compile(inputstream, grammars)

        local file = io.open(outputname, "w+")
        file:write(compiled_text)
        file:flush()
        file:close()
    end


    -- Based partially on code from Candran
    -- Thanks for having an implementation to reference
    -- https://github.com/Reuh/candran

    local function luxtre_searcher(modulepath)
        local filepath = filepath_search(modulepath, filetype)
        if filepath then
            return function(filepath)
                local status, res = pcall(loaders.loadfile, filepath)
                if status == true then
                    return res(modulepath)
                else
                    error("error loading module '" .. modulepath .. "'\n" .. res, 3)
                end
            end
        else
            local err = ("no file '%s' in package.path"):format(modulepath .. filetype)
            if _VERSION < "Lua 5.4" then
                err = "\n\t" .. err
            end
            return err
        end
    end

    loaders.register = function()
        local searchers 
        if _VERSION == "Lua 5.1" then
            searchers = package.loaders
        else
    ---@diagnostic disable-next-line: deprecated
            searchers = package.searchers
        end
        for _, s in ipairs(searchers) do
            if s == luxtre_searcher then
                return
            end
        end
        table.insert(searchers, 1, luxtre_searcher)
    end
    

    return loaders
end

return create_loaders
local path = (...):gsub("grammars[./\\]read_grammars", "")
-- local create_loaders = require(path .. "grammars.generate_loaders")


local newGrammar = require(path .. "parser.grammar")
local preprocess = require(path .. "parser.preprocess")
local tokenate = require(path .. "parser.tokenate")
local parse = require(path .. "parser.parse")
local ast = require(path .. "parser.ast")
local new_output = require(path .. "parser.output")

local new_sandbox = require(path .. "utils.sandbox")
local load_func = require(path .. "utils.safeload")

local module = {}

-- @import grammar_name

local keys = {
    "keywords",
    "operators",
    "reset",
    "remove",
    "import"
}
local ops = {
    "->",
    "{%",
    "%}"
}
local rules = {
    {"START", "block <eof>", function(self, out)
        local ln = out:push_header()
        ln:append("return function( grammar )")
        ln:append([[


local __repeatable_post_base = function(self, out)
    return { }
end
local __repeatable_post_gather = function(self, out, gather)
    local tab = self.children[1]:print(out, true)
    local val = self.children[2]

    table.insert(tab, val)
    if gather then
        return tab
    else
        for _, child in ipairs(tab) do
            child:print(out)
        end
    end

end
        ]])
        out:pop()

        self.children[1]:print(out)
        ln = out:push_footer()
        ln:append("grammar:_generate_nullable()")
        ln:append("end")
        out:pop()
    end},

    {"reserve_kws", "'@' keywords '{' reserve_list '}'", function(self, out)
        local ln = out:push_header()
        ln:append("local __keys = {")
        self.children[4]:print(out)
        ln:append("\n}")
        ln:append("\ngrammar:addKeywords(__keys)")
        out:pop()
    end},

    {"reserve_kws", "'@' keywords remove '{' reserve_list '}'", function(self, out)
        local ln = out:push_header()
        ln:append("local __keys = {")
        self.children[5]:print(out)
        ln:append("\n}")
        ln:append("\nfor k,v in ipairs(__keys) do\n\tgrammar._keywords[v] = nil\nend ")
        out:pop()
    end},

    {"reserve_ops", "'@' operators '{' reserve_list '}'", function(self, out)
        local ln = out:push_header()
        ln:append("local __ops = {")
        self.children[4]:print(out)
        ln:append("\n}")
        ln:append("\ngrammar:addOperators(__ops)")
        out:pop()
    end},

    {"reserve_ops", "'@' operators remove '{' reserve_list '}'", function(self, out)
        local ln = out:push_header()
        ln:append("local __ops = {")
        self.children[5]:print(out)
        ln:append("\n}")
        ln:append([[

local operators = grammar._operators
for _,v in ipairs(__ops) do
    for i = #operators, 1, -1 do
        local op = operators[i]
        if op == v then
            table.remove(operators, i)
        end
    end
end
]])
        out:pop()
    end},

    {"reserve_list", "reserve_list ',' reserve_item", function(self, out) self.children[1]:print(out); self.children[3]:print(out) end},
    {"reserve_list", "reserve_item"},
    {"reserve_item", "String", function(self, out) out:line():append("\n\t" .. self.children[1].value .. ",") end},
    {"reserve_item", ""},

    {"block", "block statement", function(self, out) 
        self.children[1]:print(out)
        out:flush()
        self.children[2]:print(out)
    end},
    {"block", ""},

    {"statement", ""},
    {"statement", "functext"},
    {"statement", "ruledef"},
    {"statement", "reset_prod"},
    {"statement", "reserve_kws"},
    {"statement", "reserve_ops"},
    {"statement", "import_grammar"},

    {"reset_prod", "'@' reset Name", function(self, out)
        local ln = out:push_header()
        ln:append("grammar._list[\"" .. self.children[3].value .. "\"] = nil")
        ln:append("grammar._used[\"" .. self.children[3].value .. "\"] = nil")
        out:pop()
    end},

    {"import_grammar", "'@' import String", function(self, out)
        local ln = out:push_header()
        ln:append(([[
do
    local status, res = pcall(__load_grammar, %s)
    if status == false then
        error("failed import in " .. __filepath .. "\n\t" .. res, 2)
    else
        res(grammar)
    end
end
]]):format(self.children[3].value:gsub("^(['\"])%$", "__rootpath .. %1.")))
        out:pop()
    end},

    {"ruledef", "Name '->' rule_list catch_functext", function(self, out)
        local name = self.children[1].value
        out._tmp_curr_rulename = name
        self.children[4]:print(out)

        local rule_list = self.children[3]:print(out)
        for _,v in ipairs(rule_list) do
            local ln = out:push_prior()
            if v == [[""]] or v == [['']] then
                ln:append( ('grammar:addRule("%s", ""'):format(name) )
            else
                ln:append( ('grammar:addRule("%s", [=[%s]=]'):format(name, v) )
            end
            if out._tmp_caught_functext then
                ln:append((", %s_post"):format(name))
            end
            ln:append(")")
            out:pop()
        end
        out._tmp_curr_rulename = nil
        out._tmp_caught_functext = nil
    end},

    {"catch_functext", "functext", function(self, out)
        out._tmp_caught_functext = true
        local name = out._tmp_curr_rulename
        local ln = out:push_prior()
        ln:append( ("local %s_post = function(self, out)"):format(name) )
        self.children[1]:print(out)
        ln:append(" end")
        out:pop()
    end},
    {"catch_functext", ""},

	{"rule_list", "rule_pattern", function(self, out)

        return { table.concat(self.children[1]:print(out), " ") }
    end},
    {"rule_list", "rule_list '|' rule_list", function(self, out)
        local tab = self.children[1]:print(out)
        local tab2 = self.children[3]:print(out)
        for _,v in ipairs(tab2) do
            table.insert(tab, v)
        end
        return tab
    end},

    {"rule_pattern", "rule_pattern rule_item", function(self, out)
        local tab = self.children[1]:print(out)
        table.insert(tab, self.children[2]:print(out))
        return tab
    end},
    {"rule_pattern", "", function(self, out) return {} end},


    {"rule_item", "'(' rule_list ')'", function(self, out)
        local tab = self.children[2]:print(out)
        local name = ("(" .. table.concat(tab, "|") .. ")"):gsub(" ", "_")
        if not out.data.__used_ebnf then out.data.__used_ebnf = {} end
        if not out.data.__used_ebnf[name] then
            out.data.__used_ebnf[name] = true
            for _,v in ipairs(tab) do
                local ln = out:push_prior()
                if v == [[""]] or v == [['']] then
                    ln:append( ('grammar:addRule("%s", "")'):format(name) )
                else
                    ln:append( ('grammar:addRule("%s", [=[%s]=])'):format(name, v) )
                end
                out:pop()
            end
        end
        return name
    end},

    {"rule_item", "'[' rule_list ']'", function(self, out)
        local tab = self.children[2]:print(out)
        local name = ("[" .. table.concat(tab, "|") .. "]"):gsub(" ", "_")
        if not out.data.__used_ebnf then out.data.__used_ebnf = {} end
        if not out.data.__used_ebnf[name] then
            out.data.__used_ebnf[name] = true
            for _,v in ipairs(tab) do
                local ln = out:push_prior()
                if v == [[""]] or v == [['']] then
                    ln:append( ('grammar:addRule("%s", "")'):format(name) )
                else
                    ln:append( ('grammar:addRule("%s", [=[%s]=])'):format(name, v) )
                end
                out:pop()
            end
            local ln = out:push_prior()
            ln:append( ('grammar:addRule("%s", "")'):format(name) )
            out:pop()
        end
        return name
    end},

    {"rule_item", "'{' rule_list '}'", function(self, out)
        local tab = self.children[2]:print(out)
        local name = ("{" .. table.concat(tab, "|") .. "}"):gsub(" ", "_")
        if not out.data.__used_ebnf then out.data.__used_ebnf = {} end
        if not out.data.__used_ebnf[name] then
            out.data.__used_ebnf[name] = true
            for _,v in ipairs(tab) do
                local ln = out:push_prior()
                if v == [[""]] or v == [['']] then
                    ln:append( ('grammar:addRule("%s", "")'):format(name) )
                else
                    ln:append( ('grammar:addRule("%s", [=[%s]=])'):format(name, v) )
                end
                out:pop()
            end
            local ln = out:push_prior()
            ln:append( ('grammar:addRule("%s_lhs", "%s_lhs %s", __repeatable_post_gather)'):format(name, name, name) )
            local ln = out:push_prior()
            ln:append( ('grammar:addRule("%s_lhs", "", __repeatable_post_base)'):format(name) )
            out:pop()
            out:pop()
        end
        return name .. "_lhs"
    end},

    {"rule_item", "Name", function(self, out) return self.children[1].value end},
    {"rule_item", "String", function(self, out) return self.children[1].value end},
    {"rule_item", "Keyword", function(self, out) return self.children[1].value end},

    {"functext", "'{%' grab_any '%}'", function(self, out) out:line():append(self.children[2]:print(out) or "") end },

    {"grab_any", ""},
    {"grab_any", "grab_any any", function(self, out)
			return (self.children[1]:print(out) or "") .. (self.children[2].children[1]._before or "") .. self.children[2].children[1].value
	end,},
    {"any", "Name"},
    {"any", "Number"},
    {"any", "String"},
    {"any", "Symbol"},
    {"any", "Keyword"}
}



local grammar = newGrammar()
grammar:addKeywords(keys)
grammar:addOperators(ops)
grammar:addRules(rules)
grammar :_generate_nullable()

local function make_grammar_function(filename, env, print_out)
    local concat = {}
    local file = io.open(filename)
    if not file then
        error(("file %s does not exist"):format(filename), 2)
    end
    
---@diagnostic disable-next-line: need-check-nil
    for line in file:lines() do
        table.insert(concat, line)
    end
    local ppenv = preprocess(table.concat(concat, "\n"), filename)
    local inpstream = tokenate.inputstream_from_ppenv(ppenv)
    local tokstream = tokenate.new_tokenstream()
    tokstream:tokenate_stream(inpstream, grammar)

    local status, res = pcall(parse.earley_parse, grammar, tokstream, "START")
    if status == false then
        error(res, 2)
    end
    local fast = ast.earley_extract(res)
    local output = new_output()
    fast.tree:print(output)
    local compiled = output:print()
    if print_out then
        print(compiled)
    end

    local chunk, err = load_func(compiled, filename, "t", env)
    if err then
        error(err, 0)
    end

    return chunk()
end

module.loaded = {}
function module.load_grammar(name, print_out)
    if type(name) ~= "string" then
        error("given filename must be a string", 2)
    end
    name = name:gsub("^[./\\]", "")
    local fixedname = name:gsub("%.", "/")
    fixedname = fixedname .. ".luxg"

    if module.loaded[name] then
        return module.loaded[name]
    else
        local sandbox = new_sandbox()
        sandbox.__load_grammar = module.load_grammar
        sandbox.__filepath = name
        sandbox.__rootpath = name:gsub("[.\\/]?[^.\\/]-$", "")
        local status, res = pcall(make_grammar_function, fixedname, sandbox, print_out)
        if status == false then
            error(res, 2)
        else
            module.loaded[name] = res
            return res
        end
    end
end

return module
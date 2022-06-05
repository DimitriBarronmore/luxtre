local path = (...):gsub("grammars[./\\]read_grammars", "")

local newGrammar = require(path .. "parser.grammar")
local tokenate = require(path .. "parser.tokenate")
local parse = require(path .. "parser.parse")
local new_output = require(path .. "parser.output")
local load_func = require(path .. "utils.safeload")

local module = {}

--[[ grammar grammar: EBNF

    @reserve {sep, by, commas}
    -- handles both operators and keywords

    name -> rule | rule | rule {% function text here %}
    - all sub-rules in the same prod line use the same print-func

    {% loose function text %}

    in a rule:
        (inner-rules like this)
        -> pulls inner rule into new pattern; primarily a convenience
        [optional sets like this]
        -> pulls into new nullable pattern
        { repeating sets like this }
        -> pulls into left-recursive nullable pattern

--]]

local keys = {
    "keywords",
    "operators",
    "reset"
}
local ops = {
    "->",
    "{%",
    "%}"
}
local rules = {
    {"START", "block", function(self, out)
        local ln = out:push_header()
        ln:append("return function( output_grammar )")
        ln:append([[


local __repeatable_post_base = function(self, out)
    return { }
end
local __repeatable_post_gather = function(self, out)
    local tab = self.children[1]:print(out)
    table.insert(tab, self.children[2].children[1].value)
    return tab
end
        ]])
        out:pop()

        self.children[1]:print(out)
        ln = out:push_footer()
        ln:append("output_grammar:_generate_nullable()")
        ln:append("end")
        out:pop()
    end},

    {"reserve_kws", "'@' keywords '{' reserve_list '}'", function(self, out)
        out.data.has_keys = true
        local ln = out:push_header()
        ln:append("local __keys = {")
        self.children[4]:print(out)
        ln:append("\n}")
        ln:append("\noutput_grammar:addKeywords(__keys)")
        out:pop()
    end},
    {"reserve_ops", "'@' operators '{' reserve_list '}'", function(self, out)
        out.data.has_ops = true
        local ln = out:push_header()
        ln:append("local __ops = {")
        self.children[4]:print(out)
        ln:append("\n}")
        ln:append("\noutput_grammar:addOperators(__ops)")
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

    {"reset_prod", "'@' reset Name", function(self, out)
        local ln = out:push_header()
        ln:append("output_grammar._list[\"" .. self.children[3].value .. "\"] = nil")
        out:pop()
    end},

    {"ruledef", "Name '->' rule_list catch_functext", function(self, out)
        local name = self.children[1].value
        out._tmp_curr_rulename = name
        self.children[4]:print(out)

        local rule_list = self.children[3]:print(out)
        for _,v in ipairs(rule_list) do
            local ln = out:push_prior()
            ln:append( ("output_grammar:addRule(\"%s\", [=[%s]=]"):format(name, v) )
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
        local tab = self.children[2]:print()
        local name = ("(" .. table.concat(tab, "|") .. ")"):gsub(" ", "_")
        if not out.data.__used_ebnf then out.data.__used_ebnf = {} end
        if not out.data.__used_ebnf[name] then
            out.data.__used_ebnf[name] = true
            for _,v in ipairs(tab) do
                local ln = out:push_prior()
                ln:append( ('output_grammar:addRule("%s", [=[%s]=])'):format(name, v) )
                out:pop()
            end
        end
        return name
    end},

    {"rule_item", "'[' rule_list ']'", function(self, out)
        local tab = self.children[2]:print()
        local name = ("[" .. table.concat(tab, "|") .. "]"):gsub(" ", "_")
        if not out.data.__used_ebnf then out.data.__used_ebnf = {} end
        if not out.data.__used_ebnf[name] then
            out.data.__used_ebnf[name] = true
            for _,v in ipairs(tab) do
                local ln = out:push_prior()
                ln:append( ('output_grammar:addRule("%s", [=[%s]=])'):format(name, v) )
                out:pop()
            end
            local ln = out:push_prior()
            ln:append( ('output_grammar:addRule("%s", "")'):format(name) )
            out:pop()
        return name
        end
    end},

    {"rule_item", "'{' rule_list '}'", function(self, out)
        local tab = self.children[2]:print()
        local name = ("{" .. table.concat(tab, "|") .. "}"):gsub(" ", "_")
        if not out.data.__used_ebnf then out.data.__used_ebnf = {} end
        if not out.data.__used_ebnf[name] then
            out.data.__used_ebnf[name] = true
            for _,v in ipairs(tab) do
                local ln = out:push_prior()
                ln:append( ('output_grammar:addRule("%s", [=[%s]=])'):format(name, v) )
                out:pop()
            end
            local ln = out:push_prior()
            ln:append( ('output_grammar:addRule("%s_lhs", "%s_lhs %s", __repeatable_post_gather)'):format(name, name, name) )
            local ln = out:push_prior()
            ln:append( ('output_grammar:addRule("%s_lhs", "", __repeatable_post_base)'):format(name) )
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

local __repeatable_post_base = function(self, out)
    return { }
end
local __repeatable_post_gather = function(self, out)
    local tab = self.children[1]:print(out)
    table.insert(tab, self.children[2].children[1].value)
    return tab
end

-- local post_test = function(self, out)  for i,v in ipairs(self.children[1]:print()) do print(i,v) end  end
-- grammar:addRule("{String}", [=[String]=])
-- grammar:addRule("{String}", [=[Name]=])

-- grammar:addRule("{String}_lhs", "", __repeatable_post_base)
-- grammar:addRule("{String}_lhs", "{String}_lhs {String}", __repeatable_post_gather)
-- grammar:addRule("test", [=[{String}_lhs]=] , post_test )

-- -------
local txt = [[
@keywords {"name", "name2", "name3", "name4", "h", "nambs"}

@operators {
    "===", 
    "!=",
    "&&",
}

{% print ("arbitrary code") ** ==%}

--name -> Name [String | String] {Number | Symbol} | second (pattern | alt) | third pattern {%functext over here%}

{%  %}

test -> {String} {% for i,v in ipairs(self.children[1]:print()) do print(i,v) end %}

@operators {
    "$$", 
    "()",
    "^0",
}

--name -> different pattern [h test test] | patt2 | {partt3} | (p4 hh4 | alt4) {%different functext%}

@reset name

]]

-- local txt = [[
--     "H" "Name" "Name" h
-- ]]

-- local function load_grammar(tokenstream)
--     local pars = parse.earley_parse(grammar, tokenstream, "start")
--     local ast = parse.extract_parsetree(pars)
--     local out = new_output()
--     ast.tree:print(out)
--     local chunk = out:print()
-- end

local inpstream = tokenate.inputstream_from_text(txt)
local tokstream = tokenate.new_tokenstream()
tokstream:tokenate_stream(inpstream, grammar)
local pars = parse.earley_parse(grammar, tokstream, "START")
local ast = parse.extract_parsetree(pars)
local out = new_output()
ast.tree:print(out)
print(out:print())
# Custom Grammars
The backbone of Luxtre is the ability to define and combine custom grammars which can transform the final output of a file. To understand exactly how to write a grammar we first need to understand exactly how Luxtre processes code before it reaches the parser.

## Tokenization
After the pre-processor runs, the resulting code is converted into a series of the following basic terminal tokens:

- Name: A valid Lua variable name following the standard convention.
- Keyword: A Name which is set aside for special use by the current grammar.
- Number: A valid Lua number literal.
- String: Both single-line and multi-line string literals, surrounding quotes included.
- Symbol: A single character which falls into none of the previous categories.
- Operator: Multiple characters making up a compound operator defined by the grammar.

Luxtre's grammar files always operate directly on these basic terminals. There is currently no way to disable tokenization or alter the tokenization rules.

## Basic Syntax

### Keywords / Operators
Keyword and Operator rules can be added to the current grammar with `@keyword` and `@operator` statements.
```lua
@keywords {"list", "of", "strings"}
@operators {"list", "of", "strings"}
```
For example, for the base Lua grammar this looks something like:
```lua
@keywords {
    "do",
    "while",
    "repeat",
    "for",
    "end",
    "until",
    "break",
    "if",
    "elseif",
    [...]
}

@operators { "==", "<=", ">=", "~=", "...", [...] }
```
If the keyword `remove` is inserted before the list, the given items will be removed from the grammar.
```
@keywords remove {"list", "of", "strings"}
```

### Grammar Rules
Production rules can be added to the grammar with a rule definition statement:
```
rule_name -> rule definition
```

For each space-separated word in the definition the following rules are applied:
- If the word is one of the six terminals (Name, Number, String, Symbol, Keyword, Operator), the pattern matches any token of that type.
- If the word is a defined Keyword in the grammar, the pattern matches that keyword.
- If the word is a single or double-quoted string, the pattern matches the contents as a Symbol or Operator.
- If the word is `<eof>`, the pattern matches the end of the input.
- Otherwise, the pattern matches the named non-terminal.

Alternate production rules can be added to the definition using `|`.
```
rule -> Name | String | Number
```

Luxtre's output system is most easily used when sub-items are written explicitly in the style of plain BNF, but optional, repetitional, and grouping sub-patterns can be written. These patterns will be expanded into the necessary rules automatically.
```
grouping -> start (option 1 | option 2) ending
optional -> start [optional sequence] ending
repeating -> start {repeated sequence} ending
```

If you wish to remove a non-terminal entirely and start over, such as to replace one from a prior grammar, you can use a `@reset` statement. This will remove all productions of that rule from the grammar before the contents of the current file run.
```
@reset rule_name
```

## Code Blocks and Rule Printing
Text within the brackets `{* *}` is captured and used as a code block. On their own, code blocks are written directly into the output. When placed at the end of a rule definition, they become a print function.
```
rule_name -> pattern {* print behavior *}
```

Print functions are the way text is output to the final file. 
All grammars are required to have a single root production rule named `START.`
Luxtre does not post-process items at the time of discovery; rather, after the AST is assembled the `START` rule's `:print(out)` function is called and execution trickles down towards the leaves.

If a print function is not explictly declared, a default is used which simply calls `:print` on each of the current item's child branches/leaves.

Note that print functions do not need to actually output text; with careful management it is possible to perform the equivalent of semantic actions by resolving a production rule into an intermediate data structure. 

> Repeating sequence patterns make use of this. When `:print(out)` is called on a repeating sequence it returns an array of the matched rules. If you plan to use them, be sure to handle the output properly.

## Node Objects
Print functions have access to two variables: `self`, the current discovered node in the AST, and `out`, the current output stream (see "The Output Object" below). Each node has a simply defined structure which gives the user enough information to transform the final text output.
```
ast_node: {
    .type:  either "non-terminal" or "terminal"
    .value: if the node is a terminal, this is the original text.
            if the node is a non-terminal, contains internal table data.
    .rule:  if the node is a terminal, this is the type of terminal it is.
            if the node is a non-terminal, this is the name of the production rule.
    :print(out): the node's print function.
        NOTE: when calling this always make sure to pass the self and 'out' arguments.

    -- only in terminals --
    ._before: the whitespace/newline characters immediately preceeding the original text. situationally useful.
    .position: a table {line, column} containing the position of the original token in the input.

    -- only in non-terminals --
    .children: A table containing the matched sub-productions in order.
}
```

## The Output Object
The output object uses a pair of stacks to control how output is written to the final compiled code, as well as to provide scoped, shadowable information.
Output is split into three sections, the Header, Body, and Footer, each of which can have lines added individually.

### Primary Stack
```
out:line()
Returns the active line at the top of the stack. 
Initially set to a blank line in the Body.

out:push_next()
Push a new line to the top of the stack, positioned after the active line.
Returns the new line.

out:push_prior()
Push a new line to the top of the stack, positioned before the active line. 
Returns the new line.

out:push_header()
Push a new line to the top of the stack, positioned at the end of the header. 
Returns the new line.

out:push_footer()
Push a new line to the top of the stack, positioned at the end of the footer.

Returns the new line.

out:pop()
Pop the active line off the stack and return the new active line, if any.

out:flush()
Moves all previous lines to the output 
and resets the stack with a new Body line.

out.data
A static table which can be used for storing
non-scoped information about the state of the file.

out.scope
A secondary stack useful for storing
scoped information about the state of the file.

out.scope:push()
Push a new scope to the top of the stack. Deep-copies previous information.

out.scope:pop()
Pops the stack to revert the scope state.

out:print()
Returns the concatenated output as a string.
You shouldn't need to touch this yourself.
```

# Meta-Grammar
This is the grammar used by the grammar parser, presented as an advanced example.
```
@keywords {"keywords", "operators", "reset"}
@operators {"->", "{%", "%}"}

START -> block {%
    local ln = out:push_header()
    ln:append("return function( output_grammar )")
    ln:append([[


local __repeatable_post_base = function(self, out)
    return { }
end
local __repeatable_post_gather = function(self, out)
    local tab = self.children[1]:print(out)
    table.insert(tab, self.children[2].children[1])
    return tab
end
    ]])
    out:pop()

    self.children[1]:print(out)
    ln = out:push_footer()
    ln:append("output_grammar:_generate_nullable()")
    ln:append("end")
    out:pop()
%}

block -> {statement} {%
    for _,v in ipairs(self.children[1]:print(out)) do
        v:print(out)
        out:flush()
    end
%}

statement -> functext | ruledef | reset_prod | reserve_kws | reserve_ops

reserve_kws -> '@' keywords '{' reserve_list '}' {%
    local ln = out:push_header()
    ln:append("local __keys = {")
    self.children[4]:print(out)
    ln:append("\n}")
    ln:append("\noutput_grammar:addKeywords(__keys)")
    out:pop()
%}

reserve_kws -> '@' keywords remove '{' reserve_list '}' {%
    local ln = out:push_header()
    ln:append("local __keys = {")
    self.children[5]:print(out)
    ln:append("\n}")
    ln:append("\nfor k,v in ipairs(__keys) do\n\toutput_grammar._keywords[v] = nil\nend ")
    out:pop()
%}

reserve_ops -> '@' operators '{' reserve_list '}' {%
    local ln = out:push_header()
    ln:append("local __ops = {")
    self.children[4]:print(out)
    ln:append("\n}")
    ln:append("\noutput_grammar:addOperators(__ops)")
    out:pop()
%}

reserve_ops -> '@' operators remove '{' reserve_list '}' {%
    local ln = out:push_header()
    ln:append("local __ops = {")
    self.children[5]:print(out)
    ln:append("\n}")
    ln:append([[

local operators = output_grammar._operators
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
%}

reserve_list -> {reserve_item [',']}
reserve_item -> String

reset_prod -> '@' reset Name {%
    local ln = out:push_header()
    ln:append("output_grammar._list[\"" .. self.children[3].value .. "\"] = nil")
    out:pop()
%}

ruledef -> Name '->' rule_list [catch_functext] {%
    local name = self.children[1].value
    out._tmp_curr_rulename = name
    self.children[4]:print(out)

    local rule_list = self.children[3]:print(out)
    for _,v in ipairs(rule_list) do
        local ln = out:push_prior()
        if v == [[""]] or v == [['']] then
            ln:append( ('output_grammar:addRule("%s", ""'):format(name) )
        else
            ln:append( ('output_grammar:addRule("%s", [=[%s]=]'):format(name, v) )
        end
        if out._tmp_caught_functext then
            ln:append((", %s_post"):format(name))
        end
        ln:append(")")
        out:pop()
    end
    out._tmp_curr_rulename = nil
    out._tmp_caught_functext = nil
%}

catch_functext -> functext {%
    out._tmp_caught_functext = true
    local name = out._tmp_curr_rulename
    local ln = out:push_prior()
    ln:append( ("local %s_post = function(self, out)"):format(name) )
    self.children[1]:print(out)
    ln:append(" end")
    out:pop()
%}

functext -> '{%' gather_any '%}' {% out:line():append(self.children[2]:print(out) or "") %}

gather_any -> ""
gather_any -> gather_any any {% 
    return (self.children[1]:print(out) or "")
    .. (self.children[2].children[1]._before or "") .. self.children[2].children[1].value
%}

any -> Name | Number | String | Symbol | Keyword

rule_list -> rule_pattern {% return {table.concat(self.children[1]:print(out)," ")} %}

rule_list -> rule_list '|' rule_list {% 
    local tab = self.children[1]:print(out)
    local tab2 = self.children[3]:print(out)
    for _,v in ipairs(tab2) do
        table.insert(tab, v)
    end
    return tab
%}

rule_pattern -> rule_pattern rule_item {%
    local tab = self.children[1]:print(out)
    table.insert(tab, self.children[2]:print(out))
    return tab
%}
rule_pattern -> "" {% return {} %}

rule_item -> '(' rule_list ')' {% 
    local tab = self.children[2]:print(out)
    local name = ("(" .. table.concat(tab, "|") .. ")"):gsub(" ", "_")
    if not out.data.__used_ebnf then out.data.__used_ebnf = {} end
    if not out.data.__used_ebnf[name] then
        out.data.__used_ebnf[name] = true
        for _,v in ipairs(tab) do
            local ln = out:push_prior()
            if v == [[""]] or v == [['']] then
                ln:append( ('output_grammar:addRule("%s", "")'):format(name) )
            else
                ln:append( ('output_grammar:addRule("%s", [=[%s]=])'):format(name, v) )
            end
            out:pop()
        end
    end
    return name
%}

rule_item -> '[' rule_list ']' {% 
    local tab = self.children[2]:print(out)
    local name = ("[" .. table.concat(tab, "|") .. "]"):gsub(" ", "_")
    if not out.data.__used_ebnf then out.data.__used_ebnf = {} end
    if not out.data.__used_ebnf[name] then
        out.data.__used_ebnf[name] = true
        for _,v in ipairs(tab) do
            local ln = out:push_prior()
            if v == [[""]] or v == [['']] then
                ln:append( ('output_grammar:addRule("%s", "")'):format(name) )
            else
                ln:append( ('output_grammar:addRule("%s", [=[%s]=])'):format(name, v) )
            end
            out:pop()
        end
        local ln = out:push_prior()
        ln:append( ('output_grammar:addRule("%s", "")'):format(name) )
        out:pop()
    return name
    end
%}

rule_item -> '{' rule_list '}' {% 
    local tab = self.children[2]:print(out)
    local name = ("{" .. table.concat(tab, "|") .. "}"):gsub(" ", "_")
    if not out.data.__used_ebnf then out.data.__used_ebnf = {} end
    if not out.data.__used_ebnf[name] then
        out.data.__used_ebnf[name] = true
        for _,v in ipairs(tab) do
            local ln = out:push_prior()
            if v == [[""]] or v == [['']] then
                ln:append( ('output_grammar:addRule("%s", "")'):format(name) )
            else
                ln:append( ('output_grammar:addRule("%s", [=[%s]=])'):format(name, v) )
            end
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
%}

rule_item -> Name | String | Keyword {% return self.children[1].value %}

```
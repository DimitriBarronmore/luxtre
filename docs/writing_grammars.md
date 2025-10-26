# Custom Grammars
A cool feature of Luxtre is the ability to define and combine custom grammars which can transform the final output of a file. To understand exactly how to write a grammar we first need to understand exactly how Luxtre processes code before it reaches the parser.

> Note: Luxtre's compilation step is more than a little rickshaw and these features are EXTREMELY likely to change with further development. Forward-compatibility is not only not guaranteed, it should not be expected at this time. If you intend to make your own grammars in the current version, be prepared for them to not work in newer releases.

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
> Note: Repeating groups have special behavior in order to make them more useful. Calling `:print(out, true)` on a repeating sequence will set it to gather mode. In gather mode nothing is printed to the output, and the function instead returns an ordered table of every rule captured by the group.


## Extending Grammars
If you want to extend or alter an existing grammar, you can use an `@import` statement. This will apply the given file's grammar rules. You can use as many of these as you want, and they can be nested.
```
@import "filepath"
```

If you wish to remove a non-terminal from an existing grammar entirely and start over, you can use an `@reset` statement. This will remove all productions of that rule from the grammar.
```
@reset rule_name
```

Note that the order in which these statements run is important, even though you can write them anywhere in the file.

## Code Blocks and Rule Printing
Text within the brackets `{% %}` is captured and used as a code block. On their own, code blocks are written directly into the output. When placed at the end of a rule definition, they become a print function. Print functions have two arguments: `out`, and `fm`. 
```
rule_name -> pattern {% do print_things() end %}
```

Print functions are the way text is output to the final file. 
All grammars are required to have a root production rule named `START.`
Luxtre does not post-process items at the time of discovery; rather, after the AST is assembled the `START` rule's `:print(out)` function is called and execution trickles down towards the leaves.

If a print function is not explictly declared, a default is used which simply calls `:print` on each of the current item's child branches/leaves.

> Note that print functions do not need to actually output text; with careful management it is possible to perform the equivalent of semantic actions by resolving a production rule into an intermediate data structure. Be careful with this, as not making this behavior optional will interrupt the default echo-to-output print behavior and may make the rule harder to use.

## Setup and Cleanup

The `@setup` and `@cleanup` statements take a code block and turn them into a function which runs before or after the ast is printed, respectively. Both functions take two arguments: `out` and `args`. These are the file's output object, and the file's frontmatter. This is used by [`basic_local_scoping.luxg`](/luxtre/grammars/basic_local_scoping.luxg) and [`luxtre_standard.luxg`](/luxtre/grammars/luxtre_standard.luxg) to set up the basic scopes available in the standard grammar.

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

### Primary (Lines) Stack
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

out:push_catch()
Append a catch line to the top of the stack. This line will not be written to the output, instead silently capturing any text appended to it.

out:pop()
Pop the active line off the stack.
If the line popped is a catch line, the captured text will be returned as a string. 
Otherwise returns the new active line, if any.

out:flush()
Moves all previous lines to the output and resets the stack with a new Body line.

```

### Secondary (Scopes) Stack
Rather than holding lines, the secondary stack is useful for storing scoped information about the state of the file.
`out.scope` is always the top of scope stack, and is always a table which can be safely edited.
```
out.scope:push()
Creates a deep-copy of the top of the stack and pushes.

out.scope:pop()
Pops the stack, effectively reverting the stored values.
```

### Misc.
```
out.data
A static table which can be used for storing non-scoped information about the state of the file.
Regardless of the state of either stack, this table remains the same.

out:print()
Returns the concatenated output as a string.
You shouldn't need to touch this yourself.
```

### Line Objects
These are the main content of the primary stack and hold the final output text.
```
line:pop()
A shortcut to out:pop()

line:append(text, line_number)
Appends the given text to the line. Returns the line object for chaining.

If a line number is provided, this will be the line number that appears in error messages involving the appended text. If one is not provided, line numbers will be automatically backfilled the next time one is available. 

The backfilling mechanism means that if you're allowing terminals to print themselves, you don't usually need to worry about providing positions. If you're not, steal your positions from the terminals your rules are matching.
```

> # A note about scope rules.
> Luxtre's standard grammar uses the rule that new variables are assigned local by default. We will call this property of a variable "scope": whether a variable is local, global, something else, or not yet explicitly defined within the current chunk. Alternative grammars which extend base Lua but not Luxtre can obtain the local-by-default logic by including [basic_local_scoping.luxg](/luxtre/grammars/basic_local_scoping.luxg).
>
> Note that the default scope is not hard-coded and can be changed via grammar extension or file frontmatter.
> 
> In order to keep the syntax consistent and avoid unexpected behavior, it's important to make sure that new extensions respect variable scope and the current defaults. As such there are a few things you need to keep in mind when writing extensions that affect variable assignment or create functions with automatic arguments.
>
>  First, remember that if your extension leverages ordinary assignment part of the work is already done for you. As long as your construct is an Expression it can be picked up by Luxtre's existing assignment, local/global assignment, let assignment, and augmented assignment rules. These will take care of prepending the appropritate prefixes on the left-hand side and setting the scope of the variable being assigned to automatically.
>
> If creating something with internally scoped variables, such as auto-generated function arguments, there are a few things to keep in mind.
>> - First: `out.scope:push` and `out.scope:pop` are your friends. Internal locals can easily be contained by using paired pushes/pops off the secondary stack at the beginning and ending of the production rule. 
>> - Second: remember the order of operations.
>>   - The new variable's scope is determined, and if needed the appropriate prefix is added before the name being assigned to. 
>>   - For assigning to undefined variables, check the default assignment scope. Otherwise make certain to respect the variable's previous scope.
>>   - Until the statement is fully closed, the variable retains its previous scope. Remember that the right hand side of an assignment is always fully evaluated before the left hand side. The only exception is `let var` style pre-scoping.
>>   - Once the statement has been fully processed, if the variable's scope has changed make absolutely certain those changes are pushed to the output.
> 
> In order to help with this logic, the file [luxtre.grammars.variable_scoping_functions.luxh](/luxtre.grammars.variable_scoping_functions.luxh) contains definitions for some helpful functions that are heavily used in the default grammar.
>> - `add_scope(out, scopename, prefix, prefixmode)` -- define a scope. Valid prefix modes are `"always"` (always insert before the variable name) and `"line_start"` (only insert at the start of the line). You shouldn't need to use this.
>> - `scope_info(out, scopename)` -- returns a table {prefix, prefixmode} for the given scope. Useful for dynamically adjusting output according to the current scope.
>> - `set_default_assignment(out, scope)` -- sets the default scope for creating new variables
>> - `get_default_assignment(out, scope)` -- gets the default scope for creating new variables
>> - `set_default_index(out, scope)` -- sets the default scope for reading uninitialized variables
>> - `get_default_index(out, scope)` -- gets the default scope for reading uninitialized variables
>> 
>> - `set_scope(out, varname, scope)` -- sets the current scope of the given variable
>> - `get_scope(out, varname)` -- returns the current scope of the given variable
>> - `set_temp(out, varname, scope)` -- sets the current TEMPORARY scope of the given variable
>> - `get_temp(out, varname)` -- returns the current TEMPORARY scope of the given variable
>> - `toggle_temps(out, boolean)` -- either enables or disables temporary scope. If called with `true`, all variables print themselves with their temporary scope. If called with `false`, all variables will print with their current permanent scope. Disabled by default.
>> - `get_temps_enabled(out`) -- returns `true` if temps are toggled on and `false` if temps are toggled off.
>> - `print_with_temps(out, child, ...)` -- calls child:print(out, ...) with temporary scope guaranteed to be toggled on for the duration. Useful for printing the left-hand side of an assignment.
>> - `print_name_with_scope(out, name, pos)` -- `:append`s the variable name to the current line. If the variable's current scope has an `"always"` prefix, the prefix is added.
>> - `get_name_with_scope(out, name, pos)` -- Returns the variable's name with the proper prefix, for manual appending.
>> - `push_temps(out)` -- takes all temporary variable scope and makes it permanent. Useful for setting variable scope after an assignment is fully processed.

# Examples
The grammar which handles creating grammar extensions is itself available for reference as [examples/metagrammar.luxg](examples/metagrammar.luxg). This can also be used as an example of a full transpilation from an arbitrary non-Lua grammar into working code.

If you wish to see an example which demonstrates extending an existing grammar, consider examining Luxtre's primary grammar in [`luxtre_standard.luxg`](/luxtre/grammars/luxtre_standard.luxg).

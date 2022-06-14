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
Text within the brackets `{* *}` is captured and used as a code block. On their own, code blocks are written directly into the output. When placed at the end of a rule definition, they become a print function.
```
rule_name -> pattern {* print behavior *}
```

Print functions are the way text is output to the final file. 
All grammars are required to have a root production rule named `START.`
Luxtre does not post-process items at the time of discovery; rather, after the AST is assembled the `START` rule's `:print(out)` function is called and execution trickles down towards the leaves.

If a print function is not explictly declared, a default is used which simply calls `:print` on each of the current item's child branches/leaves.

> Note that print functions do not need to actually output text; with careful management it is possible to perform the equivalent of semantic actions by resolving a production rule into an intermediate data structure. Be careful with this, as not making this behavior optional will interrupt the default echo-to-output print behavior and may make the rule harder to use.

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

### Line Objects
```
line:pop()
A shortcut to out:pop()

line:append(text, line_number)
Appends the given text to the line. Returns the line object for chaining.

If a line number is provided, this will be the line number that appears in error messages involving the appended text. If one is nor provided, it will be later backfilled to the next line number.

If you're allowing terminals to print themselves, you don't need to worry about this too much. Otherwise, steal the position from the terminals your rules are matching.
```

# Examples
The grammar which handles these rules is available for reference in the same format as [examples/metagrammar.luxg](examples/metagrammar.luxg). This can be used as an example of a full transpilation from a grammar into raw text.

If you wish to see an example which demonstrates extending an existing grammar, consider examining Luxtre's primary grammar in [`luxtre_standard.luxg`](/luxtre/grammars/luxtre_standard.luxg).
# Preprocessing

Luxtre uses https://github.com/DimitriBarronmore/preprocess.lua as a submodule to preprocess files.
See [`preprocess/README.md`](/luxtre/preprocess/README.md) for the primary details.

# Additions to the Sandbox

## Frontmatter Arguments
Configured frontmatter is passed to the active grammar during the setup phase, allowing you to configure certain parts of the active language.

For example, the stock default-scoping grammar allows the use of frontmatter to determine the default assignment and indexing scopes for unscoped variables.
```lua
# frontmatter{
#   -- Swap the defaults around...
#	default_assignment = "global",
#   default_index = "local",
# }
print(a)    |  print(a)
a = 1       |  _ENV.a = 1
```

## Extending the Current Grammar
The `add_grammar(filename)` function allows you to extend the current file's syntax with the given `.luxg` grammar definition. Grammars added this way are loaded in order.
```lua
-- loads the file "folder.extension.luxg"
-- in order to make the syntax consistent with require,
-- dots in the path are converted to "/"
# add_grammar "folder.extension"

-- note that you can use the filename variable to load adjacent grammars.
-- assuming the current file is "folder/foobar.lux":
# local path = filename:gsub("foobar", "")
# add_grammar(path .. "extension")
```
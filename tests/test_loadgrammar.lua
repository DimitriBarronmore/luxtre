
local rg = require("luxtre.grammars.read_grammars")
local ng = require("luxtre.parser.grammar")

-- -- rg.compile("testgrammar")
local gf = rg.load_grammar("tests.testgrammar", true)

local gram = ng()
gf(gram)
gram:_debug(true)


return function( grammar )  local __repeatable_post_base = function(self, out)     return { } end local __repeatable_post_gather = function(self, out, gather)     local tab = self.children[1]:print(out, true)     local val = self.children[2]     table.insert(tab, val)     if gather then         return tab     else         for _, child in ipairs(tab) do             child:print(out)         end     end end      --0
local __keys = { --1
"keywords", --2
"operators", --3
"reset", --4
"remove", --5
"import", --6
"eof", --7
} --8
grammar:addKeywords(__keys)--1
local __ops = { --9
"->", --10
"{%", --11
"%}", --12
'==', --13
'<=', --14
'>=', --15
'~=', --16
'::', --17
'...', --18
'..', --19
} --20
grammar:addOperators(__ops)--9
----
local START_post = function(self, out) local ln = out : push_header ( ) --23
ln : append ( "return function( grammar )" ) --24
ln : append ( [[ local __repeatable_post_base = function(self, out)     return { } end local __repeatable_post_gather = function(self, out, gather)     local tab = self.children[1]:print(out, true)     local val = self.children[2]     table.insert(tab, val)     if gather then         return tab     else         for _, child in ipairs(tab) do             child:print(out)         end     end end     ]] --25
, 0 ) --42
out : pop ( ) --43
self . children [ 1 ] : print ( out ) --45
ln = out : push_footer ( ) --46
ln : append ( "grammar:_generate_nullable()" ) --47
ln : append ( "end" , 0 ) --48
out : pop ( )  end --49
grammar:addRule("START", [=[block <eof>]=] , START_post ) --22
local reserve_kws_post = function(self, out) local ln = out : push_header ( ) --53
ln : append ( "local __keys = {" , self . children [ 2 ] . position [ 1 ] ) --54
self . children [ 4 ] : print ( out ) --55
ln : append ( "}" , self . children [ 5 ] . position [ 1 ] ) --56
ln : append ( "grammar:addKeywords(__keys)" , self . children [ 2 ] . position [ 1 ] ) --57
out : pop ( )  end --58
grammar:addRule("reserve_kws", [=['@' keywords '{' reserve_list '}']=] , reserve_kws_post ) --52
local reserve_kws_post = function(self, out) local ln = out : push_header ( ) --62
ln : append ( "local __keys = {" , self . children [ 2 ] . position [ 1 ] ) --63
self . children [ 5 ] : print ( out ) --64
ln : append ( "}" , self . children [ 6 ] . position [ 1 ] ) --65
ln : append ( "for k,v in ipairs(__keys) do grammar._keywords[v] = nil end " , self . children [ 2 ] . position [ 1 ] ) --66
out : pop ( )  end --67
grammar:addRule("reserve_kws", [=['@' keywords remove '{' reserve_list '}']=] , reserve_kws_post ) --61
local reserve_ops_post = function(self, out) local ln = out : push_header ( ) --71
ln : append ( "local __ops = {" , self . children [ 2 ] . position [ 1 ] ) --72
self . children [ 4 ] : print ( out ) --73
ln : append ( "}" , self . children [ 5 ] . position [ 1 ] ) --74
ln : append ( "grammar:addOperators(__ops)" , self . children [ 2 ] . position [ 1 ] ) --75
out : pop ( )  end --76
grammar:addRule("reserve_ops", [=['@' operators '{' reserve_list '}']=] , reserve_ops_post ) --70
local reserve_ops_post = function(self, out) local ln = out : push_header ( ) --80
ln : append ( "local __ops = {" , self . children [ 3 ] . position [ 1 ] ) --81
self . children [ 5 ] : print ( out ) --82
ln : append ( "}" , self . children [ 6 ] . position [ 1 ] ) --83
ln : append ( [[ local operators = grammar._operators for _,v in ipairs(__ops) do     for i = #operators, 1, -1 do         local op = operators[i]         if op == v then             table.remove(operators, i)         end     end end ]] --84
, self . children [ 2 ] . position [ 1 ] ) --94
out : pop ( )  end --95
grammar:addRule("reserve_ops", [=['@' operators remove '{' reserve_list '}']=] , reserve_ops_post ) --79
local reserve_list_post = function(self, out) self . children [ 1 ] : print ( out ) ; self . children [ 3 ] : print ( out )  end --98
grammar:addRule("reserve_list", [=[reserve_list ',' reserve_item]=] , reserve_list_post ) --98
grammar:addRule("reserve_list", [=[reserve_item]=] ) --99
local reserve_item_post = function(self, out) out : line ( ) : append ( "" .. self . children [ 1 ] . value .. "," , self . children [ 1 ] . position [ 1 ] )  end --100
grammar:addRule("reserve_item", [=[String]=] , reserve_item_post ) --100
grammar:addRule("reserve_item", [=[]=] ) --101
local block_post = function(self, out) self . children [ 1 ] : print ( out ) --104
out : flush ( ) --105
self . children [ 2 ] : print ( out )  end --106
grammar:addRule("block", [=[block statement]=] , block_post ) --103
grammar:addRule("block", [=[]=] ) --108
grammar:addRule("statement", "" ) --110
grammar:addRule("statement", [=[functext]=] ) --110
grammar:addRule("statement", [=[ruledef]=] ) --110
grammar:addRule("statement", [=[reset_prod]=] ) --110
grammar:addRule("statement", [=[reserve_kws]=] ) --110
grammar:addRule("statement", [=[reserve_ops]=] ) --110
grammar:addRule("statement", [=[import_grammar]=] ) --110
local reset_prod_post = function(self, out) local ln = out : push_header ( ) --119
ln : append ( "grammar._list[\"" .. self . children [ 3 ] . value .. "\"] = nil" , self . children [ 3 ] . position [ 1 ] ) --120
ln : append ( "grammar._used[\"" .. self . children [ 3 ] . value .. "\"] = nil" , self . children [ 3 ] . position [ 1 ] ) --121
out : pop ( )  end --122
grammar:addRule("reset_prod", [=['@' reset Name]=] , reset_prod_post ) --118
local import_grammar_post = function(self, out) local ln = out : push_header ( ) --126
ln : append ( ( [[ do     local status, res = pcall(__load_grammar, %s)     if status == false then         error("failed import in " .. __filepath .. "\n\t" .. res, 2)     else         res(grammar)     end end ]] --127
) : format ( self . children [ 3 ] . value : gsub ( "^(['\"])%$" , "__rootpath .. %1." ) ) , self . children [ 3 ] . position [ 1 ] ) --136
out : pop ( )  end --137
grammar:addRule("import_grammar", [=['@' import String]=] , import_grammar_post ) --125
local ruledef_post = function(self, out) local name = self . children [ 1 ] . value --141
out . _tmp_curr_rulename = name --142
self . children [ 4 ] : print ( out ) --143
out . _tmp_curr_position = self . children [ 1 ] . position [ 1 ] --144
local rule_list = self . children [ 3 ] : print ( out ) --145
for _ , v in ipairs ( rule_list ) do --146
local ln = out : push_prior ( ) --147
if v == [[""]] or v == [['']] then --148
ln : append ( ( 'grammar:addRule("%s", ""' ) : format ( name ) , self . children [ 1 ] . position [ 1 ] ) --149
else --150
ln : append ( ( 'grammar:addRule("%s", [=[%s]=]' ) : format ( name , v ) , self . children [ 1 ] . position [ 1 ] ) --151
end --152
if out . _tmp_caught_functext then --153
ln : append ( ( ", %s_post" ) : format ( name ) ) --154
end --155
ln : append ( ")" , self . children [ 1 ] . position [ 1 ] ) --156
out : pop ( ) --157
end --158
out . _tmp_curr_rulename = nil --159
out . _tmp_caught_functext = nil --160
out . _tmp_curr_position = nil  end --161
grammar:addRule("ruledef", [=[Name '->' rule_list catch_functext]=] , ruledef_post ) --140
local catch_functext_post = function(self, out) out . _tmp_caught_functext = true --165
local name = out . _tmp_curr_rulename --166
local ln = out : push_prior ( ) --167
ln : append ( ( "local %s_post = function(self, out)" ) : format ( name ) ) --168
self . children [ 1 ] : print ( out ) --169
ln : append ( " end" ) --170
out : pop ( )  end --171
grammar:addRule("catch_functext", [=[functext]=] , catch_functext_post ) --164
grammar:addRule("catch_functext", "" ) --173
local rule_list_post = function(self, out) return { table . concat ( self . children [ 1 ] : print ( out ) , " " ) }  end --176
grammar:addRule("rule_list", [=[rule_pattern]=] , rule_list_post ) --175
local rule_list_post = function(self, out) local tab = self . children [ 1 ] : print ( out ) --179
local tab2 = self . children [ 3 ] : print ( out ) --180
for _ , v in ipairs ( tab2 ) do --181
table . insert ( tab , v ) --182
end --183
return tab  end --184
grammar:addRule("rule_list", [=[rule_list '|' rule_list]=] , rule_list_post ) --178
local rule_pattern_post = function(self, out) local tab = self . children [ 1 ] : print ( out ) --188
table . insert ( tab , self . children [ 2 ] : print ( out ) ) --189
return tab  end --190
grammar:addRule("rule_pattern", [=[rule_pattern rule_item]=] , rule_pattern_post ) --187
local rule_pattern_post = function(self, out) return { }  end --192
grammar:addRule("rule_pattern", "" , rule_pattern_post ) --192
local rule_item_post = function(self, out) local tab = self . children [ 2 ] : print ( out ) --196
local name = ( "(" .. table . concat ( tab , "|" ) .. ")" ) : gsub ( " " , "_" ) --197
if not out . data . __used_ebnf then out . data . __used_ebnf = { } end --198
if not out . data . __used_ebnf [ name ] then --199
out . data . __used_ebnf [ name ] = true --200
for _ , v in ipairs ( tab ) do --201
local ln = out : push_prior ( ) --202
if v == [[""]] or v == [['']] then --203
ln : append ( ( 'grammar:addRule("%s", "")' ) : format ( name ) , out . _tmp_curr_position ) --204
else --205
ln : append ( ( 'grammar:addRule("%s", [=[%s]=])' ) : format ( name , v ) , out . _tmp_curr_position ) --206
end --207
out : pop ( ) --208
end --209
end --210
return name  end --211
grammar:addRule("rule_item", [=['(' rule_list ')']=] , rule_item_post ) --195
local rule_item_post = function(self, out) local tab = self . children [ 2 ] : print ( out ) --215
local name = ( "[" .. table . concat ( tab , "|" ) .. "]" ) : gsub ( " " , "_" ) --216
if not out . data . __used_ebnf then out . data . __used_ebnf = { } end --217
if not out . data . __used_ebnf [ name ] then --218
out . data . __used_ebnf [ name ] = true --219
for _ , v in ipairs ( tab ) do --220
local ln = out : push_prior ( ) --221
if v == [[""]] or v == [['']] then --222
ln : append ( ( 'grammar:addRule("%s", "")' ) : format ( name ) , out . _tmp_curr_position ) --223
else --224
ln : append ( ( 'grammar:addRule("%s", [=[%s]=])' ) : format ( name , v ) , out . _tmp_curr_position ) --225
end --226
out : pop ( ) --227
end --228
local ln = out : push_prior ( ) --229
ln : append ( ( 'grammar:addRule("%s", "")' ) : format ( name ) , out . _tmp_curr_position ) --230
out : pop ( ) --231
end --232
return name  end --233
grammar:addRule("rule_item", [=['[' rule_list ']']=] , rule_item_post ) --214
local rule_item_post = function(self, out) local tab = self . children [ 2 ] : print ( out ) --237
local name = ( "{" .. table . concat ( tab , "|" ) .. "}" ) : gsub ( " " , "_" ) --238
if not out . data . __used_ebnf then out . data . __used_ebnf = { } end --239
if not out . data . __used_ebnf [ name ] then --240
out . data . __used_ebnf [ name ] = true --241
for _ , v in ipairs ( tab ) do --242
local ln = out : push_prior ( ) --243
if v == [[""]] or v == [['']] then --244
ln : append ( ( 'grammar:addRule("%s", "")' ) : format ( name ) , out . _tmp_curr_position ) --245
else --246
ln : append ( ( 'grammar:addRule("%s", [=[%s]=])' ) : format ( name , v ) , out . _tmp_curr_position ) --247
end --248
out : pop ( ) --249
end --250
local ln = out : push_prior ( ) --251
ln : append ( ( 'grammar:addRule("%s_lhs", "%s_lhs %s", __repeatable_post_gather)' ) : format ( name , name , name ) , out . _tmp_curr_position ) --252
local ln = out : push_prior ( ) --253
ln : append ( ( 'grammar:addRule("%s_lhs", "", __repeatable_post_base)' ) : format ( name ) , out . _tmp_curr_position ) --254
out : pop ( ) --255
out : pop ( ) --256
end --257
return name .. "_lhs"  end --258
grammar:addRule("rule_item", [=['{' rule_list '}']=] , rule_item_post ) --236
local rule_item_post = function(self, out) return self . children [ 1 ] . value  end --263
grammar:addRule("rule_item", [=[Name]=] , rule_item_post ) --261
grammar:addRule("rule_item", [=[String]=] , rule_item_post ) --261
grammar:addRule("rule_item", [=[Keyword]=] , rule_item_post ) --261
local rule_item_post = function(self, out) return "<eof>"  end --265
grammar:addRule("rule_item", [=['<' eof '>']=] , rule_item_post ) --265
local functext_post = function(self, out) self . children [ 2 ] : print ( out )  end --268
grammar:addRule("functext", [=['{%' grab_any '%}']=] , functext_post ) --267
grammar:addRule("grab_any", "" ) --271
grammar:addRule("grab_any", [=[grab_any any]=] ) --271
grammar:addRule("any", [=[Name]=] ) --274
grammar:addRule("any", [=[Number]=] ) --274
grammar:addRule("any", [=[String]=] ) --274
grammar:addRule("any", [=[Symbol]=] ) --274
grammar:addRule("any", [=[Keyword]=] ) --274
grammar:addRule("any", [=['==']=] ) --274
grammar:addRule("any", [=['<=']=] ) --274
grammar:addRule("any", [=['>=']=] ) --274
grammar:addRule("any", [=['~=']=] ) --274
grammar:addRule("any", [=['::']=] ) --274
grammar:addRule("any", [=['...']=] ) --274
grammar:addRule("any", [=['..']=] ) --274
---
grammar:_generate_nullable() end --0
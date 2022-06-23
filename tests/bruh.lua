----
do --3
function test ( fizz ) --11
fizz |= "buzz" --12
print ( fizz ) --13
end --14
test ( ) --15
test ( "h" ) --16
end --17
local bruh = "h" --20
tab = { 1 = "apple" , 2 = "peach" , 3 = "orange" , 500 = "durian" , true = false , bruh = "nill" , [ "str" : rep ( 4 ) : rep ( 4 ) ] : sick } --24
h = ( txt ) -> print ( txt ) --27
h ( txt ) -> print ( txt ) --29
local h ( txt ) -> print ( txt ) --31
tab = { apple : -> print ( "apple" ) } --33
h => print ( self . whatever ) --35
local h ( txt ) => print ( txt ) --36
do --38
function decorate ( func ) --39
return function ( ) --40
print "hallo" --41
func ( ) --42
end --43
end --44
function decorate2 ( func ) --45
return function ( ) --46
print "world" --47
func ( ) --48
end --49
end --50
function decorate3 ( func ) --51
return function ( ) --52
print ":3" --53
func ( ) --54
end --55
end --56
@ decorate --57
@ decorate2 --58
@ decorate3 --59
local function bruh ( ) print ( "original message" ) end --60
bruh ( ) --61
print ( "---------" ) --69
@ decorate --78
global bruh -> print ( bruh ) --79
print ( "---------" ) --81
end --90
do --92
global b = c --93
local a , b = c , b --94
local b --95
end --96
do --99
let b = ( ) -> print ( b ) --100
end --101
do --103
table = { a : 1 , "b" : 2 , 3 : 3 } --104
func = ( x , y ) -> ( x = x + y ) --107
pow_x ( x ) -> do --110
y = x * x --111
return y --112
end --113
end --114
do --116
local object = { name = "h" } --117
print_name => ( print ( self . name ) ) --118
object . y = function ( self ) print ( self . y ) end --120
print ( y ) --122
end --123
do --125
global table = { 1 , 2 , 3 , 4 = "h" } --126
table . h = true --127
table = { 2 } --129
end --130
do --132
global b --133
a , b , c = 1 , 2 , 3 --134
do --135
local table = { 1 } --136
end --137
global name , name2 = 1 , 1 --138
clear_table ( table ) -> do --139
for k , _ in pairs ( table ) do --140
table [ k ] = nil --141
end --142
end --143
print ( # table ) --145
clear_table ( table ) --146
print ( # table ) --147
end --149
do --151
global i = 0 --152
for i = 1 , 3 do --153
print ( i ) --154
end --155
print ( i ) --156
end --157
do --158
global name , val --159
name , val = 1 , 1 --160
for name , val in ipairs ( { 1 , 2 , 3 , 4 } ) do --161
print ( name , val ) --162
end --163
print ( name , val ) --164
end--165
---
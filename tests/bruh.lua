 local _ENV = _ENV if _VERSION < "Lua 5.2" then 	_ENV = (getfenv and getfenv()) or _G end		 --0
 local __export = {}  		 --0
----
do--3
local function test ( fizz ) --11
fizz = fizz or ( "buzz" ) --12
_ENV.print ( fizz ) --13
end--14
test ( ) --15
test ( "h" ) --16
end--17
local bruh = "h" --20
local tab = { [ 1 ] = "apple" , [ 2 ] = "peach" , [ 3 ] = "orange" , [ 500 ] = "durian" , [ true ] = false , bruh = "nill" , [ ( "str" ) : rep ( 4 ) : rep ( 4 ) ] = _ENV.sick } --24
local h = function( txt ) return _ENV.print ( txt ) end --27
h = function( txt ) return _ENV.print ( txt ) end --29
local h = function( txt ) return _ENV.print ( txt ) end --31
tab = { apple = function( ) return _ENV.print ( "apple" ) end } --33
h = function( self ) return _ENV.print ( self . whatever ) end --35
local h = function( self , txt ) return _ENV.print ( txt ) end --36
do--38
local function decorate ( func ) --39
return function ( ) --40
_ENV.print "hallo" --41
func ( ) --42
end --43
end--44
local function decorate2 ( func ) --45
return function ( ) --46
_ENV.print "world" --47
func ( ) --48
end --49
end--50
local function decorate3 ( func ) --51
return function ( ) --52
_ENV.print ":3" --53
func ( ) --54
end --55
end--56
local bruh = --60
decorate ( --57
decorate2 ( --58
decorate3 ( function --59
( ) --60
_ENV.print ( "original message" ) --60
end ) ) ) --60
bruh ( ) --61
_ENV.print ( "---------" ) --69
_ENV. bruh = --79
decorate ( function( ) return --78
_ENV.print ( bruh ) end ) --79
_ENV.print ( "---------" ) --81
end--90
do--92
_ENV.b = _ENV.c --93
local a , b = _ENV.c , _ENV.b --94
local b --95
end--96
do--99
local b--100
b = function( ) return _ENV.print ( _ENV.b ) end --100
end--101
do--103
local table = { a = 1 , [ "b" ] = 2 , [ 3 ] = 3 } --104
local func = function( x , y ) x = x + y end --107
local pow_x = function( x ) --110
local y = x * x --111
return y end --112
end--114
do--116
local object = { name = "h" } --117
local print_name = function( self ) _ENV.print ( self . name ) end --118
object . y = function ( self ) --120
_ENV.print ( self . y ) --120
end --120
_ENV.print ( _ENV.y ) --122
end--123
do--125
_ENV.table = { 1 , 2 , 3 , [ 4 ] = "h" } --126
_ENV.table . h = true --127
_ENV.table = { 2 } --129
end--130
do--132
local a, c--?
a , _ENV.b , c = 1 , 2 , 3 --134
do--135
local table = { 1 } --136
end--137
_ENV.name, _ENV.name2 = 1 , 1 --138
local clear_table = function( table ) --139
for k , _ in _ENV.pairs ( table ) do --140
table [ k ] = nil --141
end--142
end--?
_ENV.print ( # _ENV.table ) --145
clear_table ( _ENV.table ) --146
_ENV.print ( # _ENV.table ) --147
end--149
do--151
_ENV.i = 0 --152
for i = 1 , 3 do --153
_ENV.print ( i ) --154
end--155
_ENV.print ( _ENV.i ) --156
end--157
do--158
_ENV.name , _ENV.val = 1 , 1 --160
for name , val in _ENV.ipairs ( { 1 , 2 , 3 , 4 } ) do --161
_ENV.print ( name , val ) --162
end--163
_ENV.print ( _ENV.name , _ENV.val ) --164
end--165
---
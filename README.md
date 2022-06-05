# Luxtre

Luxtre is a small dialect of [Lua 5.2](http://www.lua.org/) which compiles back into native code, written entirely in native Lua. It adds a handful of helpful additions to the syntax and enables simple macro preprocessing.

Luxtre is compatible with Lua JIT, Lua 5.1, Lua 5.2, Lua 5.3, and Lua 5.4, but does not currently backport newer syntax. Existing Lua code will work in Luxtre without modification.

**Current Status:** 
Luxtre executes and outputs files properly, but is not yet complete. Future versions will have further syntax changes/additions and the ability to add new ones, as well as better error location redirection and better formatted output.

> WARNING: Features you see here are entirely subject to change. Luxtre is still a work in progress, and forward-compatibility is not yet guaranteed.

[**See the Documentation**](docs)

# Command-line Use
Lux currently offers an extremely basic method for running files directly from a commandline in linux. Add the `bin` folder to your path, and call `lux <filename>` to run a .lux file. 

Note that it expects the `bin` folder to be adjacent to the `luxtre` folder; you cannot move it to a separate location.
local loaders = {}

--[[
	necessary functions:
	- load (from string, into env)
	- attempt to open file, return file object
	- file object abstraction:
		- get all text from file
		- close file 

--]]

loaders.lua = {}

local lua_fileobj_mt = {}
lua_fileobj_mt.__index = lua_fileobj_mt

lua_fileobj_mt.read_all = function(self)
	return self.file:read("*a")
end

lua_fileobj_mt.read = function(self, ...)
	return self.file:read(...)
end

lua_fileobj_mt.lines = function(self, ...)
	return self.file:lines(...)
end

lua_fileobj_mt.write = function(self, ...)
	self.file:write(...)
end

lua_fileobj_mt.flush = function(self)
	self.file:flush()
end

lua_fileobj_mt.close = function(self)
	self.file:close()
end

local newfile_lua = function(file)
	return setmetatable({file = file}, lua_fileobj_mt)
end

loaders.lua.open = function(filepath, mode)
	if mode == nil then mode = "r" end
	local file = io.open(filepath, mode)
	if file then
		return newfile_lua(file)
	end
end

loaders.lua.exists = function(filepath)
	local file = io.open(filepath)
	return (file ~= nil)
end

loaders.lua.open_internal = loaders.lua.open

loaders.lua.open_for_write = function(filepath, mode)
	if mode == nil then mode = "w+" end
	local file = io.open(filepath, mode)
	if file then
		return newfile_lua(file)
	end
end


loaders.love = {}

local love_fileobj_mt = {}
love_fileobj_mt.__index = love_fileobj_mt


love_fileobj_mt.read_all = function(self)
	return self.file:read("*a")
end

love_fileobj_mt.read = function(self, ...)
	return self.file:read(...)
end

love_fileobj_mt.lines = function(self, ...)
	return self.file:lines(...)
end

love_fileobj_mt.write = function(self, ...)
	self.file:write(...)
end

love_fileobj_mt.flush = function(self)
	self.file:flush()
end

love_fileobj_mt.close = function(self)
	self.file:close()
end

local newfile_love = function(file)
	return setmetatable({file = file}, love_fileobj_mt)
end

loaders.love.exists = function(filepath)
	-- local nativefs = require("utils.nativefs")
	-- local prev_direc = love.filesystem.getWorkingDirectory()
	-- nativefs.setWorkingDirectory(love.filesystem.getSource())

	if love.filesystem.getInfo(filepath) then
		-- nativefs.setWorkingDirectory(prev_direc)
		return true
	else
		-- nativefs.setWorkingDirectory(prev_direc)
		-- if nativefs.getInfo(filepath) then
		-- 	return true
		-- else
			return false
		-- end
	end
	-- 	return false
	-- end
	-- return (nativefs.getInfo(filepath) and true) or false
end

loaders.love.open = function(filepath, mode)
	-- local nativefs = require("utils.nativefs")
	-- local prev_direc = love.filesystem.getWorkingDirectory()
	-- nativefs.setWorkingDirectory(love.filesystem.getSource())

	if mode == nil then mode = "r" end

	-- local prev_direc = love.filesystem.getWorkingDirectory()
	-- nativefs.setWorkingDirectory(love.filesystem.getSource())

	-- local f, err
	-- if nativefs.getInfo(filepath) then
	-- 	f, err = nativefs.newFile(filepath, mode)
	-- else
	-- 	nativefs.setWorkingDirectory(prev_direc)
	-- 	f, err = nativefs.newFile(filepath, mode)
	-- end
	-- nativefs.setWorkingDirectory(prev_direc)
		

	local f, err = love.filesystem.newFile(filepath, mode)
	-- if f == nil then
	-- 	f, err = nativefs.newFile(filepath, mode)
	-- end


	-- local s, r = f:open(mode)
	-- nativefs.setWorkingDirectory(prev_direc)
	print(filepath, f, err)
	if f == nil then
		return f, err
		-- error ("hhh " .. love.filesystem.getWorkingDirectory() .. " | " .. (r or ""))
	else
		return newfile_love(f)
	end
	-- if file then
		-- return newfile_lua(file)
	-- end
end

-- loaders.love.open_internal = function(...)
-- 	local nativefs = require("utils.nativefs")
-- 	local prev_directory = love.filesystem.getWorkingDirectory()
-- 	nativefs.setWorkingDirectory(love.filesystem.getSource())
-- 	local s, r = loaders.love.open(...)
-- 	nativefs.setWorkingDirectory(prev_directory)
-- 	return s, r
-- end

loaders.love.open_for_write = function(filepath, mode)
	if mode == nil then mode = "w+" end
	local file = io.open(filepath, mode)
	if file then
		return newfile_lua(file)
	end
end


local export_mt = {}
export_mt.__newindex = function()
	error("attempt to modify read-only table", 2)
end

local export = {}

function export.set_active_loader(name)
	if loaders[name] then
		export_mt.__index = loaders[name]
	else
		error(("no loader named '%s'"):format(name), 2)
	end
	-- if loaders[name] == "love" then
	-- 	local nativefs = require "nativefs"

	-- end
end

setmetatable(export, export_mt)

-- testing line:
export.set_active_loader("lua")

return export
local M = {}
local Utils = require "ink.utils"

M.create = function(data, parent, name)
	local container = {
		name = name or "_",
		is_container = true,
		index = 1, 
		parent = parent, 
		content = {},
		attributes = {},
		stitch = "__root",
		visits = 0
	}

	local keep_visits = false
	local count_start_only = false

	if parent then
		container.name = #parent.name == 0 and container.name or (parent.name .. "." .. container.name)
		container.stitch = parent.stitch
	end

	container.visit = function(name)
		name = name or ""
		if (not count_start_only) and (name:sub(1, #container.name) == container.name) then return end
		if not keep_visits then return end
		if count_start_only and container.index > 1 then return end -- need to visit parent maybe?
		
		container.visits = container.visits  + 1
		
		if parent then
			parent.visit(name)
		end
	end
	
	container.next = function() 
		if container.index > #container.content then return nil end
		local item = container.content[container.index]
		container.index = container.index + 1
		return item
	end

	if type(data) ~= "table" then
		return container
	end

	data = Utils.clone(data)

	--read attributes first
	local attrs = data[#data]
	if type(attrs) == "table" then 
		container.attributes = attrs

		if attrs["#n"] then
			container.name = container.name .. "." .. attrs["#n"]
		end

		if attrs["#f"] then --read container's flags
			keep_visits = Utils.testflag(attrs["#f"], 0x1)
			count_start_only = Utils.testflag(attrs["#f"], 0x4) 
			
			if parent and keep_visits and not count_start_only then
				container.stitch = container.name
				container.is_stitch = true
			end

		end

		for key, value in pairs(attrs) do
			if type(value) == "table" and #value > 0 then
				container.attributes[key] = M.create(value, container, key)
			end
		end
	end
		
	--read items
	for i, item in ipairs(data) do
		if i < #data then
			if type(item) == "table" and #item > 0 then
				item = M.create(item, container, tostring(i))
			end
			table.insert(container.content, item)
		end
	end

	return container
end


M.serialize = function(container, output)
	output[container.name] = {--[[index = container.index,--]] visits = container.visits}
	for _, child in pairs(container.attributes) do
		if type(child) == "table" and child.is_container then
			M.serialize(child, output)
		end
	end
	for _, child in ipairs(container.content) do
		if type(child) == "table" and child.is_container then
			M.serialize(child, output)
		end
	end
end

M.deserialize = function(container, data)
	container.visits = data[container.name] and data[container.name].visits or container.visits
	
	for _, child in pairs(container.attributes) do
		if type(child) == "table" and child.is_container then
			M.deserialize(child, data)
		end
	end
	for _, child in ipairs(container.content) do
		if type(child) == "table" and child.is_container then
			M.deserialize(child, data)
		end
	end
end

return M
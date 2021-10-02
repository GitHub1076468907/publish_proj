--test_ues_file
local Util = require "Utils"
local format = string.format
local config = require "output/attr"

--[[local _tmp = config[1]
tprint(_tmp)
tprint(_tmp.show_name)--]]

--[[local attr = config.attr
print("=====pairs")
for key,v in pairs(attr[1]) do
	print("key,v", key, v)
end
print("=====ipairs")
for key,v in ipairs(attr[1]) do
	print("key,v", key, v)
end--]]
--[[tprint(config[1])
print(config[1].base_attr)--]]
--tprint(attr)
--tprint(config[40][6].add_attr_list)
--[[tprint(config.chapter[1][1001])
tprint(config.chapter[1].chapters)
tprint(config.chapter[1].chapters.bg)--]]
--[[tprint(config.achieve_event.events[1][1001])
tprint(config.achieve_event.show_name)--]]



--[[local get_raw_dat = function(t, k)
    local tbl = rawget(t,k)
    assert(tbl, format('获取不到 %s 字段的成员', k))
    return tbl
end

local function itr(t, idx)
    local tbl = get_raw_dat(t,"__inner_tab_11111")
    local key, v = next(tbl, idx)
    if not key then
        return nil
    else
        return key, v
    end
end



local read_only_meta = {
    __index = function(t,k)
        local tbl = get_raw_dat(t,"__inner_tab_11111")
        print("read_only_meta index", k)
         local res = tbl[k]
         tprint(res)

        return res
    end,
    __newindex = function(t,k)
        error("ConfigManager", format("config is read only !!! key:' %s '", k))
    end,
    __len = function(t)
        local tbl = get_raw_dat(t,"__inner_tab_11111")
        return #tbl
    end,
    __pairs = function(t)
        return itr, t, nil
    end,
}



local function  read_only(tbl)
    local _insert_tbl = {}
    for i,v in pairs(tbl) do
        if type(v) == "table" then
            _insert_tbl[i] = read_only(v)
        else
            _insert_tbl[i] = v
        end
    end
    local read_only_tab = setmetatable({__inner_tab_11111 = _insert_tbl}, read_only_meta)
    return read_only_tab
end


story = read_only(story)--]]



--tprint(story.type)
--[[
local test = { a = 1}
print(test.a and false or true)--]]
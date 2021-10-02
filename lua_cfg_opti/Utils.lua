--Utils.lua
local sformat = string.format
local tinsert = table.insert
local tconcat = table.concat
local lfs = require "lfs"

local function toprintable(value)
    local t = type(value)
    if t == 'number' then
        return tostring(value)
    elseif t == 'string' then
        return sformat('%q', value)
    elseif t == 'boolean' then
        return value and 'true' or 'false'
    elseif t == 'function' then
        return tostring(value)
    elseif t == nil then
        return tostring(nil)
    end
    return
end


function pretty_serialize(T, CR)
	local function ser_table(tbl, index)
        local space = string.rep(' ', index)
		local tmp={}
        tinsert(tmp, string.format("{%s", CR or "\n"))
		for k,v in pairs(tbl) do
            local key = toprintable(k)
            local value = toprintable(v)

            tinsert(tmp, space)
            tinsert(tmp, '[')
            tinsert(tmp, key)
            tinsert(tmp, '] = ')
            if value then
                tinsert(tmp, value)
            elseif type(v) == 'table' then
                tinsert(tmp, ser_table(v, index + 4))
            else
                error(string.format("value for key %s is invalid, value:%s", key, value))
            end
            tinsert(tmp, string.format(",%s", CR or "\n"))
        end
        tinsert(tmp, space)
        tinsert(tmp, '}')
		return tconcat(tmp)
	end
	return ser_table(T, 0)
end


local function print_value(value)
    local t = type(value)
    if t == 'number' then
        return tostring(value)
    elseif t == 'string' then
        return value
    elseif t == 'boolean' then
        return value and 'true' or 'false'
    elseif t == "table" then
        return pretty_serialize(value)
    elseif value == nil then
        return "nil"
    else
        return "usedefine:" .. t
    end
end

_G.tprint = function( ... )
    local arg = table.pack(...)
    local t = {}
    for i = 1, arg.n do
        table.insert(t, print_value(arg[i]).."\n")
    end
    print(table.concat(t))
    --print(debug.traceback())
end

local function readAll(file)
    local f = assert(io.open(file, "r"))
    local content = f:read("*all")
    f:close()
    return content
end
_G.readAll = readAll

local function replace_str(all_content, replace_content, target_str)
    local find_str = string.format("#%s#", target_str)
    all_content = string.gsub(all_content, find_str, function()
        --使用这种方式替换不会受到  replace_content 中有转义字符的影响
        --若第三个参数直接给 replace_content 则当其有魔法字符时会有报错 invalid use of '%' in replacement string 假设为 "50%"
        return replace_content
    end)
    return all_content
end
_G.replace_str = replace_str

local get_tab_len = function(tab)
	local num = 0
	for _,v in pairs(tab) do
		num = num + 1
	end
	return num
end

local function diff_tab(tab1, tab2)
	tab1 = tab1 or {}
	tab2 = tab2 or {}
	if get_tab_len(tab1) ~= get_tab_len(tab2) then
        return true
    end
    for k, v in pairs(tab1) do
        if tab2[k] then
            if type(v) ~= type(tab2[k]) then
                return true
            else
                if type(v) == "table" then
                    if diff_tab(v, tab2[k]) then
                        return true
                    end
                else
                    if v ~= tab2[k] then
                        return true
                    end
                end
            end
        else
            return true
        end
    end
end

_G.diff_tab = diff_tab

function _G.get_lua_file_name(file_name_with_suffix)
    local idx = file_name_with_suffix:match(".+()%.%w+$")
    if idx then file_name_with_suffix = file_name_with_suffix:sub(1, idx - 1) end
    return file_name_with_suffix
end

local function _copy_file(ori_path, tar_path)
    local base_temp = readAll(ori_path)
    local fp = io.open(tar_path, "w")
    fp:write(base_temp)
    fp:close()
end

_G.copy_file = _copy_file



local ori_dir = "input"
local out_dir = "output"

function _G.get_ori_dir()
    return ori_dir
end

local function _get_ori_path(cfg_name, no_need_suffix)
    return sformat("%s/%s%s", ori_dir, cfg_name, no_need_suffix and "" or ".lua")
end
_G.get_ori_path = _get_ori_path

local function _get_tar_path(cfg_name, no_need_suffix)
    return sformat("%s/%s%s", out_dir, cfg_name, no_need_suffix and "" or ".lua")
end
_G.get_tar_path = _get_tar_path


local function _file_exists(path)
    local file = io.open(path, "rb")
    if file then file:close() end
    return file ~= nil
end
_G.file_exists = _file_exists

local function _remove_dir_file(path)

    local function _rmdir(path)
        local iter, dir_obj = lfs.dir(path)
        while true do
            local dir = iter(dir_obj)
            if dir == nil then break end
            if dir ~= "." and dir ~= ".." then
                local curDir = path.."/" ..dir
                local mode = lfs.attributes(curDir, "mode") 
                if mode == "directory" then
                    _rmdir(curDir.."/")
                elseif mode == "file" then
                    os.remove(curDir)
                end
            end
        end
    end
    _rmdir(path)
end
_G.remove_dir_file = _remove_dir_file

local function _clean_output()
    _remove_dir_file(out_dir)
end
_G.clean_output = _clean_output


local function _split_str(s, p)
    local rt= {}
    string.gsub(s, '[^'..p..']+', function(w) table.insert(rt, w) end )
    return rt
end
_G.split_str = _split_str
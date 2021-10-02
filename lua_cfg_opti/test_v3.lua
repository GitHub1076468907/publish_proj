local sformat = string.format
local DataDump = require "dumper"
local Utils = require "Utils"
local lfs = require "lfs"
local get_lua_file_name = _G.get_lua_file_name
local remove_dir_file = _G.remove_dir_file
local tprint = _G.tprint

local insert = table.insert
local copy_file = _G.copy_file
local get_tar_path = _G.get_tar_path
local get_ori_path = _G.get_ori_path
local clean_output = _G.clean_output
local split_str = _G.split_str


local combine_key_char = "."
local _deal_file_size = 1024*6


--可将list 的key抽出, 让原本tbl的dict只能存储在node里，改为数字key可以将部分存到数组中， 这样就能减少成为node的所需tkey类型的额外字段成本
--加上重复tbl抽出公用
--做一个优化，将key的数值赋值， 按照key出现的次数来排序，最多的就拍最前。 一样则按str来比较排序 （能比较有效的转dict为list）

local _record_key = {}
local _duplicate_tab = {} --记录最后重复的tbl


local _get_tbl_size = function(tbl)
    local num = 0
    for _,v in pairs(tbl) do
        num = num + 1
    end
    return num
end

local function _get_only_tab(sort_tbl)
    local is_find = false
     for _, tab in pairs(_duplicate_tab) do
         if not diff_tab(tab, sort_tbl) then
             sort_tbl = tab
             is_find = true
             break
         end
     end
     if not is_find then
         insert(_duplicate_tab, sort_tbl)
          local idx = #_duplicate_tab
          return _duplicate_tab[idx]
     else
         return sort_tbl
     end
end


local _add_keys = function(key_name, belong_tab_key)
    if not _record_key[belong_tab_key] then
        _record_key[belong_tab_key] = {}
    end
    local idx = false
    if type(key_name) == "number" then
        print(sformat("%s存在数字key: %s，因此不对他做转换了", belong_tab_key, key_name))
        _record_key[belong_tab_key] = nil
        return false
    end
    if not _record_key[belong_tab_key][key_name] then
        _record_key[belong_tab_key][key_name] = 0
    end
    _record_key[belong_tab_key][key_name] = _record_key[belong_tab_key][key_name] + 1
    return true
end


local _get_single_tab_key = function(tab, key_list)
    local key_name = table.concat(key_list, combine_key_char)
    local _need_continue = false
    for key,val in pairs(tab) do
        if type(key) == "number" then
            for _key, _val in pairs(val) do
                 _need_continue = _add_keys(_key, key_name)
                if not _need_continue then
                    tprint("出问题的key所在的tbl是:", val)
                    break
                end
            end
        end
    end
end


local _check_table = function(tab)
    for k, v in pairs(tab) do
        if type(v) ~= 'table' then
            return true
        end
    end 
end

local _check_is_single_list = function(tbl)
    local _type = type(tbl)
    if _type ~= "table" then return end
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            if type(k) == "number" then
                for k2,v2 in pairs(v) do
                    if type(v2) ~= "table" and type(k2) == "string" then
                        return true
                    end
                end
            end
        else
            return false
        end
    end
    return false
end


local singe_clone_tab = function(res)
    local _res = {}
    for k,v in pairs(res) do
        _res[k] = v
    end
    return _res
end

local function _check_list(cfg, key)
    key = key or {}
    if _check_table(cfg) then
        return false
    else
        if _check_is_single_list(cfg) then
             _get_single_tab_key(cfg, key) 
        else
            for k, v in pairs(cfg) do
                local _key = singe_clone_tab(key, k)
                table.insert(_key, k)
                _check_list(v, _key)
            end
        end
    end
    return true
end

local _sort_key_function = function(a, b)
    if a.count > b.count then
        return true
    elseif a.count < b.count then
        return false
    end
    return a.key < b.key
end

local __inner_sort_key = function(tbl)
    local list = {}
    local res = {}
    for key,v in pairs(tbl) do
        insert(list, {key = key, count = v})
    end
    table.sort(list, _sort_key_function)
    for i, val in ipairs(list) do
        res[val.key] = i
    end
    return res
end

local _add_multi_key = function(res, keys, val)
    if keys == "" then
        return val
    else
        local key_list = split_str(keys, combine_key_char)
        local tab = res
        local all_num = #key_list
        for i,v in ipairs(key_list) do
            v = tonumber(v) or v
            if not tab[v] then
                tab[v] = {}
            end
            if i == all_num then
                tab[v] = val
            else
                tab = tab[v]
            end
        end
    end
    return res
end

local function _get_default_key(input)
    local res = {}
    for belong_tab_key, val in pairs(input) do
        res = _add_multi_key(res, belong_tab_key, val)
    end
    local function _trans_num(tbl)
        if _check_table(tbl) then
            local sort_tbl = __inner_sort_key(tbl)
            return _get_only_tab(sort_tbl)
        else
            local _res = {}
            for k,v in pairs(tbl) do
                _res[k] = _trans_num(v)
            end
            return _res
        end
    end

    res = _trans_num(res)
    return res
end


local _filter_same_key = function(tab, _key, idx)
    for k,v in pairs(tab) do
        local val = v[_key]
        if val ~= nil then
            v[_key] = nil
            if type(val) == "table" then
                val = _get_only_tab(val)
            end
            v[idx] = val
        end
    end
end

local function _get_culling_cfg(default_key, _cur_config)
    if _check_table(default_key) then
        for key, idx in pairs(default_key) do
             _filter_same_key(_cur_config, key, idx)
        end
    else
        for key, val_dict in pairs(default_key) do
            local tab = _cur_config[key]
            _cur_config[key] = _get_culling_cfg(val_dict, tab)
        end
    end
    return _cur_config
end


local _deal_single_cfg = function(config_str)
    _record_key = {}
    _duplicate_tab = {}
    print(string.format("配置:%s开始转化", config_str))
    local tar_file_path =  get_tar_path(config_str)
    local require_ori_file_path = get_ori_path(config_str, true)
    local ori_file_path = get_ori_path(config_str)
    local config = require(require_ori_file_path)
    local need_trans = _check_list(config)
    if not need_trans then
        copy_file(ori_file_path, tar_file_path)
        print(string.format("配置:%s由于结构问题不做转换，原样复制", config_str))
        return
    end
    
    local default_key = {}
    default_key = _get_default_key(_record_key)


    if not next(default_key) then
        copy_file(ori_file_path, tar_file_path)
        print(string.format("配置:%s default_key转换为空 因此不做转换，原样复制", config_str))
        return
    end

    
    
    local _cur_config = _get_culling_cfg(default_key, config)

    local t = _cur_config
    local base_temp = readAll("template_v2.lua")
    
    local fp = io.open(tar_file_path, "w")
    local s = DataDump(default_key)
    
    local content = replace_str(base_temp, s , "key_map")
    
    
    s = DataDump(_cur_config)
    content = replace_str(content, s , "content")
    
    fp:write(content)
    fp:close()
    print(string.format("配置:%s已转化完成", config_str))
end


--clean_output()
local ori_dir = _G.get_ori_dir()
for file in lfs.dir(ori_dir) do
    if file ~= "." and file ~= ".." then
        local size = lfs.attributes(ori_dir .. "/" .. file).size
        file = get_lua_file_name(file)
        if size >= _deal_file_size then
            _deal_single_cfg(file)
        else
            local tar_file_path = get_tar_path(file)
            local ori_file_path = get_ori_path(file)
            copy_file(ori_file_path, tar_file_path)
            print(sformat("%s文件比较小，就不进行转换了, 直接复制", file))
        end
    end
end

--_deal_single_cfg("item")
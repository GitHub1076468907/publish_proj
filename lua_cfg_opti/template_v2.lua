--template.lua
local function get_key()
	#key_map#
end


local function get_t()
	#content#
end
local key_map = get_key()
local t = get_t()


local _check_table = function(tab)
    for _, v in pairs(tab) do
        if type(v) ~= 'table' then
            return true
        end
    end 
end


local _idx_2_key = {}
local find_idx_2_key = function(_key_map, idx)
    if _idx_2_key[_key_map] and _idx_2_key[_key_map][idx] then
        return _idx_2_key[_key_map][idx]
    end
    for k,v in pairs(_key_map) do
        if v == idx then
            _idx_2_key[idx] = k
            return k
        end
    end
    _idx_2_key[_key_map] = {}
    _idx_2_key[_key_map][idx] = idx
    return idx
end

local function bind_meta_tab(_key_map, cfg)
	if _check_table(_key_map) then
        local meta_tbl = {
            __index = function(tbl,k)
                local key_idx = rawget(_key_map, k)
                return rawget(tbl, key_idx)
            end,
            __pairs = function(tbl)
                local ori_idx = nil 
                local _iter = function(_t, idx)
                    ori_idx = ori_idx or idx
                    local _key, v = next(_t, ori_idx)
                    ori_idx = _key
                    if _key == nil or v == nil then --要判定 为 nil 不然会受false影响
                        return
                    else
                      if type(_key) == "number" then
                         return find_idx_2_key(_key_map, _key), v
                      else
                          return _key, v
                      end
                    end
                end
                return _iter, tbl
            end
        }
		for key, _table in pairs(cfg) do
			if type(key) == "number" then
				setmetatable(_table, meta_tbl)
			end
		end
	else
		for k,v in pairs(_key_map) do
			local tab = rawget(cfg, k)
			bind_meta_tab(v, tab)
		end
	end
end

bind_meta_tab(key_map, t)

return t
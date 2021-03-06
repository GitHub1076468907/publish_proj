local tconcat = table.concat
local tinsert = table.insert
local srep = string.rep
local sformat = string.format
local sfind = string.find
local type = type
local pairs = pairs
local tostring = tostring
local next = next
local unpack = table.unpack

local extend = {
    Table = {},
    Io = {},
    String = {},
    Array = {},
    Protobuf = {},
    Random = {},
    Queue = {},
    Misc = {},
}

----------------------------------------
-- Table
function extend.Table.size(T)
    local i = 0
    for _, _ in pairs(T) do
        i = i + 1
    end
    return i
end

function extend.Table.find(T, x)
    for k, v in pairs(T) do
        if v == x then
            return k, v
        end
    end
end

function extend.Table.keys(T)
    local out = {}
    for k, _ in pairs(T) do
        out[#out + 1] = k
    end
    return out
end

function extend.Table.values(T)
    local out = {}
    for _, v in pairs(T) do
        out[#out + 1] = v
    end
    return out
end

function extend.Table.list2map(T)
    local out = {}
    for _, v in ipairs(T) do
        out[v] = v
    end
    return out
end

function extend.Table.foreach(T, F)
    local out = {}
    for k, v in pairs(T) do
        out[#out + 1] = F(v, k)
    end
    return out
end

function extend.Table.get_default(T, key, default)
    local t = T[key]
    if not t then
        t = default
        T[key] = t
    end
    return t
end

function extend.Table.clone(T)
    local out = {}
    for k, v in pairs(T) do
        out[k] = v
    end
    return out
end

function extend.Table.deep_clone(T)
    local mark={}
    local function copy_table(t)
        if type(t) ~= 'table' then return t end
        local mt = getmetatable(t)
        local res = {}
        for k,v in pairs(t) do
            if type(v) == 'table' then
                if not mark[v] then
                    mark[v] = copy_table(v)
                end
                res[k] = mark[v]
            else
                res[k] = v
            end
        end
        setmetatable(res,mt)
        return res
    end
    return copy_table(T)
end

function extend.Table.serialize(T)
	local mark={}
	local assign={}

	local function ser_table(tbl,parent)
		mark[tbl]=parent
		local tmp={}
		for k,v in pairs(tbl) do
			local key= type(k)=="number" and "["..k.."]" or "['" .. k .. "']"
			if type(v)=="table" then
				local dotkey= parent..(type(k)=="number" and key or "."..key)
				if mark[v] then
					tinsert(assign,dotkey.."="..mark[v])
				else
					tinsert(tmp, key.."="..ser_table(v,dotkey))
				end
			elseif type(v) == "string" then
				tinsert(tmp, key.."=".. sformat("%q", v))
            else
				tinsert(tmp, key.."=".. tostring(v))
            end
		end
		return "{"..tconcat(tmp,",").."}"
	end
	return ser_table(T,"ret")..tconcat(assign," ")
end

function extend.Table.filter(T, func)
   local t = {}
   for i,v in ipairs(T) do
      if func(v) then
         table.insert(t,v)
      end
   end
   return t
end

function extend.Table.deserialize(data)
    if data == nil or data == "" then
        return nil
    end

	local load_source = coroutine.wrap(function()
		coroutine.yield "do local ret="
		coroutine.yield (data)
		coroutine.yield " return ret end"
	end)

	local routine, err = load( load_source ,  "@deserialize", "t", {})
	return assert(routine, tostring(err) .. data)()
end

function extend.Table.print(T, CR)
    assert(type(T) == "table")

	CR = CR or '\r\n'
	local cache = {  [T] = "." }
	local function _dump(t,space,name)
		local temp = {}
		for k,v in next,t do
			local key = tostring(k)
			if cache[v] then
				tinsert(temp,"+" .. key .. " {" .. cache[v].."}")
			elseif type(v) == "table" then
				local new_key = name .. "." .. key
				cache[v] = new_key
				tinsert(temp,"+" .. key .. _dump(v,space .. (next(t,k) and "|" or " " ).. srep(" ",#key),new_key))
			else
				tinsert(temp,"+" .. key .. " [" .. tostring(v).."]")
			end
		end
		return tconcat(temp,CR..space)
	end
	print(_dump(T, "",""))
end

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

function extend.Table.new_weaktbl()
    return setmetatable({},{__mode = "v"})
end

function extend.Table.pretty_serialize(T, CR)
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
----------------------------------------
-- Io
function extend.Io.readfile(file)
	local fh = io.open(file , "rb")
	if not fh then return end
	local data = fh:read("*a")
	fh:close()
	return data
end

function extend.Io.writefile(file, data)
	local fh = io.open(file , "w+b")
	if not fh then return end
	fh:write(data)
	fh:close()
	return
end

function extend.Io.hasfile(file)
	local fh = io.open(file , "r+")
    if fh then
        fh:close()
        return true
    end
    return
end

function extend.eprint(...)
    local arg = {...}
    tinsert(arg, '\r')
    print(unpack(arg))
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
        return extend.Table.pretty_serialize(value)
    elseif value == nil then
        return "nil"
    else
        return "usedefine:" .. t
    end
end

function extend.tprint(...)
--#if not COC_PUBLISH
    print(extend.pretty_str(...))
--#endif
end

function extend.pretty_str( ... )
    local arg = table.pack(...)
    local t = {}
    for i = 1, arg.n do
        table.insert(t, print_value(arg[i]).."\n")
    end
    return table.concat(t)
end

function extend.String.to_camel_case(name)
	local camel_case = ""
	for section in name:gmatch( "[^_]+" ) do
		camel_case = camel_case..section:sub( 1, 1 ):upper()..section:sub( 2 )
    end
    name = camel_case
    camel_case = ''
	for section in name:gmatch( "[^.]+" ) do
		camel_case = camel_case..'.'..section:sub( 1, 1 ):upper()..section:sub( 2 )
	end
	return camel_case:sub(2)
end

function extend.String.start_with(str, start_pattern)
    local s, _ = sfind(str, start_pattern)
    return (s == 1)
end

function extend.String.replace(str, ori_char, replace_char)
    return str:gsub(ori_char, replace_char)
end

function extend.String.trans_url(url, ori_char, replace_char)
    ori_char = ori_char or "\\"
    replace_char = replace_char or "/"
    return url:gsub(ori_char, replace_char)
end

function extend.String.split(input, delimiter)
    input = tostring(input)
    delimiter = tostring(delimiter)
    if (delimiter=='') then return false end
    local pos,arr = 0, {}
    for st,sp in function() return string.find(input, delimiter, pos, true) end do
        table.insert(arr, string.sub(input, pos, st - 1))
        pos = sp + 1
    end
    table.insert(arr, string.sub(input, pos))
    return arr
end
----------------------------------------
-- Array

function extend.Array.insert(...)
    tinsert(...)
end

function extend.Array.member(L,key)
   -- ??????key???????????????L???
   for k,v in ipairs(L) do
      if key == v then
         return k,v
      end
   end
   return false
end

function extend.Array.append (L1,L2)
   -- ?????????????????????????????????
   for _,v in ipairs(L2) do
      L1[#L1+1] = v
   end
   return L1
end

function extend.Array.foreach(T, F)
    local out = {}
    for k, v in ipairs(T) do
        out[#out + 1] = F(v, k)
    end
    return out
end

function extend.Array.min(T)
    if #T == 0 then return nil end
    local i = 1
    for k,v in ipairs(T) do
        if v < T[i] then i = k end
    end
    return T[i] ,i
end

-- remove the first value
function extend.Array.remove(T, value)
    local pos
    for i, v in ipairs(T) do
        if v == value then
            pos = i
            break
        end
    end

    if not pos then
        return false
    end
    table.remove(T, pos)
    return true
end

-- find the first pos
function extend.Array.find(T, value)
    local pos
    for i, v in ipairs(T) do
        if v == value then
            pos = i
            break
        end
    end
    return pos
end

----------------------------------------
-- Protobuf
local function dump(dest, src)
    for k, v in pairs(dest) do
        if type(v) == "table" then
            dest[k] = dump(v, src[k])
        else
            dest[k] = src[k]
        end
    end
    return dest
end

function extend.Protobuf.table_is_empty(tbl)
    return (next(tbl) == nil)
end

extend.Protobuf.dump = dump
--------------------------------
-- Random
function extend.Random.random_choice(t)
    if #t <= 0 then
        return nil
    end

    return t[math.random(#t)]
end

--  ????????????????????????????????????????????????
function extend.Random.random_list(rate_list)
    local sum_rate  =   0

    for _, rate in ipairs(rate_list) do
        sum_rate = sum_rate + rate
    end

    if (sum_rate <= 0) then
        return nil
    end

    local roll  = math.random() * sum_rate
    for _, rate in ipairs(rate_list) do
        if (rate >= roll) then
            return _
        else
            roll = roll - rate
        end
    end

    assert(nil)
end

function extend.Random.sample_table(tbl, cnt)
    -- ?????????table?????????????????????cnt???tbl
    local out = {}
    local rkeys = extend.Random.random_size(extend.Table.keys(tbl), cnt)
    for _, key in ipairs(rkeys) do
        out[key] = tbl[key]
    end
    return out
end

function extend.Random.random_size(list, cnt)
    -- ?????????list?????????????????????cnt???list
    assert(cnt > 0)
    local L = {}
    for i, v in ipairs(list) do
        L[i] = v
    end

    local sz = #L
    if cnt >= sz then
        return L
    end

    for i = 1, cnt do
        local j = math.random(i, sz)
        local tmp = L[j]
        L[j] = L[i]
        L[i] = tmp
    end

    for i = cnt+1,sz do
        L[i] = nil
    end

    return L
end

function extend.Random.random_struct_list(rate_struct_list, cb)
    local rate_list = {}

    for _, s in ipairs(rate_struct_list) do
        local rate  = cb(s)
        if (rate ~= nil) then
            table.insert(rate_list, rate)
        else
            table.insert(rate_list, 0)
        end
    end

    return extend.Random.random_list(rate_list)
end

function extend.Random.random_float(min, max)
    if (max == nil) then
        return (math.random() * min)
    end

    local k = max - min
    return min + math.random() * k
end

function extend.Random.toss(ratio)
    return math.random() < ratio
end

--------------------------------
-- Misc
function extend.Misc.assert(v,message,level)
   if not v then
      message = message or "Assertion failed!"
      level = level or 1
      error(message,level+1)
   end
end

function extend.Misc.tags(...)
    local tags = {}

    for i = 1, select("#",...) do
        local v = select(i, ...)
        if type(v) == "table" then
            local key = table.remove(v, 1)
            tags[key] = v
        else
            tags[v] = true
        end
    end

    return tags
end

function extend.Misc.all(func1, ...)
    for _, v in pairs({...}) do
        if not func1(v) then
            return false
        end
    end
    return true
end

function extend.Misc.any(func1, ...)
    for _, v in pairs({...}) do
        if func1(v) then
            return true
        end
    end
    return false
end

-- Queue
local _queue_mt = {__index = extend.Queue}

function extend.Queue.create()
    return setmetatable({queue={},head=0,tail=-1},_queue_mt)
end

function extend.Queue.enqueue(Q,v)
    Q.tail = Q.tail + 1
    Q.queue[Q.tail] = v
end

function extend.Queue.dequeue(Q)
    if Q.tail < Q.head then
        return nil
    end

    local v = Q.queue[Q.head]
    Q.queue[Q.head] = nil
    Q.head = Q.head + 1

    if Q.tail < Q.head then
        Q.tail = -1
        Q.head = 0
    end
    return v
end

function extend.Queue.get_item(Q, index)
    assert(index > 0)
    return Q.queue[Q.head + index -1]
end

function extend.Queue.qsize(Q)
    return Q.tail - Q.head + 1
end

function extend.inject(meta, api_tbl)
    for k, v in pairs(api_tbl) do
        --assert(meta[k] == nil, k)
        meta[k] = v
    end
end

return extend

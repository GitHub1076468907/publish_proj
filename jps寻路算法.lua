local width, height
local start_point, tar_point
local start_val, tar_val, no_pass_val = 1, 2, -1
local way_list = false



--前两位是xy的变化量， 最后一个是方向定义的值
local dir_def = {
	[1] = {
		up = {0, 1, 1},
		down = {0, -1, 2},
		left = {-1, 0, 3},
		right = {1, 0, 4},
	},

	[2] = {
		up_left = {-1, 1, 5},
		up_right = {1, 1, 6},
		down_left = {-1, -1, 7},
		down_right = {1, -1, 8},
	}
}

local open_list = {}
local close_list = {}

local _check_is_simple_dir = function(dir)
	return dir[3] <= 4
end


local _get_simple_get_tar_dis = function(p1)
	local abs_x = math.abs(tar_point.x - p1.x)
	local abs_y = math.abs(tar_point.y - p1.y)
	--允许斜着走，就是一次可以消掉(1,1)
	local min_val = math.min(abs_x, abs_y)
	local max_val = abs_x + abs_y - min_val
	return min_val + max_val - min_val  --等于斜着走的步数 + 直线走的步数
end

local _debug_p_info = function(p, extra)
	if extra then
		print(extra)
	end
	print("正在检查的点信息是:")
	print("x:", p.x)
	print("y:", p.y)
	if p.dir then
		print("dir:", p.dir[3])
	end
	print("dis_ori:", p.dis_ori)
	print("dis_tar:", p.dis_tar)
end

local _debug_dir_info = function(p)
	print("正在检查的dir信息是:")
	print("x:", p[1])
	print("y:", p[2])
	print("type:", p[3])
end

local _get_dir_by_xy_offset = function(offset_x, offset_y)
	for _,v in pairs(dir_def) do
		for _,dir in pairs(v) do
			if dir[1] == offset_x and dir[2] == offset_y then
				return dir
			end
		end 
	end
end

local _gen_p = function(x, y, dis_ori, dis_tar, parent, dir)
	local res =  {
		x = x, 
		y = y, 
		dis_ori = dis_ori,
		dis_tar = dis_tar,
		parent = parent,
		dir = dir,
	}
	if not dir and parent then
		local offset_x, offset_y = x - parent.x, y - parent.y 
		res.dir = _get_dir_by_xy_offset(offset_x, offset_y)
	end
	return res
end

local _set_p_parent = function(p, parent)
	p.parent = parent
	local offset_x, offset_y = p.x - parent.x, p.y - parent.y 
	p.dir = _get_dir_by_xy_offset(offset_x, offset_y)
end

local _same_point = function(p1, p2)
	return p1.x == p2.x and p1.y == p2.y
end


local _check_xy_invaild = function(x, y)
	if x > width or x <= 0 or y > height or y <= 0 then
		return false
	end
	return true
end

local _get_way_list_val = function(x, y)
	if not _check_xy_invaild(x, y) then return end
	return way_list[height - y + 1][x]
end


local _get_next_point = function(dir, check_point)
	local next_x = check_point.x + dir[1]
	local next_y = check_point.y + dir[2]
	if not _check_xy_invaild(next_x, next_y) then return end

	local val = _get_way_list_val(next_x, next_y)
	if val == no_pass_val then
		return
	end

	local point = _gen_p(next_x, next_y, check_point.dis_ori + 1, 0, check_point)
	point.dis_tar = _get_simple_get_tar_dis(point)
	return point
end


local _inner_check_jump = function(x,y, dir)
	local val = _get_way_list_val(x,y)
	--print("ori _inner_check_jump!!!!!!!!", x,y, dir[1], dir[2], val)
	if val == no_pass_val then
		x = x + dir[1]
		y = y + dir[2]
		val = _get_way_list_val(x, y)
		if val and val ~= no_pass_val then
			return x, y
		end
	end
end

local _dir_search


local _get_jump_point = function(check_point, dir)
	print("_get_jump_point==============================_get_jump_point")
	_debug_p_info(check_point)
	_debug_dir_info(dir)
	--1.当前点是终点
	if _same_point(check_point, tar_point) then
		check_point.dir = dir
		return {check_point}
	end
	local _type = dir[3]
	if _type <= 4 then
		local _tmp_check = {{0,1},{0,-1}}
		--2.在指定搜索方向下存在强迫邻居点
		if _type <= 2 then
			-- up down
			_tmp_check = {{1,0},{-1,0}}
		end
		for _,v in ipairs(_tmp_check) do
			local x,y = _inner_check_jump(check_point.x + v[1], check_point.y + v[2] , dir)
			if x and y then
				check_point.dir = dir
				return {check_point}
			end
		end
	else
		--3.若搜索方向是斜向，则会往斜向的水平和垂直分量方向移动查找
		local _tmp_dir1 = {0, dir[2], dir[2] > 0 and 1 or 2}
		print("245", _tmp_dir1[0], _tmp_dir1[1], _tmp_dir1[2])
		local res = _dir_search(_tmp_dir1, check_point, true)
		if res then
			check_point.dir = dir
			return {check_point}
		end
		local _tmp_dir2 = {dir[1], 0, dir[1] > 0 and 4 or 3}
		print("253", _tmp_dir1[0], _tmp_dir1[1], _tmp_dir1[2])
		res = _dir_search(_tmp_dir2, check_point, true)
		if res then
			check_point.dir = dir
			return {check_point}
		end
	end
end


_dir_search = function(dir, check_point, no_next_p)
	print("_dir_search", dir[3], check_point.x, check_point.y, no_next_p)
	local _point = no_next_p and check_point or _get_next_point(dir, check_point) --check_point
	while _point do
		local res = _get_jump_point(_point, dir)
		if res then
			print("_get_jump_point 找到返回的值了!!!!!!")
			print(debug.traceback())
			_set_p_parent(res[1], check_point) --目前是每个方向只会返回一个跳点
			return res
		else
			_point = _get_next_point(dir, _point)
		end
	end
end



local __check_not_in_close_list = function(check_point)
	for _,v in ipairs(close_list) do
		if v.x == check_point.x and v.y == check_point.y then
			print("该点已经在close list中, 坐标为:")
			print("x:", v.x)
			print("y:", v.y)
			return true
		end
	end
end

local __check_not_in_open_list = function(check_point)
	for _,v in ipairs(open_list) do
		if v.x == check_point.x and v.y == check_point.y then
			print("该点已经在open_list中, 坐标为:")
			print("x:", v.x)
			print("y:", v.y)
			return true
		end
	end
end

local loop_max = 100
local loop_time = 0
local __inner_jps = function(open_list)
	local check_point
	while #open_list > 0 do
		loop_time = loop_time + 1
		if loop_time >= loop_max then
			print("循环太多次了")
			return
		end
		check_point = table.remove(open_list, 1)
		_debug_p_info(check_point, "__inner_jps:========================")
		local dir = check_point.dir
		if dir then
			--只往一些指定的方向去查找
			--单个直接方向的都改为增加同侧斜边方向的， 斜边方向的，都增加以下单边方向的
			local check_dir = {dir}
			local get_dir
			if dir[1] == 0 then
				get_dir = _get_dir_by_xy_offset(1, dir[2])
				table.insert(check_dir, get_dir)
				get_dir = _get_dir_by_xy_offset(-1, dir[2])
				table.insert(check_dir, get_dir)
			elseif dir[2] == 0 then
				get_dir = _get_dir_by_xy_offset(dir[1], 1)
				table.insert(check_dir, get_dir)
				get_dir = _get_dir_by_xy_offset(dir[1], -1)
				table.insert(check_dir, get_dir)
			else
				get_dir = _get_dir_by_xy_offset(0, dir[2])
				table.insert(check_dir, get_dir)
				get_dir = _get_dir_by_xy_offset(dir[1], 0)
				table.insert(check_dir, get_dir)
				get_dir = _get_dir_by_xy_offset(-dir[1], dir[2])
				table.insert(check_dir, get_dir)
				get_dir = _get_dir_by_xy_offset(dir[1], -dir[2])
				table.insert(check_dir, get_dir)
			end
			for _,v in pairs(check_dir) do
				local find_point = _dir_search(v, check_point)
				if find_point then 
					for _,point in ipairs(find_point) do
						_debug_p_info(point, "===============================340")
						if _same_point(point, tar_point) then
							return point
						end
						if not __check_not_in_close_list(point) and not __check_not_in_open_list(v) then
							table.insert(open_list, point)
						end
					end
				end
			end
		else
			for idx,dirs in ipairs(dir_def) do
				for _,v in pairs(dirs) do
					local find_point = _dir_search(v, check_point)
					if find_point then 
						for _,point in ipairs(find_point) do
							_debug_p_info(point, "===============================370")
							if _same_point(point, tar_point) then
								return point
							end
							if not __check_not_in_close_list(point) and not __check_not_in_open_list(v) then
								table.insert(open_list, point)
							end
						end
					end
				end
			end
		end
		table.insert(close_list, check_point)
		print("#close_list", #close_list)
		print("open_list~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
		for i,v in ipairs(open_list) do
			_debug_p_info(v, "openlist: " .. i)
		end
		--做open_list的最先选取排序
		table.sort(open_list, function(a,b)
			return a.dis_ori + a.dis_tar < b.dis_ori + b.dis_tar
		end)
	end
end

--jps寻路
local function find_way_by_jps(ori_point_list)
	way_list = ori_point_list
	width = #ori_point_list[1]
	height = #ori_point_list

	for idx,v in ipairs(ori_point_list) do
		assert(#v == width, idx .. "行的width个数 不等于" .. width)
		for _i, _v in ipairs(v) do
			if _v == 1 then
				assert(not start_point, "出现重复的起始点1")
				start_point = _gen_p(_i, height - idx + 1, 0)
				table.insert(open_list, start_point)
			elseif _v == 2 then
				tar_point = _gen_p(_i, height - idx + 1)
			end
		end
	end
	start_point.dis_tar = _get_simple_get_tar_dis(start_point)

	return __inner_jps(open_list)
end

local way_list = {
	{0,	0, 0, 0,	0, 		0},
	{0,	0, 0, 0, 	-1, 	2},
	{0,	0, 0, 0,	-1, 	0},
	{1,	0, 0, 0,	-1, 	0},
	{0,	0, 0, 0,	0, 		0},
}

local res_point = find_way_by_jps(way_list)
while res_point do
	print(res_point.x, res_point.y)
	res_point = res_point.parent
end
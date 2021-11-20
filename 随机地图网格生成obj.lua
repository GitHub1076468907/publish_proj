local random_seed = 70

local scene_width = 12
local scene_height = 12

local circleW = 1
local circleH = 0.5

local base_y = -2 --地底层的初始高度

--保留小数点后几位
function GetPreciseDecimal(nNum, n)
    if type(nNum) ~= "number" then
        return nNum
    end
    n = n or 0
    n = math.floor(n)
    if n < 0 then
        n = 0
    end
    local nDecimal = 10 ^ n
    local nTemp = math.floor(nNum * nDecimal)
    local nRet = nTemp / nDecimal
    return nRet
end


--获取单位向量
local _get_unit_dir = function(a)
    local mo = math.sqrt(a[1]*a[1] + a[2]*a[2] + a[3]*a[3])
    return {GetPreciseDecimal(a[1]/mo, 5), GetPreciseDecimal(a[2]/mo, 5), GetPreciseDecimal(a[3]/mo, 5)}
end

-- 向量叉乘
function GetVector3Cross(v1, v2)
    return _get_unit_dir({v1.y*v2.z - v2.y*v1.z , v2.x*v1.z-v1.x*v2.z ,  v1.x*v2.y-v2.x*v1.y})
end

local get_pos_sub = function(a, b)
    return {x = b[1] - a[1], y = b[2] - a[2], z = b[3] - a[3]}
end


local get_triangele_dir = function(a, b, c)
    local pos_1 = get_pos_sub(a,b)
    local pos_2 = get_pos_sub(b,c)
    return GetVector3Cross(pos_1, pos_2)
end

local get_half_dir = function(a, b)
    local c_dir = {(a[1] + b[1])/2, (a[2] + b[2])/2, (a[3] + b[3])/2}
    return _get_unit_dir(c_dir)
end

local _get_dir = function(a,b,c)
    local res = get_triangele_dir(a,b,c)
    print(res[1],res[2], res[3])
end

--_get_dir({0,1,0},{1,0,0},{0,0,-1})
--0.57735   0.57735 -0.57735



local cell_def_enum = {
    zero = 1, --顶点都在一平面
    one = 2, --顶点中有一个在二平面
    two_near = 3, --顶点中有两个在二平面 相邻顶点
    two_oppi = 4, --顶点中有两个在二平面 对边顶点
    three = 5,  --顶点中有三个在二平面
    three_and_mid_one = 6, --顶点中有3个在二平面, 其中3个中处于中央的那个在三平面
}


--地形基于哪个点的朝向
local rotate_base_point_idx = {
    lb = 1, --左下角是原始地形面片的朝向
    rb = 2,
    rt = 3,
    lt = 4,
}

-- 1234  顺时针旋转之后1格后就会变成 4123
local _sub_num = function(num1, sub_num)
    num1 = num1 - sub_num
    if num1 <= 0 then
        num1 = num1 + 4
    end
    return num1
end

local _get_rotate_after_triangle_idx = function(ori_triange_idx, rotate)
    local offset = rotate - 1
    for i, v in ipairs(ori_triange_idx) do
        ori_triange_idx[i] = _sub_num(v, offset)
    end
    return ori_triange_idx
end


local zero_cell_info = function()
    local res = {}
    res.points_base_lb = {{0,0,0}, {circleW,0,0}, {circleW,0,-circleW}, {0,0,-circleW}}
    res.cell_def_enum = cell_def_enum.zero
    res.point_in_layer = {4} --代表1层有4个点,2 3 层均没有点
    res.get_point_in_rotate_idx = function(rotate_idx)
        return res.points_base_lb
    end
    --返回当前旋转状态下的三角形绘制顺序值
    res.get_triangle_idx = function(rotate_idx)
        local base_res =  {{1,2,4}, {2,3,4}}
        for i,v in ipairs(base_res) do
            base_res[i] = _get_rotate_after_triangle_idx(v, rotate_idx)
        end
        return base_res
    end
    res.get_vn_by_rotate_idx = function(rotate_idx)
        return {{0,1,0},{0,1,0},{0,1,0},{0,1,0}}
    end
    return res
end

local one_cell_info = function()
    local res = {}
    res.points_base_lb = {{0,circleH,0}, {circleW,0,0}, {circleW,0,-circleW}, {0,0,-circleW}}
    res.cell_def_enum = cell_def_enum.one
    res.point_in_layer = {3,1} --代表1层有3个点,2 层 1个点
    res.get_point_in_rotate_idx = function(rotate_idx)
        return {{0,rotate_idx == rotate_base_point_idx.lb and circleH or 0,0}, 
                {circleW,rotate_idx == rotate_base_point_idx.lt and circleH or 0,0}, 
                {circleW,rotate_idx == rotate_base_point_idx.rt and circleH or 0,-circleW}, 
                {0,rotate_idx == rotate_base_point_idx.rb and circleH or 0,-circleW}}
    end
    --返回当前旋转状态下的三角形绘制顺序值
    res.get_triangle_idx = function(rotate_idx)
        local base_res =  {{1,2,4}, {2,3,4}}
        for i,v in ipairs(base_res) do
            base_res[i] = _get_rotate_after_triangle_idx(v, rotate_idx)
        end
        return base_res
    end
    return res
end

local two_near_cell_info = function()
    local res = {}
    res.points_base_lb = {{0,circleH,0}, {circleW,0,0}, {circleW,0,-circleW}, {0,circleH,-circleW}}
    res.cell_def_enum = cell_def_enum.two_near
    res.point_in_layer = {2,2} --代表1层有2个点,2层2个点
    res.get_point_in_rotate_idx = function(rotate_idx)
        return {{0,(rotate_idx == rotate_base_point_idx.lb or rotate_idx == rotate_base_point_idx.lt) and circleH or 0,0}, 
                {circleW,(rotate_idx == rotate_base_point_idx.lt or rotate_idx == rotate_base_point_idx.rt) and circleH or 0,0}, 
                {circleW,(rotate_idx == rotate_base_point_idx.rt or rotate_idx == rotate_base_point_idx.rb) and circleH or 0,-circleW}, 
                {0,(rotate_idx == rotate_base_point_idx.lb or rotate_idx == rotate_base_point_idx.rb) and circleH or 0,-circleW}}
    end
    --返回当前旋转状态下的三角形绘制顺序值
    res.get_triangle_idx = function(rotate_idx)
        local base_res =  {{1,2,4}, {2,3,4}}
        for i,v in ipairs(base_res) do
            base_res[i] = _get_rotate_after_triangle_idx(v, rotate_idx)
        end
        return base_res
    end
    return res
end

local two_oppi_cell_info = function()
    local res = {}
    res.points_base_lb = {{0,0,0}, {circleW,circleH,0}, {circleW,0,-circleW}, {0,circleH,-circleW}}
    res.cell_def_enum = cell_def_enum.two_oppi
    res.point_in_layer = {2,2}
    res.get_point_in_rotate_idx = function(rotate_idx)
        return {{0,(rotate_idx == rotate_base_point_idx.rb or rotate_idx == rotate_base_point_idx.lt) and circleH or 0,0}, 
                {circleW,(rotate_idx == rotate_base_point_idx.lb or rotate_idx == rotate_base_point_idx.rt) and circleH or 0,0}, 
                {circleW,(rotate_idx == rotate_base_point_idx.rb or rotate_idx == rotate_base_point_idx.lt) and circleH or 0,-circleW}, 
                {0,(rotate_idx == rotate_base_point_idx.lb or rotate_idx == rotate_base_point_idx.rt) and circleH or 0,-circleW}}
    end
    --返回当前旋转状态下的三角形绘制顺序值
    res.get_triangle_idx = function(rotate_idx)
        local base_res =  {{1,2,3}, {1,3,4}}
        for i,v in ipairs(base_res) do
            base_res[i] = _get_rotate_after_triangle_idx(v, rotate_idx)
        end
        return base_res
    end
    return res
end

local three_cell_info = function()
    local res = {}
    res.points_base_lb = {{0,circleH,0}, {circleW,circleH,0}, {circleW,0,-circleW}, {0,circleH,-circleW}}
    res.cell_def_enum = cell_def_enum.three
    res.point_in_layer = {1,3}
    res.get_point_in_rotate_idx = function(rotate_idx)
        return {{0,rotate_idx == rotate_base_point_idx.rt and 0 or circleH,0}, 
                {circleW,rotate_idx == rotate_base_point_idx.rb and 0 or circleH,0}, 
                {circleW,rotate_idx == rotate_base_point_idx.lb and 0 or circleH,-circleW}, 
                {0,rotate_idx == rotate_base_point_idx.lt and 0 or circleH,-circleW}}
    end
    --返回当前旋转状态下的三角形绘制顺序值
    res.get_triangle_idx = function(rotate_idx)
        local base_res =  {{1,2,4}, {2,3,4}}
        for i,v in ipairs(base_res) do
            base_res[i] = _get_rotate_after_triangle_idx(v, rotate_idx)
        end
        return base_res
    end
    return res
end


local three_and_mid_one_cell_info = function()
    local res = {}
    res.points_base_lb = {{0,2 * circleH,0}, {circleW,circleH,0}, {circleW,0,-circleW}, {0,circleH,-circleW}}
    res.cell_def_enum = cell_def_enum.three_and_mid_one
    res.point_in_layer = {1,2,1} --代表1层有1个点, 2层有2个点, 3层有1个点
    res.get_point_in_rotate_idx = function(rotate_idx)
        local lb_y = rotate_idx == rotate_base_point_idx.lb and 2*circleH or (rotate_idx == rotate_base_point_idx.rt and 0 or circleH)
        local rb_y = rotate_idx == rotate_base_point_idx.lt and 2*circleH or (rotate_idx == rotate_base_point_idx.rb and 0 or circleH)
        local rt_y = rotate_idx == rotate_base_point_idx.rt and 2*circleH or (rotate_idx == rotate_base_point_idx.lb and 0 or circleH)
        local lt_y = rotate_idx == rotate_base_point_idx.rb and 2*circleH or (rotate_idx == rotate_base_point_idx.lt and 0 or circleH)
        return {{0,lb_y,0}, 
                {circleW,rb_y,0}, 
                {circleW,rt_y,-circleW}, 
                {0,lt_y,-circleW}}
    end
    --返回当前旋转状态下的三角形绘制顺序值
    res.get_triangle_idx = function(rotate_idx)
        local base_res =  {{1,2,4}, {2,3,4}}
        for i,v in ipairs(base_res) do
            base_res[i] = _get_rotate_after_triangle_idx(v, rotate_idx)
        end
        return base_res
    end
    return res
end

local gen_cell = {
    [cell_def_enum.zero] = zero_cell_info(),
    [cell_def_enum.one] = one_cell_info(),
    [cell_def_enum.two_near] = two_near_cell_info(),
    [cell_def_enum.two_oppi] = two_oppi_cell_info(),
    [cell_def_enum.three] = three_cell_info(),
    [cell_def_enum.three_and_mid_one] = three_and_mid_one_cell_info()
}

math.randomseed(random_seed)

local _get_random_num = function(include_a, include_b)
    return math.random(include_a, include_b)
end

local show_debug_cell_info = function(cell_info, pre_desc)
    print(pre_desc)
    if cell_info then
        print("cell_def_enum is :", cell_info.cell_def.cell_def_enum)
        print("cell_rotate_idx is :", cell_info.rotate_idx)
    else
        print("is nil!!!!")
    end
end

local check_suit_idx = function(cell, rb_lb_y_offset, lt_lb_y_offset)
    local res = {}
    for i = rotate_base_point_idx.lb, rotate_base_point_idx.lt do
        local pos = cell.get_point_in_rotate_idx(i)
        local can_insert = true
        if rb_lb_y_offset and pos[2][2] - pos[1][2] ~= rb_lb_y_offset then
            can_insert = false
        end
        if can_insert and lt_lb_y_offset and pos[4][2] - pos[1][2] ~= lt_lb_y_offset then
            can_insert = false
        end
        if can_insert then
            table.insert(res, i)
        end
    end
    return res
end

local tprint = function(tbl, desc)
    print(desc)
    for _,v in ipairs(tbl) do
        print(v)
    end
end

--根据顶点高度差 返回符合的所有 面片*旋转idx的组合
--return {{cell_info = cell_info, suit_idxs = {适合的idx列表,...}}, ...}
local get_all_suit_group = function(rb_lb_y_offset, lt_lb_y_offset)
    local res = {}
    local start_idx, end_idx = cell_def_enum.zero, cell_def_enum.three_and_mid_one
    for i = start_idx, end_idx do
        local cell = gen_cell[i]
        local suit_idxs = check_suit_idx(cell, rb_lb_y_offset, lt_lb_y_offset)
        if suit_idxs and next(suit_idxs) then
            table.insert(res, {cell_info = cell, suit_idxs = suit_idxs})
        end
    end
    return res
end

local debug_all_suit_group = function(all_suit_group)
    print("可供选择面片信息如下 :")
    for _, v in ipairs(all_suit_group) do
        tprint(v.suit_idxs, "cell类型是 : ".. v.cell_info.cell_def_enum .. " 可以选中的旋转方向是:")
    end
end

--根据左边和下边的cell信息得到这个位置下可以随机的面片类型 和 旋转类型
local get_cell = function(pre_h_cell, pre_w_cell)
    local lb_y = 0, rb_lb_y, lt_lb_y, cell_info
    if pre_h_cell then
        cell_info = pre_h_cell.cell_def
        local idx = pre_h_cell.rotate_idx
        local pos = cell_info.get_point_in_rotate_idx(idx)
        rb_lb_y= pos[3][2] - pos[4][2]
    end
    if pre_w_cell then
        cell_info = pre_w_cell.cell_def
        local idx = pre_w_cell.rotate_idx
        local pos = cell_info.get_point_in_rotate_idx(idx)
        lt_lb_y = pos[3][2] - pos[2][2]
    end
    local all_suit_group = get_all_suit_group(rb_lb_y, lt_lb_y)
    if not next(all_suit_group) then
        return
    end
    local get_random_cell_idx = _get_random_num(1, #all_suit_group)
    --debug_all_suit_group(all_suit_group)
    local cell = all_suit_group[get_random_cell_idx].cell_info
    local get_random_idx = _get_random_num(1, #all_suit_group[get_random_cell_idx].suit_idxs)
    --print("选中的cell类型是 : ", cell.cell_def_enum, " 选中的旋转方向是:", all_suit_group[get_random_cell_idx].suit_idxs[get_random_idx])
    return {cell_def = cell, rotate_idx = all_suit_group[get_random_cell_idx].suit_idxs[get_random_idx], pre_h_cell = pre_h_cell, pre_w_cell = pre_w_cell}
end

local final_cell_list = {} -- {{cell_def = cell_info, rotate_idx = rotate_base_point_idx, final_pos_record = final_pos}}
--基础思路 1.随机每一个可以使用的面片 2.随机该面片可以使用的朝向值
--每一个格子的初始选择受限制于左边和下边的格子侧面顶点分布(假设是从左下角往height侧先铺)
local pre_h_cell, pre_w_cell
for w = 1, scene_width do
    for h = 1, scene_height do
        --print("#final_cell_list:", #final_cell_list)
        if h ~= 1 then
            pre_h_cell = final_cell_list[#final_cell_list] --下边的格子
        else
            pre_h_cell = nil
        end
        pre_w_cell = final_cell_list[#final_cell_list - (scene_height - 1)] --左边的格子
        local cell = get_cell(pre_h_cell, pre_w_cell)
        if not cell then
            show_debug_cell_info(pre_h_cell, "pre_h_cell info: ")
            show_debug_cell_info(pre_w_cell, "pre_w_cell info: ")
            assert(cell, "出现了找不到适合的cell")
        end
        table.insert(final_cell_list, cell)
    end
end
for idx,v in ipairs(final_cell_list) do
    print("idx: ",idx, " cell_def_enum: ", v.cell_def.cell_def_enum, " rotate_idx: ", v.rotate_idx)
    --show_debug_cell_info(v.pre_h_cell, "v.pre_h_cell info: ")
    --show_debug_cell_info(v.pre_w_cell, "v.pre_w_cell info: ")
end

-------------------------------生成网格数据结束


-------------------------------将网格数据写入一个obj文件中

local _clear_un_valid_float = function(a)
    local floor_num = math.floor(a)
    if a == floor_num then
        return floor_num
    else
        return a
    end
end

local get_cell_pos_by_base = function(cell, rotate_idx, base_lb_pos)
    local pos = cell.get_point_in_rotate_idx(rotate_idx)
    local offset = {pos[1][1] - base_lb_pos[1], pos[1][2] - base_lb_pos[2], pos[1][3] - base_lb_pos[3]}
    local final_pos = {
        {base_lb_pos[1], base_lb_pos[2], base_lb_pos[3]}, --这里不能直接赋值base_lb_pos, 因为后面会改这个的值
        {_clear_un_valid_float(pos[2][1] - offset[1]), _clear_un_valid_float(pos[2][2] - offset[2]), _clear_un_valid_float(pos[2][3] - offset[3])},
        {_clear_un_valid_float(pos[3][1] - offset[1]), _clear_un_valid_float(pos[3][2] - offset[2]), _clear_un_valid_float(pos[3][3] - offset[3])},
        {_clear_un_valid_float(pos[4][1] - offset[1]), _clear_un_valid_float(pos[4][2] - offset[2]), _clear_un_valid_float(pos[4][3] - offset[3])}
    }
    return final_pos
end

local get_vn_by_rotate_idx = function(cell, rotate_idx)
    local trangle_idx = cell.get_triangle_idx(rotate_idx)
    local pos = cell.get_point_in_rotate_idx(rotate_idx)
    local res = {{},{},{},{}}
    for _,tris in ipairs(trangle_idx) do
        local dir = get_triangele_dir(pos[tris[1]], pos[tris[2]], pos[tris[3]])
        for _, idx in ipairs(tris) do
            table.insert(res[idx], dir)
        end
    end
    --一个顶点有多个法线的,进行相加/2的简单平均 获得半程向量
    for i,v in ipairs(res) do
        if #v > 1 then
            res[i] = get_half_dir(v[1],v[2])
        else
            res[i] = v[1]
        end
    end
    return res
end


local tbl_v = {} --顶点位置数据
local tbl_dict = {}

local vt = {0.175, 0.258, 0.000} --这里不处理uv, 就默认直接这个值吧

local tbl_vn = {} --顶点法线数据
local tbl_vn_dict = {}
local tbl_f = {} --三角形数据

local _save_v = function(pos)
    --tprint(pos, "_save_v!!!!!!")
    local str = table.concat(pos, "_")
    if tbl_dict[str] then
        return tbl_dict[str]
    end
    table.insert(tbl_v, pos)
    local idx = #tbl_v
    tbl_dict[str] = idx
    return idx
end

local _save_vn = function(vn)
    --tprint(vn, "vn!!!!!!!!!!!!")
    local str = table.concat(vn, "_")
    if tbl_vn_dict[str] then
        return tbl_vn_dict[str]
    end
    table.insert(tbl_vn, vn)
    local idx = #tbl_vn
    tbl_vn_dict[str] = idx
    return idx
end

local idx_list = {}
local save_cell_pos_info = function(final_pos, vn_idx_list, triangle_idx_list)
    idx_list = {}
    for i,v in ipairs(final_pos) do
        idx_list[i] = _save_v(v)
    end

    local tri,point = {}
    for _,triange in ipairs(triangle_idx_list) do
        tri = {}
        for _, idx in ipairs(triange) do
            point = {}
            table.insert(point, idx_list[idx])
            table.insert(point, 1) --uv没有弄,默认只有一个
            table.insert(point, vn_idx_list[idx])
            table.insert(tri, table.concat(point, "/"))
        end
        table.insert(tbl_f, table.concat(tri, " "))
    end
end

local save_cell_vn = function(cell, rotate_idx)
    local vn_list = get_vn_by_rotate_idx(cell, rotate_idx)
    return {_save_vn(vn_list[1]), _save_vn(vn_list[2]), _save_vn(vn_list[3]), _save_vn(vn_list[4])}
end


local lb_base_pos = {0,0,0}
local cell, rotate_idx, final_pos
local vn_idx_list, triangle_idx_list
for i,v in ipairs(final_cell_list) do
    cell = v.cell_def
    rotate_idx = v.rotate_idx
    final_pos = get_cell_pos_by_base(cell, rotate_idx, lb_base_pos)
    v.final_pos_record = final_pos
    --tprint(final_pos[1], "final_pos[1]:   ")
    --tprint(final_pos[2], "final_pos[2]:   ")
    --tprint(final_pos[3], "final_pos[3]:   ")
    --tprint(final_pos[4], "final_pos[4]:   ")
    vn_idx_list = save_cell_vn(cell, rotate_idx)
    triangle_idx_list = cell.get_triangle_idx(rotate_idx)
    save_cell_pos_info(final_pos, vn_idx_list, triangle_idx_list)
    if i % scene_height == 0 then
        --换了另一列重开开始,这时顶点要找 w pre 的2 号点位
        local pre_w_cell = final_cell_list[i - (scene_height - 1)] --左边的格子
        --print("i : ", i, " 开始重新找列了")
        --show_debug_cell_info(pre_w_cell, "pre_w_cell info: ")
        local _final_pos = pre_w_cell.final_pos_record
        --tprint(_final_pos[1], "_final_pos[1]:   ")
        --tprint(_final_pos[2], "_final_pos[2]:   ")
        --tprint(_final_pos[3], "_final_pos[3]:   ")
        --tprint(_final_pos[4], "_final_pos[4]:   ")
        lb_base_pos[1] = _final_pos[2][1]
        lb_base_pos[2] = _final_pos[2][2]
        lb_base_pos[3] = _final_pos[2][3]
    else
        lb_base_pos[1] = final_pos[4][1]
        lb_base_pos[2] = final_pos[4][2]
        lb_base_pos[3] = final_pos[4][3]
    end
    --tprint(lb_base_pos, "lb_base_pos 当前的值是: ")
end

print("===========================分水岭")
-------------------------------生成地底层网格前/右面
local insert = table.insert
local ground_cell_list = {}
local group_cell_dict_cache = {} -- 只保留上一层的缓存(因为只会相邻的点会公用)
local triange_record_list = {} --三角形关系记录

local _save_cell = function(cell_info)
   local str = table.concat(cell_info, '_')
   if group_cell_dict_cache[str] then
        return group_cell_dict_cache[str]
   end
   insert(ground_cell_list, cell_info)
   group_cell_dict_cache[str] = #ground_cell_list
   return group_cell_dict_cache[str]
end

local _gen_ground_cell = function(cell, idx_1, idx_2)
    local cell_def = cell.cell_def
    local rotate_idx = cell.rotate_idx
    local pos_list = cell.final_pos_record--get_point_in_rotate_idx(rotate_idx)

    local pos_1, pos_2 = pos_list[idx_1], pos_list[idx_2]
    --[[print("--------------------------------------")
    print("cell_def", cell_def.cell_def_enum)
    print("cell_def rotate_idx", rotate_idx)
    print("base_point", pos_1[1], pos_1[2], pos_1[3])
    print("base_point_2", pos_2[1], pos_2[2], pos_2[3])--]]
    local cur_y = base_y
    local max_y = math.max(pos_1[2], pos_2[2])
    local min_y = math.min(pos_1[2], pos_2[2]) --pos_1[2] + pos_2[2] - max_y

    --检查是否需要创建四边形
    if cur_y < min_y then
        local idx_1 = _save_cell({pos_1[1], cur_y, pos_1[3]})
        local idx_2 = _save_cell({pos_2[1], cur_y, pos_2[3]})
        local idx_4 = _save_cell({pos_1[1], min_y, pos_1[3]})
        local idx_3 = _save_cell({pos_2[1], min_y, pos_2[3]})
        insert(triange_record_list,{idx_1, idx_2, idx_4})
        insert(triange_record_list,{idx_2, idx_3, idx_4})
    end

    --检查是否需要生成三角形
    if min_y ~= max_y then
        local max_pos = pos_1[2] == max_y and pos_1 or pos_2
        local min_pos = pos_1[2] == min_y and pos_1 or pos_2
        local idx_1 = _save_cell({max_pos[1], min_y, max_pos[3]})
        local idx_2 = _save_cell({min_pos[1], min_pos[2], min_pos[3]})
        local idx_3 = _save_cell({max_pos[1], max_pos[2], max_pos[3]})
        if min_pos[1] > max_pos[1] then
            insert(triange_record_list,{idx_2, idx_3, idx_1})
        else
            insert(triange_record_list,{idx_2, idx_1, idx_3})
        end
    end
end

for i = 1, scene_width do
    _gen_ground_cell(final_cell_list[1 + (i - 1)*scene_height], 1, 2)
end

ground_cell_list.group_front = {idx = #ground_cell_list, vn = {0, 0, 1}}

for i = 1, scene_height do
    _gen_ground_cell(final_cell_list[i + (scene_width - 1)*scene_height], 2, 3)
end

ground_cell_list.group_right = {idx = #ground_cell_list, vn = {1, 0, 0}}

--[[for i,v in ipairs(triange_record_list) do
    print("i:", i, table.concat(v, "_"))
    for pos,v2 in ipairs(v) do
        print("pos:", pos, table.concat(ground_cell_list[v2], "_"))
    end
end
--]]






-----------------开始放入地层网格数据
local group_front = ground_cell_list.group_front
local group_right = ground_cell_list.group_right
local front_vn_idx = _save_vn(group_front.vn)
local right_vn_idx = _save_vn(group_right.vn)

local point,vn_idx_list,idx_list,tri
for _, idxs in ipairs(triange_record_list) do
    tri = {}
    for i, id in ipairs(idxs) do
        point = {}
        local pos = ground_cell_list[id]
        local real_vn_pos = id <= group_front.idx and front_vn_idx or right_vn_idx
        local real_pos = _save_v(pos)

        table.insert(point, real_pos)
        table.insert(point, 1) --uv没有弄,默认只有一个
        table.insert(point, real_vn_pos)
        table.insert(tri, table.concat(point, "/"))
    end
    table.insert(tbl_f, table.concat(tri, " "))
end




print(#tbl_v)
print(#tbl_vn)
print(#tbl_f)
--tprint(tbl_f, "tbl_f")

--开始写文件
_file = io.open("test_scene_gen.obj", "w")
local format = string.format
local desc = ""
for _, v in ipairs(tbl_v) do
    --tprint(v, "v:!!!!")
    desc = format("v %s\n", table.concat(v, " "))
    _file:write(desc)
end
_file:write("\n")
desc = format("vt  %s\n", table.concat(vt, " "))
_file:write(desc)
_file:write("\n")
for _, v in ipairs(tbl_vn) do
    desc = format("vn  %s\n", table.concat(v, " "))
    _file:write(desc)
end
_file:write("\n")
for _, v in ipairs(tbl_f) do
    desc = format("f %s\n", v)
    _file:write(desc)
end

_file:close()
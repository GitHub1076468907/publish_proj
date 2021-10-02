--FYI: https://github.com/Tencent/xLua/blob/master/Assets/XLua/Doc/XLua_Tutorial_EN.md
local extend = require(PluginPath ..'/../extend')
local trans_url = extend.String.trans_url
local replace = extend.String.replace
local split = extend.String.split
local size = extend.Table.size
local readfile = extend.Io.readfile
local file_exists = _G.file_exists
local get_all_file = _G.get_all_file
local ProcessUtil =  CS.FairyEditor.ProcessUtil
local writefile = extend.Io.writefile
local PublishHandler = CS.FairyEditor.PublishHandler

local BuilderUtil = CS.FairyEditor.BuilderUtil
local tprint = function(...)
    fprint(extend.pretty_str(...))
end

local IOUtil = CS.FairyEditor.IOUtil
local alert = CS.FairyEditor.App.Alert
local Confirm = CS.FairyEditor.App.Confirm
local insert = table.insert
local format = string.format
local sfind = string.find
local remove = table.remove

local repeats_times = 2 --重复次数出现这么多次时才会拿来进行移动处理
local common_pkg_name = "Common" --默认转移过去的公共包名
local common_pkg_def_dicts = {
    Common = true,
    Icon = true,
    BackGroundImg = true,
}
local log_file_name = "_check_res_repeat_log.txt" --过程log打印文件
local write_file_handle = false
local f_proj

local show_info = function(...)
    tprint(...)
    if not write_file_handle then
        write_file_handle = io.open(log_file_name , "w+b")
    end
    write_file_handle:write(extend.pretty_str(...))
end

local _get_file_md5 = function(file_path)
    return BuilderUtil.GetMD5HashFromFile(file_path)
end

local _get_pkg_img_md5_fpkgitem_dicts = function(pkg)
    local dicts = {}
    local all_check_num = 0
    --Example这个不进行检测
    if pkg.name ~= "Example" then
        for _, item in pairs(pkg.items) do
            --只检测主干的image
            if item.type == "image" and item.branch == "" then
                all_check_num = all_check_num + 1
                local full_path = item.file
                local md5 = _get_file_md5(full_path)
                dicts[md5] = item
            end
        end
    end
    return dicts
end

local _get_pic_url_by_fitem = function(f_item)
    return f_item:GetURL()
end

local _get_pkg_path_part = function(f_item)
    return trans_url(format("%s%s%s", f_item.owner.name, f_item.path, f_item.name))
end

--设置 f_item 是否导出
local _set_f_item_exported = function(item_list, bool)
	App.libView:SetResourcesExported(item_list, bool)
end

--拿取主干下的fitem 对应分支的item
local _get_branch_item = function(f_item, br)
	local file_path = f_item.file
	local path = f_item.path
	local name = f_item.name
	local pkg = f_item.owner
	local br_file_path = replace(file_path, "assets", format("assets_%s",br))
	if file_exists(br_file_path) then
		for _, item in pairs(pkg.items) do
			if item.branch == br and item.name == name and item.path == format("/:%s%s", br, path) then
				return item
			end
		end
	end
end

local function get_all_branch_items(f_item)
    local res = {}
    local all_br = f_proj.allBranches
	for _, br in pairs(all_br) do
		--排除掉主干
		if br ~= "" then
			local br_item = _get_branch_item(f_item, br)
			if br_item then
				insert(res, br_item)
			end
		end
    end
    return res
end


--把该image fitem 删掉也把分支的对应图片一起处理
local _del_pkg_f_item_and_br = function(f_item)
	local pkg_item = f_item.owner
	pkg_item:DeleteItem(f_item)
    local had_deal_br = false
    --把在分支的对应图片也干掉
    local all_branch_items = get_all_branch_items(f_item)
    if next(all_branch_items) then
        had_deal_br = true
        for _,v in ipairs(all_branch_items) do
            pkg_item:DeleteItem(v)
        end
    end

--[[     local all_br = f_proj.allBranches
	for _, br in pairs(all_br) do
		--排除掉主干
		if br ~= "" then
			local br_item = _get_branch_item(f_item, br)
			if br_item then
				had_deal_br = true
				pkg_item:DeleteItem(br_item)
			end
		end
	end ]]
	return had_deal_br and pkg_item.name
end

local _move_res_inner = function(f_pkg_item, br, path)
    _set_f_item_exported({f_pkg_item}, true)
    local List_item = CS.System.Collections.Generic.List(CS.FairyEditor.FPackageItem)
    local list = List_item()
    list:Add(f_pkg_item)

    local use_copy_handle = true
	local ui_common_pkg = App.project:GetPackageByName(common_pkg_name)
	local dir_path = path or "/images"
    if br and br ~= "" then
        show_info("有分支上的迁移！！！！！！！！！", br, "  ", f_pkg_item.file)
        dir_path = format("/:%s%s", br, dir_path)
        if not ui_common_pkg:GetBranchRootItem(br) then
            ui_common_pkg:CreateBranch(br)
        end
    end
    local ui_common_img_dir = ui_common_pkg:GetItemByPath(dir_path)
    if not ui_common_img_dir then
        ui_common_img_dir = ui_common_pkg:CreatePath(dir_path)
    end
    if use_copy_handle then
        local copyHandler = CS.FairyEditor.CopyHandler()
        copyHandler:InitWithItems(list, ui_common_pkg, ui_common_img_dir.id, CS.FairyEditor.DependencyQuery.SeekLevel.SELECTION)
		copyHandler:Copy(ui_common_pkg, CS.FairyEditor.CopyHandler.OverrideOption.RENAME, true)
		local tra_pkg_item = ui_common_pkg:GetItem(f_pkg_item.id)
		return tra_pkg_item
    else
        --这个弹窗非阻塞的
        App.libView:MoveResources(ui_common_img_dir, {f_pkg_item})
    end
--[[     local pre_path = format("%s%s", ui_common_pkg.basePath, "/images/")
    local common_file_path = format("%s%s", pre_path, f_pkg_item.fileName)
    --tprint(common_file_path)
    local count = 1
    while(file_exists(common_file_path)) do
        tprint("新建路径已存在，需要重新设置名字：" .. common_file_path)
        local file_name = replace(f_pkg_item.fileName, f_pkg_item.name, f_pkg_item.name .. count)
        common_file_path = format("%s%s", pre_path, file_name)
        count = count + 1
    end
    IOUtil.CopyFile(f_pkg_item.file, common_file_path)
    --这个异步非阻塞的，会没refresh完就去跑下面的代码了
    App.RefreshProject()
    for _, item in pairs(ui_common_pkg.items) do
        tprint(item.file)
    end ]]
	--tprint("!!!move package finish:")

end

local _move_res = function(f_pkg_item)
	local move_item = _move_res_inner(f_pkg_item, "")
	local all_br = f_proj.allBranches
	for _, br in pairs(all_br) do
		--分支图片也跟着移动
		if br ~= "" then
			local br_item = _get_branch_item(f_pkg_item, br)
			if br_item then
				_move_res_inner(br_item, br)
			end
		end
	end
	return move_item
end



local temp_url_item_dicts = {}
--修改组件的xml以此修改引用替换
local _pkg_change_url = function(pkg, change_dicts, log_func)
    local change_log_dict = {}

    local pkg_id = pkg.id
    local _inner_get_item = function(url)
        if temp_url_item_dicts[url] then
            return temp_url_item_dicts[url]
        else
            local item = f_proj:GetItemByURL(url)
            temp_url_item_dicts[url] = item
            return item
        end
    end

    local _inner_record_change_log = function(ori_url,tar_url,item, all_turn_times, menber)
        local path = item.file
        change_log_dict[path] = change_log_dict[path] or {}
        local key = format("%s->%s",ori_url,tar_url)
        change_log_dict[path][key] = change_log_dict[path][key] or {}
        change_log_dict[path][key].ori_url = ori_url
        change_log_dict[path][key].tar_url = tar_url
        if all_turn_times then
            change_log_dict[path][key].all_turn_times = all_turn_times
        end
        if menber then
            change_log_dict[path][key].turn_menbers = change_log_dict[path][key].turn_menbers or {}
            insert(change_log_dict[path][key].turn_menbers, menber)
        end
    end

    for _, item in pairs(pkg.items) do
        if item.type == 'component' then
            local file_data = readfile(item.file)
            local trans_data = file_data
            local trans_time = 0
            for ori_url, tar_url in pairs(change_dicts) do
                --直接替换一整个url的
                if sfind(trans_data, ori_url) then
                    trans_data, trans_time = replace(trans_data, ori_url, tar_url)
                    _inner_record_change_log(ori_url, tar_url, item, trans_time)
                end
                local ori_url_item = _inner_get_item(ori_url)
                local ori_comp_id = ori_url_item.id
                local ori_pkg_id = ori_url_item.owner.id
                local tar_url_item = _inner_get_item(tar_url)
                local tar_comp_id = tar_url_item.id
                local tar_pkg_id = tar_url_item.owner.id
                --替换src，pkg的 ，应该只有用于图片的
                trans_data = string.gsub(trans_data, format('(<image[^/>]*src="%s".-/>)',ori_comp_id), function(args)
                    local data = args
                    --xml没有记录pkgid的话正明用的是本包的图片
                    local xml_ori_pkg_id = string.match(data, 'pkg="(.-)"') --根据这个字段来判断原本是否有
                    local xml_pkg_id = xml_ori_pkg_id or pkg_id
                    --都匹配，要进行替换 src, 看情况是否显示pkg， fileName 字段
                    if xml_pkg_id == ori_pkg_id then
                        data = string.gsub(data, '((%a*)=(".-"))', function(args1,args2,args3)
                            if args2 == "src" then
                                return format('src="%s"', tar_comp_id)
                            elseif args2 == 'name' then
                                _inner_record_change_log(ori_url, tar_url, item, nil, args3)
                            elseif args2 == "pkg" then
                                if tar_pkg_id == pkg_id then
                                    --一样的就不用这个字段了
                                    return ""
                                else
                                    return format('pkg="%s"', tar_pkg_id)
                                end
                            elseif args2 == "fileName" then
                                local new_file_name = format("%s%s", string.sub(tar_url_item.path, 2), tar_url_item.fileName)
                                local file_str = format('fileName="%s"', new_file_name)
                                --在这里把需要补充显示的pkg加在它后面好了
                                if not xml_ori_pkg_id and not sfind(data, 'pkg=') then
                                    if tar_pkg_id ~= pkg_id then
                                        return format('%s pkg="%s"', file_str, tar_pkg_id)
                                    end
                                end
                                return file_str
                            end
                            return args1
                        end)
                    end
                    return data
                end)
            end
            if trans_data ~= file_data then
                writefile(item.file, trans_data)
            end
        end
    end
    return change_log_dict
end

--change_dicts key 是原来的ui引用，value是要改成的ui引用
local _change_pic_url_list = function(change_dicts, log_func)
	--遍历所有的包进行替换
	local has_change_dict = {}
	local pkg_change = {}
    local all_pkg = f_proj.allPackages
    local is_change = false
    for _, pkg_obj in pairs (all_pkg) do
        is_change = false
        local change_dict = _pkg_change_url(pkg_obj, change_dicts, log_func)
        if change_dict and next(change_dict) then
            pkg_change[pkg_obj.name] = true
            is_change = true
			for _, keys in pairs (change_dict) do
				for _, dat in pairs(keys) do
					has_change_dict[dat.ori_url] = true
				end
			end
			if is_change and log_func then
				log_func(format("pkg_name: %s change", pkg_obj.name))
				log_func(change_dict)
			end
		end
	end
	return pkg_change, has_change_dict
end


local _get_url_by_ui_path = function(url)
    --f_pkg_item.owner:GetItemByPath("/images/test1/ico_jiangbing")
    local splits = split(url, "/")
    local pkg_name = splits[1]
    local path = replace(url, pkg_name, "")
    local pkg = f_proj:GetPackageByName(pkg_name)
    return pkg:GetItemByPath(path):GetURL()
end

local _check_change_code = function(change_code_use_dicts, lua_path_root, show_log_func, tmp_path_2_url)
    local change_dicts = {}
	local lua_path_url = PluginPath .. lua_path_root
    --show_log_func("lua_path_url", lua_path_url)
    --lua 的正则匹配  不支持这种组合选择
	--code_res_re_pkg_collect = table.concat(code_res_re_pkg_collect, "|")

    local __get_code_set_res = function(file_path)
        local ori_data = readfile(file_path)
        local file_data = ori_data
        file_data = string.gsub(file_data, "([\'\"][ui://]*([%w_]+/([^\"]-))[\'\"])", function(full_str,ui_path)
            local res = full_str
			if change_code_use_dicts[ui_path] then
                res = replace(res, ui_path, change_code_use_dicts[ui_path])
				show_log_func(format("%s文件检查到了有路径需要修改 原值是:%s, 转变为:%s",file_path, ui_path, change_code_use_dicts[ui_path]))
				if tmp_path_2_url and tmp_path_2_url[ui_path] then
					pic_url = tmp_path_2_url[ui_path]
				else
                    pic_url = _get_url_by_ui_path(ui_path)
                end
                change_dicts[pic_url] = true
            end
            return res
        end)

        if file_data ~= ori_data then
            writefile(file_path, file_data)
        end
    end


	local check_lua_dir = {} --加上要检测的lua dir 字符串列表
	for _,_dir in ipairs(check_lua_dir) do
        local tmp_path = lua_path_url .. "\\" .. _dir
        local all_file = get_all_file(tmp_path, "*.lua", true)

        local len = #all_file
        for i = 1, len do
            local code_path = all_file[i]
			__get_code_set_res(code_path)
        end
    end
	return change_dicts
end

local _trans_args = function(change_code_use_dicts)
    local tmp_tab = {}
    for url, url2 in pairs(change_code_use_dicts) do
        insert(tmp_tab, url)
        insert(tmp_tab, url2)
    end
    return table.concat(tmp_tab, "--") --有些符号在传到bat那里就会直接截断了，先试到这个可行
end


local _check_change_config = function(change_code_use_dicts, show_log_func, tmp_path_2_url)
	local change_dicts = {}
    local save_file = false
    local args = {}
    args[1] = "/c"
    args[2] = PluginPath .. "\\deal_excel.bat" --由于在xlua里没有比较方便读取xls文件的工具, 就这一部转而用py去处理
    args[3] = _trans_args(change_code_use_dicts)
    ProcessUtil.Start("cmd.exe", args, PluginPath, true)
    local file_path = PluginPath .. "\\change_cfg_use_log.txt"
    local file_data = readfile(file_path)
    if file_data then
        if file_data ~= "" then
            file_data = replace(file_data, "\r\n", "\n")
            local change_url_list = split(file_data, '\n')
            for _,path in ipairs(change_url_list) do
                if path ~= "" then
                    local pic_url = ""
                    show_log_func(format("配置检查到了替换, 原值是:%s, 转变为:%s",path, change_code_use_dicts[path]))
                    if tmp_path_2_url and tmp_path_2_url[path] then
                        pic_url = tmp_path_2_url[path]
                    else
                        pic_url = _get_url_by_ui_path(path)
                    end
                    change_dicts[pic_url] = true
                end
            end
        end
        if not save_file then
            IOUtil.DeleteFile(file_path, true)
        end
    else
        show_log_func("记录配置更替文件读取有问题，就不清点配置所更改到的配置了，可自行到同级目录下的 change_cfg_use_log.txt 文件查看变更path")
    end
    return change_dicts
end


local run_export = function(pkg_name,branch)
    local pkg = f_proj:GetPackageByName(pkg_name)
    if pkg then
        local handle = PublishHandler(pkg, branch)
        handle:Run()
    end
end


local _deal_repeats_dicts = function(need_deal_md5_dicts, show_info_func, tran_common_pkg_name)
    show_info_func = show_info_func or function(msg)
        tprint(msg)
    end
    local change_package = {} --记录变更的包，用于后面的导出

	local args_common_pkg = tran_common_pkg_name
	local change_pic_url_dicts = {}
	local change_code_use_dicts = {}
	local list_tips_index = 0
	local tmp_path_2_url = {} --先记录下路径对应的url，不然在操作资源的时候会先干掉pkg的部分image，导致后面找不到
	local branch_pkg_dict = {} --记录更改了分支的包名列表

    local ori_item_2_common_record = {}

    local save_del_item_list = {}
    for md5, item_list in pairs(need_deal_md5_dicts) do
        local code_use_list = {}  --list 的 代码引用格式 pkg/path/name
		local pic_url_list = {} --list 的 ui：xxxx..格式
		local code_use_dicts = {}
		local pic_url_dicts = {}
		local common_index = -1 --公共包所在的序号
		local list_index = -1
		list_tips_index = list_tips_index + 1
        tran_common_pkg_name = args_common_pkg
		for index,f_item in ipairs(item_list) do
            --ui://xxxxx
            local ui_url = _get_pic_url_by_fitem(f_item)
            insert(pic_url_list, ui_url)
            --pkg/path/name
            local ui_path = _get_pkg_path_part(f_item)
			insert(code_use_list, ui_path)
			tmp_path_2_url[ui_path] = ui_url
			local pkg = f_item.owner.name
            change_package[pkg] = true
            if common_pkg_def_dicts[pkg] then
                common_index = index
				tran_common_pkg_name = pkg
            end
        end
        show_info_func(format("第%s组重复图片是================:\n md5: %s",list_tips_index, md5))
        show_info_func("pic_url_list: ", pic_url_list)
        show_info_func("code_use_list: ", code_use_list)

        -- 制作 key:要替换的目标值  val：list：所有需要替换的原始值
		if common_index ~= -1 then
			local pic_url = remove(pic_url_list, common_index)
			pic_url_dicts[pic_url] = pic_url_list
			local code_use = remove(code_use_list, common_index)
			code_use_dicts[code_use] = code_use_list

			local common_image_item = item_list[common_index]
            show_info("这个common_image_item是要替换的主体", common_image_item.file)
            _set_f_item_exported({common_image_item}, true)
            
            local max_branch_item_lists = {} --用来保存要删除的item所拥有的分支items
			--移除掉其他图片
			for i, item in ipairs(item_list) do
                if i ~= common_index then
                    insert(save_del_item_list, item)
                    local branch_items = get_all_branch_items(item)
                    if #branch_items > #max_branch_item_lists then
                        max_branch_item_lists = branch_items
                    end
					--[[ local branch_pkg = _del_pkg_f_item_and_br(item)
					if branch_pkg then
						branch_pkg_dict[branch_pkg] = true
					end ]]
				end
            end
            
            if #max_branch_item_lists > 0 then
                --看看公共包是否需要这些分支包添加过去
                local branch_items = get_all_branch_items(common_image_item)
                if #branch_items < #max_branch_item_lists then
                    local is_find = false
                    for _,v in ipairs(max_branch_item_lists) do
                        is_find = false
                        for _,v2 in ipairs(branch_items) do
                            if v.branch == v2.branch then
                                is_find = true
                                break
                            end
                        end
                        if not is_find then
                            --移动到公共包中去
                            _move_res_inner(v, v.branch, common_image_item.path)
                        end
                    end
                end
            end
		else
			--要在指定公共包新建该图片
            --选取列表里中分支item最多的一个item出来用
            local max_branch_item_lists = {} --用来保存要删除的item所拥有的分支items
            local index = 1
            for i, item in ipairs(item_list) do
                local branch_items = get_all_branch_items(item)
               -- show_info("item, branch_items_num", item.file, "  ",#branch_items)
                if #branch_items > #max_branch_item_lists then
                    max_branch_item_lists = branch_items
                    index = i
                end
            end
            local ori_item = remove(item_list, index)
            local ori_url = _get_pic_url_by_fitem(ori_item)
            ori_item_2_common_record[ori_url] = true
            --因为这个item移到公共包之后，原先的就会找不到的了，因此这里先存一下，后面方便拿取id，pkg_id等
            temp_url_item_dicts[ori_url] = ori_item
            show_info("这个common_image_item移动到common包，是要替换的主体: ", ori_item.file)
            local common_item =  _move_res(ori_item)
            change_package[common_item.owner.name] = true --common_image_item-要把转图过去的公共包也加进去一起导出

			local pic_url_2 = _get_pic_url_by_fitem(common_item)
			pic_url_dicts[pic_url_2] = pic_url_list
			local ui_path = _get_pkg_path_part(common_item)
			code_use_dicts[ui_path] = code_use_list
			--移除掉其他图片
            for _, item in ipairs(item_list) do
                insert(save_del_item_list, item)
				--[[ local branch_pkg = _del_pkg_f_item_and_br(item)
				if branch_pkg then
					branch_pkg_dict[branch_pkg] = true
				end ]]
			end
		end

		for key, url_list in pairs(pic_url_dicts) do
			for _,url in ipairs(url_list) do
				change_pic_url_dicts[url] = key
			end
		end

		for url, code_list in pairs(code_use_dicts) do
			for _,code_url in ipairs(code_list) do
				change_code_use_dicts[code_url] = url
			end
		end
    end

	show_info_func(format("=======================资源引用的替换开始"))
    local pkg_change, has_change_dicts = _change_pic_url_list(change_pic_url_dicts, show_info_func)
    show_info_func(format("=======================资源引用的替换结束"))

    local len = #save_del_item_list
    show_info_func(format("文件增删操作开始（包括分支================"))
    if len > 0 then
        for i = len, 1, -1 do
            show_info_func(format("删除文件路径: %s", save_del_item_list[i].file))
            local branch_pkg = _del_pkg_f_item_and_br(save_del_item_list[i])
			if branch_pkg then
				branch_pkg_dict[branch_pkg] = true
			end
        end
    end

    show_info_func(format("文件增删操作完成（包括分支================, 总共操作文件数有： %s", len))

	App.RefreshProject()
	local len_ori_need_dicts = size(change_pic_url_dicts)
	local len_change_ui_dicts = size(has_change_dicts)
	show_info_func(format("需要改变的数量:%s", len_ori_need_dicts))
	show_info_func(format("ui里引用已改变的数量:%s",len_change_ui_dicts))
	for pkg in pairs(pkg_change) do
		change_package[pkg] = true
	end
	show_info_func(format("=======================已完成资源引用的替换"))

	show_info_func("=======================开始检查代码是否需要更改路径")
    lua_code_path = ""
	local change_code_dicts = _check_change_code(change_code_use_dicts, lua_code_path, show_info_func, tmp_path_2_url)
	local len_change_code_dicts = size(change_code_dicts)
	--len_reset_dicts = len_reset_dicts - len_change_code_dicts
	show_info_func(format("代码里引用改变的数量:%s", len_change_code_dicts))
	show_info_func(format("=======================已完成代码检查的替换"))

	show_info_func("=======================开始检查配置是否需要更改路径")
	local change_config_dicts = _check_change_config(change_code_use_dicts, show_info_func, tmp_path_2_url)
	local len_change_config_dicts = size(change_config_dicts)
	--len_reset_dicts = len_reset_dicts - len_change_config_dicts
	show_info_func(format("配置里引用改变的数量:%s", len_change_config_dicts))

    for url in pairs(change_config_dicts) do
        has_change_dicts[url] = true
    end

	for url in pairs(change_code_dicts) do
        has_change_dicts[url] = true
    end


	for url in pairs(change_pic_url_dicts) do
        if not has_change_dicts[url] and not ori_item_2_common_record[url] then
            show_info_func(format("该url：%s 没有在ui里改变引用，看看是啥", url))
        end
    end

    for url in pairs(has_change_dicts) do
        if not change_pic_url_dicts[url] then
            show_info_func(format("该url：%s 怎么还没有在需要的更改列表中，看看是啥", url))
        end
    end


    local __inner = function(pkg_dicts)
        local res = {}
        for pkg in pairs(pkg_dicts) do
            insert(res, pkg)
        end
        return table.concat(res, ",")
    end

	local all_pkg_str = __inner(change_package)
	show_info_func(format("本次操作涉及到的pkg有:\n%s\n并进行导出操作", all_pkg_str))
	local all_branch_pkg_str = __inner(branch_pkg_dict)
	show_info_func(format("本次操作涉及到的分支pkg有:\n%s",all_branch_pkg_str))

    for pkg_name in pairs(change_package) do
        run_export(pkg_name, "")
    end
end


local run = function()
    f_proj = App.project
    local all_pkg = f_proj.allPackages
    local all_md5_dicts = {}
    local need_deal_md5_dicts = {}
    for _,pkg in pairs(all_pkg) do
        local pkg_md5_dict = _get_pkg_img_md5_fpkgitem_dicts(pkg)
		for md5, f_pkgitem in pairs(pkg_md5_dict) do
            all_md5_dicts[md5] = all_md5_dicts[md5] or {}
            insert(all_md5_dicts[md5], f_pkgitem)
        end
    end
    show_info("需要处理的重复列表有：")
    for md5, item_list in pairs(all_md5_dicts) do
        --show_info(format("md5 : %s #item_list : %s", md5, #item_list))
		if #item_list >= repeats_times then
            need_deal_md5_dicts[md5] = item_list
        end
	end
    if next(need_deal_md5_dicts) then
        _deal_repeats_dicts(need_deal_md5_dicts, show_info, common_pkg_name)
    end
    show_info("==================检查完毕")
    if write_file_handle then
        write_file_handle:close()
        write_file_handle = false
    end
end

local main = function()
    Confirm("怕你误点到了，真的要进行资源查重?", function(args)
        if args == "yes" then
            run()
        end
    end)
end


local toolMenu = App.menu:GetSubMenu("custom_tool")
if toolMenu then
    toolMenu:AddItem("一键资源查重","check_res_repeat",function()
        main()
    end);
end

function onDestroy()
-------do cleanup here-------
end
--FYI: https://github.com/Tencent/xLua/blob/master/Assets/XLua/Doc/XLua_Tutorial_EN.md
local extend = require(PluginPath ..'/../extend') --require(PluginPath..'/extend')
local ProcessUtil = CS.FairyEditor.ProcessUtil
local Confirm = CS.FairyEditor.App.Confirm

local tprint = function(...)
    fprint(extend.pretty_str(...))
end
_G.tprint = tprint
local alert = CS.FairyEditor.App.Alert
local insert = table.insert
local remove = table.remove
local format = string.format
local readfile = extend.Io.readfile
local hasfile = extend.Io.hasfile
local sfind = string.find
local sgsub = string.gsub

local nice_str = "(￣▽￣)~*"
local bad_str = "눈_눈"

local _get_check_str_dict = function(pkg_item)
    local res = {}
    local src_str = format('src=\"%s\"', pkg_item.id)
    local url_str = format('url=\"%s\"', pkg_item:GetURL())
    res[src_str] = true
    res[url_str] = true
    return res
end

local _check_url_is_same = function(url1,url2)
    local _inner_trans = function(url)
        return sgsub(url,"/","\\")
    end
    return _inner_trans(url1) == _inner_trans(url2)
end


local remove_single = function(pkg, direct_deal)
    tprint(pkg.name)
    local items = pkg.items

    local res_items = {}
    local comp_items = {}

    for _, v in pairs(items) do
        if v.type == "image" and not v.exported then
            res_items[v.branch] = res_items[v.branch] or {}
            insert(res_items[v.branch], v)
        end
        if v.type == "component" then
            insert(comp_items, v)
        end
    end

    local items_master = res_items[""]
    res_items[""] = nil
    local item_checks = {}
    for _,v in ipairs(items_master) do
        insert(item_checks ,{check_dict = _get_check_str_dict(v), item = v})
    end
    for _,v in ipairs(comp_items) do
        local file = v.file
        local file_data = readfile(file)
        if file_data then
            local count = #item_checks
            for index = count , 1, -1 do
                local checks = item_checks[index]
                local has_check = false
                for check_str in pairs(checks.check_dict) do
                    if sfind(file_data, check_str) then
                        --tprint( v.name, "找到了", check_str)
                        has_check = true
                        break
                    end
                end
                if has_check then
                    remove(item_checks, index)
                end
                if not next(item_checks) then
                    break
                end
            end
        else
            tprint("error", "读取不到该文件:", file)
        end
        if not next(item_checks) then
            break
        end
    end

    local _check_is_in_del = function(path)
        for _,v in ipairs(item_checks) do
            if _check_url_is_same(v.item.file, path) then
                return true
            end
        end
    end

    local del_items_list = {}
    for _,v in ipairs(item_checks) do
        insert(del_items_list,v)
    end
    --分支的图片 只要在主干同路径下没有则可以视为没有卵用的了
    for _,v in pairs(res_items) do
        for _, item in pairs(v) do
            local master_file = sgsub(item.file,format("assets_%s",item.branch),"assets",1)
            --tprint("find master_file: ", master_file)
            if hasfile(master_file) then
                if _check_is_in_del(master_file) then
                    insert(del_items_list,{item = item})
                end
            else
                insert(del_items_list,{item = item})
            end
        end
    end

    if direct_deal then
        if next(del_items_list) then
            local str = bad_str .. " 检测到以下资源没有进行使用，进行确认是否将其删除:\n"
            for _,v in ipairs(del_items_list) do
                str = str ..  format("%s%s%s\n", pkg.name, v.item.path, v.item.fileName)
            end
            Confirm(str, function(args)
                if args == "yes" then
                    for _,v in ipairs(del_items_list) do
                        pkg:DeleteItem(v.item)
                        tprint(format("删除了：%s%s%s", pkg.name, v.item.path, v.item.fileName))
                    end
                end
            end)
        else
            alert(pkg.name .. " 没有需要删除的资源" .. nice_str)
        end
    else
        return del_items_list
    end
end

local remove_all = function()
    local allPackages = App.project.allPackages
    local all_del_items_list = {}
    for _, pkg in pairs(allPackages) do
        local del_items_list = remove_single(pkg)
        if next(del_items_list) then
            insert(all_del_items_list, {pkg = pkg, del_item_list = del_items_list})
        end
    end

    if next(all_del_items_list) then
        local str = bad_str .. " 检测到以下资源没有进行使用，进行确认是否将其删除:\n"
        for _,v in ipairs(all_del_items_list) do
            str = str .. "========" .. v.pkg.name .. "\n"
            for _,v2 in ipairs(v.del_item_list) do
                str = str ..  format("%s%s%s\n", v.pkg.name, v2.item.path, v2.item.fileName)
            end
        end
        Confirm(str, function(args)
            if args == "yes" then
                for _,v in ipairs(all_del_items_list) do
                    for _,v2 in ipairs(v.del_item_list) do
                        str = str ..  format("%s%s%s\n", v.pkg.name, v2.item.path, v2.item.fileName)
                        v.pkg:DeleteItem(v2.item)
                        tprint(format("删除了：%s%s%s", v.pkg.name, v2.item.path, v2.item.fileName))
                    end
                end
            end
        end)
    else
        alert("没有需要删除的资源" .. nice_str)
    end
end


local function main(is_all)
    if not is_all then
        local f_pkg_item = App.libView:GetSelectedResource()
        local pkg = f_pkg_item.owner
        remove_single(pkg, true)
    else
        remove_all()
    end
end



local toolMenu = App.menu:GetSubMenu("custom_tool")
if toolMenu then
    toolMenu:AddItem("清除当前选中包无用资源","remove_unuse_res",function()
        main()
    end);
    toolMenu:AddItem("清除全部包的无用资源","remove_unuse_res_all",function()
        main(true)
    end);
end



function onDestroy()
    --入口会统一移除，这里就不用再移除了
end
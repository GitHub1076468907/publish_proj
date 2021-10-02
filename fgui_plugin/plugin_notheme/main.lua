--FYI: https://github.com/Tencent/xLua/blob/master/Assets/XLua/Doc/XLua_Tutorial_EN.md
local format = string.format

local _create_new_comp_template = function(name)
    local path = format("ui://Common/%s",name)
    local tar_item = App.project:GetItemByURL(path)
    local cur_pkg = App.libView:GetSelectedResource().owner
    if tar_item then
        local cur_item = cur_pkg:DuplicateItem(tar_item, name)
        cur_item.exported = true
    end
end



local contextMenu = App.libView.contextMenu
contextMenu:AddItem("新增全屏窗口模板组件","win_templ_full",1, false,function()
    _create_new_comp_template("TemplateFullWin")
end);
contextMenu:AddItem("新增窗口模板组件","win_templ",1, false,function()
    _create_new_comp_template("TemplateWin")
end);

function onDestroy()
-------do cleanup here-------
    contextMenu:RemoveItem("win_templ_full")
    contextMenu:RemoveItem("win_templ")
end
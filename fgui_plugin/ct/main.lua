
App.menu:AddItem("自定义工具","custom_tool",-1,true,function(string)
end);

-------do cleanup here-------

function onDestroy()
    App.menu:RemoveItem("custom_tool")
end
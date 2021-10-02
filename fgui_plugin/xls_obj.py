import os
try:
    import xlwt
except :
    os.system('pip install xlwt')
    import xlwt
try:
    import xlrd
except :
    os.system('pip install xlrd')
    import xlrd


# data = {
#     "Key":"日程帮助",
#     "CHS":"xxxxxxx",
#     "EN":"xxxxxx",
#      ...
# }
# sheet_data = {
#     "name":"Sheet1",
#     "nrows":10,
#     "header_dict":{
#         "Key":{
#             "name":"Key",
#             "col_index":0
#         },
#         ...
#     }
#     "data_list":[]
# }


class XlsObj:
    def __init__(self, path):
        self.__path = path
        self.__sheet_data_list = []
        self.__key2data = {}
        self.__key2sheet_index = {}
        self.__isexists = os.path.exists(path)
        if self.__isexists:
            self.__load_xls()
        else:
            self.__load_empty()

    def __get_data_list(self, sheet_index):
        sheet_data = self.__sheet_data_list[sheet_index]
        return sheet_data["data_list"]

    def __add_data(self, key, sheet_index, data):
        data_list = self.__get_data_list(sheet_index)
        index = len(data_list)
        data_list.insert(index, data)
        self.__key2sheet_index[key] = sheet_index
        self.__key2data[key] = data

    def __remove_data(self, key):
        if key not in self.__key2data:
            return
        data = self.__key2data[key]
        sheet_index = self.__key2sheet_index[key]
        data_list = self.__get_data_list(sheet_index)
        data_list.remove(data)
        del self.__key2data[key]
        del self.__key2sheet_index[key]

    def __get_data(self, key):
        data = self.__key2data[key]
        return data

    def __load_empty(self):
        header_dict = {
            "Key":{"name":"Key", "col_index":0},
            "CHS":{"name":"CHS", "col_index":1},
            "EN":{"name":"EN", "col_index":2},
        }
        sheet_data = {"name":"Sheet1", "header_dict":header_dict, "data_list":[]}
        self.__sheet_data_list.append(sheet_data)

    def __trans_type_val(self, type_def, val):
        if type_def.startswith("bool"):
            #bool类型在读取出的时候会是1，在这里定义下类型进行转换
            val = val == 1 and "TRUE" or val
        return val

    def __load_xls(self):
        path = self.__path
        workbook = xlrd.open_workbook(filename=path, formatting_info=True)
        sheet_name_list = workbook.sheet_names()
        for sheet_index in range(0, len(sheet_name_list)):
            sheet_name = sheet_name_list[sheet_index]
            sheet = workbook.sheet_by_name(sheet_name)
            if sheet.nrows == 0:
                continue
            ##header
            header_dict = {}
            header_type_list = []
            header_name_list = sheet.row_values(1)
            type_tmp_list = sheet.row_values(0)
            for i in range(0, len(header_name_list)):
                name = header_name_list[i]
                header_dict[name] = {"name":name, "col_index":i}
            for i in range(0, len(type_tmp_list)):
                name = type_tmp_list[i]
                header_type_list.append(name)
            sheet_data = {"name":sheet_name, "header_dict":header_dict, "data_list":[], "header_type_list":header_type_list}
            self.__sheet_data_list.append(sheet_data)
            ##content
            for row_index in range(2, sheet.nrows):
                data = {}
                key = ""
                for k, header in header_dict.items():
                    cell = sheet.cell(row_index, header["col_index"])
                    data[k] = cell.value
                    if header["col_index"] == 0:
                        data[k] = cell.value
                        data[header["name"]] = cell.value
                        key = cell.value
                    else:
                        data[k] = self.__trans_type_val(header_type_list[header["col_index"]] ,cell.value)
                self.__add_data(key, sheet_index, data)

    def __make_xls_style(self):
        font = xlwt.Font()
        font.name = "微软雅黑"
        #字体大小，n为字号，20为衡量单位
        font.height = 12 * 20

        style = xlwt.XFStyle()
        style.font = font
        return style

    def save(self):
        print("Save Xls", self.__path)
        workbook = xlwt.Workbook(encoding="utf-8")
        style = self.__make_xls_style()
        ##create sheet and header
        for sheet_data in self.__sheet_data_list:
            sheet = workbook.add_sheet(sheet_data["name"])
            header_dict = sheet_data["header_dict"]
            for _, header in header_dict.items():
                col_index = header["col_index"]
                if not self.__isexists:
                    if header["name"] == "Key":
                        sheet.write(0, col_index, "string#key", style)
                    else:
                        if header["name"] == "CHS":
                            sheet.write(0, col_index, "string", style)
                        else:
                            sheet.write(0, col_index, "string#defaultnil", style)
                else:
                    type_list = sheet_data["header_type_list"]
                    sheet.write(0, col_index, type_list[col_index], style)
                # 设置列宽，一个中文等于两个英文等于两个字符，n为字符数，256为衡量单位
                cell_size = col_index == 0 and 30 or 120
                sheet.col(col_index).width = cell_size * 256
                sheet.write(1, col_index, header["name"], style)
            data_list = sheet_data["data_list"]
            ##content
            for i in range(0, len(data_list)):
                data = data_list[i]
                row_index = i + 2 ##前两行是文件头
                for k, v in data.items():
                    header = header_dict[k]
                    sheet.write(row_index, header["col_index"], v, style)

        workbook.save(self.__path)

    def exist_data(self, key):
        return key in self.__key2data

    def add_data(self, key):
        data = {}
        sheet_index = 0
        sheet_data = self.__sheet_data_list[sheet_index]
        header_dict = sheet_data["header_dict"]
        tab_key = ""
        for k in header_dict:
            data[k] = ""
            if header_dict[k]["col_index"] == sheet_index:
                tab_key = header_dict[k]["name"]
        data[tab_key] = key
        self.__add_data(key, sheet_index, data)
        #print("add {}".format(key))

    def modify_data_value(self, key, value_key, value):
        data = self.__get_data(key)
        data[value_key] = value
        #print("write {} {} {}".format(key, value_key, value))

    def get_data_value(self, key, value_key):
        data = self.__get_data(key)
        if value_key in data:
            return data[value_key]

    def delete_datas(self, key_list):
        for key in key_list:
            print("delete {}".format(key))
            self.__remove_data(key)

    def get_all_keys(self):
        list = []
        for sheet_data in self.__sheet_data_list:
            header_dict = sheet_data["header_dict"]
            tab_key = ""
            for k in header_dict:
                if header_dict[k]["col_index"] == 0:
                    tab_key = header_dict[k]["name"]
                    break
            for data in sheet_data["data_list"]:
                list.append(data[tab_key])

        return list


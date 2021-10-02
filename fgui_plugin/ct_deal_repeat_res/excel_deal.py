import os, sys
import json
import math
import argparse
import subprocess
import time
sys.path.append(os.path.join(os.path.dirname(__file__), '../'))#为了引用下面的xls_obj.py文件
from xls_obj import XlsObj
from write_file import FileDeal


def deal_args(_args):
    dict = {}
    args = _args.args
    all_args = args.split("--")
    num = 1
    for str in all_args:
        if num % 2 == 1:
            dict[all_args[num-1]] = all_args[num]
        num = num + 1
    _args.args = dict

def check_run(args):
    arg_tmp = args.args
    if arg_tmp != None and arg_tmp != "" :
        deal_args(args)
        return True


def main(args):
    change_code_use_dicts = args.args
    change_dicts = {}
    cp = os.path.dirname(os.path.abspath(__file__))
    ui_xml_file = os.path.abspath(cp + "/excel") #更改为自己项目中的excel目录
    writer = None
    if args.nolog == None:
        writer = FileDeal("change_cfg_use_log.txt", "w")
    obj = None
    check_xml_list = {} #需要检测的项 k:表格名 v页名 比如:"资源表.xls":"路径"
    has_write = False
    for xls in check_xml_list:
        xls_path = ui_xml_file + "\\" + xls
        has_change = False
        if os.path.exists(xls_path):
            obj = XlsObj(xls_path)
            xls_all_keys = obj.get_all_keys()
            for xls_key in xls_all_keys:
                val = obj.get_data_value(xls_key, check_xml_list[xls])
                if val in change_code_use_dicts:
                    has_change = True
                    has_write = True 
                    obj.modify_data_value(xls_key, check_xml_list[xls], change_code_use_dicts[val])
                    if writer!=None:
                        writer.writeLine(val)
        else:
            print(xls_path + " 不存在该文件")
        if has_change and obj != None:
            obj.save()
    if has_write and writer != None:
        writer.save()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='fgui插件合并重复资源的配置修改用该py脚本来处理')
    parser.add_argument("-a",  "--args", help="将bat传入的需要替换的资源配置")
    parser.add_argument("-nl", "--nolog", help="不需要生成log文件")
    args = parser.parse_args()
    if check_run(args):
        main(args)
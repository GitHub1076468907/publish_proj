#图片切割
import subprocess
import shutil
import os
import math
def run(cmd):
    subprocess.run(cmd, shell=True).check_returncode()

try:
	import cv2 
except :
	run("pip install opencv-python")
	import cv2

import numpy as np 

try:
	from matplotlib import pyplot as plt 
except :
	run("pip3 install matplotlib")
	from matplotlib import pyplot as plt

output_symmetry_dir = "pic/symmetry_cut"
output_rectangle_dir = "pic/rectangle_cut"
output_fin_dir = "pic/fin_cut"
if os.path.exists(output_symmetry_dir):
	shutil.rmtree(output_symmetry_dir)
os.makedirs(output_symmetry_dir)
if os.path.exists(output_fin_dir):
	shutil.rmtree(output_fin_dir)
os.makedirs(output_fin_dir)
if os.path.exists(output_rectangle_dir):
	shutil.rmtree(output_rectangle_dir)
os.makedirs(output_rectangle_dir)

join_symmetry_pixel_min = 50 #图片大小的像素要有这个阈值以上才进行取对称区域
duplicate_area = 30 #判断颜色像素相似的像素范围最低阈值
cut_save_pixel_num = 3 #切割时保留重复的像素范围值


DIR_H = 1 #水平方向
DIR_V = 2 #垂直方向
DIR_H_COLOR = (0, 0, 255,255)
DIR_V_COLOR = (0,255,0,255)
FIN_CUT_COLOR = (255,0,0,255)

###################判断像素相似程度函数
color_distance_limit = 150 #不知道alpha的计算，先不用
def color_distance(rgb_1, rgb_2):
     B_1,G_1,R_1 = rgb_1
     B_2,G_2,R_2 = rgb_2
     rmean = (R_1 + R_2 ) / 2
     R = R_1 - R_2
     G = G_1 - G_2
     B = B_1 - B_2
     return math.sqrt((2+rmean/256)*(R**2)+4*(G**2)+(2+(255-rmean)/256)*(B**2)) < color_distance_limit

color_distance_2_limit = 150 #判断颜色是否相似的最高阈值，超过就认为两个颜色不相似
def color_distance_2_val(rgb_1, rgb_2, alpha_args = None):
	B_1,G_1,R_1 = rgb_1[0], rgb_1[1], rgb_1[2]
	B_2,G_2,R_2 = rgb_2[0], rgb_2[1], rgb_2[2]
	A_1, A_2 = None, None
	if len(rgb_1) > 3:
		A_1 = rgb_1[3]
	if len(rgb_2) > 3:
		A_2 = rgb_2[3]
	if alpha_args == None:
		alpha_args = 0.2
	if A_1 == 0 and A_2 == 0:
		return 0
	absR = (int(R_1) - int(R_2))
	absG = (int(G_1) - int(G_2))
	absB = (int(B_1) - int(B_2))
	if A_1 is None or A_2 is None:
		absA = 0
	else:
		absA = int(A_1) - int(A_2)
	return absR * absR * 0.299 + absG * absG * 0.587 + absB * absB * 0.114 + absA * absA * alpha_args

def color_distance_2(rgb_1, rgb_2):
	val = color_distance_2_val(rgb_1, rgb_2)
	res = val <= color_distance_2_limit
	# if not res:
	# 	print("color_distance_2 fail", rgb_1, rgb_2, val, res)
	return res

def get_max_distance_val(base_rgb, rgb1, rgb2):
	val1 = color_distance_2_val(base_rgb, rgb1)
	val2 = color_distance_2_val(base_rgb, rgb2)
	#print("val1,val2", val1,val2)
	if val1 >= val2:
		return rgb1
	else:
		return rgb2
###################


def write_img(output_dir, name, img):
	path = output_dir + '/' + name + '.png'
	print("write_img:", path)
	#print(img.shape)
	cv2.imwrite(path, img) #path文件夹不存在的话不会报错，所以要自己先创建好放置文件夹

def get_file_name_by_path(path):
	name = os.path.basename(path)
	return name.split(".")[0]


def check_same_img(img1,img2):
	return check_same_by_pixle_val(img1, img2)

def check_same_by_sub(img1, img2):
	# img1 = img1[0:3]
	# img2 = img2[0:3]
	difference = cv2.subtract(img1, img2)
	result = not np.any(difference)
	return result

#val1 要包含四个通道的值
def check_pixel_same(val1, val2, calc_tab = None):
	#return ((val1 == val2).all() or (val1[3] == 0 and val2[3] == 0))
	if calc_tab != None:
		res_dis = color_distance_2(val1, calc_tab["pixel"])
		res_dis_max = color_distance_2(val1, calc_tab["maxdis_pixel"])
		return res_dis and res_dis_max
	else:
		return color_distance_2(val1, val2)


def check_same_by_pixle_val(img1,img2):
	n = 0
	height, width, _ = img1.shape 
	for line in range(height):
		for pixel in range(width):
			img_val = img1[line][pixel]#[0:3]
			img2_val = img2[line][pixel]#[0:3]
			if (img_val != img2_val).any(): #check_pixel_same(img_val, img2_val):
				if color_distance_2_val(img_val, img2_val, alpha_args = 0.01) > 10:
					return False
	return True


def check_img_same(img1,img2, reverse_val, save_name):
	#图片对称的判断相同要反过来的，因为是中间对称
	if reverse_val != None: 
		img2 = cv2.flip(img2,reverse_val) #reverse_val 0:x轴翻转 >0:y轴翻转 <0: xy同时翻转
	result = check_same_img(img1, img2)
	if result:
		return True, img1
	return None, None

def get_middle_val(val):
	res = math.floor(val/2)
	if res == 0:
		return res + 1
	else:
		return res

#检查图片对称,对称的话先切成一半
def check_pic_symmetry(img, save_name):
	shape = img.shape
	height = shape[0]
	width = shape[1]
	res = None
	if height >= join_symmetry_pixel_min or width >= join_symmetry_pixel_min:
		middle_x, middle_y = get_middle_val(width), get_middle_val(height)
		#print(shape, middle_x, middle_y)
		if width >= 2:
			#左右对称
			left_img = img[0:height , 0:middle_x]
			right_img = img[0:height , middle_x:width]
			res, new_img = check_img_same(left_img, right_img, 1,save_name)
		#上下对称
		if res == None:
			#print("尝试试下上下对称的")
			if height >= 2:
				top_img = img[0:middle_y , 0:width]
				down_img = img[middle_y:height , 0:width]
				res, new_img = check_img_same(top_img, down_img, 0, save_name)
	if res != None:
		write_img(output_symmetry_dir, save_name, new_img)
		return new_img
	else:
		write_img(output_symmetry_dir, save_name, img)
		return img


def __new_tab(list, min_key, max_key):
	tab = {"pixel":(0,0,0), "maxdis_pixel":(0,0,0)}
	tab[min_key] = -1
	tab[max_key] = -1
	list.append(tab)

def __print_dict(dict):
	#print(dict)
	for key in dict:
		print(str(key) + " : ")
		print(dict[key])


def __filter(dict, minkey, maxkey):
	for k in dict:
		list = dict[k]
		list_len = len(list)
		for i in range(list_len-1, -1, -1): 
			info = list[i]
			if (info[maxkey] - info[minkey]) < duplicate_area:
				list.pop(i)

#list xmin, xmax, ymin, ymax
def __filter2(list, is_horizontal):
	list_len = len(list)
	for i in range(list_len-1, -1, -1): 
		info = list[i]
		need_pop = False
		if is_horizontal:
			need_pop = (info[1] - info[0]) < duplicate_area
		else:
			need_pop = (info[3] - info[2]) < duplicate_area
		if need_pop:
			list.pop(i)

def get_pic_duplicate_info(img, dir):
	info_dict = {}
	height, width, _ = img.shape

	def __inner_common(cur_val, pre_val, index, cur_index, min_key, max_key):
		#RGBA 都一样 或者 A都一样为0透明的，都算一样的

		#1.pre_val不能直接拿上一个像素的值来算，因为如果每个像素之间我们会允许一定颜色差的话，随着一直渐变，可能首尾会有很大的颜色差了
		#2.还要和之前通过的最大距离点进行计算，如果和这个也相差太大也去除掉
		calc_tab = None
		if index in info_dict:
			if len(info_dict[index]) > 0:
				last_tab = info_dict[index][len(info_dict[index]) - 1]
				if last_tab[min_key] != -1:
					calc_tab = last_tab
					#pre_val = last_tab["pixel"]
					#print("用了缓存的像素值来计算了", pre_val)
		if check_pixel_same(cur_val, pre_val, calc_tab):
			if not index in info_dict:
				info_dict[index] = []
				__new_tab(info_dict[index], min_key, max_key)
			last_tab = info_dict[index][len(info_dict[index]) - 1]
			if last_tab[min_key] == -1:
				last_tab[min_key] = cur_index - 1
				last_tab[max_key] = cur_index
				last_tab["pixel"] = pre_val
				last_tab["maxdis_pixel"] = pre_val
			else:
				last_tab["maxdis_pixel"] = get_max_distance_val(last_tab["pixel"], last_tab["maxdis_pixel"], pre_val)
				if last_tab[max_key] == cur_index - 1:
					last_tab[max_key] = cur_index
				else:
					print("注意了，怎么加的像素值上一个值和max的值记录不一样")
		else:
			if not index in info_dict:
				info_dict[index] = []
				__new_tab(info_dict[index], min_key, max_key)
			last_tab = info_dict[index][len(info_dict[index]) - 1]
			if last_tab[min_key] != -1:
				__new_tab(info_dict[index], min_key, max_key)

	if dir == DIR_H:
		for line in range(height):
			for pixel in range(width):
				cur_val = img[line][pixel]#[0:3] (BGRA这样的顺序)
				if pixel > 0:
					pre_val = img[line][pixel - 1]#[0:3]
					__inner_common(cur_val, pre_val, line, pixel,"xmin", "xmax")
		__filter(info_dict, "xmin", "xmax")
	elif dir == DIR_V:
		for pixel in range(width):
			for line in range(height):
				cur_val = img[line][pixel]#[0:3] (BGRA这样的顺序)
				if line > 0:
					pre_val = img[line - 1][pixel]#[0:3]
					__inner_common(cur_val, pre_val, pixel, line, "ymin", "ymax")
		__filter(info_dict, "ymin", "ymax")
	return info_dict


def get_max_duplicate_area(info, minkey, maxkey, is_horizontal):
	def __new_rect_list(list, xmin = 0, xmax = 0, ymin = 0, ymax = 0):
		new_list = [xmin, xmax, ymin, ymax]
		list.append(new_list)
		return new_list#xmin, xmax, ymin, ymax

	#获取交集tab
	def __inner_get_tntersection(list, check_dict_info, cur_index):
		res_list = []
		for dat in check_dict_info:
			if is_horizontal:
				if dat["xmax"] > list[0] and dat["xmin"] < list[1]:
					__new_rect_list(res_list, max(list[0], dat["xmin"]), min(list[1], dat["xmax"]), list[2], cur_index)
			else:
				if dat["ymax"] > list[2] and dat["ymin"] < list[3]:
					__new_rect_list(res_list, list[0], cur_index, max(list[2], dat["ymin"]), min(list[3], dat["ymax"]))
		return res_list

	all_rect_dict = []
	dict_len = len(info)
	for index in range(dict_len):
		dats = info[index]
		dats_len = len(dats)
		if is_horizontal: 
			if index == 0:
				for dats_index in range(dats_len):
					dat = dats[dats_index]
					__new_rect_list(all_rect_dict, dat["xmin"], dat["xmax"], 0, 0)
			else:
				do_res = []
				for rect_list in all_rect_dict:
					res = __inner_get_tntersection(rect_list, dats, index)
					do_res = do_res + res
				all_rect_dict = do_res
		else:
			if index == 0:
				for dats_index in range(dats_len):
					dat = dats[dats_index]
					__new_rect_list(all_rect_dict, 0, 0, dat["ymin"], dat["ymax"])
			else:
				do_res = []
				for rect_list in all_rect_dict:
					res = __inner_get_tntersection(rect_list, dats, index)
					do_res = do_res + res
				all_rect_dict = do_res

	__filter2(all_rect_dict, is_horizontal)
	return all_rect_dict


def get_max_area_info(info, dir):
	big_one = None
	check_min, check_max = 0, 1
	if dir == DIR_V:
		check_min, check_max = 2, 3
	def __inner_get_offset(val1):
		return  val1[check_max] - val1[check_min]

	for area_info in info:
		if big_one != None:
			if __inner_get_offset(big_one) < __inner_get_offset(area_info):
				big_one = area_info
		else:
			big_one = area_info
	return big_one

# h_areas [[86, 122, 0, 231],  xmin xmax ymin ymax
# v_areas [[0, 276, 75, 140]]
# 取得类似上面数据的两个范围交集
def get_overlapping(h_area, v_area):
	if h_area == None:
		return v_area
	if v_area == None:
		return h_area
	return [max(h_area[0], v_area[0]), min(h_area[1], v_area[1]), max(h_area[2], v_area[2]), min(h_area[3], v_area[3])]


#处理图片重复区域，并寻找适合进行九宫切割的
def check_pic_duplicate(img, name):
	print("check_pic_duplicate 遍历图片获取左右上下方向的像素重复区域...", name)
	# 找出左右方向一样的区域
	h_info_dict = get_pic_duplicate_info(img, DIR_H)
	# 找出上下方向一样的区域
	v_info_dict = get_pic_duplicate_info(img, DIR_V)
	__print_dict(h_info_dict)
	#print("=====================华丽分割线=======================")
	__print_dict(v_info_dict)
	h_areas = get_max_duplicate_area(h_info_dict, "xmin", "xmax", True)
	v_areas = get_max_duplicate_area(v_info_dict, "ymin", "ymax", False)
	print("x方向重复区域信息：", h_areas)
	print("y方向重复区域信息：", v_areas)
	rect_image = img.copy()
	for h_area in h_areas:
		get_area_rectangle(rect_image, h_area[0], h_area[1], h_area[2], h_area[3], DIR_H_COLOR)
	for v_area in v_areas:
		get_area_rectangle(rect_image, v_area[0], v_area[1], v_area[2], v_area[3], DIR_V_COLOR)
	write_img(output_rectangle_dir, name + "_rectangle", rect_image)

	#仅进行面积大的去进行切除
	h_big_area = get_max_area_info(h_areas, DIR_H)
	v_big_area = get_max_area_info(v_areas, DIR_V)

	fin_area = get_overlapping(h_big_area, v_big_area)
	print("最后要进行切除去掉的重复区域是(xmin, xmax, ymin, ymax)： ", fin_area)
	if fin_area != None:
		get_area_rectangle(rect_image, fin_area[0], fin_area[1], fin_area[2], fin_area[3], FIN_CUT_COLOR)
		write_img(output_rectangle_dir, name + "_rectangle_fin", rect_image)
		cut_fin_pic(img, fin_area, name)

def cut_fin_pic(img, fin_area, name):
	#TODO 看看要不要取重复区域的平均颜色值来填充，现在直接拿范围里的第一个像素直接填充吧
	height,width, _ = img.shape
	#[86, 122, 75, 140]  [0, 11, 0, 610]

	#xy 分开两次隔开处理
	xmin, xmax, ymin, ymax = fin_area
	if (xmax - xmin) + 1 < width:
		lef_tmp_img = img[0 : height, 0 : xmin + cut_save_pixel_num]
		right_tmp_img = img[0 : height, xmax : width]
		if lef_tmp_img is None or right_tmp_img is None:
			img = lef_tmp_img or right_tmp_img
		else:
			img = cv2.hconcat([lef_tmp_img, right_tmp_img])

	if (ymax - ymin) + 1 < height:
		up_tmp_img = img[0 : ymin, 0 : width]
		down_tmp_img = img[ymax - cut_save_pixel_num : height, 0 : width]
		if up_tmp_img is None or down_tmp_img is None:
			img = up_tmp_img or down_tmp_img
		else:
			img = cv2.vconcat([up_tmp_img, down_tmp_img])


	write_img(output_fin_dir, name, img)

def get_area_rectangle(img, xmin, xmax, ymin, ymax, color):
	#(0, 0), (200, 100)
	#(0, 0, 255), 2  方框颜色和方框宽度
	cv2.rectangle(img, (xmin, ymin), (xmax, ymax), color, 1)  

def pic(path):
	img = cv2.imread(path, cv2.IMREAD_UNCHANGED)
	name = get_file_name_by_path(path)
	print("deal pic :", path)
	#处理对称
	print("判断图片是否可以对称切半处理 :", path)
	img_part2 = check_pic_symmetry(img,name)
	#处理适用于九宫重复区域去除
	check_pic_duplicate(img_part2, name)


for filename in os.listdir("pic"):
	path = os.path.join("pic",filename)
	if not os.path.isdir(path):
		pic(path)
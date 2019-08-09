## 角色基础信息
.Player
{
    # 资源数据结构
    .resource
    {
        category            1  : integer            # 资源类型
        balance             2  : integer            # 资源余额
        expense             3  : integer            # 资源支出
    }

	pid					 1  : integer		# 角色编号
	nickname			 2  : string		# 角色名称
	portrait			 3  : string		# 角色头像
	sex					 4  : integer		# 角色性别（1 ： 男性， 2 ： 女性， 3 ： 第三性别）
	score			     5  : integer		# 角色积分
	level				 6  : integer	    # 角色等级
	resources            7  : *resource     # 角色资源
}
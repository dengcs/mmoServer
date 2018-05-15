---------------------------------------------------------------------
--- 业务错误码描述
---------------------------------------------------------------------
ERRCODE = 
{
	OK 							= 0,
	NO_CAR 						= 1,		--不存在Car
	NO_ENOUGH_MONEY 			= 2,		--金币不足
	NO_ENOUGH_DIAMOND 			= 3,		--钻石不足
	NO_ENOUGH_ITEM 				= 4,		--道具不足
	CONFIG_ERROR 				= 5,		--配置错误
	MAX_PART_LEVEL 				= 6,		--部件已达最大等级
	PARAM_INVALID 				= 7,		--参数无效
	EXIST_CAR_COMP 				= 8,		--已拥有该配件
	NO_EXIST_CAR_COMP 			= 9,		--不存在该配件
	MAX_COMP_LEVEL 				= 10,		--配件已达最大等级
	PLATE_CANNT_UPGRADE 		= 11,		--车牌配件不能升级
	PAINT_ID_INVALID 			= 12,		--涂装ID无效
	EXIST_COMP_PAINT 			= 13,		--已拥有该涂装效果
	NO_EXIST_COMP_PAINT 		= 14,		--不存在该涂装效果
	HAD_SELECTED_PAINT 			= 15,		--当前样式已经装配
	NO_ITEM 					= 16,		--不存在此道具
	EXIST_CAR 					= 17,		--已存在该赛车
	EXIST_COPILOT 				= 18,		--已存在该领航员
	NO_EXIST_COPILOT			= 19,		--不存在该领航员
	MAX_COPILOT_ADVANCE			= 20,		--领航员已达最大进阶数
	ALREADY_ACTIVE_STORY		= 21,		--已解锁传记
	MAX_SKILL_LEVEL				= 22,		--技能已达最大等级
	NO_EXIST_SKILL				= 23,		--不存在该技能
	NO_ENOUGH_SKILL_POINTS		= 24,		--技能点数不足
	NO_ENOUGH_COPILOT_LEVEL		= 25,		--导航员等级不足
	EXIST_COPILOT_SKIN 			= 26,		--存在领航员皮肤
	NO_EXIST_COPILOT_SKIN 		= 27,		--不存在领航员皮肤
	NO_ENOUGH_PLAYER_LEVEL 		= 28, 		--角色等级不足
	IN_CD_TIME					= 29, 		--在冷却时间中
	NO_ENOUGH_EXHIBI_LEVEL 		= 30,		--展厅等级不足
	NO_ENOUGH_TALENT_POINTS 	= 31,		--天赋技能点数不足
	NO_ENOUGT_CAR_NUM 			= 32,		--赛车数量不足
	NO_ENOUGT_CAR_QUALITY		= 33,		--赛车品质太低
	ALREADY_BIND_CAR 			= 34,		--已经绑定该赛车
	NO_EXIST_LEVEL 				= 35,		--不存在该等级
	NO_PRE_TALENT 				= 36,		--缺少前置天赋
	NO_IN_CD_TIME 				= 37,		--不在升级/扩建中
	MAX_EXHIBI_LEVEL	 		= 38,		--展厅满级
	MAX_CAR_LEVEL				= 39,		--赛车满级
	CAR_LEVEL_UP_FAILED 		= 40,		--赛车升级失败
	ITEM_CANNOT_USE 			= 41,		--道具不可使用
	MAX_COPILOT_LEVEL 			= 42,		--领航员满级
	DUPLICATE_PLAYER_NAME 		= 43, 		--角色名称重名了
	NO_COPILOT_STORY_CND		= 44, 		--领航员解锁条件不足
	HAD_ACTIVED_TALENT_NODE 	= 45, 		--已激活技能点
	NO_OPEN_PARKING_POS 		= 46,		--赛车停车位未开启
	NO_FOUND_PLAYER 			= 47,		--未找到玩家
	CANNOT_BE_MYSELF 			= 48,		--不能是自己
	CANNOT_HAD_SPECIAL_CHAR		= 49, 		--不能包含魔法字符
	OPERATE_INVALID             = 50,   	--非法操作
	NO_ENOUGH_TONG_MONEY 		= 51,   	--车队币不足
	GIFT_INVALID                = 52,   	--不能赠送

	NO_PASSED_LICENSE 			= 101,		--驾照未通过
	HAD_PASSED_LICENSE 			= 102,		--已经获得驾照
	NO_PASSED_SUB_TEST 			= 103,		--未通过驾照子考试
	HAD_PASSED_SUB_TEST 		= 104,		--已经通过驾照子考试
	HAD_GOT_LICENSE_AWARD 		= 105,		--已经领取驾照奖励
	NO_EXIST_LICENSE			= 106,		--不存在该驾照
	NO_PASSED_PRE_SUB_TEST		= 107,		--前置考试未通过
	NO_PASSED_PRE_LICENSE 		= 108, 		--前置驾照未通过

	CAREER_DUP_NO_OPEN 			= 121,		--生涯赛副本未解锁
	HAD_GOT_HONOR_LEVEL_AWARD 	= 122, 		--已经领取荣誉等级奖励
	NO_ENOUGH_HONOR_LEVEL 		= 123, 		--荣誉等级不足
	NO_FOUND_BADGE 				= 124,		--没有该徽章
	INVALID_SHOWING_BADGE_POS 	= 125,		--展示徽章孔位非法

	GOODS_NO_SALE 				= 131, 		--商品未上架
	MAX_BUY_COUNT 				= 132, 		--商品达最大购买次数
	NO_ENOUGH_SNATCH_COUNT 		= 133,  	--抽取次数不足
	HAD_GOT_ADDITIONAL_AWARD	= 134,  	--已经领取奖励
	TREASURE_DEADLINE_INVALID 	= 135,  	--夺宝已失效
	FASHION_BUY_AMOUNT          = 136,  	--时装购买次数限制

	HISTORY_RACE_CD 			= 141,		--历史战绩请求CD(避免频繁请求)
	NO_EXIST_PORTRAIT 			= 142, 		--不存在头像
	PORTRAIT_EXPIRED 			= 143, 		--头像过期了
	FUNCTION_NO_IMPLEMENT 		= 144, 		--功能未实现
	EXIST_PORTRAIT 				= 145, 		--存在头像
	ALLOC_UID_ERROR 			= 146,  	--分配UID失败
	MSG_SERVICE_ERROR 			= 147,  	--车库留言服务不可用
	HAD_LIKE_MESSAGE 			= 148,  	--已经留言
	NO_EXIST_MESSAGE 			= 149, 		--不存在留言
	HAD_LIKED_MESSAGE 			= 150, 		--已经点赞留言
	NO_DEL_PERMISSION			= 151, 		--没有删除权限
	CANNOT_LIKE_MYSELF 			= 152,		--不能给自己点赞
	HAD_LIKED_EXHIBITION 		= 153,  	--已经点赞车库
	HAD_GOT_LIKE_AWARD 			= 154,		--已经领取人气奖励
	NO_ENOUGH_LIKE_COUNT 		= 155, 		--车库点赞数量不足
	OVER_MAX_LEAVE_MESSAGE_COUNT= 156,  	--已经达到最大留言次数

	NO_ENOUGH_VIP 				= 161, 		--VIP等级不足
	HAD_BUY_VIP_SELL_GIFT 		= 162,  	--已买过VIP贵族礼包

	HAD_JOIN_TONG				= 201, 		--已经加入车队
	HAD_APPLY_FOR_JOIN 			= 202,  	--已经申请，请等待审核
	NO_ENOUGH_PRIVILEGE 		= 203,  	--没有权限
	NO_EXIST_JOIN_INFO 			= 204,  	--没有申请信息
	NO_EXIST_MEMBER 			= 205, 		--不存在该队员
	NO_JOIN_TONG 				= 206,  	--没有加入车队
	MAX_VICE_CAPTAIN_NUM 		= 207, 		--副队长职位数量已满
	IS_VICE_CAPTAIN 			= 208,  	--已经是副队长
	IS_NOT_VICE_CAPTAIN 		= 209, 		--不是副队长
	NO_EXIST_TONG 				= 210, 		--不存在车队
	NO_MEET_CONDITIONS 			= 211,  	--不满足入队条件
	HAD_MAX_MEMBER_NUM 			= 212,  	--车队人数已满
	CREATE_TONG_ERROR 			= 213,  	--创建车队出错
	CANNOT_KICK_YOURSELF 		= 214, 		--不能踢自己
	CANNOT_FIRE_YOURSELF 		= 215,  	--不能解雇自己
	CANNOT_APPOINT_YOURSELF 	= 216,  	--不能任命自己
	HAD_SIGN_IN 				= 217, 		--今天已经签到
	EXIT_TONG_CD 				= 218,  	--加入车队CD未冷却
	DELEGATE_PRESENT_CD 		= 219,  	--发布礼物CD为冷却
	NO_EXIST_PRESENT 			= 220,  	--不存在礼物委托
	PRESENT_HAD_DONATED 		= 221,  	--委托的礼物已经赠送
	CANNOT_CANCEL_OTHER_PRESENT = 222,  	--不能取消其他的委託的禮物
	MAX_DONATED_COUNT 			= 223,  	--已达最大赠送次数
	NO_ENOUGH_TONG_LEVEL		= 224,  	--车队等级不足
	INVALID_CAPACITY 			= 225,  	--无效扩容ID
	NO_ENOUGH_UPDATE_COUNT 		= 226,  	--没有足够刷新次数
	DUPLICATE_TONG_NAME 		= 227, 		--车队名称重名了
	CANNOT_DONATED_YOURSELF 	= 228,  	--不能赠送给自己
	WARDROBE_FASHION_EXPIRE     = 229,  	--试衣间时装过期


	CDKEY_COMMON_ERROR			= 9001,		-- 未知系统错误
	CDKEY_REENTRANT_FAILED      = 9002,		-- 系统忙（激活操作重入）
	CDKEY_NOT_EXISTS			= 9003,		-- 激活码不存在
	CDKEY_ALREADY_RECEIVED		= 9004,		-- 激活码已使用
	CDKEY_ALREADY_EXPIRED		= 9005,		-- 激活码已失效
	CDKEY_LEVEL_LIMIT			= 9006,		-- 角色等级限制
	CDKEY_PERMISSION_DINIED		= 9007,		-- 角色权限限制


	FRIEND_FRIEND_FULL          = 10011,	-- 好友已满
    FRIEND_APPLY_FULL           = 10012,	-- 申请列表已满
    FRIEND_APPLIED_FULL         = 10013,	-- 发送申请列表已满
    FRIEND_BLACK_FULL           = 10014,	-- 黑名单列表已满
    FRIEND_ALREADY_FRIEND       = 10015,    -- 已经是好友
    FRIEND_ALREADY_APPLY        = 10016,	-- 好友已申请
    FRIEND_ALREADY_APPLIED      = 10017,	-- 已经在发起申请列表
    FRIEND_ALREADY_BLACK        = 10018,	-- 已经在黑名单
    FRIEND_NOT_EXIST            = 10019,	-- 好友不存在
    FRIEND_NOT_FRIEND           = 10020,	-- 不是好友
    FRIEND_NOT_APPLY            = 10021,	-- 没有申请
    FRIEND_NOT_APPLIED          = 10022,	-- 没有申请
    FRIEND_NOT_BLACK            = 10023,	-- 没有申请
    FRIEND_ALREADY_COHESION     = 10024,	-- 已经在亲密列表
    CHATD_ERROR_CHAT_TYPE       = 10101,	-- 错误聊天类型
    CHATD_IS_TOO_OFEN           = 10102,	-- 聊天太频繁
    CHATD_TEAM_NOT_EXIST		= 10103,	-- 队伍不存在


    -- 用户登录/握手相关错误码描述
    ACCOUNT_COMMON_ERROR		= 20100,	-- 未知系统错误
    ACCOUNT_LOGIN_FAILED		= 20101,	-- 账号登录失败
    ACCOUNT_EXECUTE_FAILED		= 20102,	-- 访问数据库失败
    ACCOUNT_ALREADY_FROZEN		= 20103,	-- 账号已被冻结
    ACCOUNT_ACCESS_REJECTED		= 20104,	-- 拒绝登录（维护模式，未通过白名单验证）

    AUTH_COMMON_ERROR           = 20001,	-- 账号校验失败
    AUTH_SERVER_CLOSE			= 20002,	-- 服务器维护中
    AUTH_USER_KICKOUT			= 20003,	-- 账号被踢掉

    -- 房间赛组队服务错误码
    ROOM_ENTERENV_FAILED		= 21001,	-- 状态转换错误（普通状态转为组队状态）
    ROOM_LEAVEENV_FAILED		= 21002,	-- 状态转换错误（组队状态转为普通状态）
    ROOM_UNKNOWN_CHANNEL		= 21003,	-- 未知频道
    ROOM_UNKNOWN_MODE			= 21004,	-- 未知房间模式
    ROOM_NOT_EXISTS				= 21005,	-- 房间不存在
	ROOM_NOT_MEMBER				= 21006,	-- 成员不存在
    ROOM_NOT_PREPARE			= 21007,	-- 非准备状态
    ROOM_NOT_READY				= 21008,	-- 非就绪状态
    ROOM_NOT_RUNNING			= 21009,	-- 非战斗状态
	ROOM_PERMISSION_DINIED		= 21010,	-- 没有权限
	ROOM_NOT_POSITION			= 21011,	-- 没有座位
	ROOM_WRONG_STATE			= 21012,	-- 状态错误
	ROOM_WRONG_COUNT			= 21013,	-- 错误成员数量(至少需要2名玩家)
	ROOM_WRONG_TEAMS			= 21014,	-- 错误队伍数量
	ROOM_INVALID_OPERATION		= 21015,	-- 非法操作
    ROOM_CREAE_FAILED			= 21016,	-- 创建房间失败
    ROOM_JOIN_FAILED			= 21017,	-- 加入房间失败
	ROOM_TRANSPLACE_FAILED		= 21018,	-- 转换座位失败
	ROOM_LOCKED_FAILED			= 21019,	-- 锁定座位失败
	ROOM_UNLOCK_FAILED			= 21020,	-- 解锁座位失败
	ROOM_START_FAILED			= 21021,	-- 战场启动失败
	ROOM_AUTHENTICATE_FAILED	= 21022,	-- 密码检验失败
	ROOM_EQUIP_FAILED			= 21023,	-- 更换装备失败
	ROOM_PLAYER_STATUS_ERROR    = 21024,	-- 角色状态错误


	-- 对战赛组队服务错误码
	PVP_ENTERENV_FAILED			= 22001,	-- 状态转换错误（普通状态转为组队状态）
	PVP_LEAVEENV_FAILED         = 22002,	-- 状态转换错误（组队状态转为普通状态）
	PVP_UNKNOWN_MODE			= 22003,	-- 未知队伍模式
	PVP_NOT_EXISTS				= 22004,	-- 队伍不存在
	PVP_NOT_PREPARE				= 22005,	-- 非准备状态
	PVP_NOT_READY				= 22006,	-- 非就绪状态
	PVP_PERMISSION_DINIED		= 22007,	-- 没有权限
	PVP_NOT_MEMBER				= 22008,	-- 成员不存在
	PVP_CREATE_FAILED			= 22009,	-- 创建队伍失败
	PVP_JOIN_FAILED				= 22010,	-- 加入队伍失败
	PVP_START_FAILED			= 22011,	-- 战场启动失败

	-- 排位赛组队服务错误码
	QUALIFYING_COMMON_ERROR     = 23010,	-- 排位赛系统错误
	QUALIFYING_ENTERENV_FAILED  = 23001,	-- 状态转换错误（普通状态转为组队状态）
	QUALIFYING_LEAVEENV_FAILED  = 23002,	-- 状态转换错误（组队状态转为普通状态）
	QUALIFYING_SEASON_FINISHED	= 23003,	-- 赛季已经结束
	QUALIFYING_NOT_EXISTS		= 23004,	-- 队伍不存在
	QUALIFYING_NOT_PREPARE		= 23005,	-- 非准备状态
	QUALIFYING_NOT_READY        = 23006,	-- 非就绪状态
	QUALIFYING_PERMISSION_DINIED= 23007,	-- 没有权限
	QUALIFYING_CREATE_FAILED    = 23008,	-- 创建队伍失败
	QUALIFYING_JOIN_FAILED      = 23009,	-- 加入队伍失败
	QUALIFYING_START_FAILED     = 23010,	-- 战场启动失败
	QUALIFYING_MATCH_PREPARE	= 23011,	-- 比赛准备中（每日'6 - 24'开放）

	-- 限时活动服务错误码
	ACTIVITY_ENTERENV_FAILED    = 24001,	-- 状态转换错误（普通状态转为组队状态）
	ACTIVITY_LEAVEENV_FAILED	= 24002,	-- 状态转换错误（普通状态转为组队状态）
	ACTIVITY_SEASON_CLOSED		= 24003,	-- 赛季已经关闭
	ACTIVITY_SEASON_PREPARE     = 24004,	-- 赛季准备中
	ACTIVITY_START_FAILED       = 24005,	-- 战场启动失败
	ACTIVITY_COMMON_ERROR       = 24006,	-- 普通错误
	ACTIVITY_PURCHASE_DISALLOW	= 24007,	-- 禁止购买
	ACTIVITY_LEAK_RESOURCE		= 24008,	-- 资源不足
	ACTIVITY_ATTEND_LIMITED     = 24009,	-- 已达上限

	-- 战场服务错误码
	GAME_ENTERENV_FAILED        = 25001,	-- 状态转换错误（组队状态转为战斗状态）
	GAME_LEAVEENV_FAILED		= 25002,	-- 状态转换错误（战斗状态转为普通状态）
	GAME_UNKNOWN_MODE			= 25003,	-- 未知战场模式
	GAME_UNKNOWN_TRACK			= 25004,	-- 未知赛道类型
	GAME_NOT_PREPARE			= 25005,	-- 非准备状态
	GAME_NOT_LOADING			= 25006,	-- 非加载状态
	GAME_NOT_READY				= 25007,	-- 非就绪状态
	GAME_NOT_RUNNING			= 25008,	-- 非战斗状态
	GAME_NOT_FINISHED			= 25009,	-- 非结算状态
	GAME_NOT_MEMBER				= 25010,	-- 成员不存在
	GAME_PERMISSION_DINIED		= 25011,	-- 没有权限
	GAME_PROTOCOL_UNSUPPORTED	= 25012,	-- 协议不支持
	GAME_ALREADY_PICKED			= 25013,	-- 物品已经被捡取
	GAME_CREATE_FAILED          = 25014,	-- 创建战场失败
	GAME_RECONNECT_FAILED		= 25015,	-- 重连战场失败

	-- 车队赛组队服务错误码
	FACTION_ENTERENV_FAILED		= 26001,	-- 状态转换错误（普通状态转为组队状态）
	FACTION_LEAVEENV_FAILED		= 26002,	-- 状态转换错误（普通状态转为组队状态）
	FACTION_COMMON_ERROR		= 26003,	-- 未知系统错误
	FACTION_PLAYER_STATE_ERROR	= 26004,	-- 角色状态错误
	FACTION_NOT_OPENED			= 26005,	-- 比赛未开放
	FACTION_PERMISSION_DINIED	= 26006,	-- 没有权限
	FACTION_NOT_EXISTS			= 26007,	-- 队伍不存在
	FACTION_NON_MEMBER			= 26008,	-- 非车队成员
	FACTION_NOT_PREPARE			= 26009,	-- 非准备状态
	FACTION_NOT_READY			= 26010,	-- 非就绪状态
	FACTION_CREATE_FAILED		= 26011,	-- 创建队伍失败
	FACTION_JOIN_FAILED			= 26012,	-- 加入队伍失败
	FACTION_START_FAILED		= 26013,	-- 战场启动失败
	FACTION_MATCH_LIMIT 		= 26014, 	-- 没有足够比赛次数

	--- 牌号仓库相关错误
	PNSTORAGE_COMMON_ERROR		= 30001,	-- 牌号仓库相关通常错误
	PNSTORAGE_NOT_EXPANDABLE	= 30002,	-- 牌号仓库不可扩容
	PNSTORAGE_LEAK_DIAMONDS		= 30003,	-- 钻石不足
	PNSTORAGE_LEAK_TICKET		= 30004,	-- 奖券不足
	PNSTORAGE_NOT_COMMODITY		= 30005,	-- 没有可购买牌号
	PNSTORAGE_COMMODITY_EXISTS	= 30006,	-- 存在可购买牌号
	PNSTORAGE_ALREADY_FULL		= 30007,	-- 牌号仓库已满

	--- 每日任务相关错误
	TASK_COMMON_ERROR			= 31001,	-- 任务通常错误
	TASK_NOT_EXISTS				= 31002,	-- 任务不存在
	TASK_ALREADY_RECEIVED		= 31003,	-- 任务奖励已领取
	TASK_NOT_COMPLETED			= 31004,	-- 任务未完成
	MARK_NOT_EXISTS				= 31005,	-- 活跃标记不存在
	MARK_ALREADY_RECEIVED		= 31006,	-- 活跃奖励已领取
	MARK_NOT_COMPLETED			= 31007,	-- 活跃标记未完成

	--- 系统活动相关错误
	ACTION_COMMON_ERROR			= 32001,	-- 活动通常错误
	ACTION_NOT_EXISTS			= 32002,	-- 活动不存在
	ACTION_ALREADY_RECEIVED		= 32003,	-- 奖励已领取/已经签到
	ACTION_RECEIVE_FAILED		= 32004,	-- 领取失败
	ACTION_NOT_ELEMENT			= 32005,	-- 项目不存在
	ACTION_ELEMENT_UNSUPPORT	= 32006,	-- 操作不支持
	ACTION_ELEMENT_UNCOMPLETED	= 32007,	-- 项目未完成
	ACTION_LEAK_RESOURCE		= 32008,	-- 资源不足
	ACTION_RECEIVE_REJECTED		= 32009,	-- 拒绝签到/领奖

	--- 角色天赋相关错误
	ABILITY_TALENT_ABNORMAL		= 33001,	-- 天赋数据异常
	ABILITY_WITHOUT_UNLOCKED	= 33002,	-- 天赋未被解锁
	ABILITY_MAX_LEVEL			= 33003,	-- 已达最大等级
	ABILITY_LEAK_POINT			= 33004,	-- 缺少天赋点数
	ABILITY_LEAK_RESOURCE		= 33005,	-- 缺少所需资源

	---- 充值相关
	PAYMENT_CREATE_FAILED 		= 34001, 	-- 创建订单失败
	PAYMENT_NOT_COMMODITY 		= 34002, 	-- 没有找到商品
	PAYMENT_ALREADY_CONFIRM		= 34003, 	-- 订单已经确认过了
	PAYMENT_CONFIRM_FAILED 		= 34004, 	-- 订单确认失败
	PAYMENT_MONEY_ERROR			= 34005, 	-- 订单金额不一致
}

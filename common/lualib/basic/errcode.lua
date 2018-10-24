---------------------------------------------------------------------
--- 业务错误码描述
---------------------------------------------------------------------
ERRCODE = 
{
	OK 							= 0,

	-------------------------------------------------------
	--- 公共错误相关
	-------------------------------------------------------
	COMMON_LACK_RESOURCE                        = 1000,     -- 资源不足
	COMMON_LACK_DIAMOND                         = 1001,     -- 钻石不足
	COMMON_LACK_MONEY                           = 1002,     -- 金币不足
	COMMON_LACK_POWER                           = 1003,     -- 体力不足
	COMMON_LACK_ITEM                            = 1004,     -- 道具不足
	COMMON_SYSTEM_ERROR                         = 1005,     -- 系统错误
	COMMON_CLIENT_ERROR                         = 1006,     -- 前端错误
	COMMON_CONFIG_ERROR                         = 1007,     -- 配置错误
	COMMON_PARAMS_ERROR                         = 1008,     -- 参数错误
	COMMON_STATUS_ERROR                         = 1009,     -- 状态错误
	COMMON_MAXLVL_ERROR                         = 1010,     -- 最大等级错误

	--- 房间服务相关错误
	ROOM_ENTERENV_FAILED				= 10001,	-- 进入房间
	ROOM_LEAVEENV_FAILED				= 10002,	-- 离开房间
	ROOM_CREATE_FAILED					= 10003,	-- 创建房间

	--- 战场服务错误码
	GAME_ENTERENV_FAILED				= 20001,	-- 进入战场
	GAME_LEAVEENV_FAILED				= 20002,	-- 退出战场


	---- 充值相关
	PAYMENT_CREATE_FAILED 		= 30001, 	-- 创建订单失败
	PAYMENT_NOT_COMMODITY 		= 30002, 	-- 没有找到商品
	PAYMENT_ALREADY_CONFIRM		= 30003, 	-- 订单已经确认过了
	PAYMENT_CONFIRM_FAILED 		= 30004, 	-- 订单确认失败
	PAYMENT_MONEY_ERROR			= 30005, 	-- 订单金额不一致
}

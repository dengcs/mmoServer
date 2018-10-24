---------------------------------------------------------------------
--- 业务错误码描述
---------------------------------------------------------------------
ERRCODE = 
{
	OK 							= 0,

	-------------------------------------------------------
	--- 公共错误相关
	-------------------------------------------------------
	COMMON_LACK_RESOURCE                        = 8000,     -- 资源不足
	COMMON_LACK_DIAMOND                         = 8001,     -- 钻石不足
	COMMON_LACK_MONEY                           = 8002,     -- 金币不足
	COMMON_LACK_POWER                           = 8003,     -- 体力不足
	COMMON_LACK_ITEM                            = 8004,     -- 道具不足
	COMMON_SYSTEM_ERROR                         = 9000,     -- 系统错误
	COMMON_CLIENT_ERROR                         = 9001,     -- 前端错误
	COMMON_CONFIG_ERROR                         = 9002,     -- 配置错误
	COMMON_PARAMS_ERROR                         = 9003,     -- 参数错误
	COMMON_STATUS_ERROR                         = 9004,     -- 状态错误
	COMMON_MAXLVL_ERROR                         = 9005,     -- 最大等级错误

    -- 房间赛组队服务错误码

    ROOM_UNKNOWN_CHANNEL		= 21003,	-- 未知频道
    ROOM_UNKNOWN_MODE			= 21004,	-- 未知房间模式
    ROOM_NOT_EXISTS				= 21005,	-- 房间不存在
	ROOM_NOT_MEMBER				= 21006,	-- 成员不存在
    ROOM_NOT_PREPARE			= 21007,	-- 非准备状态
    ROOM_NOT_READY				= 21008,	-- 非就绪状态
    ROOM_NOT_RUNNING			= 21009,	-- 非战斗状态
	ROOM_INVALID_OPERATION		= 21015,	-- 非法操作


	-- 战场服务错误码
	GAME_UNKNOWN_MODE			= 25003,	-- 未知战场模式
	GAME_NOT_MEMBER				= 25010,	-- 成员不存在


	---- 充值相关
	PAYMENT_CREATE_FAILED 		= 34001, 	-- 创建订单失败
	PAYMENT_NOT_COMMODITY 		= 34002, 	-- 没有找到商品
	PAYMENT_ALREADY_CONFIRM		= 34003, 	-- 订单已经确认过了
	PAYMENT_CONFIRM_FAILED 		= 34004, 	-- 订单确认失败
	PAYMENT_MONEY_ERROR			= 34005, 	-- 订单金额不一致
}

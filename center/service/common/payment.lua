--
-- 支付服务
--
local service  = require "service"
local nova     = require "nova"
local md5      = require "md5"
local utility  = require "common.utility"
local COMMAND  = {}
-- 底层驱动加载
local userdriver = nova.userdriver()
local summdriver = nova.summdriver()
local taskdriver = nova.taskdriver()

-----------------------------------------------------------
--- 内部变量/内部逻辑
-----------------------------------------------------------

-- 订单编号序列
local SEQUENCE = os.time() % 10000

-- 订单编号生成（时间戳 + 角色编号 + 商品编号 + 订单序号）
-- 1. 角色编号
-- 2. 商品编号
local function allocid(uid, cid)
	SEQUENCE = (SEQUENCE + 1) % 10000
	return string.format("%010d%s%04d", os.time(), md5.sumhexa(uid..cid), SEQUENCE)
end

-- 商品列表[商品编号， 商品价格]
local commodities = nil

-- 加载商品
local function load_commodities()
	commodities = {}
	for _, v in pairs(nova.sheetdata("ConfigShop")) do
		repeat
			-- 过滤未开放商品
			if #v.SaleTime == 2 then
				local cpoint = os.time()
				local spoint = utility.str2time(v.SaleTime[1])
				local epoint = utility.str2time(v.SaleTime[2])
				if cpoint < spoint or cpoint > epoint then
					break
				end
			end
			-- 过滤非支付商品
			if #v.CostType ~= 1 then
				break
			end
			if v.CostType[1][1] ~= 4 then
				break
			end
			-- 记录商品
			local commodity =
			{
				id    = v.ID,
				money = math.ceil(v.CostType[1][2] * 100),
			}
			-- 记录商品
			commodities[v.ID] = commodity
		until(true)
	end
	return commodities
end

-----------------------------------------------------------
--- 数据库操作
-----------------------------------------------------------

-- 数据库名称
local database = nova.getenv("db_name") or "AMBER"

-- 订单操作集
local payment = {}

-- 创建订单（在数据库创建订单记录）
-- 1. 订单编号
-- 2. 角色编号
-- 3. 商品信息
function payment.create(oid, uid, commodity)
	local sid     = nova.getenv("zoneid") or "server-1"
	local cid     = commodity.id
	local money   = commodity.money
	local sqlcomm = string.format("INSERT INTO payment_storage(`gameorder`, `state`, `server`, `uid`, `cid`, `money`, `create_time`) VALUES('%s', 0, '%s', '%s', %d, %d, now());",
		oid, sid, uid, cid, money)
	if not userdriver.insert(database, sqlcomm) then
		return false
	else
		return true
	end
end

-- 确定订单（更新数据库订单记录）
-- 1. 游戏订单号
-- 2. 平台订单号
-- 3. 平台标志
-- 4. 支付金额
-- 5. 订单状态（1 - 成功， 2 - 异常）
function payment.confirm(oid, order, channel, pay_time, channel_uid, state)
	local sqlcomm = string.format("UPDATE payment_storage SET `order` = '%s', `channel` = '%s', `state` = %d, `pay_time` = '%s', `channel_uid` = '%s', `confirm_time` = now() WHERE gameorder = '%s'",
		order,
		channel,
		(state or 1),
		pay_time,
		channel_uid,
		oid)
	if not userdriver.update(database, sqlcomm) then
		return false
	else
		return true
	end
end

-- 查询订单
-- 1. 订单编号
function payment.query(oid)
	local sqlcomm = string.format("SELECT * FROM payment_storage WHERE gameorder = '%s'", oid)
	local result  = userdriver.select(database, sqlcomm)
	if next(result) then
		return result[1]
	else
		return nil
	end
end

-----------------------------------------------------------
--- 支付服务接口
-----------------------------------------------------------

-- 服务启动
function COMMAND.on_init(arguments)
	-- 加载商品列表
	load_commodities()
end

-- 服务退出
function COMMAND.on_exit()
end

-- 创建订单(返回请求应答)
-- 1. 角色编号
-- 2. 商品编号
function COMMAND.on_create(uid, cid)
	-- 商品检查
	local commodity = commodities[cid]
	if commodity == nil then
		return {ret = ERRCODE.PAYMENT_NOT_COMMODITY}
	end
	-- 生成订单
	local oid = allocid(uid, cid)
	if payment.create(oid, uid, commodity) then
		return {ret = 0, order = oid, cid = cid}
	else
		return {ret = ERRCODE.PAYMENT_CREATE_FAILED}
	end
end

-- 确定订单（不检查支付金额，订单号有效则确定订单）
-- 1. 通知内容
function COMMAND.on_confirm(data)
	-- 订单检查
	local result = payment.query(data.gameorder)
	if result == nil then
		return ERRCODE.PAYMENT_NOT_EXISTS
	end

	LOG_DEBUG("gameorder=%s, order=%s, money=%s, state=%d, pay_time=%s, channel=%s, channel_uid=%s",
		data.gameorder,
		data.order,
		data.money,
		data.state,
		data.pay_time,
		data.channel,
		data.channel_uid
	)
	LOG_DEBUG("result", table.tostring(result))
	if result.state ~= 0 then
		--TODO:把失败订单持久化
		return ERRCODE.PAYMENT_ALREADY_CONFIRM --"订单状态错误"
	elseif result.money ~= data.money then
		return ERRCODE.PAYMENT_MONEY_ERROR --"成交金额不一致"
	end
	-- 发放物品
	local _, retval = userdriver.usercall(result.uid, "on_payment_confirm", data.gameorder, result.cid, data.money)
	if not retval then
		return ERRCODE.PAYMENT_CONFIRM_FAILED  --"确认失败"
	end

	-- 确认订单
	if not payment.confirm(data.gameorder, data.order, data.channel, data.pay_time, data.channel_uid, 1) then
		LOG_ERROR("payment.confirm failed!!!")
		return ERRCODE.PAYMENT_CONFIRM_FAILED --"确认失败"
	end
	return 0
end

-----------------------------------------------------------
--- 注册支付服务
-----------------------------------------------------------
local handler = {}

-- 消息分发逻辑
-- 1. 消息来源
-- 2. 消息类型
-- 3. 消息内容
function handler.command_handler(source, cmd, ...)
	local fn = COMMAND[cmd]
	if fn then
		return fn(source, ...)
	else
		ERROR("svcmanager : command[%s] can't find!!!", cmd)
	end
end

handler.init_handler = init_handler
handler.exit_handler = exit_handler

service.start(handler)

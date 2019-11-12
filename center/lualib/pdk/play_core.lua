---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by dengcs.
--- DateTime: 2018/11/7 15:28
---
local skynet 		= require "skynet"
local json_codec	= require("pdk.json_codec")
local poker_type	= require("pdk.poker_type")
local play_state	= require("pdk.play_state")
local ENUM 			= require("config.enum")

local tb_insert		= table.insert
local PLAY_STATE 	= ENUM.PLAY_STATE
local PLAY_EVENT	= ENUM.PLAY_EVENT
local STATE_BOTTOM	= 11 -- 获得底牌

local hide_byte_bit = 0x400

local play_core = {}

function play_core.new()
	local core = {}
	core.play_mgr 	= {}
	core.play_state = play_state.new()
	setmetatable(core, {__index = play_core})

	local functions = core:auth_functions_to_state()
	core.play_state:copy_functions_from_core(functions)

	return core
end

function play_core:begin(data)
	self.data = data
	self.landowner = 0
	self.double = 1
	self.round_state = {idx = 0, type = 0, value = 0, count = 0}
	self.play_state:start_and_run()
end

function play_core:call_super(fnName, ...)
	local func = self.play_mgr.functions[fnName]
	if func then
		return func(...)
	end
end

function play_core:copy_functions_from_manager(functions)
	self.play_mgr.functions = functions
end

-- 授权给状态模块的函数
function play_core:auth_functions_to_state()
	local function state_notify(idx, state)
		self:state_notify(idx, state)
	end

	local function push_bottom()
		self:push_bottom()
	end

	local function get_landowner()
		return self.landowner
	end

	local functions = {}
	functions.state_notify 	= state_notify
	functions.push_bottom 	= push_bottom
	functions.get_landowner	= get_landowner

	return functions
end

function play_core:state_notify(idx, state)
	if state == PLAY_STATE.PREPARE then
		local data = json_codec.encode(state, {idx = idx})
		self:call_super("notify", idx, data)
	elseif state == PLAY_STATE.DEAL then
		local data = json_codec.encode(state, self:get_cards(idx))
		self:call_super("notify", idx, data)
	elseif state == PLAY_STATE.SNATCH then
		local data = json_codec.encode(state)
		self:call_super("notify", idx, data)
	end
end

-- 推送底牌
function play_core:push_bottom()
	if self.landowner > 0 then
		local places = self.data.places[self.landowner]
		if places then
			for _, v in pairs(self.data.cards) do
				tb_insert(places.cards, v)
			end
		end

		local data = json_codec.encode(STATE_BOTTOM, {idx = self.landowner, msg = self.data.cards})
		self:call_super("broadcast", data)
	end
end

-- 获取某个位置的牌
function play_core:get_cards(idx)
	local place = self.data.places[idx]
	if place then
		return place.cards
	end
end

function play_core:get_default_indexes(idx)
	local cards = self:get_cards(idx)
	return poker_type.get_default_indexes(cards)
end

function play_core:get_type_indexes(idx, type, value, count)
	local cards = self:get_cards(idx)
	return poker_type.get_type_indexes(type, cards, value, count)
end

-- 出牌
function play_core:remove_cards(idx, card_indexes)
	local ret_cards = {}
	local cards = self:get_cards(idx)
	for _, v in pairs(card_indexes or {}) do
		tb_insert(ret_cards, cards[v])
		cards[v] = cards[v] | hide_byte_bit
	end
	return ret_cards
end

function play_core:check_game_over(idx)
	assert(idx)

	local cards = self:get_cards(idx)
	for i, v in pairs(cards or {}) do
		if v < hide_byte_bit then
			return false
		end
	end

	return true
end

function play_core:game_over(idx)
	self.play_state:stop()
	local overData =
	{
		idx 		= idx,
		double		= self.double,
		landowner 	= self.landowner,
	}
	-- 通知客户端游戏已经结束
	local bc_data = json_codec.encode(PLAY_STATE.OVER, overData)
	self:call_super("broadcast", bc_data)
	-- 通知内部处理游戏结束事件
	self:call_super("event", PLAY_EVENT.GAME_OVER, overData)
end

function play_core:set_round_state(idx, type, value, count)
	self.round_state.idx = idx
	self.round_state.type = type
	self.round_state.value = value
	self.round_state.count = count
end

-- 是否可以随意出牌
function play_core:is_main_type(idx)
	if self.round_state.idx == 0 then
		return true
	end

	if self.round_state.idx == idx then
		return true
	end
	return false
end

-- 验牌及出牌
function play_core:check_and_play(idx, msg)
	local indexes = {}
	local cards = self:get_cards(idx)
	for _, v in pairs(msg or {}) do
		local bFind = false
		for kk, vv in pairs(cards or {}) do
			if v == vv then
				bFind = true
				tb_insert(indexes, kk)
				break
			end
		end

		if not bFind then
			return false
		end
	end

	local is_main = self:is_main_type(idx)
	if is_main then
		local type, max_value, count = poker_type.test_type(msg)
		if type then
			self:remove_cards(idx, indexes)
			self:set_round_state(idx, type, max_value, count)
			return true
		end
	else
		local type = self.round_state.type
		local value = self.round_state.value
		local count = self.round_state.count

		local ret_type, max_value, ret_count = poker_type.check_type(type, msg, value, count)
		if ret_type then
			self:remove_cards(idx, indexes)
			self:set_round_state(idx, ret_type, max_value, ret_count)
			return true
		end
	end

	return false
end

-- 托管
function play_core:entrust(idx)
	local msg = 0

	local is_main = self:is_main_type(idx)
	if is_main then
		local indexes, type, max_value, count = self:get_default_indexes(idx)
		if indexes then
			local cards = self:remove_cards(idx, indexes)
			self:set_round_state(idx, type, max_value, count)
			msg = cards
		end
	else
		local type = self.round_state.type
		local value = self.round_state.value
		local count = self.round_state.count
		local indexes, max_value = self:get_type_indexes(idx, type, value, count)
		if indexes then
			local cards = self:remove_cards(idx, indexes)
			self:set_round_state(idx, type, max_value, count)
			msg = cards
		end
	end

	return msg
end

function play_core:timeout_super(ti, name, ...)
	local function execute(...)
		self:call_super(name, ...)
	end

	skynet.timeout(ti, execute)
end

function play_core:timeout_update(ti, idx, cmd, msg)
	local function execute()
		local data = json_codec.encode(cmd, msg)
		self:update(idx, data, true)
	end

	skynet.timeout(ti, execute)
end

-- 接收玩家命令
function play_core:update(idx, data, direct)
	local place_idx, state = self.play_state:watch_turn()

	if state == PLAY_STATE.OVER then
		return
	end

	if place_idx == idx then
		local cmd, msg = json_codec.decode(data)
		if cmd ~= state then
			return
		end

		local ok = false

		if state == PLAY_STATE.SNATCH then
			if direct then
				ok = true
			else
				if msg == 1 then
					self.landowner = idx
					ok = true
				elseif self.landowner == (idx%3 + 1) then
					self.play_state:inc_count()
					self:timeout_update(300, idx, cmd, 0)
				elseif self.landowner == 0 and idx == 3 then
					self:timeout_update(300, idx, cmd, 0)
					self:timeout_super(310, "shuffle_and_deal")
				elseif msg == 0 then
					ok = true
				elseif not msg then
					self:timeout_update(300, idx, cmd, 0)
				end
			end
		elseif state == PLAY_STATE.PLAY then
			-- 是否是托管的定时调用
			if direct then
				ok = true
			else
				if not msg then
					-- 托管
					msg = self:entrust(idx)
					self:timeout_update(300, idx, cmd, msg)
				elseif msg == 0 then
					-- 要不起
					local is_main = self:is_main_type(idx)
					if is_main == false then
						ok = true
					end
				elseif self:check_and_play(idx, msg) then
					-- 出牌
					ok = true
				end
			end
		end

		if ok then
			local broadcast_data = json_codec.encode(state, {idx = idx, msg = msg})
			self:call_super("broadcast", broadcast_data)

			local is_game_over = self:check_game_over(idx)
			if is_game_over then
				self:game_over(idx)
			end

			place_idx, state = self.play_state:turn()
			local notify_data = json_codec.encode(state)
			self:call_super("notify", place_idx, notify_data)
		end
	end
end


return play_core
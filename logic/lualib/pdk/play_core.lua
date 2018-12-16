---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by dengcs.
--- DateTime: 2018/11/7 15:28
---
local json_codec	= require("pdk.json_codec")
local poker_type	= require("pdk.poker_type")
local play_state	= require("pdk.play_state")
local ENUM 			= require("config.gameenum")
local random		= require("utils.random")

local tb_insert		= table.insert
local PLAY_STATE 	= ENUM.PLAY_STATE
local PLAY_EVENT	= ENUM.PLAY_EVENT

local hide_byte_bit = 1024

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

-- 内部消息通知
function play_core:event(id, data)
	local event = self.play_mgr.functions.event
	if event then
		event(id, data)
	end
end

-- 座位通知消息
function play_core:notify(idx, data)
	local notify = self.play_mgr.functions.notify
	if notify then
		notify(idx, data)
	end
end

-- 游戏广播消息
function play_core:broadcast(data)
	local broadcast = self.play_mgr.functions.broadcast
	if broadcast then
		broadcast(data)
	end
end

function play_core:state_notify(idx, state)
	if state == PLAY_STATE.DEAL then
		local data = json_codec.encode(state, self:get_cards(idx))
		self:notify(idx, data)
	elseif state == PLAY_STATE.SNATCH then
		local data = json_codec.encode(state)
		self:notify(idx, data)
	end
end

function play_core:push_bottom()
	if self.landowner > 0 then

		local places = self.data.places[self.landowner]
		if places then
			for _, v in pairs(self.data.cards) do
				tb_insert(places.cards, v)
			end
		end

		local data = json_codec.encode(11, {idx = self.landowner, msg = self.data.cards})
		self:broadcast(data)

		local notify_data = json_codec.encode(11)
		self:notify(self.landowner, notify_data)
	end
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

function play_core:copy_functions_from_manager(functions)
	self.play_mgr.functions = functions
end

-- 获取某个位置的牌
function play_core:get_cards(idx)
	local place = self.data.places[idx]
	if place then
		return place.cards
	end
end

-- 验证棋牌类型
function play_core:check_type(type, cards)
	return poker_type.check_type(type, cards)
end

-- 获取出牌类型
function play_core:test_type(cards)
	return poker_type.test_type(cards)
end

function play_core:get_default_indexes(idx)
	local cards = self:get_cards(idx)
	return poker_type.get_default_indexes(cards)
end

function play_core:get_type_indexes(idx, type, value, count)
	local cards = self:get_cards(idx)
	return poker_type.get_type_indexes(type, cards, value, count)
end

--
function play_core:post_cards(idx, card_indexes)
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

	self:event(PLAY_EVENT.GAME_OVER, {})

	local broadcast_data = json_codec.encode(PLAY_STATE.OVER, {idx = idx})
	self:broadcast(broadcast_data)
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

-- 托管
function play_core:entrust(idx)
	local msg = nil

	local is_main = self:is_main_type(idx)
	if is_main then
		local indexes, type, max_value, count = self:get_default_indexes(idx)
		if indexes then
			local cards = self:post_cards(idx, indexes)
			self:set_round_state(idx, type, max_value, count)
			msg = cards
		end
	else
		local type = self.round_state.type
		local value = self.round_state.value
		local count = self.round_state.count
		local indexes, max_value = self:get_type_indexes(idx, type, value, count)
		if indexes then
			local cards = self:post_cards(idx, indexes)
			self:set_round_state(idx, type, max_value, count)
			msg = cards
		end
	end

	return msg
end

-- 接收玩家命令
function play_core:update(idx, data)
	local place_idx, state = self.play_state:watch_turn()

	if state == PLAY_STATE.OVER then
		return
	end

	if place_idx == idx then
		local cmd, msg = json_codec.decode(data)
		if not cmd then
			return
		end

		local ok = false

		if state == PLAY_STATE.SNATCH and cmd == state then
			if msg == 1 then
				self.landowner = idx
			end
			ok = true
		elseif state == PLAY_STATE.DOUBLE and cmd == state then
			if msg == 1 then
				self.double = self.double * 2
			end
			ok = true
		elseif state == PLAY_STATE.PLAY and cmd == state then
			if not msg then
				-- 托管
				msg = self:entrust(idx)
			end
			ok = true
		end

		if ok then
			local broadcast_data = json_codec.encode(state, {idx = idx, msg = msg})
			self:broadcast(broadcast_data)

			local is_game_over = self:check_game_over(idx)
			if is_game_over then
				self:game_over(idx)
			end

			place_idx, state = self.play_state:turn()
			local notify_data = json_codec.encode(state)
			self:notify(place_idx, notify_data)
		end
	end
end


return play_core
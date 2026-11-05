--[[--------------------------------------------------------------------------
	ForeverCompat.lua —— 《魔兽世界：无限》(World of Warcraft: Forever) 兼容层

	目标客户端：安装目录 _forever_，产品代号 wowf，版本 1.60.1，
	             TOC Interface = 16001，现代 Mainline (约 12.1.5) API，Lua 5.1。

	移植约定：
	  * 优先使用现代 API：C_Spell / C_SpellBook / C_Item / C_Container / C_TradeInfo；
	  * classic-only 的老 API 只在探测到确实存在时才调用，缺失时安全降级，绝不抛错；
	  * 交易 / 容器 / 法术书 / 物品信息 / 事件注册统一走本文件的 TBT_* 包装，
	    业务代码不再直接调用已被移除的 API。
--------------------------------------------------------------------------]]--

TBT_Compat = TBT_Compat or {}
local C = TBT_Compat

-- 交易对象的名字可能是 secret value（12.x 起引入）。secret 字符串禁止参与拼接
-- 与输出，也无法作为密语目标，统一用这个占位符显示。
TBT_SECRET_NAME = TBT_SECRET_NAME or "???"

local function HasAPI(tbl, methodName)
	return type(tbl) == "table" and type(tbl[methodName]) == "function"
end
C.HasAPI = HasAPI

-- ===========================================================================
-- 通用工具
-- ===========================================================================

-- 判断一个值是不是 secret value（不是则返回 false，任何异常都按"不是"处理）
function C.IsSecret(value)
	if value == nil then return false end
	if type(issecretvalue) ~= "function" then return false end
	local ok, secret = pcall(issecretvalue, value)
	return (ok and secret) and true or false
end

-- 安全调用任意全局函数：函数不存在或内部报错都只返回 false，不影响调用方
function C.CallGlobal(name, ...)
	local fn = _G[name]
	if type(fn) ~= "function" then return false end
	return pcall(fn, ...)
end

-- 安全 hooksecurefunc：函数不存在时不 hook
function C.HookGlobal(name, func)
	if type(_G[name]) ~= "function" then return false end
	return pcall(hooksecurefunc, name, func)
end

-- 安全 HookScript
function C.HookScript(frame, scriptName, func)
	if not frame or type(frame.HookScript) ~= "function" then return false end
	return pcall(frame.HookScript, frame, scriptName, func)
end

-- 事件在版本间可能被删除。先用 C_EventUtils 预检，再 pcall 注册，
-- 避免 "Attempt to register unknown event" 直接抛错中断整段初始化。
function C.RegisterEvent(frame, event)
	if not frame or type(event) ~= "string" then return false end
	if HasAPI(_G.C_EventUtils, "IsEventValid") then
		local ok, valid = pcall(C_EventUtils.IsEventValid, event)
		if ok and valid == false then return false end
	end
	return pcall(frame.RegisterEvent, frame, event)
end

-- math.atan2 在 Lua 5.1 存在，这里只是兜底（部分客户端可能裁剪过数学库）
function C.Atan2(y, x)
	if type(math.atan2) == "function" then return math.atan2(y, x) end
	if x == 0 then return y >= 0 and math.pi / 2 or -math.pi / 2 end
	local a = math.atan(y / x)
	if x < 0 then a = a + math.pi end
	return a
end

-- ===========================================================================
-- 法术书（替代 GetSpellInfo(i, BOOKTYPE_SPELL)）
-- ===========================================================================

-- 返回法术书第 index 个条目的 name, icon, spellID（槽位为空时返回 nil）
function C.GetSpellBookItem(index, bookType)
	bookType = bookType or _G.BOOKTYPE_SPELL or "spell"
	local name, spellID, icon

	if HasAPI(_G.C_SpellBook, "GetSpellBookItemName") then
		local ok, n, sid = pcall(C_SpellBook.GetSpellBookItemName, index, bookType)
		if ok then name, spellID = n, sid end
		if name and HasAPI(_G.C_SpellBook, "GetSpellBookItemTexture") then
			local ok2, tex = pcall(C_SpellBook.GetSpellBookItemTexture, index, bookType)
			if ok2 then icon = tex end
		end
	end

	if not name and type(_G.GetSpellBookItemName) == "function" then
		local ok, n, sid = pcall(_G.GetSpellBookItemName, index, bookType)
		if ok then name, spellID = n, sid end
	end

	-- 老客户端兜底：GetSpellInfo(index, bookType)
	if not name and type(_G.GetSpellInfo) == "function" then
		local ok, n, _rank, ic, _cast, _min, _max, sid = pcall(_G.GetSpellInfo, index, bookType)
		if ok then name, icon, spellID = n, ic, sid end
	end

	if not name then return nil end
	return name, icon, spellID
end

-- ===========================================================================
-- 容器（替代 GetContainerNumSlots / GetContainerItemInfo / PickupContainerItem ...）
-- ===========================================================================

function C.GetContainerNumSlots(bag)
	if HasAPI(_G.C_Container, "GetContainerNumSlots") then
		local slots = C_Container.GetContainerNumSlots(bag)
		return slots or 0
	end
	if type(_G.GetContainerNumSlots) == "function" then
		local ok, slots = pcall(_G.GetContainerNumSlots, bag)
		if ok then return slots or 0 end
	end
	return 0
end

-- 返回老式多返回值：icon, count, locked, quality, readable, lootable, itemLink, itemID
function C.GetContainerItemInfo(bag, slot)
	if HasAPI(_G.C_Container, "GetContainerItemInfo") then
		local info = C_Container.GetContainerItemInfo(bag, slot)
		if not info then return nil end
		return info.iconFileID, info.stackCount, info.isLocked, info.quality,
			info.isReadable, info.hasLoot, info.hyperlink, info.itemID
	end
	if type(_G.GetContainerItemInfo) == "function" then
		local ok, icon, count, locked, quality, readable, lootable, link, itemID =
			pcall(_G.GetContainerItemInfo, bag, slot)
		if ok then return icon, count, locked, quality, readable, lootable, link, itemID end
	end
end

function C.GetContainerItemLink(bag, slot)
	if HasAPI(_G.C_Container, "GetContainerItemLink") then
		return C_Container.GetContainerItemLink(bag, slot)
	end
	if type(_G.GetContainerItemLink) == "function" then
		local ok, link = pcall(_G.GetContainerItemLink, bag, slot)
		if ok then return link end
	end
end

function C.PickupContainerItem(bag, slot)
	if HasAPI(_G.C_Container, "PickupContainerItem") then
		return pcall(C_Container.PickupContainerItem, bag, slot)
	end
	if type(_G.PickupContainerItem) == "function" then
		return pcall(_G.PickupContainerItem, bag, slot)
	end
	return false
end

function C.UseContainerItem(bag, slot)
	if HasAPI(_G.C_Container, "UseContainerItem") then
		return pcall(C_Container.UseContainerItem, bag, slot)
	end
	if type(_G.UseContainerItem) == "function" then
		return pcall(_G.UseContainerItem, bag, slot)
	end
	return false
end

-- 背包数量：0..NUM_CONTAINER_FRAMES（老常量在现代可能被移除）
function C.GetNumBags()
	return _G.NUM_CONTAINER_FRAMES or _G.NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5
end

-- ===========================================================================
-- 物品信息（替代 GetItemInfo）
-- ===========================================================================

-- 返回 C_Item.GetItemInfo 的多返回值：name, link, quality, itemLevel, ...
function C.GetItemInfo(item)
	if HasAPI(_G.C_Item, "GetItemInfo") then
		return C_Item.GetItemInfo(item)
	end
	if type(_G.GetItemInfo) == "function" then
		return _G.GetItemInfo(item)
	end
end

-- ===========================================================================
-- 交易窗口（GetTrade* / ClickTradeButton / GetPlayerTradeMoney ...）
--   现代客户端里这些入口可能搬到 C_TradeInfo 下，先查全局再查 C_TradeInfo。
-- ===========================================================================

local function TradeFunc(name)
	local fn = _G[name]
	if type(fn) == "function" then return fn end
	local info = _G.C_TradeInfo
	if type(info) == "table" and type(info[name]) == "function" then return info[name] end
	return nil
end
C.TradeFunc = TradeFunc

-- unit = "Player" / "Target"；返回原版多返回值（两个 unit 的返回值顺序不同，调用方按原逻辑解包）
function C.GetTradeItemInfo(unit, id)
	local fn = TradeFunc("GetTrade" .. unit .. "ItemInfo")
	if not fn then return nil end
	local ok, name, texture, numItems, quality, isUsable, enchantment = pcall(fn, id)
	if not ok then return nil end
	return name, texture, numItems, quality, isUsable, enchantment
end

function C.GetTradeItemLink(unit, id)
	local fn = TradeFunc("GetTrade" .. unit .. "ItemLink")
	if not fn then return nil end
	local ok, link = pcall(fn, id)
	if ok then return link end
end

-- unit = "player" / "target"
function C.GetTradeMoney(unit)
	local fn = TradeFunc((unit == "player") and "GetPlayerTradeMoney" or "GetTargetTradeMoney")
	if fn then
		local ok, money = pcall(fn)
		if ok and type(money) == "number" then return money end
	end
	return 0
end

function C.ClickTradeButton(index)
	local fn = TradeFunc("ClickTradeButton")
	if not fn then return false end
	return pcall(fn, index)
end

function C.ClickTargetTradeButton(index)
	local fn = TradeFunc("ClickTargetTradeButton")
	if not fn then return false end
	return pcall(fn, index)
end

-- 把光标上的物品放进交易窗口的第一个空槽。
-- 老客户端的入口是 FrameXML 的 TradeFrame_OnMouseUp；现代客户端里
-- "ClickTradeButton(index)" 就是"把光标物品放入第 index 个交易槽"，作为回退路径。
function C.PlaceCursorItemInTrade()
	if type(_G.TradeFrame_OnMouseUp) == "function" then
		if pcall(_G.TradeFrame_OnMouseUp) then return true end
	end
	local getInfo = TradeFunc("GetTradePlayerItemInfo")
	for i = 1, 6 do
		local name = getInfo and getInfo(i)
		if not name then return C.ClickTradeButton(i) end
	end
	return false
end

-- ===========================================================================
-- 零星 FrameXML 全局函数（各版本间容易被改名/移除，全部做能力探测）
-- ===========================================================================

function C.CursorOnUpdate(button)
	return C.CallGlobal("CursorOnUpdate", button)
end

function C.CursorUpdate()
	return C.CallGlobal("CursorUpdate")
end

function C.ResetCursor()
	return C.CallGlobal("ResetCursor")
end

function C.DressUpItemLink(link)
	return C.CallGlobal("DressUpItemLink", link)
end

function C.ChatEdit_InsertLink(link)
	if not link then return false end
	return C.CallGlobal("ChatEdit_InsertLink", link)
end

function C.MoneyFrame_Update(frameName, money)
	return C.CallGlobal("MoneyFrame_Update", frameName, money or 0)
end

function C.GameTooltipSetDefaultAnchor(tooltip, owner)
	if type(_G.GameTooltip_SetDefaultAnchor) == "function" then
		return C.CallGlobal("GameTooltip_SetDefaultAnchor", tooltip, owner)
	end
	if tooltip and tooltip.SetOwner then tooltip:SetOwner(owner, "ANCHOR_RIGHT") end
	return true
end

-- GameTooltip:SetBagItem 在部分版本被 C_Container 替代，缺失时返回 false
function C.GameTooltipSetBagItem(tooltip, bag, slot)
	if not tooltip then return false end
	if type(tooltip.SetBagItem) == "function" then
		return (pcall(tooltip.SetBagItem, tooltip, bag, slot))
	end
	if HasAPI(_G.C_Container, "SetBagItem") then
		return pcall(C_Container.SetBagItem, tooltip, bag, slot)
	end
	return false
end

-- ===========================================================================
-- FauxScrollFrame（记录列表的分页滚动）
-- ===========================================================================

function C.FauxScrollFrameUpdate(frame, count, visible, lineHeight)
	if type(_G.FauxScrollFrame_Update) == "function" then
		return (pcall(FauxScrollFrame_Update, frame, count, visible, lineHeight))
	end
	return false
end

function C.FauxScrollFrameGetOffset(frame)
	if type(_G.FauxScrollFrame_GetOffset) == "function" then
		local ok, offset = pcall(FauxScrollFrame_GetOffset, frame)
		if ok then return offset end
	end
	return nil
end

function C.FauxScrollFrameOnVerticalScroll(frame, offset, lineHeight, updateFunc)
	if type(_G.FauxScrollFrame_OnVerticalScroll) == "function" then
		return (pcall(FauxScrollFrame_OnVerticalScroll, frame, offset, lineHeight, updateFunc))
	end
	return false
end

-- ForeverCompat.lua 提供的现代 API 兼容层（toc 中先于本文件加载）
local C = TBT_Compat

SLASH_TRADELOGSHOW1 = "/tbtdebug";
SlashCmdList["TRADELOGSHOW"] = function(msg)
	if(not TradeLog_TradesHistory)then return end
	DEFAULT_CHAT_FRAME:AddMessage("(debug)TradeId-"..msg.." |Htradelog:"..msg.."|h[DETAIL]|h:");
	TBT_CURRENT_TRADE = TradeLog_TradesHistory[0+msg];
	TradeLog_OutputLog();
	table.remove(TradeLog_TradesHistory, #TradeLog_TradesHistory);
end

TBT_CURRENT_TRADE = nil;

local function curr()
	if(not TBT_CURRENT_TRADE) then
		TBT_CURRENT_TRADE = TradeLog_CreateNewTrade();
	end
	return TBT_CURRENT_TRADE;
end

function TradeLog_CreateNewTrade()
	local trade = {
		id = nil,
		when = nil,
		where = nil,
		who = nil,
		player=TBT_UnitName("player") or TBT_SECRET_NAME,
		playerMoney = 0,
		targetMoney = 0,
		playerItems = {},
		targetItems = {},
		events = {},  --for analysing cancel reason
		toofar = nil, --for further analysing cancel reason
		result = nil, --[cancelled | complete | error]
		reason = nil, --["self" | "selfrunaway" | "toofar" | "other" | "selfhideui" | ERR_TRADE_BAG_FULL | ERR_TRADE_MAX_COUNT_EXCEEDED | ERR_TRADE_TARGET_BAG_FULL | ERR_TRADE_TARGET_MAX_COUNT_EXCEEDED]
	};
	return trade;
end

function TradeLog_OnLoad(self)

	-- 事件名在版本间可能已被移除，统一走兼容层注册（C_EventUtils 预检 + pcall）
	C.RegisterEvent(self, "ADDON_LOADED");
	C.RegisterEvent(self, "TRADE_SHOW");
	C.RegisterEvent(self, "TRADE_CLOSED");
	C.RegisterEvent(self, "TRADE_REQUEST_CANCEL");
	C.RegisterEvent(self, "PLAYER_TRADE_MONEY");

	C.RegisterEvent(self, "TRADE_MONEY_CHANGED");
	--C.RegisterEvent(self, "TRADE_PLAYER_ITEM_CHANGED"); --this is an uncertain problem, seems TRADE_PLAYER_ITEM_CHANGED always fire 2 times?
	C.RegisterEvent(self, "TRADE_TARGET_ITEM_CHANGED");
	C.RegisterEvent(self, "TRADE_ACCEPT_UPDATE");
	C.RegisterEvent(self, "UI_INFO_MESSAGE");
	C.RegisterEvent(self, "UI_ERROR_MESSAGE");
end

-- Register our minimap button with MinimapButtonButton (MBB) if it is
-- installed. MBB only auto-collects minimap buttons whose frame names
-- follow specific naming conventions and whose globals were created in
-- Lua; our button is created in XML and is named "TradeListFrameButton",
-- so it would be missed. MBB keeps its options in the global saved
-- variable MinimapButtonButtonOptions and uses the whitelist table by
-- reference, so adding our button there (before PLAYER_LOGIN, where MBB
-- does its scan) makes MBB collect it without modifying MBB itself.
-- If the user explicitly ignores the button in MBB (blacklist), that
-- decision is respected.
local function TradeLog_RegisterWithMBB()
	local mbbOptions = _G.MinimapButtonButtonOptions;
	if(type(mbbOptions) ~= "table" or type(mbbOptions.whitelist) ~= "table") then
		return; -- MBB not installed or not ready
	end
	if(type(mbbOptions.blacklist) == "table" and mbbOptions.blacklist["TradeListFrameButton"]) then
		return; -- user explicitly chose to ignore this button
	end
	mbbOptions.whitelist["TradeListFrameButton"] = true;
end

function TradeLog_OnVariableLoad()
	-- local menu = CreateFrame("Frame", "TBT_AnnounceChannelDropDown", TradeFrame, "UIDropDownMenuTemplate");
	-- menu:SetPoint("BOTTOMLEFT", "TradeFrame", "BOTTOMLEFT", 80, 49);
	-- UIDropDownMenu_SetWidth(TBT_AnnounceChannelDropDown, 62, 3);
    -- TBT_AnnounceChannelDropDown:SetScript("OnShow", function(self) self:SetFrameLevel(TradeFrame:GetFrameLevel()) end)

	-- 没有交易窗口时退化为挂在 UIParent 上，功能不丢
	local parent = TradeFrame or UIParent;
	-- 模板名在 modern 客户端仍存在，但缺模板时 CreateFrame 会抛错，这里降级为无样式复选框
	local okCreate, cb = pcall(CreateFrame, "CheckButton", "TBT_AnnounceCB", parent, "InterfaceOptionsCheckButtonTemplate");
	if(not okCreate or not cb)then
		cb = CreateFrame("CheckButton", "TBT_AnnounceCB", parent);
	end
	cb:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 16, 0);
	cb:SetWidth(26);
	cb:SetHeight(26);
	if TBT_AnnounceCBText then
		TBT_AnnounceCBText:SetText(TRADE_LOG_ANNOUNCE);
	end
	cb.tooltipText = TRADE_LOG_ANNOUNCE_TIP;
	cb:SetScript("OnClick", function(self) TradeLog_Announce_Checked = self:GetChecked()and true or false; end);

    -- menu:SetPoint('BOTTOMLEFT', cb, 50, -3)
	TradeLog_TradesHistory = TradeLog_TradesHistory or {};

	for k, v in ipairs(TradeLog_TradesHistory) do
		v.id = v.id or k
	end

	TradeLog_AnnounceChannel = TradeLog_AnnounceChannel or "WHISPER";

	-- UIDropDownMenu_Initialize(TBT_AnnounceChannelDropDown, TBT_AnnounceChannelDropDown_Initialize);
	-- UIDropDownMenu_SetSelectedValue(TBT_AnnounceChannelDropDown, TradeLog_AnnounceChannel);

	if(TradeLog_Announce_Checked) then TBT_AnnounceCB:SetChecked(1); end;

	if TradeLogFrame_CreateMinimapButton then TradeLogFrame_CreateMinimapButton() end
	TradeLog_RegisterWithMBB();
end

-- 交易错误/提示文本常量在各版本间可能缺失（也可能是 nil），
-- 这里逐个比对且跳过 nil，避免 nil==nil 造成的误判
local function TradeLog_IsText(text, ...)
	if(not text)then return false end
	for i = 1, select("#", ...) do
		local expected = select(i, ...)
		if(expected and expected==text)then return true end
	end
	return false
end

function TradeLog_OnEvent(self, event, arg1, arg2)
	--local arg1 = ...;
	if (event=="UI_ERROR_MESSAGE") then
		if TradeLog_IsText(arg2, ERR_TRADE_BAG_FULL, ERR_TRADE_MAX_COUNT_EXCEEDED, ERR_TRADE_TARGET_BAG_FULL, ERR_TRADE_TARGET_MAX_COUNT_EXCEEDED) then
			curr().result = "error";
			curr().reason=arg2;
			TradeLog_LogTradeAndReset();
		elseif TradeLog_IsText(arg2, ERR_TRADE_TARGET_DEAD, ERR_TRADE_TOO_FAR) then
			DEFAULT_CHAT_FRAME:AddMessage(arg2, 1, 0.2, 0.2);
		end
	elseif (event=="UI_INFO_MESSAGE" and TradeLog_IsText(arg2, ERR_TRADE_CANCELLED, ERR_TRADE_COMPLETE)) then
		if(arg2==ERR_TRADE_CANCELLED) then
			curr().result = "cancelled";
		else
			curr().result = "complete";
		end
		TradeLog_LogTradeAndReset();

	elseif (event=="TRADE_CLOSED" or event=="TRADE_REQUEST_CANCEL" or event == "TRADE_SHOW") then
		table.insert(curr().events, event);

	elseif (event=="TRADE_PLAYER_ITEM_CHANGED") then
		TradeLog_UpdateItemInfo(arg1, "Player", curr().playerItems);

	elseif (event=="TRADE_TARGET_ITEM_CHANGED") then
		TradeLog_UpdateItemInfo(arg1, "Target", curr().targetItems);

	elseif (event=="TRADE_MONEY_CHANGED") then
		TradeLog_UpdateMoney();

	elseif (event=="TRADE_ACCEPT_UPDATE") then
		for i = 1, 7 do
			TradeLog_UpdateItemInfo(i, "Player", curr().playerItems);
			TradeLog_UpdateItemInfo(i, "Target", curr().targetItems);
		end
		TradeLog_UpdateMoney();
	elseif (event=="ADDON_LOADED") and arg1 == "TheBurningTrade" then
		TradeLog_OnVariableLoad()
	end

	if (event=="TRADE_REQUEST_CANCEL") then --judge the trade distance for further analysing the cancel reason
		-- 先取再判断：UnitName 在 12.x 可能返回 secret value，不能直接拿来做拼接/比较
		local ok, npcName = pcall(UnitName, "NPC");
		if(ok and not C.IsSecret(npcName) and npcName ~= nil) then
			if (CheckInteractDistance("npc", 2)) then
				curr().toofar = "no";
			else
				curr().toofar = "yes";
			end
		end;
	end

	if (event=="TRADE_SHOW") then
		-- 12.x 起 UnitName 可能返回 secret value：只记录占位符，禁止拼接/输出真实名字
		local ok, name, server = pcall(UnitName, "NPC");
		if(not ok)then name, server = nil, nil end
		if(not name)then
			-- 还没有交易对象信息，保持 who 为空（原逻辑：视为没打开过窗口）
		elseif(C.IsSecret(name) or C.IsSecret(server))then
			curr().who = TBT_SECRET_NAME;
			curr().whoSecret = true;
		elseif(server and server ~= "")then
			curr().who = name.."-"..server;
		else
			curr().who = name;
		end
	end
end

function TradeLog_UpdateItemInfo(id, unit, items)
	local name, texture, numItems, quality, isUsable, enchantment;
	--why GetTradePlayerItemInfo and GetTradeTargetItemInfo return different things?
	-- wowf：这两个入口统一由兼容层探测（先全局，再 C_TradeInfo）
	if(unit=="Target") then
		name, texture, numItems, quality, isUsable, enchantment = C.GetTradeItemInfo(unit, id);
	else
		name, texture, numItems, quality, enchantment = C.GetTradeItemInfo(unit, id);
	end

	if(not name) then
		items[id] = nil;
		return;
	end

	local itemLink = C.GetTradeItemLink(unit, id);

	items[id] = {
		name = name,
		texture = texture,
		numItems = numItems,
		isUsable = isUsable,
		enchantment = enchantment,
		itemLink = itemLink,
	}
end

function TradeLog_UpdateMoney()
	curr().playerMoney = C.GetTradeMoney("player");
	curr().targetMoney = C.GetTradeMoney("target");
end

function TradeLog_AnalyseCancelReason()
	local reason = "unknown"; --should be unknown only when no trade window opened.
	local e = curr().events;
	local n = table.getn(e);
	if(n>=3 and e[n]=="TRADE_REQUEST_CANCEL" and e[n-1]=="TRADE_CLOSED" and e[n-2]=="TRADE_CLOSED") then
		reason = "self";
	elseif(n>=3 and e[n]=="TRADE_REQUEST_CANCEL" and e[n-1]=="TRADE_CLOSED" and e[n-2]=="TRADE_SHOW") then
		reason = "selfrunaway";
	elseif(n>=3 and e[n]=="TRADE_CLOSED" and e[n-1]=="TRADE_CLOSED" and e[n-2]=="TRADE_REQUEST_CANCEL") then
		if(curr().toofar == "yes") then
			reason = "toofar";
		elseif(curr().toofar == "no") then
			reason = "other";
		else
			reason = "wrong!!"; --this should not happen, if you see, contact me :p
		end
	elseif(n>=3 and e[n]=="TRADE_REQUEST_CANCEL" and e[n-1]=="TRADE_SHOW" and e[n-2]=="TRADE_CLOSED") then
		reason = "selfhideui";
	end

	curr().events = nil; --reason analyzed, abandon it to release that tiny memory
	return reason;
end

function TradeLog_LogTradeAndReset()
	curr().when = date("%m-%d %H:%M:%S");
	curr().where = GetRealZoneText();
	if( curr().result == "cancelled" ) then
		curr().reason = TradeLog_AnalyseCancelReason();
	elseif( curr().result == "error" ) then
		curr().reason = curr().reason;
	end
	TradeLog_OutputLog();
	TBT_CURRENT_TRADE = nil;
end

local function TBT_nextId(tab)
	local n = 0;
	for k,v in pairs(tab) do
		if(v.id>n) then n=v.id end;
	end
	return n+1;
end

function TradeLog_OutputLog()
	local numPlayer, numTarget, enPlayer, enTarget, msg;
	if(not curr().who) then
		--never show the trade window
		if( curr().reason =="selfhideui" ) then
			DEFAULT_CHAT_FRAME:AddMessage(string.gsub(TRADE_LOG_FAILED_NO_TARGET, "%%r", CANCEL_REASON_TEXT[curr().reason]));
		else
			TBT_debug("debug : no window opened");
		end
		return;
	end
	curr().id = TBT_nextId(TradeLog_TradesHistory);
	table.insert(TradeLog_TradesHistory, curr());
	if(type(TradeListScrollFrame_Update)=="function") then TradeListScrollFrame_Update(); end

	numPlayer = 0; numTarget = 0;
	for i=1,6 do if(curr().playerItems[i]) then numPlayer = numPlayer + 1 end end
	for i=1,6 do if(curr().targetItems[i]) then numTarget = numTarget + 1 end end
	if(curr().playerItems[7] and curr().playerItems[7].name and curr().playerItems[7].enchantment) then enPlayer = curr().playerItems[7].enchantment end;
	if(curr().targetItems[7] and curr().targetItems[7].name and curr().targetItems[7].enchantment) then enTarget = curr().targetItems[7].enchantment end;

	-- 名字是 secret value 时不能拼接 |Hplayer: 超链接，只输出占位符
	local whoLink;
	if(curr().whoSecret)then
		whoLink = curr().who;
	else
		whoLink = "|Hplayer:"..curr().who.."|h"..curr().who.."|h";
	end
	if(curr().result == "complete") then
		local hasSendAny, hasReceiveAny, strSend, strReceive

		hasSendAny = false;
		strSend = "";
		if(curr().playerMoney > 0) then
			if(hasSendAny) then strSend = strSend..", "; end
			hasSendAny = true;
			strSend = strSend..TradeLog_GetMoneyColorText(curr().playerMoney);
		end
		for i=1,6 do
			if(curr().playerItems[i]) then
				if(hasSendAny) then strSend = strSend..", "; end
				hasSendAny = true;
				strSend = strSend..curr().playerItems[i].itemLink;
				if(curr().playerItems[i].numItems>1) then
					strSend = strSend.."x"..curr().playerItems[i].numItems;
				end
			end
		end
		if(enTarget) then
			if(hasSendAny) then strSend = strSend..", "; end
			hasSendAny = true;
			strSend = strSend..TRADE_LOG_ENCHANT..":"..enTarget
		end

		hasReceiveAny = false;
		strReceive = "";
		if(curr().targetMoney > 0) then
			if(hasReceiveAny) then strReceive = strReceive..", "; end
			hasReceiveAny = true;
			strReceive = strReceive..TradeLog_GetMoneyColorText(curr().targetMoney);
		end
		for i=1,6 do
			if(curr().targetItems[i]) then
				if(hasReceiveAny) then strReceive = strReceive..", "; end
				hasReceiveAny = true;
				strReceive = strReceive..curr().targetItems[i].itemLink;
				if(curr().targetItems[i].numItems>1) then
					strReceive = strReceive.."x"..curr().targetItems[i].numItems;
				end
			end
		end
		if(enPlayer) then
			if(hasReceiveAny) then strReceive = strReceive..", "; end
			hasReceiveAny = true;
			strReceive = strReceive..TRADE_LOG_ENCHANT..":"..enPlayer
		end

		if(not hasSendAny and not hasReceiveAny) then
			DEFAULT_CHAT_FRAME:AddMessage(string.gsub(TRADE_LOG_SUCCESS_NO_EXCHANGE, "%%t", whoLink), 1, 1, 0);
		else
			local linkString = "|CFF00B4FF|Htradelog:"..curr().id.."|h["..TRADE_LOG_DETAIL.."]|h|r";
			if(TradeLogFrame) then
				DEFAULT_CHAT_FRAME:AddMessage(string.gsub(TRADE_LOG_SUCCESS, "%%t", whoLink)..linkString..":", 1, 1, 0);
			else
				DEFAULT_CHAT_FRAME:AddMessage(string.gsub(TRADE_LOG_SUCCESS, "%%t", whoLink)..TRADE_LOG_DETAIL..":", 1, 1, 0);
			end
			if(hasSendAny) then
				DEFAULT_CHAT_FRAME:AddMessage("("..TRADE_LOG_HANDOUT..") "..strSend, 1, 0.8, 0.8);
			end
			if(hasReceiveAny) then
				DEFAULT_CHAT_FRAME:AddMessage("("..TRADE_LOG_RECEIVE..") "..strReceive, 0.8, 1, 0.8);
			end
		end

	elseif(curr().result == "cancelled") then
		msg = string.gsub(TRADE_LOG_CANCELLED, "%%t", whoLink);
		msg = string.gsub(msg, "%%r", CANCEL_REASON_TEXT[curr().reason]);
		DEFAULT_CHAT_FRAME:AddMessage(msg, 1, 0.5, 0.5);
	else
		msg = string.gsub(TRADE_LOG_FAILED, "%%t", whoLink);
		msg = string.gsub(msg, "%%r", curr().reason);
		DEFAULT_CHAT_FRAME:AddMessage(msg, 1, 0.1, 0.1);
	end

	if(TBT_AnnounceCB and TBT_AnnounceCB:GetChecked()) then
		TradeLog_AnnounceTrade(curr());
	end
end

--for saying in channel, so no links. And message can't be too lang
function TradeLog_AnnounceTrade(trade)
	local numPlayer, numTarget, enPlayer, enTarget, msg;
	if(not trade.who) then
		return;
	end

	numPlayer = 0; numTarget = 0;
	for i=1,6 do if(trade.playerItems[i]) then numPlayer = numPlayer + 1 end end
	for i=1,6 do if(trade.targetItems[i]) then numTarget = numTarget + 1 end end
	if(trade.playerItems[7] and trade.playerItems[7].name and trade.playerItems[7].enchantment) then enPlayer = trade.playerItems[7].enchantment end;
	if(trade.targetItems[7] and trade.targetItems[7].name and trade.targetItems[7].enchantment) then enTarget = trade.targetItems[7].enchantment end;

	local whoLink = trade.who;
	if(trade.result == "complete") then
		local hasSendAny, hasReceiveAny, strSend, strReceive

		hasSendAny = false;
		strSend = "";
		if(trade.playerMoney > 0) then
			if(hasSendAny) then strSend = strSend..", "; end
			hasSendAny = true;
			strSend = strSend..TradeLog_GetMoneyPlainText(trade.playerMoney);
		end

		if(numPlayer > 0) then
			if(hasSendAny) then strSend = strSend..", "; end
			hasSendAny = true;
			strSend = strSend..string.gsub(TRADE_LOG_ITEM_NUMBER, "%%d", numPlayer);
		end

		hasReceiveAny = false;
		strReceive = "";
		if(trade.targetMoney > 0) then
			if(hasReceiveAny) then strReceive = strReceive..", "; end
			hasReceiveAny = true;
			strReceive = strReceive..TradeLog_GetMoneyPlainText(trade.targetMoney);
		end

		if(numTarget > 0) then
			if(hasReceiveAny) then strSend = strSend..", "; end
			hasReceiveAny = true;
			strReceive = strReceive..string.gsub(TRADE_LOG_ITEM_NUMBER, "%%d", numTarget);
		end

		if(not hasSendAny and not hasReceiveAny) then
			msg = string.gsub(TRADE_LOG_SUCCESS_NO_EXCHANGE, "%%t", whoLink)
		else
			msg = string.gsub(TRADE_LOG_SUCCESS, "%%t", whoLink);

			if(hasSendAny) then
				msg = msg .."("..TRADE_LOG_HANDOUT..") "..strSend;
			end
			if(hasReceiveAny) then
				msg = msg.."("..TRADE_LOG_RECEIVE..") "..strReceive;
			end
		end

	elseif(trade.result == "cancelled") then
		msg = string.gsub(TRADE_LOG_CANCELLED, "%%t", whoLink);
		-- 原代码这里误用了 curr().reason（此时已换新交易对象，取到 nil 会让 gsub 报错），
		-- 改为使用刚结束的这笔交易的 reason，并对缺失值兜底
		local reasonText = (CANCEL_REASON_TEXT_ANNOUNCE and CANCEL_REASON_TEXT_ANNOUNCE[trade.reason]) or trade.reason or "";
		msg = string.gsub(msg, "%%r", reasonText);
	else
		msg = string.gsub(TRADE_LOG_FAILED, "%%t", whoLink);
		msg = string.gsub(msg, "%%r", trade.reason or "");
	end

	local channel = TradeLog_FindAnnounceChannel(TradeLog_AnnounceChannel);
	if(channel=="WHISPER")then
		-- secret 名字无法作为密语目标，跳过密语通告（其余频道照常）
		if(trade.whoSecret or not trade.who)then return end
		SendChatMessage(msg,channel,nil,trade.who);
	else
		SendChatMessage(msg,channel);
	end
end

function TradeLog_FindAnnounceChannel(channel)
	--channel should be WHISPER, RAID, PARTY, SAY, YELL
	if(channel=="RAID") then
		if (IsInRaid()) then
			return "RAID";
		elseif ( IsInGroup() ) then
			return "PARTY";
		else
			return "SAY";
		end
	elseif(channel=="PARTY") then
		if ( IsInGroup() ) then
			return "PARTY";
		else
			return "SAY";
		end
	end
	return channel;
end

function TradeLog_GetMoneyColorText(money)
	local GSC_GOLD="ffd100"
	local GSC_SILVER="e6e6e6"
	local GSC_COPPER="c8602c"

	local g = math.floor( money / 10000 );
	local s = math.floor( money / 100 ) - g*100 ;
	local c = money - ( g * 100 + s ) * 100;

	local text = ""
	if(g>0) then text = text.."|cffffff00"..g.."|r".."|cff"..GSC_GOLD..TRADE_LOG_MONEY_NAME.gold.."|r"; end
	if(s>0) then text = text.."|cffffff00"..s.."|r".."|cff"..GSC_SILVER..TRADE_LOG_MONEY_NAME.silver.."|r"; end
	if(c>0) then text = text.."|cffffff00"..c.."|r".."|cff"..GSC_COPPER..TRADE_LOG_MONEY_NAME.copper.."|r"; end

	return text;
end

function TradeLog_GetMoneyPlainText(money)
	local g = math.floor( money / 10000 );
	local s = math.floor( money / 100 ) - g*100 ;
	local c = money - ( g * 100 + s ) * 100;

	local text = ""
	if(g>0) then text = text..g..TRADE_LOG_MONEY_NAME.gold; end
	if(s>0) then text = text..s..TRADE_LOG_MONEY_NAME.silver; end
	if(c>0) then text = text..c..TRADE_LOG_MONEY_NAME.copper; end

	return text;
end

--for UI
-- 说明：通告频道下拉框当前未启用（TradeLog_OnVariableLoad 中的创建代码已注释），
-- 现代客户端也已弃用 UIDropDownMenu_* 系列，这里保留能力探测以免被调用时报错。
function TBT_AnnounceChannelDropDown_OnClick(self)
	if(type(UIDropDownMenu_SetSelectedValue) ~= "function")then return end
	UIDropDownMenu_SetSelectedValue(TBT_AnnounceChannelDropDown, self.value);
	if(TBT_AnnounceCB)then TBT_AnnounceCB:SetChecked(1); end
	TradeLog_AnnounceChannel = self.value;
end

function TBT_AnnounceChannelDropDown_Initialize()
	if(type(UIDropDownMenu_GetSelectedValue) ~= "function" or type(UIDropDownMenu_AddButton) ~= "function")then return end
	local selectedValue = UIDropDownMenu_GetSelectedValue(_G["TBT_AnnounceChannelDropDown"]);
	local info;

	info = {};
	info.text = TRADE_LOG_CHANNELS.whisper;
	info.func = TBT_AnnounceChannelDropDown_OnClick;
	info.value = "WHISPER"
	if ( info.value == selectedValue ) then
		info.checked = 1;
	end
	UIDropDownMenu_AddButton(info);

	info = {};
	info.text = TRADE_LOG_CHANNELS.raid;
	info.func = TBT_AnnounceChannelDropDown_OnClick;
	info.value = "RAID"
	if ( info.value == selectedValue ) then
		info.checked = 1;
	end
	UIDropDownMenu_AddButton(info);

	info = {};
	info.text = TRADE_LOG_CHANNELS.party;
	info.func = TBT_AnnounceChannelDropDown_OnClick;
	info.value = "PARTY"
	if ( info.value == selectedValue ) then
		info.checked = 1;
	end
	UIDropDownMenu_AddButton(info);

	info = {};
	info.text = TRADE_LOG_CHANNELS.say;
	info.func = TBT_AnnounceChannelDropDown_OnClick;
	info.value = "SAY"
	if ( info.value == selectedValue ) then
		info.checked = 1;
	end
	UIDropDownMenu_AddButton(info);

	info = {};
	info.text = TRADE_LOG_CHANNELS.yell;
	info.func = TBT_AnnounceChannelDropDown_OnClick;
	info.value = "YELL"
	if ( info.value == selectedValue ) then
		info.checked = 1;
	end
	UIDropDownMenu_AddButton(info);
end

local frame = CreateFrame("Frame");
frame:SetScript("OnEvent", TradeLog_OnEvent);
TradeLog_OnLoad(frame);

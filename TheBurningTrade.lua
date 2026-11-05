
local _
-- ForeverCompat.lua（toc 中先于本 XML 加载）提供的现代 API 兼容层
local C = TBT_Compat

TBT_PORTAL_MAPPING = {
	[TBT_PORTAL_1]="Interface\\AddOns\\TheBurningTrade\\icons\\9.tga",
	[TBT_PORTAL_2]="Interface\\AddOns\\TheBurningTrade\\icons\\11.tga",
	[TBT_PORTAL_3]="Interface\\AddOns\\TheBurningTrade\\icons\\4.tga",
	[TBT_PORTAL_4]="Interface\\AddOns\\TheBurningTrade\\icons\\5.tga",
	[TBT_PORTAL_5]="Interface\\AddOns\\TheBurningTrade\\icons\\6.tga",
	[TBT_PORTAL_6]="Interface\\AddOns\\TheBurningTrade\\icons\\8.tga",
	[TBT_PORTAL_7]="Interface\\AddOns\\TheBurningTrade\\icons\\10.tga",
	[TBT_PORTAL_8]="Interface\\AddOns\\TheBurningTrade\\icons\\13.tga",
	[TBT_PORTAL_9]="Interface\\AddOns\\TheBurningTrade\\icons\\3.tga",
	[TBT_PORTAL_10]="Interface\\AddOns\\TheBurningTrade\\icons\\12.tga",
	[TBT_PORTAL_11]="Interface\\AddOns\\TheBurningTrade\\icons\\7.tga",
	[TBT_PORTAL_12]="Interface\\AddOns\\TheBurningTrade\\icons\\2.tga",
}
local function SetOrHookScript(frame, scriptName, func)
	if( frame:GetScript(scriptName) ) then
		frame:HookScript(scriptName, func);
	else
		frame:SetScript(scriptName, func);
	end
end

function TBTFrame_OnLoad(self)
	C.RegisterEvent(self, "LOOT_READY");

	-- 交易窗口是 FrameXML 的 UI；wowf 若连 TradeFrame 都没有（理论上不会发生），
	-- 只跳过界面增强，法术书扫描等逻辑照常进行。
	if not TradeFrame then
		TBTFrame_OnPlayerEnter()
		return
	end

	--display the trade recepient info
	local targetInfoText = TradeFrame:CreateFontString("TradeFrameTargetInfoText", "ARTWORK", "GameFontNormal");
	targetInfoText:SetWidth(100);
	targetInfoText:SetHeight(12);
	targetInfoText:SetJustifyH("RIGHT");
	-- 现代交易窗口的对方名字 FontString 名字未变则沿用，否则退化为挂在交易窗口上
	local recipientAnchor = _G.TradeFrameRecipientNameText or TradeFrame;
	targetInfoText:SetPoint("TOPLEFT", recipientAnchor, "BOTTOMLEFT", 0, -8);
	-- UnitClass/UnitLevel 有可能返回 secret value（12.x），拼接前必须过滤
	local function TBTFrame_UpdateTargetInfo()
		if not UnitExists("NPC") then return end
		local class, level = UnitClass("NPC"), UnitLevel("NPC");
		if class and level and not C.IsSecret(class) and not C.IsSecret(level) then
			TradeFrameTargetInfoText:SetText(class.." - "..level);
		end
	end
	-- wowf 上 TradeFrame_OnShow 未必还是全局函数，缺失时改用脚本钩子
	if type(_G.TradeFrame_OnShow) == "function" then
		C.HookGlobal("TradeFrame_OnShow", TBTFrame_UpdateTargetInfo);
	else
		C.HookScript(TradeFrame, "OnShow", TBTFrame_UpdateTargetInfo);
	end

	--button for whisper
	local button = CreateFrame("Button", "TradeFrameTargetWhisperButton", TradeFrame, "UIPanelButtonTemplate");
	button:SetWidth(30);
	button:SetHeight(21);
	button:SetPoint("TOPLEFT", "TradeFrameTargetInfoText", "BOTTOMLEFT", 0, -2);
	button:SetText(TBT_RIGHT_BUTTON.whisper);
	button:SetScript("OnClick", function(self)
		-- TBT_UnitName 在名字是 secret value 时返回 nil：此时无法密语，直接跳过
		local target = TBT_UnitName("NPC");
		if target then
			C.CallGlobal("ChatFrame_SendTell", target);
		end
	end)

	--button for emote1
	button = CreateFrame("Button", "TradeFrameTargetEmote1Button", TradeFrame, "UIPanelButtonTemplate");
	button:SetWidth(30);
	button:SetHeight(21);
	button:SetPoint("LEFT", "TradeFrameTargetWhisperButton", "RIGHT", 5, 0);
	button:SetText(TBT_RIGHT_BUTTON.ask);
	button:SetScript("OnClick", function(self) C.CallGlobal("DoEmote", "hungry", "NPC") end);

	--button for emote2
	button = CreateFrame("Button", "TradeFrameTargetEmote2Button", TradeFrame, "UIPanelButtonTemplate");
	button:SetWidth(30);
	button:SetHeight(21);
	button:SetPoint("LEFT", "TradeFrameTargetEmote1Button", "RIGHT", 5, 0);
	button:SetText(TBT_RIGHT_BUTTON.thank);
	button:SetScript("OnClick", function(self) C.CallGlobal("DoEmote", "thank", "NPC") end);

	--button for click-targetting, positioned at portrait.
	button = CreateFrame("Button", "TradeFrameTargetRecipientButton", TradeFrame, "SecureActionButtonTemplate")
	button:SetAttribute("type", "target");
	button:SetAttribute("unit", "NPC");
	button:SetWidth(60)
	button:SetHeight(70)
	button:SetPoint("CENTER", "TradeFrame", "TOPLEFT", 210, -35);

	--for rightclick quick trade


	--for alt+leftclick quick trade
	-- 取按钮对应的背包号/槽位：现代客户端可能把容器按钮挂在"合并背包"窗口下，
	-- GetParent():GetID() 不再等于背包号，优先用 FrameXML 的换算函数。
	local function TBT_GetBagSlot(itemButton)
		if type(_G.ContainerFrameItemButton_CalculateItemSlot) == "function" then
			local ok, bag, slot = pcall(ContainerFrameItemButton_CalculateItemSlot, itemButton);
			if ok and bag and slot then return bag, slot end
		end
		local parent = itemButton:GetParent();
		if parent and parent.GetID and itemButton.GetID then
			return parent:GetID(), itemButton:GetID();
		end
		return nil, nil;
	end

	-- 时代版本里拍卖行相关全局函数在 modern 客户端已不存在，全部走能力探测
	C.HookGlobal("ContainerFrameItemButton_OnModifiedClick", function(self, button)
		local bag, slot = TBT_GetBagSlot(self);
		if not bag or not slot then return end

		if(button == "LeftButton" and IsAltKeyDown() ) then
			if(InboxFrame and InboxFrame:IsVisible()) then
				C.CallGlobal("MailFrameTab_OnClick", nil, 2);
			end
			if(SendMailAttachment1 and SendMailAttachment1:IsVisible()) then
				C.UseContainerItem(bag, slot);
			elseif(AuctionsItemButton and AuctionsItemButton:IsVisible()) then
				C.PickupContainerItem(bag, slot);
				C.CallGlobal("ClickAuctionSellItemButton");
				C.CallGlobal("AuctionsFrameAuctions_ValidateAuction");
				if(CursorHasItem()) then ClearCursor(); end;
			end
		end

		--for shift+leftclick start auction search directly.
		if(button == "LeftButton" and IsShiftKeyDown() and AuctionFrame and AuctionFrame:IsVisible()) then
			--[[
			AuctionFrameTab_OnClick(nil, 1);
			if(BrowseMinLevel and BrowseMaxLevel and BrowseDropDown and IsUsableCheckButton) then
				BrowseMinLevel:SetText("")
				BrowseMaxLevel:SetText("")
				UIDropDownMenu_SetText("",BrowseDropDown)
				UIDropDownMenu_SetSelectedName(BrowseDropDown)
				AuctionFrameBrowse.selectedClassIndex = nil;
				AuctionFrameBrowse.selectedClass = nil;
				IsUsableCheckButton:SetChecked(false);
				AuctionFrameFilters_Update();
			end
			]]
			C.ChatEdit_InsertLink(C.GetContainerItemLink(bag, slot));
			C.CallGlobal("AuctionFrameBrowse_Search");
		end

		if(button=="RightButton" and IsControlKeyDown() and IsAltKeyDown() and AuctionsItemButton and AuctionsItemButton:IsVisible()) then
			C.PickupContainerItem(bag, slot);
			C.CallGlobal("ClickAuctionSellItemButton");
			C.CallGlobal("AuctionsFrameAuctions_ValidateAuction");
			C.CallGlobal("AuctionsCreateAuctionButton_OnClick");
		end
	end)
	TBTFrame_OnPlayerEnter()
end

function TBTFrame_SetButtonSpell(button, spell)
	if not button then return end
	if not InCombatLockdown() then
		button:SetAttribute("type", "spell");
		button:SetAttribute("spell", spell);
		button.spellName = spell
	end
end

function TBT_TradeItem(self, type)
	local item, quantity,spell,maxRank,spells,i;
	if not TBT_MaxSpellRank then return end -- 法术书尚未扫描完成（TBTFrame_OnPlayerEnter）
	maxRank = TBT_MaxSpellRank[type];
	if(maxRank) then
		TBTFrame_SetButtonSpell(self, "");
		local spells, npcLevel;
		spells = TBT_SPELL_TABLE[type];
		npcLevel = UnitLevel("npc");

		for i=maxRank, 1,-1 do
			if(spells[i].level <= npcLevel) then
				item = spells[i].item;
				spell = TBT_GetSpellName(spells[i].name, spells[i].rank); --localization
				break;
			end
		end

		if(type=="water" or type=="food") then
			quantity=15;
		else
			quantity=1;
		end

		local bag, slot = TBT_FindItem(item, quantity, type)
		if(slot) then
			local emptySlot = false;
			for i=1,6 do
				if(not C.GetTradeItemInfo("Player", i)) then
					emptySlot = true;
				end;
			end
			if(emptySlot) then
				if(C.PickupContainerItem(bag, slot)) then
					if(StackSplitFrame) then StackSplitFrame:Hide(); end
					C.PlaceCursorItemInTrade();
					return;
				end
			end
		end
		TBTFrame_SetButtonSpell(self, spell);
	end
end

function GetCurrentMageSpell()
	-- 旧存档里 TBT_CurrentPortal 可能是字符串，做一次类型保护
	if type(TBT_CurrentPortal) ~= "table" then return nil end
	return TBT_CurrentPortal[1],TBT_CurrentPortal[2]
end

local function GetPortalTexture(spellName)
	if not spellName then return nil end
	return TBT_PORTAL_MAPPING[spellName]
end

function CreatePortalButtons(cbutton)
	if type(TBT_CurrentPortal) ~= "table" then return end
	TBT_MagePortalButtons = {}
	local radius = 45
	local angle = 22.5

	local button =CreateFrame("Button", "TradeFramePortalButtonCenter", TradeFrame, "TBTButtonTemplate");
	button:SetWidth(35);
	button:SetHeight(35);
	button:SetPoint("CENTER",cbutton,"CENTER")
	button:SetFrameStrata("DIALOG")
	TBTFrame_SetButtonSpell(button,TBT_CurrentPortal[1])
	button:Hide()
	button:SetScript("OnEnter",function(self)
		cbutton.stats='showed'
		TBTTooltip:ClearLines()
		TBTTooltip:SetOwner(self, "ANCHOR_LEFT");
		TBTTooltip:AddLine(self.spellName)
		TBTTooltip:Show()
	end)
	button:SetScript("OnLeave",function()
		TBTTooltip:Hide()
	end)

	button:SetScript("PreClick",function()
		cbutton.stats ='hidden'
	end)

	for _i,_spellInfo in pairs(TBT_MagePortals) do
		-- 用 math.cos/math.sin（全局 cos/sin 属 WoW 便利别名，wowf 上不保证存在）
		xoff = radius* math.cos(angle)
		yoff = radius* math.sin(angle)
		local button = CreateFrame("Button", "TradeFramePortalButton".._i, TradeFrame, "TBTButtonTemplate");
		button:SetWidth(26);
		button:SetHeight(26);
		button:SetNormalTexture(GetPortalTexture(_spellInfo[1]))
		button:SetFrameStrata("DIALOG")
		TBTFrame_SetButtonSpell(button,_spellInfo[1])
		button:SetPoint("CENTER",cbutton,"CENTER",-xoff,yoff)
		button:SetScript("OnLeave",function(button)
			TBTTooltip:Hide()
		end)
		button:SetScript("PreClick",function(button)
			TBT_CurrentPortal=_spellInfo
			TBTFrame_SetButtonSpell(cbutton,TBT_CurrentPortal[1])
			cbutton:SetNormalTexture(TBT_CurrentPortal[2]);
			cbutton.stats='hidden'
		end)
		button:SetScript("OnEnter",function(button)
			cbutton.stats='showed'
			TBTTooltip:ClearLines()
			TBTTooltip:SetOwner(button, "ANCHOR_LEFT");
			TBTTooltip:AddLine(button.spellName)
			TBTTooltip:Show()
		end)
		button:Hide()
		table.insert(TBT_MagePortalButtons,button)
		angle = angle + 45
	end
end

function TogglePortalPanel(tog)
	if tog == TBT_portalShown then return end
	-- 法师面板只在法术书里有传送门且按钮已创建时才有意义
	if not TBTPortalPanel or not TradeFramePortalButtonCenter
		or not TradeFramePlayerSpell3Button or type(TBT_CurrentPortal) ~= "table" then
		return
	end

	_G.TBTPortalPanel:SetPoint("CENTER",TradeFramePlayerSpell3Button,"CENTER")
	_G.TBTPortalPanel:SetAlpha(0.7)
	_G.TBTPortalPanel:SetFrameStrata("HIGH")
	TBTFrame_SetButtonSpell(TradeFramePortalButtonCenter,TBT_CurrentPortal[1])
	TradeFramePortalButtonCenter:SetNormalTexture(GetPortalTexture(TBT_CurrentPortal[1]))
	if tog then
		TBTPortalPanel:Show()
		TradeFramePortalButtonCenter:Show()
		for _,_button in pairs(TBT_MagePortalButtons) do
			_button:Show()
		end
	else
		TBTPortalPanel:Hide()
		TradeFramePortalButtonCenter:Hide()
		for _,_button in pairs(TBT_MagePortalButtons) do
			_button:Hide()
		end
	end
	TBT_portalShown= tog

end

function TBTFrame_CreateLeftButton(class)
	if(_G.TradeFramePlayerSpell1Button~=nil)then return end; --already created
	if not TradeFrame then return end -- 没有交易窗口就不做界面增强

	local button = nil;
	if(class=="MAGE") then
		--for make water button
		button = CreateFrame("Button", "TradeFramePlayerSpell1Button", TradeFrame, "TBTButtonTemplate");
		button:SetWidth(26);
		button:SetHeight(26);
		button:SetNormalTexture("Interface\\Icons\\inv_drink_18");
		button:SetPoint("TOPLEFT", "TradeFrame", "TOPLEFT", 60, -30);
		button:SetScript("PreClick", function(self) TBT_TradeItem(self, "water") end);
		button:SetScript("PostClick", function(self) TBTFrame_SetButtonSpell(self,"") end);

		button = CreateFrame("Button", "TradeFramePlayerSpell2Button", TradeFrame, "TBTButtonTemplate");
		button:SetWidth(26);
		button:SetHeight(26);
		button:SetNormalTexture("Interface\\Icons\\inv_misc_food_33");
		button:SetPoint("LEFT", "TradeFramePlayerSpell1Button", "RIGHT", 5, 0);
		button:SetScript("PreClick", function(self) TBT_TradeItem(self, "food") end);
		button:SetScript("PostClick", function(self) TBTFrame_SetButtonSpell(self,"") end);

		local spell,texture = GetCurrentMageSpell()
		if not spell then return end
		button = CreateFrame("Button", "TradeFramePlayerSpell3Button", TradeFrame, "TBTButtonTemplate");
		button:SetWidth(26);
		button:SetHeight(26);
		TBTFrame_SetButtonSpell(button,spell)
		button:SetNormalTexture(texture);
		button:SetPoint("LEFT", "TradeFramePlayerSpell2Button", "RIGHT", 5, 0);
		button:SetScript("PreClick", function(self) self.stats = 'hidden' end);
		button:SetScript("OnEnter", function(self)
			if not self.stats or self.stats =='hidden' then
				self.stats = 'entered'
				self.entertime = 0
			elseif self.stats =='left' then
				self.stats= 'showed'
			end
			--wait a second and pop up
			--pop up here
		end)

		button:SetScript("OnUpdate",function(self,elapsed)
			if not self.stats then return end
			if self.stats=='entered' then
				self.entertime = self.entertime + elapsed
			end
			if self.stats=='left' then
				self.lefttime = self.lefttime + elapsed
			end
			if self.stats=='entered' and self.entertime >=0.5 then
				self.stats='showed'
			end
			if self.stats=='left' and self.lefttime >=0.2 then
				self.stats='hidden'
			end
			if self.stats=='entered' or self.stats=='hidden' then
				TogglePortalPanel(false)
			elseif self.stats=='showed' or self.stats=='left' then
				TogglePortalPanel(true)
			end
		end)

		button:SetScript("OnLeave",function(self)
			if self.stats=='entered' then
				self.stats='hidden'
			end
		end)

		CreatePortalButtons(button)
	--	button:Hide()
		TBT_portalShown= false
	elseif (class=="WARLOCK") then
		button = CreateFrame("Button", "TradeFramePlayerSpell1Button", TradeFrame, "TBTButtonTemplate");
		button:SetWidth(26);
		button:SetHeight(26);
		button:SetNormalTexture("Interface\\Icons\\inv_stone_04");
		button:SetPoint("TOPLEFT", "TradeFrame", "TOPLEFT", 70, -30);
		button:SetScript("PreClick", function(self) TBT_TradeItem(self, "stone") end);
		button:SetScript("PostClick", function(self) TBTFrame_SetButtonSpell(self,"") end);
	elseif (class=="ROGUE") then
		button = CreateFrame("Button", "TradeFramePlayerSpell1Button", TradeFrame, "TBTButtonTemplate");
		button:SetWidth(30);
		button:SetHeight(30);
		button:SetNormalTexture("Interface\\Icons\\spell_nature_moonkey");
		button:SetPoint("TOPLEFT", "TradeFrame", "TOPLEFT", 70, -30);
		button:SetAttribute("type","spell");
		button:SetAttribute("spell", TBT_UNLOCK_SKILL_NAME);
		-- ClickTargetTradeButton 在 modern 客户端仍由 C 层提供，缺失时静默跳过
		button:SetScript("PostClick", function(self) C.ClickTargetTradeButton(7); end);
	end
end

TBT_MaxSpellRank = nil;

function TBTFrame_OnPlayerEnter()
	local _,class = UnitClass("player")


	if(TBT_MaxSpellRank==nil) then
		TBT_MaxSpellRank = {};
		if(class=="MAGE")then
			TBT_MagePortals= {}
		end
		--look through player's spell book
		-- wowf 已无 GetSpellInfo，改走 C_SpellBook（见 ForeverCompat.GetSpellBookItem）
		local i = 1
		local spellName, spellIcon,id;
		-- 上限 2000 只是防呆：现代法术书可能返回非 nil 的空名，避免死循环
		while i <= 2000 do
			spellName, spellIcon, id = C.GetSpellBookItem(i, BOOKTYPE_SPELL);

			if not spellName then
				do break end
			end

			if(class=="MAGE")then
				--collect portals

				if string.find(spellName,TBT_SPELL_PORTAL) then
					table.insert(TBT_MagePortals,{spellName,spellIcon})
				end
				UpdateMaxRank("water", id);
				UpdateMaxRank("food", id);
			elseif(class=="WARLOCK")then
				UpdateMaxRank("stone", id);
			end
			i = i + 1
		end
		if(class=="MAGE")then
			TBT_CurrentPortal = TBT_CurrentPortal or TBT_MagePortals and TBT_MagePortals[1]
		end
	end
	TBTFrame_CreateLeftButton(class);
end

function TBTFrame_OnEvent(self, event, ...)
	-- 现代客户端的拾取入口可能被 C_Loot 取代，缺失时直接跳过自动拾取
	if type(_G.GetNumLootItems) ~= "function" or type(_G.GetLootSlotInfo) ~= "function"
		or type(_G.LootSlot) ~= "function" then
		return
	end
	if(GetNumLootItems() == 1) then
		local iconPath = GetLootSlotInfo(1);
		if(iconPath and string.find(iconPath, "Interface\\Icons\\INV_Enchant_") == 1) then
			LootSlot(1);
		end
	end
end

local ids = {
	water = { 5504, 5505, 5506, 6217, 10138, 10139, 10140, },
	food = { 587, 597, 990, 6129, 10144, 10145, 28612,},
	stone = { 6201, 6202, 5699, 11729, 11730, },
}
function UpdateMaxRank(type, id)
	local spells = ids[type];
	local j;
	for j = 1, #spells do
		if spells[j] == id then
			if(not TBT_MaxSpellRank[type] or j > TBT_MaxSpellRank[type]) then
				TBT_MaxSpellRank[type] = j;
			end
		end
	end
end

function TBT_FindItem(item,quantity,type)
	local bag,slot,i;
	local myName = TBT_UnitName("player"); -- secret 名字时为 nil，见下方降级处理
	for bag=0,C.GetNumBags() do
		for slot=1,C.GetContainerNumSlots(bag) do
			local _, count, locked = C.GetContainerItemInfo(bag, slot)
			if (count and not locked and count >= quantity ) then
				local itemLink = C.GetContainerItemLink(bag, slot);
				local found, _, name = string.find(itemLink or "", "^|%x+|H.+|h%[(.+)%]")
				if (found and item == name) then
					TBT_debug("item==name",name);
					--to distinguish the healthstone made by other warlock
					if(type=="stone" and GameTooltip)then
						local maker = nil; -- nil 表示"无法判断制造者"
						GameTooltip:SetOwner(UIParent,"ANCHOR_LEFT");
						-- GameTooltip:SetBagItem 在现代可能被 C_Container 取代，由兼容层探测
						if C.GameTooltipSetBagItem(GameTooltip, bag, slot) then
							local numLines = GameTooltip.NumLines and GameTooltip:NumLines() or 0;
							for i=1,numLines,1 do
								local line = _G["GameTooltipTextLeft"..i];
								local text = line and line:GetText();
								if(text) then
									local _,_,makerText = string.find(text,TBT_GAMETOOLTIP_MADE_BY);
									if(makerText) then
										maker = makerText;
										break;
									end
								end
							end
						end
						GameTooltip:Hide();
						TBT_debug("name=",maker);
						if(maker)then
							if(not myName or maker==myName)then
								return bag,slot
							end
							-- 别人做的治疗石，继续找下一个
						else
							-- tooltip 不可用 / 没有"由 xx 制造"字样：无法区分，直接采用（降级）
							return bag, slot;
						end
					elseif (type~="stone") then
						return bag, slot;
					end
				end
			end
		end
	end
	return nil,nil
end

function TBT_GetSpellName(name, rank)
	if(rank) then
		rank, _ = string.gsub(TBT_SPELL_RANK_PATTERN,"%(%%d%)", rank)
		return name.."("..rank..")";
	else
		return name;
	end
end

--for {name, server} return "name-server"
function TBT_UnitName(unit)
	local name,server = UnitName(unit);
	if(not name)then return nil end
	-- 12.x 起 UnitName 可能返回 secret value：禁止拼接，交回 nil 让调用方降级
	if(C.IsSecret(name) or C.IsSecret(server))then return nil end
	if(server and server ~= "") then
		return name.."-"..server;
	else
		return name;
	end
end

function TBT_debug(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
	if(1) then return; end
	local msg = "";
	if(arg1) then msg = msg..arg1.."," else msg = msg.." ," end
	if(arg2) then msg = msg..arg2.."," else msg = msg.." ," end
	if(arg3) then msg = msg..arg3.."," else msg = msg.." ," end
	if(arg4) then msg = msg..arg4.."," else msg = msg.." ," end
	if(arg5) then msg = msg..arg5.."," else msg = msg.." ," end
	if(arg6) then msg = msg..arg6.."," else msg = msg.." ," end
	if(arg7) then msg = msg..arg7.."," else msg = msg.." ," end
	DEFAULT_CHAT_FRAME:AddMessage(msg);
end


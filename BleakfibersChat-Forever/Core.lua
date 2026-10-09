--[[
    Bleakfiber's Chat - Core.lua
    Gameplay & Event Engine: URL Detection, Universal Class Colors,
    Whisper Popout Routing, Persistent History, EditBox & Clutter Suppression
]]

local addonName, BFC = ...
BFC = LibStub("AceAddon-3.0"):NewAddon(BFC, "BleakfibersChat", "AceEvent-3.0", "AceHook-3.0")
_G["BleakfibersChatCore"] = BFC

-- Class color hex cache
local CLASS_COLORS = {}
for classToken, color in pairs(RAID_CLASS_COLORS) do
    CLASS_COLORS[classToken] = string.format("%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
end

-- Channel name shortening lookup
local CHANNEL_REPLACEMENTS = {
    ["%[(%d+)%.%s*.-%]"]     = "[%1]",
    ["%[Guild%]"]            = "[G]",
    ["%[Party%]"]            = "[P]",
    ["%[Party Leader%]"]     = "[PL]",
    ["%[Raid%]"]             = "[R]",
    ["%[Raid Leader%]"]      = "[RL]",
    ["%[Raid Warning%]"]     = "[RW]",
    ["%[Officer%]"]          = "[O]",
    ["%[Battleground%]"]     = "[BG]",
    ["%[Battleground Leader%]"] = "[BL]",
}

-- Session in-memory line buffer per frame for copy & export
BFC.sessionHistory = {}

--[[-----------------------------------------------------------------------------
    Lifecycle: OnInitialize & OnEnable
-------------------------------------------------------------------------------]]
function BFC:OnInitialize()
    self:InitDB()
    self:RegisterWithMasterConfig()

    -- Character key for persistent storage
    local charName = UnitName("player") or "Unknown"
    local realmName = GetRealmName() or "DefaultRealm"
    self.charKey = charName .. " - " .. realmName

    -- Ensure character storage table exists
    self.historyDB[self.charKey] = self.historyDB[self.charKey] or {
        frames = {},
        editBox = {},
    }
end

function BFC:OnEnable()
    self:SetupWhisperRouting()
    self:SetupClassColoring()
    self:SetupUrlDetection()
    self:SetupChatFrames()
    self:SetupEditBox()
    self:SetupChatHistory()

    self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

--[[-----------------------------------------------------------------------------
    Whispers to New Window / Tab by Default
-------------------------------------------------------------------------------]]
function BFC:SetupWhisperRouting()
    local db = self.db or {}
    if db.whisperWindow then
        -- Native Blizzard CVar for popout whisper tabs
        if SetCVar then
            SetCVar("whisperMode", "popout")
        end
    end

    self:RegisterEvent("CHAT_MSG_WHISPER", "OnWhisperMessage")
    self:RegisterEvent("CHAT_MSG_WHISPER_INFORM", "OnWhisperMessage")
    self:RegisterEvent("CHAT_MSG_BN_WHISPER", "OnWhisperMessage")
    self:RegisterEvent("CHAT_MSG_BN_WHISPER_INFORM", "OnWhisperMessage")
end

function BFC:OnWhisperMessage(event, msg, sender, ...)
    local db = self.db or {}
    if not db.whisperWindow then return end

    -- Ensure temporary whisper window/tab is active if supported
    if FCF_OpenTemporaryWindow and sender and sender ~= "" then
        local chatType = (event:find("BN_WHISPER")) and "BN_WHISPER" or "WHISPER"
        local frame = FCF_OpenTemporaryWindow(chatType, sender)
        if frame and db.whisperNotifyGlow then
            local tab = _G[frame:GetName() .. "Tab"]
            if tab and FCF_FlashTab then
                FCF_FlashTab(tab)
            end
        end
    end
end

--[[-----------------------------------------------------------------------------
    Universal Player Class Coloring
-------------------------------------------------------------------------------]]
function BFC:SetupClassColoring()
    local db = self.db or {}
    if not db.classColorNames then return end

    -- Enable native Blizzard class color flags across all chat types
    if ChatTypeInfo then
        local typesToColor = {
            "SAY", "EMOTE", "YELL", "WHISPER", "WHISPER_INFORM",
            "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING",
            "GUILD", "OFFICER", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER",
            "BN_WHISPER", "BN_WHISPER_INFORM",
        }
        for _, t in ipairs(typesToColor) do
            if ChatTypeInfo[t] then
                ChatTypeInfo[t].colorNameByClass = true
            end
        end
        for i = 1, 20 do
            local ch = "CHANNEL" .. i
            if ChatTypeInfo[ch] then
                ChatTypeInfo[ch].colorNameByClass = true
            end
        end
    end
end

-- Helper: Retrieve player class color hex
function BFC:GetPlayerClassHex(name, guid)
    if guid and guid ~= "" and GetPlayerInfoByGUID then
        local _, classToken = GetPlayerInfoByGUID(guid)
        if classToken and CLASS_COLORS[classToken] then
            return CLASS_COLORS[classToken]
        end
    end

    -- Check party/raid units
    if name and name ~= "" then
        local cleanName = name:match("^(.-)%-") or name
        for i = 1, GetNumGroupMembers() or 0 do
            local unit = (IsInRaid() and "raid" or "party") .. i
            if UnitName(unit) == cleanName then
                local _, classToken = UnitClass(unit)
                if classToken and CLASS_COLORS[classToken] then
                    return CLASS_COLORS[classToken]
                end
            end
        end
        if UnitName("player") == cleanName then
            local _, classToken = UnitClass("player")
            if classToken and CLASS_COLORS[classToken] then
                return CLASS_COLORS[classToken]
            end
        end
    end

    return nil
end

--[[-----------------------------------------------------------------------------
    URL Detection & Clickable Hyperlinks
-------------------------------------------------------------------------------]]
-- URL Regex Matching Patterns
local URL_PATTERNS = {
    -- Protocols: http://, https://, ftp://
    "(https?://%S+)",
    "(ftp://%S+)",
    -- WWW prefix: www.example.com
    "(www%.[%w_%.%+%-]+%.%a%a+/%S*)",
    "(www%.[%w_%.%+%-]+%.%a%a+)",
    -- Discord invitations
    "(discord%.gg/%S+)",
    "(discordapp%.com/invite/%S+)",
    -- Common domains with path
    "([%w_%.%+%-]+%.(?:com|org|net|io|gg|tv|de|ru|uk|ca|me|app)/%S+)",
}

local function FormatURL(url)
    return string.format("|cff33ccff|Hurl:%s|h[%s]|h|r", url, url)
end

function BFC:ProcessMessageText(message, sender, guid)
    if not message or message == "" then return message end
    local db = self.db or {}

    -- 1. URL Replacement
    if db.enableUrlLinks then
        for _, pattern in ipairs(URL_PATTERNS) do
            message = message:gsub(pattern, FormatURL)
        end
    end

    -- 2. Channel Name Shortening
    if db.shortChannelNames then
        for pat, repl in pairs(CHANNEL_REPLACEMENTS) do
            message = message:gsub(pat, repl)
        end
    end

    -- 3. Universal Player Class Coloring in Hyperlinks
    if db.classColorNames and sender and sender ~= "" then
        local classHex = self:GetPlayerClassHex(sender, guid)
        if classHex then
            -- Replace player link color with class color
            local searchStr = "|Hplayer:" .. sender
            if message:find(searchStr, 1, true) then
                local pat = "(|c%x%x%x%x%x%x%x%x)(|Hplayer:" .. sender .. ".-|h%[.-%]|h|r)"
                message = message:gsub(pat, "|cff" .. classHex .. "%2")
            end
        end
    end

    -- 4. Timestamps
    if db.showTimestamps and not message:find("^|c%x%x%x%x%x%x%x%x%[") then
        local tFormat = db.timestampFormat or "%H:%M"
        local tColor = db.timestampColor or { r = 0.55, g = 0.58, b = 0.63 }
        local hex = string.format("%02x%02x%02x", tColor.r * 255, tColor.g * 255, tColor.b * 255)
        local stamp = date(tFormat)
        if stamp and stamp ~= "" then
            message = string.format("|cff%s[%s]|r %s", hex, stamp, message)
        end
    end

    return message
end

function BFC:SetupUrlDetection()
    -- Hook SetItemRef to catch "url:" hyperlinks
    local orig_SetItemRef = SetItemRef
    SetItemRef = function(link, text, button, chatFrame)
        if link and link:sub(1, 4) == "url:" then
            local url = link:sub(5)
            if BFC.CopyFrame and BFC.CopyFrame.ShowURL then
                BFC.CopyFrame:ShowURL(url)
            end
            return
        end
        return orig_SetItemRef(link, text, button, chatFrame)
    end
end

--[[-----------------------------------------------------------------------------
    ChatFrame Modernization: MouseWheel, Buttons, Typography & Copy Button
-------------------------------------------------------------------------------]]
local copyButtons = {}

local function CreateCopyButton(chatFrame)
    local frameName = chatFrame:GetName()
    if not frameName or copyButtons[frameName] then return end

    local btn = CreateFrame("Button", frameName .. "BleakCopyBtn", chatFrame)
    btn:SetSize(16, 16)
    btn:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", -2, -2)
    btn:SetAlpha(0.35)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(btn)
    icon:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
    btn.icon = icon

    btn:SetScript("OnEnter", function(self)
        self:SetAlpha(1.0)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("|cffffd100Copy Chat Log|r", 1, 1, 1)
        GameTooltip:AddLine("Click to open plain-text copy window for this chat tab.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetAlpha(0.35)
        GameTooltip:Hide()
    end)
    btn:SetScript("OnClick", function()
        if BFC.CopyFrame and BFC.CopyFrame.ShowChatLog then
            BFC.CopyFrame:ShowChatLog(chatFrame)
        end
    end)

    copyButtons[frameName] = btn
end

function BFC:SetupChatFrames()
    local db = self.db or {}
    local numWindows = NUM_CHAT_WINDOWS or 7

    -- Suppress Blizzard Intrusive Buttons
    if db.hideChatButtons then
        if ChatFrameMenuButton then
            ChatFrameMenuButton:Hide()
            ChatFrameMenuButton:HookScript("OnShow", ChatFrameMenuButton.Hide)
        end
        if ChatFrameChannelButton then
            ChatFrameChannelButton:Hide()
            ChatFrameChannelButton:HookScript("OnShow", ChatFrameChannelButton.Hide)
        end
    end

    for i = 1, numWindows do
        local cf = _G["ChatFrame" .. i]
        if cf then
            -- Unclamp frame to allow flush screen placement
            if db.unclampFromScreen then
                cf:SetClampedToScreen(false)
            end

            -- Mousewheel scrolling (Smooth + Shift jump)
            if db.enableMouseWheel then
                cf:EnableMouseWheel(true)
                cf:SetScript("OnMouseWheel", function(self, delta)
                    if delta > 0 then
                        if IsShiftKeyDown() then
                            self:ScrollToTop()
                        else
                            self:ScrollUp()
                        end
                    elseif delta < 0 then
                        if IsShiftKeyDown() then
                            self:ScrollToBottom()
                        else
                            self:ScrollDown()
                        end
                    end
                end)
            end

            -- Hide scroll up/down/bottom buttons if requested
            if db.hideScrollButtons then
                local bottomBtn = _G["ChatFrame" .. i .. "BottomButton"]
                if bottomBtn then
                    bottomBtn:Hide()
                    bottomBtn:HookScript("OnShow", bottomBtn.Hide)
                end
                local upBtn = _G["ChatFrame" .. i .. "UpButton"]
                if upBtn then
                    upBtn:Hide()
                    upBtn:HookScript("OnShow", upBtn.Hide)
                end
                local downBtn = _G["ChatFrame" .. i .. "DownButton"]
                if downBtn then
                    downBtn:Hide()
                    downBtn:HookScript("OnShow", downBtn.Hide)
                end
            end

            -- Typography
            self:ApplyFrameTypography(cf)

            -- In-memory session tracking & Hook AddMessage
            local fName = cf:GetName()
            self.sessionHistory[fName] = self.sessionHistory[fName] or {}

            if not cf._bfcAddMessageHooked then
                local origAddMessage = cf.AddMessage
                cf.AddMessage = function(frame, msg, r, g, b, id, ...)
                    -- Run text formatting pipeline
                    local processed = BFC:ProcessMessageText(msg)

                    -- Record to session memory
                    table.insert(BFC.sessionHistory[fName], processed)
                    if #BFC.sessionHistory[fName] > 500 then
                        table.remove(BFC.sessionHistory[fName], 1)
                    end

                    -- Record to persistent SavedVariables if enabled and not currently restoring
                    if not BFC.isRestoringHistory and BFC.db and BFC.db.enableChatHistory then
                        local charStore = BFC.historyDB[BFC.charKey]
                        if charStore and charStore.frames then
                            charStore.frames[fName] = charStore.frames[fName] or {}
                            local frameList = charStore.frames[fName]
                            table.insert(frameList, { text = processed, r = r, g = g, b = b, time = time() })
                            local maxLines = BFC.db.chatHistoryLines or 200
                            while #frameList > maxLines do
                                table.remove(frameList, 1)
                            end
                        end
                    end

                    return origAddMessage(frame, processed, r, g, b, id, ...)
                end
                cf._bfcAddMessageHooked = true
            end

            -- Add Copy Button to tab
            CreateCopyButton(cf)
        end
    end
end

function BFC:ApplyFrameTypography(chatFrame)
    local db = self.db or {}
    local fontName = db.font or "Nata Sans Regular"
    local fontSize = db.fontSize or 12
    local fontOutline = db.fontOutline or "OUTLINE"
    local fontPath = self.FetchFont and self:FetchFont(fontName) or "Fonts\\FRIZQT__.TTF"

    chatFrame:SetFont(fontPath, fontSize, fontOutline)
end

--[[-----------------------------------------------------------------------------
    Persistent Chat History & Session Divider
-------------------------------------------------------------------------------]]
function BFC:SetupChatHistory()
    -- Initialized; restored on PLAYER_ENTERING_WORLD
end

function BFC:PLAYER_ENTERING_WORLD()
    local db = self.db or {}
    if not db.enableChatHistory then return end

    local charStore = self.historyDB[self.charKey]
    if not (charStore and charStore.frames) then return end

    self.isRestoringHistory = true
    local numWindows = NUM_CHAT_WINDOWS or 7

    for i = 1, numWindows do
        local cf = _G["ChatFrame" .. i]
        if cf then
            local fName = cf:GetName()
            local savedLines = charStore.frames[fName]
            if savedLines and #savedLines > 0 then
                -- Print session divider
                if db.showSessionDivider then
                    cf:AddMessage("|cff666666------------- Previous Session -------------|r", 0.5, 0.5, 0.5)
                end
                for _, entry in ipairs(savedLines) do
                    cf:AddMessage(entry.text, entry.r or 1, entry.g or 1, entry.b or 1)
                end
            end
        end
    end

    self.isRestoringHistory = false
end

-- Public extraction helper for CopyFrame
function BFC:GetChatFrameMessages(chatFrame)
    local fName = chatFrame and chatFrame.GetName and chatFrame:GetName()
    if fName and self.sessionHistory[fName] then
        return self.sessionHistory[fName]
    end
    return {}
end

-- Open copy dialog for active/selected chat frame
function BFC:OpenActiveChatCopy()
    local active = SELECTED_CHAT_FRAME or ChatFrame1
    if self.CopyFrame and self.CopyFrame.ShowChatLog then
        self.CopyFrame:ShowChatLog(active)
    end
end

--[[-----------------------------------------------------------------------------
    EditBox Modernization: Docking, Sticky Channels & Command Memory
-------------------------------------------------------------------------------]]
function BFC:SetupEditBox()
    local db = self.db or {}

    -- Sticky Channels Configuration
    if db.stickyChannels and ChatTypeInfo then
        local stickyList = { "SAY", "PARTY", "RAID", "GUILD", "OFFICER", "WHISPER", "CHANNEL" }
        for _, t in ipairs(stickyList) do
            if ChatTypeInfo[t] then
                ChatTypeInfo[t].sticky = 1
            end
        end
    end

    -- Reposition EditBox (Bottom or Top)
    for i = 1, NUM_CHAT_WINDOWS or 7 do
        local eb = _G["ChatFrame" .. i .. "EditBox"]
        if eb then
            self:PositionEditBox(eb, _G["ChatFrame" .. i])
        end
    end
end

function BFC:PositionEditBox(editBox, chatFrame)
    local db = self.db or {}
    if not (editBox and chatFrame) then return end

    editBox:ClearAllPoints()
    if db.editBoxPosition == "TOP" then
        editBox:SetPoint("BOTTOMLEFT", chatFrame, "TOPLEFT", -5, 26)
        editBox:SetPoint("BOTTOMRIGHT", chatFrame, "TOPRIGHT", 5, 26)
    else
        -- Standard BOTTOM docking
        editBox:SetPoint("TOPLEFT", chatFrame, "BOTTOMLEFT", -5, -8)
        editBox:SetPoint("TOPRIGHT", chatFrame, "BOTTOMRIGHT", 5, -8)
    end
end

--[[-----------------------------------------------------------------------------
    Live Settings Application
-------------------------------------------------------------------------------]]
function BFC:ApplySettings()
    self:SetupWhisperRouting()
    self:SetupClassColoring()
    self:SetupChatFrames()
    self:SetupEditBox()
end

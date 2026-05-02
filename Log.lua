-- LibCodex-1.0 / Log.lua
-- A dedicated, scrollable log window. All /codex output is appended here.
-- Chat echo defaults to ON but can be toggled, so verbose introspection
-- doesn't pollute the player's general chat. Mirrors the design used in
-- GPSGuide/Log.lua so the user already knows the controls.
--
-- Public API (also exposed via LibStub("LibCodex-1.0").Log):
--   Print(msg)         append to log + (optionally) chat
--   Show()/Hide()/Toggle()
--   SetEcho(bool)      enable/disable chat echo (persists in LibCodexDB.logEcho)
--   IsEchoing()
--   Clear()            wipe window + copy buffer
--   OpenCopy()         pop up a select-all editbox with full log text
--   GetText()          return full log as plain text (color codes stripped)
--   LoadPrefs()        pull persisted echo flag from LibCodexDB

local LibCodex = LibStub("LibCodex-1.0")
LibCodex.Log = LibCodex.Log or {}
local L = LibCodex.Log

local frame
local copyPopup
local MAX_LINES = 500
local echoToChat = true
local logLines = {}   -- mirror of every appended line, for the copy popup

local function stripColors(s)
    s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
    s = s:gsub("|r", "")
    return s
end

local function timestamp()
    if not date then return "" end
    local ok, s = pcall(date, "%H:%M:%S")
    if ok then return s end
    return ""
end

-- ----------------------------------------------------------------------------
-- Main log window. Built lazily on first show/print.
-- ----------------------------------------------------------------------------
local function buildFrame()
    if frame or not CreateFrame then return frame end

    frame = CreateFrame("Frame", "LibCodexLogFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(560, 340)
    frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -120)
    frame:SetMovable(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(360, 200, 1200, 800)
    end
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("MEDIUM")

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOP", frame.TitleBg, "TOP", 0, -3)
    frame.title:SetText("LibCodex Log")

    frame.smf = CreateFrame("ScrollingMessageFrame", nil, frame)
    frame.smf:SetPoint("TOPLEFT", 14, -32)
    frame.smf:SetPoint("BOTTOMRIGHT", -14, 36)
    frame.smf:SetFontObject(GameFontHighlightSmall)
    frame.smf:SetJustifyH("LEFT")
    frame.smf:SetMaxLines(MAX_LINES)
    frame.smf:SetFading(false)
    frame.smf:SetHyperlinksEnabled(true)
    frame.smf:EnableMouseWheel(true)
    frame.smf:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            if IsShiftKeyDown() then self:ScrollToTop() else self:ScrollUp() end
        else
            if IsShiftKeyDown() then self:ScrollToBottom() else self:ScrollDown() end
        end
    end)

    -- Bottom row: Clear, Echo toggle, Copy, Newest.
    frame.clearBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.clearBtn:SetSize(70, 22)
    frame.clearBtn:SetPoint("BOTTOMLEFT", 12, 8)
    frame.clearBtn:SetText("Clear")
    frame.clearBtn:SetScript("OnClick", function() L.Clear() end)

    frame.echoBtn = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    frame.echoBtn:SetSize(22, 22)
    frame.echoBtn:SetPoint("LEFT", frame.clearBtn, "RIGHT", 8, 0)
    frame.echoBtn.text = frame.echoBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.echoBtn.text:SetPoint("LEFT", frame.echoBtn, "RIGHT", 2, 0)
    frame.echoBtn.text:SetText("Echo to chat")
    frame.echoBtn:SetScript("OnClick", function(self)
        L.SetEcho(self:GetChecked() and true or false)
    end)

    frame.bottomBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.bottomBtn:SetSize(80, 22)
    frame.bottomBtn:SetPoint("BOTTOMRIGHT", -12, 8)
    frame.bottomBtn:SetText("Newest")
    frame.bottomBtn:SetScript("OnClick", function() frame.smf:ScrollToBottom() end)

    frame.copyBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.copyBtn:SetSize(70, 22)
    frame.copyBtn:SetPoint("RIGHT", frame.bottomBtn, "LEFT", -6, 0)
    frame.copyBtn:SetText("Copy")
    frame.copyBtn:SetScript("OnClick", function() L.OpenCopy() end)

    -- Resize grip in the bottom-right corner.
    frame.resize = CreateFrame("Button", nil, frame)
    frame.resize:SetSize(16, 16)
    frame.resize:SetPoint("BOTTOMRIGHT", -2, 2)
    frame.resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    frame.resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    frame.resize:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
    frame.resize:SetScript("OnMouseUp", function() frame:StopMovingOrSizing() end)

    frame:Hide()
    return frame
end

-- ----------------------------------------------------------------------------
-- Public API.
-- ----------------------------------------------------------------------------
function L.Print(msg)
    if msg == nil then return end
    msg = tostring(msg)
    buildFrame()
    local ts = timestamp()
    local line = (ts ~= "" and ("|cff888888[" .. ts .. "]|r ") or "") .. msg
    if frame and frame.smf then frame.smf:AddMessage(line) end
    table.insert(logLines, line)
    if #logLines > MAX_LINES then table.remove(logLines, 1) end
    if echoToChat and print then print(msg) end
end

function L.Clear()
    if frame and frame.smf then frame.smf:Clear() end
    logLines = {}
end

function L.Show()
    buildFrame()
    if not frame then return end
    if frame.echoBtn then frame.echoBtn:SetChecked(echoToChat) end
    frame:Show()
end

function L.Hide()
    if frame then frame:Hide() end
end

function L.Toggle()
    buildFrame()
    if not frame then return end
    if frame:IsShown() then frame:Hide() else L.Show() end
end

function L.SetEcho(on)
    echoToChat = on and true or false
    if frame and frame.echoBtn then frame.echoBtn:SetChecked(echoToChat) end
    LibCodexDB = LibCodexDB or {}
    LibCodexDB.logEcho = echoToChat
end

function L.IsEchoing() return echoToChat end

function L.GetText()
    if #logLines == 0 then return "(log is empty)" end
    local plain = {}
    for i, l in ipairs(logLines) do plain[i] = stripColors(l) end
    return table.concat(plain, "\n")
end

function L.LoadPrefs()
    if LibCodexDB and LibCodexDB.logEcho ~= nil then
        echoToChat = LibCodexDB.logEcho and true or false
    end
end

-- ----------------------------------------------------------------------------
-- Copy popup. Built lazily.
-- ----------------------------------------------------------------------------
local function buildCopyPopup()
    if copyPopup or not CreateFrame then return copyPopup end
    copyPopup = CreateFrame("Frame", "LibCodexLogCopyPopup", UIParent, "BasicFrameTemplateWithInset")
    copyPopup:SetSize(580, 380)
    copyPopup:SetPoint("CENTER")
    copyPopup:SetMovable(true)
    copyPopup:EnableMouse(true)
    copyPopup:RegisterForDrag("LeftButton")
    copyPopup:SetScript("OnDragStart", copyPopup.StartMoving)
    copyPopup:SetScript("OnDragStop", copyPopup.StopMovingOrSizing)
    copyPopup:SetClampedToScreen(true)
    copyPopup:SetFrameStrata("DIALOG")

    copyPopup.title = copyPopup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    copyPopup.title:SetPoint("TOP", copyPopup.TitleBg, "TOP", 0, -3)
    copyPopup.title:SetText("LibCodex Log - Copy (Ctrl+A then Ctrl+C)")

    copyPopup.scroll = CreateFrame("ScrollFrame", nil, copyPopup, "UIPanelScrollFrameTemplate")
    copyPopup.scroll:SetPoint("TOPLEFT", 14, -32)
    copyPopup.scroll:SetPoint("BOTTOMRIGHT", -34, 40)

    copyPopup.edit = CreateFrame("EditBox", nil, copyPopup.scroll)
    copyPopup.edit:SetMultiLine(true)
    copyPopup.edit:SetAutoFocus(true)
    copyPopup.edit:SetFontObject(ChatFontNormal)
    copyPopup.edit:SetWidth(520)
    copyPopup.edit:SetScript("OnEscapePressed", function() copyPopup:Hide() end)
    copyPopup.scroll:SetScrollChild(copyPopup.edit)

    copyPopup.closeBtn = CreateFrame("Button", nil, copyPopup, "UIPanelButtonTemplate")
    copyPopup.closeBtn:SetSize(80, 22)
    copyPopup.closeBtn:SetPoint("BOTTOMRIGHT", -12, 10)
    copyPopup.closeBtn:SetText("Close")
    copyPopup.closeBtn:SetScript("OnClick", function() copyPopup:Hide() end)

    copyPopup:Hide()
    return copyPopup
end

function L.OpenCopy()
    buildCopyPopup()
    if not copyPopup then return end
    copyPopup.edit:SetText(L.GetText())
    copyPopup:Show()
    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, function()
            if copyPopup and copyPopup:IsShown() then
                copyPopup.edit:SetFocus()
                copyPopup.edit:HighlightText()
            end
        end)
    elseif copyPopup.edit then
        copyPopup.edit:SetFocus()
        copyPopup.edit:HighlightText()
    end
end

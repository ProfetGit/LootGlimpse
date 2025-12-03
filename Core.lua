local LootGlimpse = LibStub("AceAddon-3.0"):NewAddon("LootGlimpse", "AceEvent-3.0", "AceConsole-3.0")
local LSM = LibStub("LibSharedMedia-3.0", true)



-- Helper to escape magic characters for pattern generation
local function EscapePattern(str)
    str = string.gsub(str, "([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
    str = string.gsub(str, "%%%%s", "(.-)") -- Capture string
    str = string.gsub(str, "%%%%d", "(%%d+)") -- Capture number
    return "^".. str.. "$"
end

-- Cache patterns at load time
local patterns = {
    EscapePattern(LOOT_ITEM_SELF_MULTIPLE), -- "You receive loot: %sx%d."
    EscapePattern(LOOT_ITEM_PUSHED_SELF_MULTIPLE), -- "You receive item: %sx%d."
    EscapePattern(LOOT_ITEM_SELF),          -- "You receive loot: %s."
    EscapePattern(LOOT_ITEM_PUSHED_SELF),   -- "You receive item: %s."
}

function LootGlimpse:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("LootGlimpseDB", {
        profile = {
            duration = 4,
            scale = 1.0,
            -- height = 50, -- Removed
            -- iconSize = 40, -- Removed
            maxItems = 5,
            fontSize = 14,
            font = "Friz Quadrata TT",
            fontOutline = "OUTLINE",
            gradientIntensity = 0.2,
            growDirection = "UP",
            qualityFilter = 0, -- Poor
            qualityFilter = 0, -- Poor
            -- showQualityBorder = false, -- Removed
            useQualityBackground = false,
            showGold = true,
            backdropTheme = "Classic",
            backgroundColor = { r = 0.404, g = 0.404, b = 0.404, a = 0.5 },
            animationType = "Fade",
        }
    }, true)

    self.framePool = {}
    self.activeFrames = {}

    -- Edit Mode Integration
    local LibEditMode = LibStub("EditModeExpanded-1.0")
    if LibEditMode then
        self.anchor = CreateFrame("Frame", "LootGlimpseAnchor", UIParent)
        self.anchor:SetSize(self.db.profile.width or 200, (self.db.profile.height or 50) * 4) -- Fallback width, taller height for list
        self.anchor:SetPoint("CENTER", 0, 200)
        
        -- Initialize DB for Edit Mode if not present
        if not self.db.profile.editMode then
            self.db.profile.editMode = {
                x = 0,
                y = 200,
                point = "CENTER",
                relativePoint = "CENTER",
            }
        end
        
        -- Register Frame
        -- Sync settings from profile to Edit Mode DB to prevent defaults (100)
        if not self.db.profile.editMode.settings then self.db.profile.editMode.settings = {} end
        
        -- Frame Size (16)
        if not self.db.profile.editMode.settings[16] then
            self.db.profile.editMode.settings[16] = (self.db.profile.scale or 1) * 100
        end

        -- Sliders (18)
        if not self.db.profile.editMode.settings[18] then self.db.profile.editMode.settings[18] = {} end
        if not self.db.profile.editMode.settings[18]["duration"] then
            self.db.profile.editMode.settings[18]["duration"] = self.db.profile.duration
        end
        if not self.db.profile.editMode.settings[18]["maxItems"] then
            self.db.profile.editMode.settings[18]["maxItems"] = self.db.profile.maxItems
        end

        -- Custom Checkboxes (12)
        if not self.db.profile.editMode.settings[12] then self.db.profile.editMode.settings[12] = {} end
        if not self.db.profile.editMode.settings[12]["growUpwards"] then
            self.db.profile.editMode.settings[12]["growUpwards"] = (self.db.profile.growDirection == "UP") and 1 or 0
        end
        
        -- Register Frame
        -- Pass false for clamped (6th arg) to disable "Clamp to Screen" default and setting
        LibEditMode:RegisterFrame(self.anchor, "Loot Glimpse", self.db.profile.editMode, UIParent, "CENTER", false)
        
        -- Standard Scale Slider (Frame Size)
        LibEditMode:RegisterResizable(self.anchor)
        
        -- Register Settings
        LibEditMode:RegisterSlider(self.anchor, "Duration", "duration", function(value) 
            self.db.profile.duration = value 
        end, 1, 10, 0.5)

        LibEditMode:RegisterSlider(self.anchor, "Max Items", "maxItems", function(value) 
            self.db.profile.maxItems = value
            self:UpdateLayout()
            if self.previewFrames then
                self:TogglePreview(false)
                self:TogglePreview(true)
            end
        end, 1, 10, 1)

        -- Grow Direction (Checkbox: Grow Upwards)
        LibEditMode:RegisterCustomCheckbox(self.anchor, "Grow Upwards", 
            function() -- OnChecked
                self.db.profile.growDirection = "UP"
                self:UpdateLayout()
            end,
            function() -- OnUnchecked
                self.db.profile.growDirection = "DOWN"
                self:UpdateLayout()
            end,
            "growUpwards" -- internalName
        )
        
        -- Hook into the frame's movement to ensure layout updates
        self.anchor:HookScript("OnDragStop", function()
             self:UpdateLayout()
        end)

        -- Hook Edit Mode Enter/Exit for Preview
        if EditModeManagerFrame then
            hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function() self:TogglePreview(true) end)
            hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function() self:TogglePreview(false) end)
        end
    else
        -- Fallback
        self.anchor = CreateFrame("Frame", "LootGlimpseAnchor", UIParent)
        self.anchor:SetSize(self.db.profile.width or 200, self.db.profile.height)
        self.anchor:SetPoint("CENTER", 0, 200)
    end

    self:RegisterEvent("CHAT_MSG_LOOT")
    self:RegisterEvent("CHAT_MSG_MONEY")
    self:RegisterChatCommand("lg", "SlashCommand")
    self:RegisterChatCommand("lootglimpse", "SlashCommand")
    
    self:SetupOptions()
end

function LootGlimpse:SlashCommand(input)
    local cmd, arg = input:match("^(%S*)%s*(.-)$")
    
    if cmd == "test" then
        self:RunTest(arg)
    else
        -- Open config
        Settings.OpenToCategory(self.settingsCategory:GetID())
    end
end

function LootGlimpse:CHAT_MSG_MONEY(event, message)
    if not self.db.profile.showGold then return end
    
    -- Extract the money string (e.g., "5 Gold 20 Silver")
    -- Usually starts with a number.
    local moneyString = message:match("(%d+.+)")
    
    -- Remove trailing dot if present
    if moneyString and moneyString:sub(-1) == "." then
        moneyString = moneyString:sub(1, -2)
    end
    
    if moneyString then
        local icon = "Interface\\Icons\\INV_Misc_Coin_02" -- Default Gold
        
        if moneyString:find("Gold") then
            icon = "Interface\\Icons\\INV_Misc_Coin_02"
        elseif moneyString:find("Silver") then
            icon = "Interface\\Icons\\INV_Misc_Coin_04"
        elseif moneyString:find("Copper") then
            icon = "Interface\\Icons\\INV_Misc_Coin_06"
        end
        
        self:QueueLootDisplay(moneyString, 1, icon, nil, nil)
    end
end

function LootGlimpse:CHAT_MSG_LOOT(event, message)
    for _, pattern in ipairs(patterns) do
        local item, quantity = message:match(pattern)
        if item then
            if tonumber(item) then 
                quantity, item = item, quantity 
            end
            
            -- Extract info from item link
            local name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice = C_Item.GetItemInfo(item)
            
            -- Quality Filter
            if quality and quality < self.db.profile.qualityFilter then
                return
            end

            if name then
                self:QueueLootDisplay(name, quantity or 1, texture, quality, link)
            else
                -- If info not ready, just show the string (might be a link)
                self:QueueLootDisplay(item, quantity or 1, nil, nil, item)
            end
            return
        end
    end
end

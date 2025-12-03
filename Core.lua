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
        -- Pass false for clamped (6th arg) to disable "Clamp to Screen" default and setting
        LibEditMode:RegisterFrame(self.anchor, "LootGlimpse", self.db.profile.editMode, UIParent, "CENTER", false)
        
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
        if arg == "waterfall" then
             -- Spawn multiple items
             -- Spawn items of every rarity
             local items = {
                 750,    -- Poor (Ruined Pelt)
                 6948,   -- Common (Hearthstone)
                 2520,   -- Uncommon (Copper Claymore)
                 1482,   -- Rare (Shadowfang)
                 873,    -- Epic (Staff of Jordan)
                 19019,  -- Legendary (Thunderfury)
                 120978, -- Artifact (Ashbringer)
                 122370, -- Heirloom (Burnished Polished Breastplate)
             }
             
             local delay = 0
             for _, itemID in ipairs(items) do
                 C_Timer.After(delay, function()
                     local item = Item:CreateFromItemID(itemID)
                     item:ContinueOnItemLoad(function()
                         local name, link, quality, _, _, _, _, _, _, texture = C_Item.GetItemInfo(itemID)
                         if name then
                             self:QueueLootDisplay(name, 1, texture, quality, link)
                         end
                     end)
                 end)
                 delay = delay + 0.3
             end
        else
            self:QueueLootDisplay("Hearthstone", 1, "Interface\\Icons\\inv_misc_rune_01", 1, "item:6948")
        end
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

function LootGlimpse:GetFrame()
    local f = table.remove(self.framePool)
    if not f then
        f = CreateFrame("Frame", nil, self.anchor, "BackdropTemplate")
        
        -- Content Frame (for animation isolation)
        f.content = CreateFrame("Frame", nil, f)
        f.content:SetAllPoints(f)
        
        -- Icon
        f.icon = f.content:CreateTexture(nil, "ARTWORK")
        f.icon:SetPoint("LEFT", 5, 0)

        -- Count
        f.count = f.content:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        f.count:SetPoint("BOTTOMRIGHT", f.icon, "BOTTOMRIGHT", -2, 2)
        f.count:SetJustifyH("RIGHT")
        
        -- Text
        f.text = f.content:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med1")
        f.text:SetPoint("LEFT", f.icon, "RIGHT", 10, 0)
        f.text:SetPoint("RIGHT", -5, 0)
        f.text:SetJustifyH("LEFT")
        f.text:SetWordWrap(false)
        
        -- Background
        f.bg = f.content:CreateTexture(nil, "BACKGROUND")
        f.bg:SetAllPoints(f.content)
        
        -- Border (Custom for fading effect)
        f.borderLeft = f.content:CreateTexture(nil, "BORDER")
        f.borderLeft:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, 0)
        f.borderLeft:SetPoint("BOTTOMLEFT", f.content, "BOTTOMLEFT", 0, 0)
        f.borderLeft:SetWidth(1)
        
        f.borderTop = f.content:CreateTexture(nil, "BORDER")
        f.borderTop:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, 0)
        f.borderTop:SetPoint("TOPRIGHT", f.content, "TOPRIGHT", 0, 0)
        f.borderTop:SetHeight(1)
        
        f.borderBottom = f.content:CreateTexture(nil, "BORDER")
        f.borderBottom:SetPoint("BOTTOMLEFT", f.content, "BOTTOMLEFT", 0, 0)
        f.borderBottom:SetPoint("BOTTOMRIGHT", f.content, "BOTTOMRIGHT", 0, 0)
        f.borderBottom:SetHeight(1)

        -- Animation Groups (Attached to content)
        f.animInGroup = f.content:CreateAnimationGroup()
        f.animInGroup:SetScript("OnFinished", function()
             -- Reset Content Position
             f.content:ClearAllPoints()
             f.content:SetAllPoints(f)
             
             -- Start Hold Timer
             local duration = tonumber(self.db.profile.duration) or 4
             f.holdTimer = C_Timer.NewTimer(duration, function()
                 f.animOutGroup:Play()
             end)
        end)

        f.animOutGroup = f.content:CreateAnimationGroup()
        f.animOutGroup:SetScript("OnFinished", function()
            self:RecycleFrame(f)
        end)

        -- Mouse Interaction (Keep on f)
        f:EnableMouse(true)
        f:SetScript("OnEnter", function(self)
            -- Stop Exit Animation if playing
            if self.animOutGroup:IsPlaying() then
                self.animOutGroup:Stop()
            end
            
            -- Cancel Hold Timer
            if self.holdTimer then
                self.holdTimer:Cancel()
                self.holdTimer = nil
            end
            
            self:SetAlpha(1)
            self.isHovered = true
            LootGlimpse:UpdateBackground(self)
            
            if self.link then
                GameTooltip:SetOwner(self, "ANCHOR_NONE")
                GameTooltip:SetPoint("TOPRIGHT", self.icon, "TOPLEFT", -5, 0)
                GameTooltip:SetHyperlink(self.link)
                GameTooltip:Show()
            end
        end)
        f:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
            self.isHovered = false
            LootGlimpse:UpdateBackground(self)
            
            -- Restart Hold Timer
            local duration = tonumber(LootGlimpse.db.profile.duration) or 4
            self.holdTimer = C_Timer.NewTimer(duration, function()
                 self.animOutGroup:Play()
            end)
        end)
    end
    
    -- Ensure parent is correct (inherits scale)
    f:SetParent(self.anchor)
    
    -- Reset State
    f:SetAlpha(1)
    f:Show()
    f.content:ClearAllPoints()
    f.content:SetAllPoints(f)
    f.animInGroup:Stop()
    f.animOutGroup:Stop()
    if f.holdTimer then f.holdTimer:Cancel() f.holdTimer = nil end
    f.link = nil
    f.isHovered = false
    
    -- Apply Visuals
    self:ApplyVisuals(f)
    
    return f
end

function LootGlimpse:UpdateFrameSize(f)
    local iconSize = 40
    local padding = 10
    local textWidth = f.text:GetStringWidth() or 0
    local totalWidth = 5 + iconSize + padding + textWidth + 15
    
    if totalWidth < 150 then totalWidth = 150 end
    f:SetWidth(totalWidth)
end

function LootGlimpse:ApplyVisuals(f)
    local db = self.db.profile
    
    -- Fixed sizes as requested
    local ITEM_HEIGHT = 50
    local ICON_SIZE = 40
    
    f:SetHeight(ITEM_HEIGHT)
    f.icon:SetSize(ICON_SIZE, ICON_SIZE)
    
    -- Font
    local fontPath = LSM and LSM:Fetch("font", db.font) or "Fonts\\FRIZQT__.TTF"
    if not fontPath then fontPath = "Fonts\\FRIZQT__.TTF" end
    
    local outline = db.fontOutline
    if outline == "NONE" then outline = "" end
    
    f.text:SetFont(fontPath, db.fontSize, outline)
    
    -- Force text refresh to ensure font change applies
    local currentText = f.text:GetText()
    if currentText then
        f.text:SetText(currentText)
    end
    
    self:UpdateBackground(f)
    self:UpdateFrameSize(f)
end

function LootGlimpse:UpdateBackground(f)
    local db = self.db.profile
    
    -- Determine Color
    local c = db.backgroundColor
    local r, g, b, a = c.r, c.g, c.b, c.a
    
    if db.useQualityBackground and f.quality then
        r, g, b = C_Item.GetItemQualityColor(f.quality)
        a = 0.5 -- Force alpha for quality background to avoid being too dark/transparent
    end

    -- Hover Effect: Brighten background significantly
    local hoverBoost = 0
    if f.isHovered then
        hoverBoost = 0.3
        r = math.min(1, r + hoverBoost)
        g = math.min(1, g + hoverBoost)
        b = math.min(1, b + hoverBoost)
        a = math.min(1, a + hoverBoost)
    end

    -- Background & Theme
    if db.backdropTheme == "Classic" then
        f.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        local intensity = db.gradientIntensity + hoverBoost
        if intensity < 0.2 then intensity = 0.2 end
        if intensity > 1 then intensity = 1 end
        
        f.bg:SetGradient("HORIZONTAL", CreateColor(r, g, b, intensity), CreateColor(r, g, b, 0))
        
        -- Borders (Fade Effect)
        f.borderLeft:SetColorTexture(r, g, b, 1)
        f.borderLeft:Show()
        
        f.borderTop:SetGradient("HORIZONTAL", CreateColor(r, g, b, 1), CreateColor(r, g, b, 0))
        f.borderTop:Show()
        
        f.borderBottom:SetGradient("HORIZONTAL", CreateColor(r, g, b, 1), CreateColor(r, g, b, 0))
        f.borderBottom:Show()
        
    elseif db.backdropTheme == "Solid" then
        f.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        f.bg:SetColorTexture(r, g, b, a)
        
        f.borderLeft:Hide()
        f.borderTop:Hide()
        f.borderBottom:Hide()
        
    elseif db.backdropTheme == "Minimal" then
        if f.isHovered then
            f.bg:SetColorTexture(r, g, b, a)
        else
            f.bg:SetColorTexture(0, 0, 0, 0)
        end
        
        f.borderLeft:Hide()
        f.borderTop:Hide()
        f.borderBottom:Hide()
    end
end

function LootGlimpse:UpdateVisuals()
    for _, f in ipairs(self.activeFrames) do
        self:ApplyVisuals(f)
    end
end

-- ColorizeBorder removed


function LootGlimpse:RecycleFrame(f)
    f.isPreview = nil
    f:Hide()
    f:ClearAllPoints()
    -- Remove from active frames
    for i, frame in ipairs(self.activeFrames) do
        if frame == f then
            table.remove(self.activeFrames, i)
            break
        end
    end
    -- Re-anchor remaining frames
    self:UpdateLayout()
    
    table.insert(self.framePool, f)
end

function LootGlimpse:QueueLootDisplay(name, quantity, texture, quality, link)
    local f = self:GetFrame()
    
    f.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    f.quality = quality -- Store for updates
    f.link = link
    
    local text = name
    
    if quantity and tonumber(quantity) > 1 then
        f.count:SetText(quantity)
        f.count:Show()
    else
        f.count:Hide()
    end
    
    if quality then
        local r, g, b, hex = C_Item.GetItemQualityColor(quality)
        f.text:SetText("|c" .. hex .. text .. "|r")
    else
        f.text:SetText(text)
    end
    
    self:UpdateBackground(f)
    
    -- Enforce Max Items
    local maxItems = self.db.profile.maxItems or 5
    while #self.activeFrames >= maxItems do
        self:RecycleFrame(self.activeFrames[1])
    end
    
    table.insert(self.activeFrames, f)
    
    -- Dynamic Sizing
    self:UpdateFrameSize(f)
    
    self:UpdateLayout()
    
    -- Setup Animation based on type
    self:SetupAnimation(f)
    
    f:Show()
    f.animInGroup:Play()
end

function LootGlimpse:SetupAnimation(f)
    -- Clear existing animations
    if f.animInGroup:GetAnimations() then f.animInGroup:RemoveAnimations() end
    if f.animOutGroup:GetAnimations() then f.animOutGroup:RemoveAnimations() end
    
    -- Clear OnPlay script (important if switching from Slide to others)
    f.animInGroup:SetScript("OnPlay", nil)
    
    local type = self.db.profile.animationType
    -- Duration is handled by C_Timer now, so we only care about In/Out durations here
    
    if type == "Fade" then
        -- IN
        local animIn = f.animInGroup:CreateAnimation("Alpha")
        animIn:SetFromAlpha(0)
        animIn:SetToAlpha(1)
        animIn:SetDuration(0.2)
        animIn:SetOrder(1)
        
        -- OUT
        local animOut = f.animOutGroup:CreateAnimation("Alpha")
        animOut:SetFromAlpha(1)
        animOut:SetToAlpha(0)
        animOut:SetDuration(0.5)
        animOut:SetOrder(1)
        
    elseif type == "Slide" then
        -- IN
        local animInTrans = f.animInGroup:CreateAnimation("Translation")
        animInTrans:SetOffset(50, 0) -- Slide RIGHT (visual: -50 -> 0)
        animInTrans:SetDuration(0.3)
        animInTrans:SetOrder(1)
        animInTrans:SetSmoothing("OUT")
        
        local animInAlpha = f.animInGroup:CreateAnimation("Alpha")
        animInAlpha:SetFromAlpha(0)
        animInAlpha:SetToAlpha(1)
        animInAlpha:SetDuration(0.2)
        animInAlpha:SetOrder(1)
        
        -- Offset content at start so it slides INTO place
        f.animInGroup:SetScript("OnPlay", function()
             f.content:ClearAllPoints()
             f.content:SetPoint("TOPLEFT", f, "TOPLEFT", -50, 0)
             f.content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -50, 0)
        end)
        
        -- OUT
        local animOut = f.animOutGroup:CreateAnimation("Alpha")
        animOut:SetFromAlpha(1)
        animOut:SetToAlpha(0)
        animOut:SetDuration(0.5)
        animOut:SetOrder(1)
        
    elseif type == "Pop" then
        -- IN
        local animInScale1 = f.animInGroup:CreateAnimation("Scale")
        animInScale1:SetScaleFrom(0.5, 0.5)
        animInScale1:SetScaleTo(1.2, 1.2)
        animInScale1:SetDuration(0.1)
        animInScale1:SetOrder(1)
        
        local animInScale2 = f.animInGroup:CreateAnimation("Scale")
        animInScale2:SetScaleFrom(1.2, 1.2)
        animInScale2:SetScaleTo(1, 1)
        animInScale2:SetDuration(0.1)
        animInScale2:SetOrder(2)
        
        local animInAlpha = f.animInGroup:CreateAnimation("Alpha")
        animInAlpha:SetFromAlpha(0)
        animInAlpha:SetToAlpha(1)
        animInAlpha:SetDuration(0.1)
        animInAlpha:SetOrder(1)
        
        -- OUT
        local animOut = f.animOutGroup:CreateAnimation("Alpha")
        animOut:SetFromAlpha(1)
        animOut:SetToAlpha(0)
        animOut:SetDuration(0.5)
        animOut:SetOrder(1)
    end
end

function LootGlimpse:UpdateLayout()
    local prev = self.anchor
    local direction = self.db.profile.growDirection
    local maxItems = self.db.profile.maxItems or 5
    local ITEM_HEIGHT = 50
    local PADDING = 5
    
    -- Update Anchor Height based on max items (including padding)
    local totalHeight = (maxItems * ITEM_HEIGHT) + (math.max(0, maxItems - 1) * PADDING)
    self.anchor:SetHeight(totalHeight)
    
    for i, f in ipairs(self.activeFrames) do
        f:ClearAllPoints()
        
        if direction == "UP" then
            if i == 1 then
                 f:SetPoint("BOTTOMLEFT", prev, "BOTTOMLEFT", 0, 0)
            else
                 f:SetPoint("BOTTOMLEFT", prev, "TOPLEFT", 0, 5)
            end
        else -- DOWN
            if i == 1 then
                 f:SetPoint("TOPLEFT", prev, "TOPLEFT", 0, 0)
            else
                 f:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -5)
            end
        end
        prev = f
    end
end

function LootGlimpse:TogglePreview(show)
    if show then
        if not self.previewFrames then
            self.previewFrames = {}
            
            local previewItemIDs = {
                 750,    -- Poor (Ruined Pelt)
                 6948,   -- Common (Hearthstone)
                 2520,   -- Uncommon (Copper Claymore)
                 1482,   -- Rare (Shadowfang)
                 873,    -- Epic (Staff of Jordan)
                 19019,  -- Legendary (Thunderfury)
                 120978, -- Artifact (Ashbringer)
                 122370, -- Heirloom (Burnished Polished Breastplate)
            }
            
            local maxItems = self.db.profile.maxItems or 5
            
            -- Generate exactly maxItems for preview
            for i = 1, maxItems do
                -- Cycle through example items
                local itemID = previewItemIDs[(i - 1) % #previewItemIDs + 1]
                
                local f = self:GetFrame()
                f.isPreview = true
                
                -- Default/Loading state
                f.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                f.text:SetText("Loading...")
                f.count:Hide()
                
                local item = Item:CreateFromItemID(itemID)
                item:ContinueOnItemLoad(function()
                    if not f.isPreview then return end
                    
                    local name, link, quality, _, _, _, _, _, _, texture = C_Item.GetItemInfo(itemID)
                    
                    if name then
                        f.icon:SetTexture(texture)
                        
                        if quality then
                            local r, g, b, hex = C_Item.GetItemQualityColor(quality)
                            f.text:SetText("|c" .. hex .. name .. "|r")
                        else
                            f.text:SetText(name)
                        end
                        
                        f.quality = quality
                        f.link = link
                        self:UpdateBackground(f)
                        
                        -- Dynamic Sizing logic
                        self:UpdateFrameSize(f)
                    end
                end)

                f:Show()
                f:SetAlpha(1)
                f.animInGroup:Stop()
                f.animOutGroup:Stop()
                if f.holdTimer then f.holdTimer:Cancel() f.holdTimer = nil end
                
                table.insert(self.previewFrames, f)
                table.insert(self.activeFrames, f)
            end
            
            self:UpdateLayout()
        end
    else
        if self.previewFrames then
            for _, f in ipairs(self.previewFrames) do
                self:RecycleFrame(f)
            end
            self.previewFrames = nil
        end
    end
end

local LootGlimpse = LibStub("AceAddon-3.0"):GetAddon("LootGlimpse")
local LSM = LibStub("LibSharedMedia-3.0", true)

function LootGlimpse:SetupOptions()
    -- 1. Basic Setup & Category Registration
    local category, layout = Settings.RegisterVerticalLayoutCategory("LootGlimpse")
    self.settingsCategory = category
    Settings.RegisterAddOnCategory(category)

    -- General Section
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("General"))

    -- Preview Mode (Checkbox with Proxy)
    local function GetPreview() return self.previewFrames ~= nil end
    local function SetPreview(value) self:TogglePreview(value) end

    local previewSetting = Settings.RegisterProxySetting(
        category,
        "LG_PREVIEW_MODE",
        Settings.VarType.Boolean,
        "Preview Mode",
        false,
        GetPreview,
        SetPreview
    )
    Settings.CreateCheckbox(category, previewSetting, "Show example loot frames to adjust settings")

    -- Show Gold (Checkbox with Proxy)
    local function GetShowGold() return self.db.profile.showGold end
    local function SetShowGold(value) self.db.profile.showGold = value end

    local showGoldSetting = Settings.RegisterProxySetting(
        category,
        "LG_SHOW_GOLD",
        Settings.VarType.Boolean,
        "Show Gold",
        true,
        GetShowGold,
        SetShowGold
    )
    Settings.CreateCheckbox(category, showGoldSetting, "Display looted money")

    -- Duration (Slider)
    -- Note: Using CreateSlider which is standard in Settings API, though not explicitly in the guide snippet,
    -- it follows the same pattern as Checkbox/Dropdown.
    local durationSetting = Settings.RegisterAddOnSetting(
        category,
        "LG_DURATION",
        "duration",
        self.db.profile,
        Settings.VarType.Number,
        "Duration",
        4
    )
    Settings.CreateSlider(category, durationSetting, { minValue = 1, maxValue = 10, step = 0.5, steps = 18, formatter = function(value) return string.format("%.1f s", value) end }, "How long the loot is shown (seconds)")

    -- Grow Direction (Dropdown with Proxy for UpdateLayout)
    local function GetGrowDir() return self.db.profile.growDirection end
    local function SetGrowDir(value) 
        self.db.profile.growDirection = value
        self:UpdateLayout()
    end
    
    local growDirSetting = Settings.RegisterProxySetting(
        category,
        "LG_GROW_DIRECTION",
        Settings.VarType.String,
        "Grow Direction",
        "UP",
        GetGrowDir,
        SetGrowDir
    )
    
    local function GetGrowDirOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add("UP", "Up")
        container:Add("DOWN", "Down")
        return container:GetData()
    end
    
    Settings.CreateDropdown(category, growDirSetting, GetGrowDirOptions, "Direction the list should grow")

    -- Quality Filter (Dropdown)
    local function GetQualityOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add(0, "|cff9d9d9dPoor|r")
        container:Add(1, "|cffffffffCommon|r")
        container:Add(2, "|cff1eff00Uncommon|r")
        container:Add(3, "|cff0070ddRare|r")
        container:Add(4, "|cffa335eeEpic|r")
        container:Add(5, "|cffff8000Legendary|r")
        return container:GetData()
    end
    
    local qualitySetting = Settings.RegisterAddOnSetting(
        category,
        "LG_QUALITY_FILTER",
        "qualityFilter",
        self.db.profile,
        Settings.VarType.Number,
        "Minimum Quality",
        0
    )
    Settings.CreateDropdown(category, qualitySetting, GetQualityOptions, "Only show items of this quality or higher")

    -- Test Buttons (Action Buttons)
    local testButton = CreateSettingsButtonInitializer("Test Single", "Test Single", function()
        self:QueueLootDisplay("Hearthstone", 1, "Interface\\Icons\\inv_misc_rune_01", 1)
    end, "Spawn a test item", true)
    layout:AddInitializer(testButton)

    local testWaterfallButton = CreateSettingsButtonInitializer("Test Waterfall", "Test Waterfall", function()
        self:SlashCommand("test waterfall")
    end, "Spawn multiple test items", true)
    layout:AddInitializer(testWaterfallButton)


    -- Appearance Section
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Appearance"))

    -- Font (Dropdown with Proxy)
    local function GetFont() return self.db.profile.font end
    local function SetFont(value)
        self.db.profile.font = value
        self:UpdateVisuals()
    end
    
    local fontSetting = Settings.RegisterProxySetting(
        category,
        "LG_FONT",
        Settings.VarType.String,
        "Font",
        "Friz Quadrata TT",
        GetFont,
        SetFont
    )
    
    local function GetFontOptions()
        local container = Settings.CreateControlTextContainer()
        local fonts = LSM and LSM:HashTable("font") or { ["Friz Quadrata TT"] = "Friz Quadrata TT" }
        -- Sort fonts? Container adds in order.
        for name, path in pairs(fonts) do
            container:Add(name, name)
        end
        return container:GetData()
    end
    
    Settings.CreateDropdown(category, fontSetting, GetFontOptions, "Font of the text")

    -- Font Size (Slider with Proxy)
    local function GetFontSize() return self.db.profile.fontSize end
    local function SetFontSize(value)
        self.db.profile.fontSize = value
        self:UpdateVisuals()
    end
    
    local fontSizeSetting = Settings.RegisterProxySetting(
        category,
        "LG_FONT_SIZE",
        Settings.VarType.Number,
        "Font Size",
        14,
        GetFontSize,
        SetFontSize
    )
    Settings.CreateSlider(category, fontSizeSetting, { minValue = 8, maxValue = 32, step = 1, steps = 24, formatter = function(value) return string.format("%d", value) end }, "Size of the font")

    -- Font Outline (Dropdown with Proxy)
    local function GetFontOutline() return self.db.profile.fontOutline end
    local function SetFontOutline(value)
        self.db.profile.fontOutline = value
        self:UpdateVisuals()
    end
    
    local fontOutlineSetting = Settings.RegisterProxySetting(
        category,
        "LG_FONT_OUTLINE",
        Settings.VarType.String,
        "Font Outline",
        "OUTLINE",
        GetFontOutline,
        SetFontOutline
    )
    
    local function GetOutlineOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add("", "None")
        container:Add("OUTLINE", "Outline")
        container:Add("THICKOUTLINE", "Thick Outline")
        container:Add("MONOCHROME", "Monochrome")
        return container:GetData()
    end
    Settings.CreateDropdown(category, fontOutlineSetting, GetOutlineOptions, "Outline style of the font")

    -- Theme (Dropdown with Proxy)
    local function GetTheme() return self.db.profile.backdropTheme end
    local function SetTheme(value)
        self.db.profile.backdropTheme = value
        self:UpdateVisuals()
    end
    
    local themeSetting = Settings.RegisterProxySetting(
        category,
        "LG_THEME",
        Settings.VarType.String,
        "Theme",
        "Classic",
        GetTheme,
        SetTheme
    )
    
    local function GetThemeOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add("Classic", "Classic (Gradient)")
        container:Add("Solid", "Solid Color")
        container:Add("Minimal", "Minimal (No BG)")
        return container:GetData()
    end
    Settings.CreateDropdown(category, themeSetting, GetThemeOptions, "Visual theme")

    -- Gradient Intensity (Slider with Proxy)
    local function GetGradient() return self.db.profile.gradientIntensity end
    local function SetGradient(value)
        self.db.profile.gradientIntensity = value
        self:UpdateVisuals()
    end
    
    local gradientSetting = Settings.RegisterProxySetting(
        category,
        "LG_GRADIENT",
        Settings.VarType.Number,
        "Gradient Intensity",
        0.2,
        GetGradient,
        SetGradient
    )
    Settings.CreateSlider(category, gradientSetting, { minValue = 0, maxValue = 1, step = 0.05, steps = 20, formatter = function(value) return string.format("%d%%", value * 100) end }, "Intensity of the gold gradient background (Classic Theme)")

    -- Background Color (Button with Swatch)
    local function UpdateSwatch(frame)
        if frame and frame.swatch then
            local c = self.db.profile.backgroundColor
            frame.swatch:SetColorTexture(c.r, c.g, c.b, c.a)
        end
    end

    local colorButton = CreateSettingsButtonInitializer("Background Color", "Set Color", function(button)
        local c = self.db.profile.backgroundColor
        ColorPickerFrame:SetupColorPickerAndShow({
            r = c.r, g = c.g, b = c.b, opacity = c.a,
            hasOpacity = true,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                local a = ColorPickerFrame:GetColorAlpha()
                self.db.profile.backgroundColor = { r = r, g = g, b = b, a = a }
                self:UpdateVisuals()
                UpdateSwatch(button:GetParent())
            end,
            opacityFunc = function()
                 local r, g, b = ColorPickerFrame:GetColorRGB()
                 local a = ColorPickerFrame:GetColorAlpha()
                 self.db.profile.backgroundColor = { r = r, g = g, b = b, a = a }
                 self:UpdateVisuals()
                 UpdateSwatch(button:GetParent())
            end,
            cancelFunc = function()
                self.db.profile.backgroundColor = c
                self:UpdateVisuals()
                UpdateSwatch(button:GetParent())
            end,
        })
    end, "Set the background color (for Solid & Classic themes)", true)

    -- Hook InitFrame to add the swatch
    local originalInit = colorButton.InitFrame
    colorButton.InitFrame = function(initializer, frame)
        originalInit(initializer, frame)
        
        if not frame.swatch then
             frame.swatch = frame:CreateTexture(nil, "ARTWORK")
             frame.swatch:SetSize(20, 20)
             frame.swatch:SetPoint("LEFT", frame.Button, "RIGHT", 10, 0)
        end
        UpdateSwatch(frame)
    end

    layout:AddInitializer(colorButton)

    -- Use Quality Color for Background (Checkbox with Proxy)
    local function GetQualityBg() return self.db.profile.useQualityBackground end
    local function SetQualityBg(value)
        self.db.profile.useQualityBackground = value
        self:UpdateVisuals()
    end
    
    local qualityBgSetting = Settings.RegisterProxySetting(
        category,
        "LG_QUALITY_BG",
        Settings.VarType.Boolean,
        "Use Quality Color for Background",
        false,
        GetQualityBg,
        SetQualityBg
    )
    Settings.CreateCheckbox(category, qualityBgSetting, "Use the item quality color for the background instead of the theme color")


    -- Animations Section
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Animations"))

    -- Animation Type (Dropdown)
    local function GetAnimTypeOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add("Fade", "Fade")
        container:Add("Slide", "Slide In")
        container:Add("Pop", "Pop In")
        return container:GetData()
    end
    
    local animSetting = Settings.RegisterAddOnSetting(
        category,
        "LG_ANIMATION",
        "animationType",
        self.db.profile,
        Settings.VarType.String,
        "Animation Type",
        "Fade"
    )
    Settings.CreateDropdown(category, animSetting, GetAnimTypeOptions, "Type of animation to use")
end

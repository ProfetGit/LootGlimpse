# Creating a Modern WoW Addon Settings Menu

This guide documents how to create a native-looking settings menu for a World of Warcraft addon, based on the implementation found in **BugSack**. It utilizes the modern `Settings` API introduced in Dragonflight.

## 1. Basic Setup & Category Registration

First, you need to register a category for your addon in the Settings panel. This is typically done in your initialization code (e.g., `PLAYER_LOGIN` or `ADDON_LOADED`).

```lua
local addonName, addon = ...
-- Create a vertical layout category
local category, layout = Settings.RegisterVerticalLayoutCategory(addonName)
addon.settingsCategory = category

-- Register the category with the Settings panel
Settings.RegisterAddOnCategory(category)
```

## 2. Simple Settings (Checkboxes)

For simple boolean settings that map directly to a saved variable table, use `Settings.RegisterAddOnSetting` followed by `Settings.CreateCheckbox`.

**Parameters:**
1. Category object
2. Unique setting name (string)
3. Variable key in your database table
4. The database table itself
5. Variable type (`Settings.VarType.Boolean`)
6. Display label
7. Default value

```lua
local function InitializeSettings()
    -- Example: Auto Popup Checkbox
    local autoPopupSetting = Settings.RegisterAddOnSetting(
        category,
        "MYADDON_AUTO_POPUP", -- Unique ID
        "auto",               -- Key in addon.db
        addon.db,             -- Table containing the value
        Settings.VarType.Boolean,
        "Auto Popup",         -- Label
        Settings.Default.False -- Default value
    )
    
    -- Add the checkbox to the layout with a tooltip description
    Settings.CreateCheckbox(category, autoPopupSetting, "Automatically show the window when an event occurs.")
end
```

## 3. Proxy Settings (Getters & Setters)

If a setting requires custom logic (e.g., toggling a Minimap icon provided by a library), use `Settings.RegisterProxySetting`. This allows you to define custom `GetValue` and `SetValue` functions.

```lua
local function GetMinimapValue()
    return not MyAddonDB.hideMinimap
end

local function SetMinimapValue(value)
    MyAddonDB.hideMinimap = not value
    if MyAddonDB.hideMinimap then
        ldbIcon:Hide(addonName)
    else
        ldbIcon:Show(addonName)
    end
end

local minimapSetting = Settings.RegisterProxySetting(
    category,
    "MYADDON_MINIMAP_ICON",
    Settings.VarType.Boolean,
    "Show Minimap Icon",
    Settings.Default.True,
    GetMinimapValue,
    SetMinimapValue
)
Settings.CreateCheckbox(category, minimapSetting, "Toggle the minimap button.")
```

## 4. Dropdown Menus

To create a dropdown, you need a generator function that returns the available options.

```lua
local function GetFontSizeOptions()
    local container = Settings.CreateControlTextContainer()
    container:Add(1, "Small")
    container:Add(2, "Medium")
    container:Add(3, "Large")
    return container:GetData()
end

local fontSizeSetting = Settings.RegisterAddOnSetting(
    category,
    "MYADDON_FONT_SIZE",
    "fontSize",
    addon.db,
    Settings.VarType.Number,
    "Font Size",
    2 -- Default to Medium
)

Settings.CreateDropdown(category, fontSizeSetting, GetFontSizeOptions)
```

## 5. Action Buttons

To add a button that performs an action (like resetting data) without storing a setting value, use `CreateSettingsButtonInitializer`.

```lua
local wipeButtonInitializer = CreateSettingsButtonInitializer(
    "Reset Data",         -- Button Label
    "Reset Data",         -- Button Text
    function()            -- OnClick Handler
        addon:ResetDatabase()
    end,
    "Clear all saved data.", -- Tooltip
    true                  -- Add search tags
)

local addonLayout = SettingsPanel:GetLayout(category)
addonLayout:AddInitializer(wipeButtonInitializer)
```

## 6. Advanced: Custom Controls (Scrollable Lists)

For complex controls, such as a scrollable list of sound files, you can create a custom initializer mixin. This involves creating a custom frame and handling its logic.

### Define the Mixin
```lua
local MyCustomDropdownInitializer = CreateFromMixins(
    ScrollBoxFactoryInitializerMixin,
    SettingsElementHierarchyMixin,
    SettingsSearchableElementMixin
)

function MyCustomDropdownInitializer:Init()
    ScrollBoxFactoryInitializerMixin.Init(self, "SettingsListElementTemplate")
    self.data = { name = "Sound Selection", tooltip = "Select a sound." }
    self:AddSearchTags("Sound")
end

function MyCustomDropdownInitializer:GetExtent()
    return 26 -- Height
end

function MyCustomDropdownInitializer:InitFrame(frame)
    frame:SetSize(280, 26)
    
    -- Setup Label
    frame.Text:SetText("Sound")
    
    -- Create Dropdown if needed
    if not frame.dropdown then
        frame.dropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
        frame.dropdown:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
        frame.dropdown:SetSize(150, 26)
        
        frame.dropdown:SetupMenu(function(dropdown, rootDescription)
            rootDescription:SetScrollMode(200) -- Enable scrolling
            
            local sounds = { "Sound 1", "Sound 2", "Sound 3" }
            for _, sound in ipairs(sounds) do
                rootDescription:CreateRadio(sound, 
                    function(s) return addon.db.sound == s end, -- IsSelected
                    function(s) addon.db.sound = s end,         -- OnSelect
                sound)
            end
        end)
    end
end
```

### Add to Layout
```lua
local customInitializer = CreateFromMixins(MyCustomDropdownInitializer)
customInitializer:Init()
layout:AddInitializer(customInitializer)
```

## 7. Opening the Menu via Slash Command

To allow users to open your settings menu directly via a slash command:

```lua
SlashCmdList.MYADDON = function(msg)
    -- Open directly to your category
    Settings.OpenToCategory(addon.settingsCategory:GetID())
end
SLASH_MYADDON1 = "/myaddon"
```

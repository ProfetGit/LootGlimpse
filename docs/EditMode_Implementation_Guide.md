# Native-Like Edit Mode Implementation Guide

This guide documents how the **Plumber** addon achieves a native-feeling "Edit Mode" integration without relying on external libraries like `LibEditMode`. It "fakes" the native system by manually handling events, overlays, and settings dialogs to perfectly mimic the default UI behavior.

## Architecture Overview

The implementation relies on three core components interacting with each other:

1.  **Event Listener (`BlizzardEditMode.lua`)**: Listens for the game's `EditMode.Enter` and `EditMode.Exit` events to toggle the addon's "Edit Mode" state.
2.  **Selection Overlay (`SharedWidgets.lua`)**: A transparent frame that sits on top of your addon's UI. It handles mouse clicks and renders the "Blue" (Highlighted) and "Yellow" (Selected) borders.
3.  **Settings Dialog (`SharedWidgets.lua`)**: A custom frame that looks like the native `EditModeSystemSettingsDialog`. It is generated dynamically based on a configuration table (Schema).

---

## 1. The Event Listener

You need a central handler to know when the player enters or exits Edit Mode.

**Mechanism:**
*   Register callbacks for `EditMode.Enter` and `EditMode.Exit` using `EventRegistry`.
*   Maintain a list of modules (frames) that support Edit Mode.
*   When entering Edit Mode, loop through modules and call their `EnterEditMode()` method.
*   When exiting, call `ExitEditMode()`.

**Code Snippet:**
```lua
local function EnterEditMode()
    -- Loop through your registered frames
    for _, module in ipairs(MyAddon.EditModeModules) do
        module:EnterEditMode()
    end
end

local function ExitEditMode()
    for _, module in ipairs(MyAddon.EditModeModules) do
        module:ExitEditMode()
    end
end

EventRegistry:RegisterCallback("EditMode.Enter", EnterEditMode, MyAddon);
EventRegistry:RegisterCallback("EditMode.Exit", ExitEditMode, MyAddon);
```

---

## 2. The Selection Overlay (The "Fake" Highlight)

This is the most critical part for the "Native Feel". You don't click your actual frame; you click a specialized overlay that mimics the Edit Mode selection box.

**Visuals:**
*   **Highlighted (Hover)**: Blue border.
*   **Selected (Clicked)**: Yellow border with a label.
*   **Textures**: Plumber uses custom textures, but you can try to replicate them or use 9-slice frames.
    *   *Plumber's Texture*: `Interface/AddOns/Plumber/Art/Frame/EditModeHighlighted` (and `EditModeSelected`).

**Behavior:**
*   **OnShow**: Register `GLOBAL_MOUSE_DOWN` to detect clicks *outside* the frame (to deselect it).
*   **OnMouseDown**: Transition from "Highlighted" (Blue) to "Selected" (Yellow) and open the Settings Dialog.
*   **OnDragStart/Stop**: Proxy these events to your main frame to handle movement.

**Code Snippet (Overlay Mixin):**
```lua
MyEditModeSelectionMixin = {}

function MyEditModeSelectionMixin:ShowHighlighted()
    self.isSelected = false
    self.Background:SetTexture("Path/To/BlueBorder") -- Or set vertex color to Blue
    self.Label:Hide()
    self:Show()
end

function MyEditModeSelectionMixin:ShowSelected()
    self.isSelected = true
    self.Background:SetTexture("Path/To/YellowBorder") -- Or set vertex color to Yellow
    self.Label:Show()
    self:Show()
    
    -- Open the Settings Dialog here
    MyAddon:OpenSettingsDialog(self.parent)
end

function MyEditModeSelectionMixin:OnMouseDown()
    self:ShowSelected()
end

function MyEditModeSelectionMixin:OnDragStart()
    self.parent:StartMoving() -- Move the actual addon frame
end
```

---

## 3. Movement Logic

The movement is standard WoW API, but restricted to Edit Mode.

**Logic:**
1.  **Enter Edit Mode**:
    *   Show the **Selection Overlay**.
    *   Enable mouse interaction (`EnableMouse(true)`).
    *   Set `SetMovable(true)`.
2.  **Exit Edit Mode**:
    *   Hide the **Selection Overlay**.
    *   Disable mouse interaction (if the frame shouldn't be clickable normally).
    *   Set `SetMovable(false)`.
    *   **Save Position**: Call `StopMovingOrSizing()` and save `GetPoint()` to your `SavedVariables`.

---

## 4. The Settings Dialog

Plumber uses a "Schema" approach to generate the settings window. This makes it easy to add new settings without writing UI code for every button.

**The Schema (`OPTIONS_SCHEMATIC`):**
```lua
local OPTIONS_SCHEMATIC = {
    title = "Loot Window",
    widgets = {
        { type = "Slider", label = "Scale", dbKey = "Scale", min = 0.5, max = 2.0 },
        { type = "Checkbox", label = "Show Title", dbKey = "ShowTitle" },
        { type = "Divider" },
        { type = "Button", label = "Reset Position", func = ResetPosition },
    }
}
```

**The Generator (`SetupSettingsDialog`):**
*   Accepts the `schematic` table.
*   Uses **Object Pools** (e.g., `CreateFramePool`) to recycle sliders and checkboxes.
*   Iterates through `widgets` list and acquires/initializes the corresponding UI element.
*   Anchors them vertically in a list.

**Mimicking the Look:**
*   **Backdrop**: `DialogBorderTranslucentTemplate`.
*   **Close Button**: `UIPanelCloseButtonNoScripts`.
*   **Title**: `GameFontHighlightLarge`.

---

## Summary of Steps to Mimic

1.  **Create the Assets**: You need a 9-slice border texture that looks like the Edit Mode selection (or use a solid color with `SetBorderColor` for a start).
2.  **Hook the Events**: Add the `EventRegistry` callbacks in your initialization code.
3.  **Implement the Overlay**: Create a `Frame` that covers your addon window. Give it the "Blue" look by default.
4.  **Handle Interaction**:
    *   Clicking Overlay -> Turn Yellow -> Show Settings Frame.
    *   Clicking Global Mouse (Outside) -> Turn Blue -> Hide Settings Frame.
5.  **Build the Settings Frame**: Create a frame that reads a table of settings and renders sliders/checkboxes.

## Key Files in Plumber to Reference

*   `Modules/BlizzardEditMode.lua`: The entry point for event handling.
*   `Modules/SharedWidgets.lua`:
    *   `CreateEditModeSelection`: The code for the Blue/Yellow overlay.
    *   `SetupSettingsDialog`: The code that builds the settings window.
*   `Modules/LootUI_Display.lua`:
    *   `MainFrame:EnterEditMode()`: Example of how a module prepares itself.
    *   `OPTIONS_SCHEMATIC`: Example of the settings configuration table.

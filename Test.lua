local LootGlimpse = LibStub("AceAddon-3.0"):GetAddon("LootGlimpse")

function LootGlimpse:RunTest(arg)
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
end

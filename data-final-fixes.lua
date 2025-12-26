-- Iterate over all turret types and convert their items to "item-with-tags"
-- This allows us to store the kill count in the item tags when mined.

local turret_types = {
    "ammo-turret", 
    "fluid-turret", 
    "electric-turret", 
    "artillery-turret"
}

for _, type_name in pairs(turret_types) do
    local prototypes = data.raw[type_name]
    if prototypes then
        for name, prototype in pairs(prototypes) do
            if prototype.minable and prototype.minable.result then
                local item_name = prototype.minable.result
                local item = data.raw["item"][item_name]
                
                -- Only convert if it's currently a standard item
                if item then
                    -- Change type
                    item.type = "item-with-tags"
                    -- Default stack size for item-with-tags is usually 1, but we want to keep original stack size
                    -- behavior: items with different tags won't stack, items with NO tags will stack.
                    -- item-with-tags supports stack_size.
                    
                    -- Move to new bucket
                    if not data.raw["item-with-tags"] then
                         data.raw["item-with-tags"] = {}
                    end
                    data.raw["item-with-tags"][item_name] = item
                    data.raw["item"][item_name] = nil
                    
                    log("Quality Turrets: Converted " .. item_name .. " to item-with-tags")
                end
            end
        end
    end
end

local function create_bonus_entity(base_entity, bonus)
  -- Ignore this mod's entities
  if base_entity.name:sub(1, 18) == "burner-fuel-bonus-" then
    return
  end

  -- Check for duplicates
  local name = "burner-fuel-bonus-" .. base_entity.name .. "-x" .. bonus
  if data.raw[base_entity.type][name] then
    return
  end

  -- Find the original item used to build the entity
  local base_item = nil
  for _, item in pairs(data.raw.item) do
    if item.place_result == base_entity.name then
      base_item = item
      break
    end
  end
  if not base_item then
    -- The entity is not buildable, abort!
    return
  end
  local item_name = "burner-fuel-bonus-" .. base_item.name

  -- Create a faster version of the entity
  local entity = table.deepcopy(base_entity)
  entity.name = name
  entity.placeable_by = {item = item_name, count = 1}
  local multiplier = bonus / 100

  -- Add speed bonuses
  if entity.type == "assembling-machine"
  or entity.type == "furnace"
  or entity.type == "rocket-silo" then
    entity.crafting_speed = entity.crafting_speed * multiplier

  elseif entity.type == "inserter" then
    -- Default effectivity: https://wiki.factorio.com/Types/EnergySource#effectivity
    if not entity.energy_source.effectivity then entity.energy_source.effectivity = 1 end
    entity.energy_source.effectivity = entity.energy_source.effectivity * multiplier
    entity.rotation_speed = entity.rotation_speed * multiplier
    entity.extension_speed = entity.extension_speed * multiplier

  elseif entity.type == "lab" then
    -- Default researching_speed: https://wiki.factorio.com/Prototype/Lab#researching_speed
    if not entity.researching_speed then entity.researching_speed = 1 end
    entity.researching_speed = entity.researching_speed * multiplier

  elseif entity.type == "mining-drill" then
    entity.mining_speed = entity.mining_speed * multiplier

  elseif entity.type == "pump" then
    entity.pumping_speed = entity.pumping_speed * multiplier

  elseif entity.type == "radar" then
    -- Default rotation_speed: https://wiki.factorio.com/Prototype/Radar#rotation_speed
    if not entity.rotation_speed then entity.rotation_speed = 0.01 end
    entity.rotation_speed = entity.rotation_speed * multiplier
    local numbers, letters = entity.energy_per_sector:match("(%d+)(.*)")
    entity.energy_per_sector = (numbers / multiplier) .. letters

  else
    -- No bonus available
    return
  end

  -- Use base entity name and description
  if not entity.localised_name then
    entity.localised_name = {"entity-name." .. base_entity.name}
  end
  if not entity.localised_description then
    entity.localised_description = {"entity-description." .. base_entity.name}
  end

  -- Add to base entity's fast_replaceable_group
  if not base_entity.fast_replaceable_group then
    base_entity.fast_replaceable_group = base_entity.name
  end
  entity.fast_replaceable_group = base_entity.fast_replaceable_group

  if not entity.flags then entity.flags = {} end
  local already_hidden = false
  for i = #entity.flags, 1, -1 do
    -- Remove placeable flags
    if entity.flags[i] == "placeable-neutral"
    or entity.flags[i] == "placeable-player"
    or entity.flags[i] == "placeable-enemy" then
      table.remove(entity.flags, i)
    end
    if entity.flags[i] == "hidden" then
      already_hidden = true
    end
  end
  -- Add hidden flag
  if not already_hidden then
    table.insert(entity.flags, "hidden")
  end

  data:extend{entity}

  -- Add a fake item to help with creating blueprints
  if data.raw.item[item_name] then return end
  local item = table.deepcopy(base_item)
  item.name = item_name
  if not item.localised_name then
    item.localised_name = {"item-name." .. base_item.name}
  end
  if not item.localised_description then
    item.localised_description = {"item-description." .. base_item.name}
  end
  item.place_result = entity.name

  -- Hide item
  item.subgroup = nil
  if not item.flags then
    item.flags = {"hidden"}
  else
    already_hidden = false
    for _, flag in pairs(item.flags) do
      if flag == "hidden" then
        already_hidden = true
        break
      end
    end
    if not already_hidden then
      table.insert(item.flags, "hidden")
    end
  end

  data:extend{item}
end

-- Load fuel bonuses
local bonuses = {}
for _, fuel in pairs(data.raw.item) do
  if fuel.fuel_acceleration_multiplier then
    local category = fuel.fuel_category
    local percent = math.floor(fuel.fuel_acceleration_multiplier * 100 + 0.5)
    if percent > 0 and percent ~= 100 then
      if not bonuses[category] then bonuses[category] = {} end
      bonuses[category][percent] = true
    end
  end
end

-- Create a copy of each entity with each bonus
for _, type in pairs(data.raw) do
  for _, entity in pairs(type) do
    if entity.energy_source and entity.energy_source.type == "burner" then
      local categories = entity.energy_source.fuel_categories
      if not categories then
        categories = {entity.energy_source.fuel_category or "chemical"}
      end
      for _, category in pairs(categories) do
        if bonuses[category] then
          for bonus, _ in pairs(bonuses[category]) do
            create_bonus_entity(entity, bonus)
          end
        end
      end
    end
  end
end

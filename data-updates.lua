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

local function create_bonus_entity(base_entity, bonus)
  -- Create a faster version of the entity
  local multiplier = bonus / 100
  local entity = table.deepcopy(base_entity)
  entity.name = "burner-fuel-bonus-" .. base_entity.name .. "-x" .. bonus
  if not entity.localised_name then
    entity.localised_name = {"entity-name." .. base_entity.name}
  end

  -- Remove placeable flags
  if entity.flags then
    for i = #entity.flags, 1, -1 do
      if entity.flags[i] == "placeable-neutral"
      or entity.flags[i] == "placeable-player"
      or entity.flags[i] == "placeable-enemy" then
        entity.flags[i] = nil
      end
    end
  end

  -- Add speed bonuses
  if entity.type == "assembling-machine"
  or entity.type == "furnace"
  or entity.type == "rocket-silo" then
    entity.crafting_speed = entity.crafting_speed * multiplier

  elseif entity.type == "inserter" then
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
    entity.energy_per_sector = entity.energy_per_sector / multiplier

  else
    -- No bonus available
    return
  end

  log(entity.name .. " " .. bonus .. "%")
  data:extend{entity}
end

-- Create a copy of each entity with each bonus
for _, entity in pairs(data.raw) do
  if entity.energy_source and entity.energy_source.type == "burner" then
    -- Default fuel_category: https://wiki.factorio.com/Types/EnergySource#fuel_category
    local category = entity.energy_source.fuel_category or "chemical"
    if bonuses[category] then
      for bonus, _ in pairs(bonuses[category]) do
        create_bonus_entity(entity, bonus)
      end
    end
  end
end

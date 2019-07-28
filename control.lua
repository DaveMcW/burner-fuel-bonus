-- Entity types that have a burner bonus
local TYPE_LIST = {
  "assembling-machine",
  "furnace",
  "inserter",
  "lab",
  "mining-drill",
  "pump",
  "radar",
  "rocket-silo",
}
local MY_TYPES = {}
for _, type in pairs(TYPE_LIST) do
  MY_TYPES[type] = true
end

function on_init()
  global.fuels = {}
  global.burners = {}
  global.burner_index = nil

  -- Cache fuel bonuses
  for _, fuel in pairs(game.item_prototypes) do
    local percent = math.floor(fuel.fuel_acceleration_multiplier * 100 + 0.5)
    if percent > 0 and percent ~= 100 then
      global.fuels[fuel.name] = percent
    end
  end

  -- Cache burner entities
  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered{type=TYPE_LIST}) do
      if entity.prototype.burner_prototype then
        global.burners[entity.unit_number] = entity
      end
    end
  end
end

function on_built(event)
  local entity = event.created_entity or event.entity or event.destination
  if not entity or not entity.valid then return end
  if not MY_TYPES[entity.type] then return end
  if not entity.prototype.burner_prototype then return end

  -- Add to burner entity cache
  global.burners[entity.unit_number] = entity
end

function on_tick(event)
  -- Update one entity per tick
  if not global.burners[global.burner_index] then global.burner_index = nil end
  global.burner_index, entity = next(global.burners, global.burner_index)
  if not entity then return end
  if entity.valid then
    update_burner(entity)
  else
    global.burners[global.burner_index] = nil
  end
end

function on_blueprint_created(event)
  -- Get the blueprint
  local player = game.players[event.player_index]
  local blueprint = player.cursor_stack
  if not blueprint.valid_for_read then return end
  if blueprint.is_blueprint_book then
    local inventory = blueprint.get_inventory(defines.inventory.item_main)
    blueprint = inventory[blueprint.active_index]
  end
  if not blueprint.is_blueprint then return end
  if not blueprint.is_blueprint_setup() then return end

  -- Replace modded entity with the base entity
  local entities = blueprint.get_blueprint_entities()
  for _, entity in pairs(entities) do
    entity.name = get_base_name(entity.name)
  end
  blueprint.set_blueprint_entities(entities)
end

function on_player_pipette(event)
  -- Replace modded entity with the base entity
  if event.item.name:sub(1, 18) == "burner-fuel-bonus-" then
    local player = game.players[event.player_index]
    local item = game.item_prototypes[get_base_name(event.item.name)]
    local cursor_stack = player.cursor_stack.valid_for_read and player.cursor_stack
    if cursor_stack then
      if cursor_stack.name == event.item.name then
        set_cursor(player, item)
      end
    elseif player.cursor_ghost and player.cursor_ghost.name == event.item.name then
      set_cursor(player, item)
    end
  end
end

function update_burner(entity)
  -- Read the entity and fuel names
  local name = get_base_name(entity.name)
  local fuel = entity.burner.currently_burning

  -- Look for an upgraded entity
  if fuel and global.fuels[fuel.name] then
    local upgrade = "burner-fuel-bonus-" .. name .. "-x" .. global.fuels[fuel.name]
    if game.entity_prototypes[upgrade] then
      name = upgrade
    else
      game.print(game.tick .. " " .. entity.unit_number .. " " .. entity.name .. " " .. upgrade)
    end
  end

  -- Replace the entity
  if entity.name ~= name then
    local new_entity = entity.surface.create_entity{
      name = name,
      position = entity.position,
      direction = entity.direction,
      force = entity.force,
      fast_replace = true,
      spill = false,
      create_build_effect_smoke = false,
    }
    if new_entity then
      global.burners[global.burner_index] = new_entity
    end
  end

end

function get_base_name(name)
  if name:sub(1, 18) == "burner-fuel-bonus-" then
    return name:sub(19):match("(.*)-x%d+$")
  else
    return name
  end
end

function set_cursor(player, item)
  local count = math.min(player.get_main_inventory().get_item_count(item.name), item.stack_size)
  if count > 0 then
    -- Use existing items
    player.remove_item{name = item.name, count = count}
    player.cursor_stack.set_stack{name = item.name, count = count}
  elseif player.cheat_mode then
    -- Cheat for some items
    player.cursor_stack.set_stack{name = item.name, count = item.stack_size}
  else
    -- Use an item ghost
    player.cursor_stack.clear()
    player.cursor_ghost = item
  end
end

script.on_init(on_init)
script.on_configuration_changed(on_init)
script.on_event(defines.events.on_built_entity, on_built)
script.on_event(defines.events.on_robot_built_entity, on_built)
script.on_event(defines.events.script_raised_built, on_built)
script.on_event(defines.events.script_raised_revive, on_built)
script.on_event(defines.events.on_entity_cloned, on_built)
script.on_event(defines.events.on_tick, on_tick)
script.on_event(defines.events.on_player_setup_blueprint, on_blueprint_created)
script.on_event(defines.events.on_player_configured_blueprint, on_blueprint_created)
script.on_event(defines.events.on_player_pipette, on_player_pipette)
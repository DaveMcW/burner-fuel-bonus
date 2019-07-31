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
  -- Cache burner entities
  global.burners = {}
  global.burner_index = nil
  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered{type=TYPE_LIST}) do
      if entity.prototype.burner_prototype then
        global.burners[entity.unit_number] = entity
      end
    end
  end
  on_configuration_changed()
end

function on_configuration_changed()
  -- Cache fuel bonuses
  global.fuels = {}
  for _, fuel in pairs(game.item_prototypes) do
    local percent = math.floor(fuel.fuel_acceleration_multiplier * 100 + 0.5)
    if percent > 0 and percent ~= 100 then
      global.fuels[fuel.name] = percent
    end
  end
end

function on_tick(event)
  local my_settings = settings.global
  if not my_settings["burner-fuel-bonus-enable"].value then return end
  -- Update N entities per tick
  for i = 1, my_settings["burner-fuel-bonus-refresh-rate"].value do
    local index = global.burner_index
    global.burner_index = next(global.burners, global.burner_index)
    update_burner(index)
  end
end

function on_built(event)
  local entity = event.created_entity or event.entity or event.destination
  if not entity or not entity.valid then return end
  if not MY_TYPES[entity.type] then return end
  if not entity.prototype.burner_prototype then return end
  if event.burner_fuel_bonus then return end

  -- Add to burner entity cache
  global.burners[entity.unit_number] = entity
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
  if not entities then return end
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
    if not item then return end
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

function on_setting_changed(event)
  if event.setting == "burner-fuel-bonus-enable"
  and not settings.global["burner-fuel-bonus-enable"].value then
    -- Remove all bonus entities
    for _, entity in pairs(global.burners) do
      if entity.valid then
        local name = get_base_name(entity.name)
        if name ~= entity.name then
          replace_burner(entity, name)
        end
      end
    end
  end
end

function update_burner(index)
  local entity = global.burners[index]
  if not entity then return end
  if not entity.valid then
    -- Remove entity from cache
    global.burners[index] = nil
    return
  end

  -- Read the entity and fuel names
  local name = get_base_name(entity.name)
  local fuel = entity.burner.currently_burning

  -- Look for an upgraded entity
  if fuel and global.fuels[fuel.name] then
    name = "burner-fuel-bonus-" .. name .. "-x" .. global.fuels[fuel.name]
  end

  -- Replace the entity
  if entity.name ~= name then
    if not game.entity_prototypes[name] then return end
    local new_entity = replace_burner(entity, name)
    if new_entity then
      global.burners[index] = new_entity
    end
  end
end

function replace_burner(entity, name)
  -- Save stats that can't be fast replaced
  local health = entity.health
  local deconstruct = entity.to_be_deconstructed(entity.force)
  local last_user = entity.last_user

  -- Fast replace
  local new_entity = entity.surface.create_entity{
    fast_replace = true,
    name = name,
    position = entity.position,
    direction = entity.direction,
    force = entity.force,
    spill = false,
    create_build_effect_smoke = false,
  }

  if new_entity then
    -- Update stats
    new_entity.health = health
    if deconstruct then
      new_entity.order_deconstruction(new_entity.force)
    end
    if last_user then
      new_entity.last_user = last_user
    end

    -- Raise build event
    script.raise_event(defines.events.script_raised_built, {entity=new_entity, burner_fuel_bonus=true})
  end

  return new_entity
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
script.on_configuration_changed(on_configuration_changed)
script.on_event(defines.events.on_tick, on_tick)
script.on_event(defines.events.on_built_entity, on_built)
script.on_event(defines.events.on_robot_built_entity, on_built)
script.on_event(defines.events.script_raised_built, on_built)
script.on_event(defines.events.script_raised_revive, on_built)
script.on_event(defines.events.on_entity_cloned, on_built)
script.on_event(defines.events.on_player_setup_blueprint, on_blueprint_created)
script.on_event(defines.events.on_player_configured_blueprint, on_blueprint_created)
script.on_event(defines.events.on_player_pipette, on_player_pipette)
script.on_event(defines.events.on_runtime_mod_setting_changed, on_setting_changed)

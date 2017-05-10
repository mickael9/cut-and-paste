require('util')
require('defines')

function unwrap_ghost(ent)
    res = {
        name = ent.name,
        type = ent.type,
        prototype = ent.prototype,
        position = ent.position,
        direction = ent.direction,
    }
    if ent.type == 'entity-ghost' then
        res.name = ent.ghost_name
        res.type = ent.ghost_type
        res.prototype = ent.ghost_prototype
    end
    return res
end

-- Rotate a point
--
-- point: the point to rotate
-- direction: new direction (from north)
--     north: no rotation
--     east: rotate clockwise 90°
--     west: rotate counter-clockwise 90°
--     south: rotate 180°
-- center: point at which the rotation is applied

function rotate_point(point, center, direction)
    local cx, cy = center.x, center.y
    local x, y = point.x, point.y
    local tx, ty = x - cx, y - cy
    local matrices = {
        [defines.direction.north] = { 1,  0,  0,  1},
        [defines.direction.west]  = { 0,  1, -1,  0},
        [defines.direction.east]  = { 0, -1,  1,  0},
        [defines.direction.south] = {-1,  0,  0, -1},
    }
    local m = matrices[direction]
    local mx = m[1] * tx + m[2] * ty
    local my = m[3] * tx + m[4] * ty

    return {x = mx + cx, y = my + cy}
end

function add_points(...)
    res = { x = 0, y = 0 }
    for _, point in pairs{...} do
        res.x = res.x + point.x
        res.y = res.y + point.y
    end
    return res
end

function negate_point(point)
    return { x = -point.x, y = -point.y }
end

function player_data(player)
    if type(player) ~= 'number' then
        player = player.index
    end

    if global.data[player] == nil then
        global.data[player] = {}
    end

    return global.data[player]
end

function get_setting(player, name)
    return settings.get_player_settings(player)[name].value
end

function sort_by_position(list)
    table.sort(list, function(a, b)
        return a.position.y < b.position.y or (
            a.position.y == b.position.y and a.position.x < b.position.x)
    end)
end

function init()
    global.data = global.data or {}
end

script.on_init(init)
script.on_configuration_changed(init)

function on_selected_area(event)
    if event.item ~= mod.tools.cut and event.item ~= mod.tools.copy then
        return
    end

    local player = game.players[event.player_index]
    local area = event.area
    local item = player.cursor_stack
    local data = player_data(player)
    local always_include_tiles = (event.name == defines.events.on_player_alt_selected_area)
    local center_pos
    local reconnect = {}
    local entities = {}
    local cut = event.item == mod.tools.cut
    local paste_tool

    -- Transform selector into a blueprint
    if cut then
        paste_tool = mod.blueprints.cut
    else
        paste_tool = mod.blueprints.copy
    end
    item.set_stack{name = paste_tool}

    item.create_blueprint{
        always_include_tiles = always_include_tiles,
        surface = player.surface,
        force = player.force,
        area = area
    }

    if not item.is_blueprint_setup() then
        return
    end

    -- Locate where the blueprint origin position is on the actual map
    --
    -- This is achieved by finding the first item (by position) in the
    -- selection area and in the blueprint.
    --
    -- The difference between the two is our center

    local blueprint_tiles = item.get_blueprint_tiles() or {}
    local blueprint_entities = item.get_blueprint_entities() or {}
    sort_by_position(blueprint_entities)

    printf("#bp entities: %s", #blueprint_entities)
    printf("#bp tiles: %s", #blueprint_tiles)

    if #blueprint_entities > 0 then
        local ref_bp = blueprint_entities[1]

        entities = player.surface.find_entities_filtered{
            area = area,
            force = player.force,
        }
        sort_by_position(entities)

        for _, match in pairs(entities) do
            match = unwrap_ghost(match)

            if match.name == ref_bp.name then
                local pos_src = match.position
                local pos_bp = ref_bp.position

                center_pos = {
                    x = pos_src.x - pos_bp.x,
                    y = pos_src.y - pos_bp.y,
                }
                printf("found bp center pos: %s", center_pos)
                break
            end
        end

        -- We copy relevant info from the source entities since those may not be valid
        -- anymore when we need them later
        for _, entity in pairs(entities) do
            reconnect[entity.unit_number] = unwrap_ghost(entity)
            reconnect[entity.unit_number].reconnect = {}
        end

        -- Also copy all circuit connections external to the blueprint
        for _, entity in pairs(entities) do
            local defs = entity.circuit_connection_definitions or {}

            for _, def in pairs(defs) do
                local target_entity = def.target_entity
                if reconnect[target_entity.unit_number] == nil then
                    table.insert(reconnect[entity.unit_number].reconnect, def)
                end
            end
        end

        printf("#reconnect: %s", #reconnect)
    end

    data.selection = {
        cut = cut,
        tool = event.item,
        paste_tool = paste_tool,
        state = item_state.moving_to_hand,
        area = area,
        source = {
            center_pos = center_pos,
            entities = entities,
            reconnect = reconnect or {},
            tiles = #blueprint_tiles > 0 and event.tiles or {},
        },
        blueprint = { tiles = blueprint_tiles, entities = blueprint_entities },
        placeholders = { top_pos = {}, center_pos = {} },
    }
end

script.on_event(defines.events.on_player_selected_area, on_selected_area)
script.on_event(defines.events.on_player_alt_selected_area, on_selected_area)

script.on_event(defines.events.on_player_cursor_stack_changed, function(event)
    printf("on_cursor_stack_changed")

    local player = game.players[event.player_index]
    local item = player.cursor_stack
    local data = player_data(player)
    local reuse_copy_bp = get_setting(player, mod.setting_names.reuse_copy_blueprint)


    if data.selection and data.selection.state ~= item_state.moving_to_hand then
        data.selection = nil
        printf("reset selection (not moving to hand)")
    end

    if not item.valid_for_read then
        printf("not valid for read")
        return
    end

    if data.selection and data.selection.paste_tool ~= item.name then
        printf("reset selection (invalid paste tool)")
        data.selection = nil
    end

    if item.name == mod.blueprints.cut  then
        if data.selection == nil or not item.is_blueprint_setup() then
            -- Cut blueprint are single-use and are automatically
            -- converted back to their tool form
            item.set_stack{name = mod.tools.cut}
            data.selection = nil
            printf("cut blueprint replaced")
        end
    elseif item.name == mod.blueprints.copy then
        -- Copy blueprints can be used like normal blueprints
        -- They're converted back to the tool form when empty
        if not item.is_blueprint_setup() or (data.selection == nil and not reuse_copy_bp) then
            item.set_stack{name = mod.tools.copy}
            data.selection = nil
            printf("copy blueprint replaced")
        elseif data.selection == nil then
            printf("recreating selection from blueprint")

            data.selection = {
                cut = false,
                tool = mod.tools.copy,
                paste_tool = item.name,
                state = item_state.in_hand,
                blueprint = {
                    tiles = item.get_blueprint_tiles() or {},
                    entities = item.get_blueprint_entities() or {},
                    placed_at = event.position,
                },
                placeholders = { top_pos = {}, center_pos = {} },
            }
        end
    end

    if data.selection then
        data.selection.state = item_state.in_hand
    end
end)

script.on_event(defines.events.on_put_item, function(event)
    local player = game.players[event.player_index]
    local item = player.cursor_stack

    printf("on_put_item", event)

    if not item.valid_for_read or (
            item.name ~= mod.blueprints.copy and
            item.name ~= mod.blueprints.cut) then
        return
    end

    local data = player_data(player)

    -- on_put_item might be called several times before on_tick is called
    -- if the player moves when placing the blueprint.
    -- If that happens, we just clear the blueprint
    -- so the game doesn't place it
    if data.selection and data.selection.state == item_state.placing then
        item.clear_blueprint()
        printf("blueprint cleared!")
        return
    end

    if not data.selection or data.selection.state ~= item_state.in_hand
            or data.selection.paste_tool ~= item.name then
        printf("invalid state, val=%s, sel=%s", item.valid_for_read, data.selection or 'nil')
        data.selection = nil
        player.clean_cursor()
        return
    end

    -- If we get here, the player successfully placed our blueprint and it either
    -- didn't collide or it did but the player used shift to force place it.

    local selection = data.selection

    -- Deconstruct the source entities and tiles  if the cut tool was used
    if selection.cut then
        for _, entity in pairs(selection.source.entities) do
            if entity.order_deconstruction(player.force) then
                -- notify other mods such as creative mode or instant blueprint
                script.raise_event(defines.events.on_marked_for_deconstruction, {
                    player_index = player.index,
                    entity = entity
                })
            end
        end

        local keep_tiles = get_setting(player, mod.setting_names.keep_tiles)
        if not keep_tiles then
            for _, tile in pairs(selection.source.tiles) do
                entity = player.surface.create_entity{
                    name = 'deconstructible-tile-proxy',
                    position = tile.position,
                    force = player.force,
                }
                -- notify other mods such as creative mode or instant blueprint
                script.raise_event(defines.events.on_marked_for_deconstruction, {
                    player_index = player.index,
                    entity = entity
                })
            end
        end
    end

    if #selection.blueprint.entities > 0 then
        -- Replace the blueprint being placed with a new one
        -- containing only two dummy tiles at (0, 0) and (0, -1)
        --
        -- Their goal is to figure out which direction the blueprint is being
        -- placed because the game won't tell us otherwise.
        --
        -- Once we've figured that out, we'll replace the blueprint again with
        -- the original one and apply it manually in the next tick

        local tiles = {}

        table.insert(tiles, {
            name = mod.placeholders.center,
            position = { x = 0, y = 0 }
        })

        table.insert(tiles, {
            name = mod.placeholders.top,
            position = { x = 0, y = -1 }
        })

        item.set_blueprint_tiles(tiles)
        item.set_blueprint_entities({})
    end

    printf("here we go")
    selection.state = item_state.placing
    global.on_tick_registered = true
    script.on_event(defines.events.on_tick, on_tick)
end)

script.on_event(defines.events.on_built_entity, function(event)
    local entity = event.created_entity
    local player = game.players[event.player_index]
    local item = event.item
    local data = player_data(player)
    local selection = data.selection

    printf("on_built_entity")

    if not selection or selection.state ~= item_state.placing then
        return
    end

    if entity.type == 'tile-ghost' then
        local original

        if entity.ghost_name == mod.placeholders.center then
            selection.placeholders.center_pos = {
                x = entity.position.x,
                y = entity.position.y
            }
            printf("center set: %s", entity.position)
        elseif entity.ghost_name == mod.placeholders.top then
            selection.placeholders.top_pos = {
                x = entity.position.x,
                y = entity.position.y
            }
            printf("top set: %s", entity.position)
        else
            return
        end

        entity.destroy()
    end
end)

function on_tick(event)
    printf("on_tick")

    for player_index, data in ipairs(global.data) do
        local player = game.players[player_index]
        local data = player_data(player)
        local selection = data.selection
        local reconnect_replaced = {}

        if selection and (not player.cursor_stack.valid_for_read
                          or player.cursor_stack.name ~= selection.paste_tool) then
            data.selection = nil
            selection = nil
            printf("cleared selection (invalid blueprint)")
        end

        if selection and selection.state == item_state.placing then
            local source = selection.source
            local blueprint = selection.blueprint
            local placeholders = selection.placeholders
            local bp_direction

            if #blueprint.entities > 0 then
                printf("placeholders: %s", selection.placeholders)

                local rotation = {
                    x = placeholders.top_pos.x - placeholders.center_pos.x,
                    y = placeholders.top_pos.y - placeholders.center_pos.y
                }

                -- Now we place the original blueprint
                local direction_map = {
                    ["0 -1"] = defines.direction.north,
                    ["1 0"]  = defines.direction.east,
                    ["-1 0"] = defines.direction.west,
                    ["0 1"]  = defines.direction.south,
                }
                local tag = string.format("%d %d", rotation.x, rotation.y)
                bp_direction = direction_map[tag]

                printf("blueprint direction: %s", bp_direction)

                -- Use blueprint entities to find out if there are colliding entities
                -- at destination, then order their deconstruction

                for _, bp_entity in pairs(blueprint.entities) do
                    -- Determine the collision box of the destination entity
                    -- in the original blueprint direction
                    local bp_entity_dir = bp_entity.direction or defines.direction.north
                    local dest_dir = (bp_direction + bp_entity_dir) % 8
                    local coll_area = game.entity_prototypes[bp_entity.name].collision_box

                    printf("bp_entity: %s", bp_entity)

                    -- Also track the entity's position along with its bounding box
                    coll_area.center = { x = 0, y = 0 }

                    printf("area: %s", coll_area)

                    for edge, point in pairs(coll_area) do
                        -- Apply original entity direction from blueprint
                        point = rotate_point(point, { x = 0, y = 0 }, bp_entity_dir)

                        -- Translate the area to the destination point
                        point = add_points(point, bp_entity.position, placeholders.center_pos)

                        -- Apply the global blueprint rotation
                        point = rotate_point(point, placeholders.center_pos, bp_direction)

                        coll_area[edge] = point

                    end

                    local coll_center = coll_area.center
                    coll_area.center = nil

                    -- Make sure the area edges are actually "left top" and "right bottom"
                    -- since we may have rotated the area
                    for _, var in pairs{'x', 'y'} do
                        if coll_area.left_top[var] > coll_area.right_bottom[var] then
                            coll_area.left_top[var], coll_area.right_bottom[var] = coll_area.right_bottom[var], coll_area.left_top[var]
                        end
                    end

                    local coll_entities = player.surface.find_entities_filtered{
                        surface = player.surface,
                        force = player.force,
                        area = coll_area,
                    }
                    printf("#coll_entities: %d", #coll_entities)

                    for _, coll_entity in pairs(coll_entities) do
                        local real_coll_entity = unwrap_ghost(coll_entity)

                        if not real_coll_entity.prototype.has_flag('not-on-map') then
                            local same_name = real_coll_entity.name == bp_entity.name
                            local same_dir = dest_dir == (coll_entity.direction or defines.direction.north)
                            local same_pos = coll_center.x == coll_entity.position.x and coll_center.y == coll_entity.position.y
                            local compatible = same_name and same_dir and same_pos
                            local replace_mode = get_setting(player, mod.setting_names.replace_mode)

                            --printf("collision: from %s", dump_entity(bp_entity))
                            --printf("collision: to %s", dump_entity(coll_entity))
                            printf("replace mode: %s, actual dir: %s, compat: %s", replace_mode, actual_direction, compatible)
                            printf("same name: %s, pos: %s, dir: %s", same_name, same_pos, same_dir)

                            if replace_mode ~= mod.setting_values.replace_mode.never then
                                if replace_mode == mod.setting_values.replace_mode.always or not compatible then
                                    local defs = coll_entity.circuit_connection_definitions

                                    if compatible and defs and #defs > 0 then
                                        reconnect_replaced[coll_entity.unit_number] = {
                                            name = real_coll_entity.name,
                                            position = real_coll_entity.position,
                                            definitions = defs,
                                        }
                                    end

                                    coll_entity.order_deconstruction(player.force)
                                    script.raise_event(defines.events.on_marked_for_deconstruction, {
                                        player_index = player.index,
                                        entity = coll_entity
                                    })
                                end
                            end
                        end
                    end
                end

                -- Reset the blueprint
                player.cursor_stack.set_blueprint_entities(selection.blueprint.entities)
                player.cursor_stack.set_blueprint_tiles(selection.blueprint.tiles)
                local ghosts = player.cursor_stack.build_blueprint{
                    force = player.force,
                    surface = player.surface,
                    direction = bp_direction,
                    position = selection.placeholders.center_pos,
                    force_build = true, -- This won't cause any harm because we never get here if there was a conflict unless the player forced it with shift
                }

                for _, ghost in pairs(ghosts) do
                    script.raise_event(defines.events.on_built_entity, {
                        player_index = player.index,
                        created_entity = ghost
                    })
                end

                printf("rebuilt blueprint")
            end

            local reconnect_wires = get_setting(player, mod.setting_names.reconnect_wires)

            for _, replacement in pairs(reconnect_replaced) do
                local entity = player.surface.find_entity('entity-ghost', replacement.position)
                if entity and entity.ghost_name == replacement.name then
                    for _, def in pairs(replacement.definitions) do
                        entity.connect_neighbour(def)
                    end
                end
            end

            if selection.cut and reconnect_wires then
                if #blueprint.entities > 0 then
                    for _, reconnect in pairs(source.reconnect) do
                        -- Rotate the original source position
                        local rotated = rotate_point(
                            reconnect.position,
                            source.center_pos,
                            bp_direction
                        )

                        -- Translate to destination position
                        local dest_pos = add_points(rotated, placeholders.center_pos, negate_point(source.center_pos))
                        local entity = player.surface.find_entity('entity-ghost', dest_pos)

                        if not entity then
                            entity = player.surface.find_entity(reconnect.name, dest_pos)
                        end

                        if entity then
                            for _, def in pairs(reconnect.reconnect) do
                                local target = def.target_entity
                                if target.valid then
                                    entity.connect_neighbour(def)
                                end
                            end
                        end
                    end
                end

                player.cursor_stack.set_stack{name = selection.tool}
                data.selection = nil
                printf("cut finished")
            else
                printf("restarting copy")
                selection.state = item_state.in_hand -- Restart from scratch
            end
        else
            printf("there was no selection, %s", selection)
        end
    end
    script.on_event(defines.events.on_tick, nil)
    global.on_tick_registered = false
end


for typ, ev in pairs{[defines.inventory.player_main]     = defines.events.on_player_main_inventory_changed,
                     [defines.inventory.player_quickbar] = defines.events.on_player_quickbar_inventory_changed}
do
    script.on_event(ev, function(event)
        printf("inventory changed")
        local player = game.players[event.player_index]
        local inv = player.get_inventory(typ)

        for i = 1, #inv do
            local stack = inv[i]
            if stack.valid_for_read then
                if stack.name == mod.blueprints.cut then
                    stack.set_stack{name = mod.tools.cut}
                    printf("cut blueprint replaced")
                elseif stack.name == mod.blueprints.copy  then
                    local reuse_copy_bp = get_setting(player, mod.setting_names.reuse_copy_blueprint)
                    if not stack.is_blueprint_setup() or not reuse_copy_bp then
                        stack.set_stack{name = mod.tools.copy}
                        printf("copy blueprint replaced")
                    end
                end
            end
        end

    end)
end

script.on_load(function()
    if global.on_tick_registered then
        script.on_event(defines.events.on_tick, on_tick)
    end
end)

require('util')
require('defines')

local ZERO = { x = 0, y = 0 }

function unwrap_ghost(ent)
    if not ent or not ent.valid then
        return { valid = false }
    end

    res = {
        name = ent.name,
        type = ent.type,
        prototype = ent.prototype,
        position = ent.position,
        direction = ent.direction,
        original = ent,
        unit_number = ent.unit_number,
        valid = true,
    }
    if ent.type == 'entity-ghost' then
        res.name = ent.ghost_name
        res.type = ent.ghost_type
        res.prototype = ent.ghost_prototype
    end
    return res
end

function can_be_part_of_blueprint(prototype)
    if not prototype.has_flag('player-creation') or prototype.has_flag('not-blueprintable') then
        return false
    end

    return has_keys(prototype.items_to_place_this)
end

-- Rotate a point
--
-- point: the point to rotate
--
-- angle: 0..1
-- center: point at which the rotation is applied

function rotate_point(point, center, angle)
    local cx, cy = center.x, center.y
    local x, y = point.x, point.y
    local tx, ty = x - cx, y - cy
    angle = angle * 2 * math.pi

    local mx = tx * math.cos(angle) - ty * math.sin(angle)
    local my = tx * math.sin(angle) + ty * math.cos(angle)

    return {x = mx + cx, y = my + cy}
end


function map_point(src_point, src_origin, src_direction,
                   dst_origin, rotation)

    local src_direction = (src_direction or 0) % 8
    local rotation = (rotation or 0) % 8
    local dst_direction = (src_direction + rotation) % 8
    local dst_point

    dst_point = rotate_point(src_point, src_origin, rotation / 8)
    dst_point = add_points(dst_point, dst_origin, negate_point(src_origin))

    return dst_point, dst_direction
end

function find_entity_or_ghost_at(surface, name, position)
    local entity = surface.find_entity('entity-ghost', position)

    if not entity or entity.ghost_name ~= name then
        entity = surface.find_entity(name, position)
    end

    return entity
end

-- Returns the four corners of an oriented bounding box and its center
function obb_corners(bounding_box)
    local center = {
        x = (bounding_box.left_top.x + bounding_box.right_bottom.x) / 2,
        y = (bounding_box.left_top.y + bounding_box.right_bottom.y) / 2,
    }

    local vertices = {
        { x = bounding_box.left_top.x,     y = bounding_box.left_top.y },
        { x = bounding_box.left_top.x,     y = bounding_box.right_bottom.y },
        { x = bounding_box.right_bottom.x, y = bounding_box.left_top.y },
        { x = bounding_box.right_bottom.x, y = bounding_box.right_bottom.y },
    }

    for edge, point in pairs(vertices) do
        vertices[edge] = rotate_point(point, center, bounding_box.orientation or 0)
    end

    return vertices, center
end

-- Returns the bouding box of an entity when placed at that position and direction
-- If the direction is not a multiple of 90° (like 45° rails), then we return
-- a bigger straight bounding box that contains the other one
function bounding_box(force, surface, name, position, direction)
    direction = (direction or 0) % 8

    -- Just create a temporary ghost and read its bounding_box property
    local ent = surface.create_entity{
        name = 'entity-ghost',
        inner_name = name,
        position = position,
        direction = direction,
        force = force,
    }

    if not ent then
        game.print(string.format("%s: %s: failed to compute bounding box", mod.name, name))
        return
    end

    local area = ent.bounding_box
    local secondary_area = ent.secondary_bounding_box
    ent.destroy()

    -- We also need to handle the case of oriented bounding boxes
    -- in that case, we just create the axis-aligned bounding box
    -- that contains the oriented bounding box

    local vertices, center = obb_corners(area)

    if secondary_area then
        local secondary_vertices = obb_corners(secondary_area)
        for _, v in pairs(secondary_vertices) do
            table.insert(vertices, v)
        end
    elseif not area.orientation or area.orientation == 0 then
        return area
    end

    area = {
        left_top     = add_points(center),
        right_bottom = add_points(center),
    }

    -- Take the min/max of all the vertices to get the final collision box
    for edge, point in pairs(vertices) do
        area.left_top.x = math.min(area.left_top.x, point.x)
        area.left_top.y = math.min(area.left_top.y, point.y)
        area.right_bottom.x = math.max(area.right_bottom.x, point.x)
        area.right_bottom.y = math.max(area.right_bottom.y, point.y)
    end

    return area
end

function find_collisions(surface, area)
    local entities = surface.find_entities_filtered{
        surface = surface,
        area = area,
    }
    local collisions = {}

    for _, entity in pairs(entities or {}) do
        if not entity.to_be_deconstructed(entity.force) then
            table.insert(collisions, entity)
        end
    end

    return collisions
end

function add_points(...)
    res = { x = 0, y = 0 }
    for _, point in pairs{...} do
        res.x = res.x + point.x
        res.y = res.y + point.y
    end
    return res
end

function sub_points(point, sub)
    return {
        x = point.x - sub.x,
        y = point.y - sub.y
    }
end

function negate_point(point)
    return { x = -point.x, y = -point.y }
end

function point_equals(p1, p2)
    return p1.x == p2.x and p1.y == p2.y
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

-- Returns true if a table has any keys (not necessarily numeric)
function has_keys(table)
    for _, _ in pairs(table or {}) do
        return true
    end
    return false
end

function deconstruct_entity(entity, player)
    local result

    if not entity or not entity.valid then
        return false
    end

    if entity.to_be_deconstructed(player.force) then
        result = true
    else
        result = entity.order_deconstruction(player.force)
    end

    if result then
        script.raise_event(defines.events.on_marked_for_deconstruction, {
            player_index = player.index,
            entity = entity,
            mod = mod.name,
        })
    end

    return result
end

function raise_built_entity(entity, player)
    if entity and entity.valid then
        script.raise_event(defines.events.on_built_entity, {
            player_index = player.index,
            created_entity = entity,
            mod = mod.name,
        })
        return true
    end
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
    local saved_entities = {}
    local entities = {}
    local cut = event.item == mod.tools.cut
    local paste_tool
    local item_requests = {}

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

    for index, tile in pairs(event.tiles) do
        local prototype = game.tile_prototypes[tile.name]

        if not prototype.can_be_part_of_blueprint then
            event.tiles[index] = nil
        end
    end

    if #blueprint_entities > 0 then
        local ref_bp = blueprint_entities[1]

        if not point_equals(area.left_top, area.right_bottom) then
            entities = player.surface.find_entities_filtered{
                area = area,
                force = player.force,
            }
        else
            entities = player.surface.find_entities_filtered{
                position = area.left_top,
                force = player.force,
            }
        end

        sort_by_position(entities)

        for index, match in pairs(entities) do
            match = unwrap_ghost(match)
            -- Filter out entites that can't be in a blueprint
            if not can_be_part_of_blueprint(match.prototype) then
                if match.type == 'item-request-proxy' then
                    local target = match.original.proxy_target
                    if target and target.valid and target.unit_number then
                        item_requests[target.unit_number] = match.original.item_requests
                    end
                end

                entities[index] = nil
            elseif not center_pos and match.name == ref_bp.name then
                local pos_src = match.position
                local pos_bp = ref_bp.position

                center_pos = sub_points(pos_src, pos_bp)
                printf("found bp center pos: %s", center_pos)
            end
        end

        -- We copy relevant info from the source entities since those may not be valid
        -- anymore when we need them later
        for _, entity in pairs(entities) do
            local saved = unwrap_ghost(entity)
            saved.reconnect = {}

            local items = {}
            local blacklisted = false

            if entity.type == 'entity-ghost' then
                items = entity.item_requests or {}
            elseif item_requests[entity.unit_number] then
                items = item_requests[entity.unit_number]
            end

            if saved.type == 'logistic-container' then
                if saved.prototype.logistic_mode ~= 'storage' then
                    blacklisted = true
                end
            end

            if not blacklisted and entity.has_items_inside() then
                local blacklist = inventory_blacklists[saved.type] or {}

                for i = 1, 8 do
                    local inv = entity.get_inventory(i)

                    if inv and not blacklist[i] then
                        for j = 1, #inv do
                            local stack = inv[j]
                            if stack.valid_for_read then
                                items[stack.name] = (items[stack.name] or 0) + stack.count
                            end
                        end
                    end
                end
            end

            if has_keys(items) then
                saved.items = items
            end

            saved_entities[entity.unit_number] = saved
        end

        -- Also copy all circuit connections external to the blueprint
        for _, entity in pairs(entities) do
            local defs = entity.circuit_connection_definitions or {}

            for _, def in pairs(defs) do
                local target_entity = def.target_entity
                if saved_entities[target_entity.unit_number] == nil then
                    table.insert(saved_entities[entity.unit_number].reconnect, def)
                end
            end
        end

        printf("#saved_entities: %s", #saved_entities)
    end

    data.selection = {
        cut = cut,
        tool = event.item,
        paste_tool = paste_tool,
        state = item_state.moving_to_hand,
        source = {
            center_pos = center_pos,
            entities = saved_entities,
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
    selection.blueprint.placed_at = event.position
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

    if not entity.valid then
        printf("invalid entity in on_built_entity")
        return
    end

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

    for player_index, data in pairs(global.data) do
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
            local bp_rotation
            local bp_place_pos

            selection.state = item_state.placed

            -- Deconstruct the source entities and tiles  if the cut tool was used
            if selection.cut then
                for _, entity in pairs(selection.source.entities) do
                    deconstruct_entity(entity.original, player)
                end

                local keep_tiles = get_setting(player, mod.setting_names.keep_tiles)
                if not keep_tiles then
                    for _, tile in pairs(selection.source.tiles) do
                        entity = player.surface.create_entity{
                            name = 'deconstructible-tile-proxy',
                            position = tile.position,
                            force = player.force,
                        }
                        deconstruct_entity(entity, player)
                    end
                end
            end

            if #blueprint.entities > 0 then
                printf("placeholders: %s", selection.placeholders)

                local rotation = sub_points(placeholders.top_pos, placeholders.center_pos)

                -- Now we place the original blueprint
                local direction_map = {
                    ["0 -1"] = defines.direction.north,
                    ["1 0"]  = defines.direction.east,
                    ["-1 0"] = defines.direction.west,
                    ["0 1"]  = defines.direction.south,
                }
                local tag = string.format("%d %d", rotation.x, rotation.y)
                bp_rotation = direction_map[tag]

                printf("blueprint rotation: %s", bp_rotation)

                -- Find the blueprint build grid shift: https://forums.factorio.com/viewtopic.php?f=25&t=48383
                -- Also checks if the blueprint is constrained by a grid or not
                local bp_grid_shift = 0
                local off_grid = true
                for _, bp_entity in pairs(blueprint.entities) do
                    local prototype = game.entity_prototypes[bp_entity.name]
                    local shift = prototype.building_grid_bit_shift
                    if shift > bp_grid_shift then
                        bp_grid_shift = shift
                    end
                    if not prototype.has_flag('placeable-off-grid') then
                        off_grid = false
                    end
                end

                if off_grid then
                    bp_place_pos = blueprint.placed_at
                else
                    local shift_val = 2^bp_grid_shift
                    bp_place_pos = {
                        x = shift_val / 2 + math.floor(math.floor(blueprint.placed_at.x) / shift_val) * shift_val,
                        y = shift_val / 2 + math.floor(math.floor(blueprint.placed_at.y) / shift_val) * shift_val,
                    }
                end

                -- Use blueprint entities to find out if there are colliding entities
                -- at destination, then order their deconstruction

                for _, bp_entity in pairs(blueprint.entities) do
                    -- Determine the collision area at the destination
                    local bp_ent_direction = bp_entity.direction or 0
                    local dest_pos, dest_dir = map_point(bp_entity.position, ZERO, bp_ent_direction,
                                                         bp_place_pos, bp_rotation)

                    printf("bp_entity: %s", bp_entity)

                    local coll_entities = {}
                    local collides = not player.surface.can_place_entity{
                        name = bp_entity.name,
                        position = dest_pos,
                        direction = dest_dir,
                        force = player.force
                    }

                    local coll_area = bounding_box(player.force, player.surface, bp_entity.name, dest_pos, dest_dir)

                    if coll_area then
                        coll_entities = find_collisions(player.surface, coll_area)

                        -- can_place_entity returns true if we collide only with ghosts
                        -- but we want it to return false in that situation
                        if #coll_entities > 0 then
                            local all_ghosts = true
                            for _, coll_entity in pairs(coll_entities) do
                                if coll_entity.type ~= 'entity-ghost' then
                                    all_ghosts = false
                                    break
                                end
                            end
                            if not collides and all_ghosts then
                                collides = true
                            end
                        end
                    end

                    if not collides then
                        coll_entities = {}
                    end

                    printf("#coll_entities: %d", #coll_entities)

                    local src_pos, src_entity

                    if source then
                        src_pos = map_point(bp_entity.position, ZERO, bp_ent_direction,
                                            source.center_pos, 0)

                        src_entity = find_entity_or_ghost_at(player.surface, bp_entity.name, src_pos)

                        if not src_entity then
                            printf("source entity %s not found at %s", bp_entity.name, src_pos)
                        end
                    end

                    for _, coll_entity in pairs(coll_entities) do
                        coll_entity = unwrap_ghost(coll_entity)

                        local replace_mode = get_setting(player, mod.setting_names.replace_mode)
                        local same_name = coll_entity.name == bp_entity.name
                        local same_pos = point_equals(dest_pos, coll_entity.position)

                        -- can we modify this entity so it matches the source one?
                        local inplace = same_name and same_pos and src_entity and src_entity.name == bp_entity.name
                        inplace = inplace and replace_mode == mod.setting_values.replace_mode.when_different

                        if inplace then
                            local same_dir = coll_entity.direction == src_entity.direction or not src_entity.supports_direction
                            -- if the only entity in the destination area is the one we want, and it has the same position then
                            -- rotating it will make it fit exactly without any other conflicts
                            if same_dir or #coll_entities == 1 then
                                coll_entity.original.copy_settings(src_entity)
                                coll_entity.original.direction = dest_dir
                            else
                                inplace = false
                            end
                        end

                        local replace = replace_mode == mod.setting_values.replace_mode.always or (
                                        replace_mode == mod.setting_values.replace_mode.when_different and not inplace)

                        if replace then
                            local defs = coll_entity.original.circuit_connection_definitions

                            if same_name and same_pos and defs and #defs > 0 then
                                reconnect_replaced[coll_entity.unit_number] = {
                                    name = coll_entity.name,
                                    position = coll_entity.position,
                                    definitions = defs,
                                }
                            end

                            deconstruct_entity(coll_entity.original, player)
                        end
                    end
                end

                -- Place the real blueprint
                player.cursor_stack.set_blueprint_entities(selection.blueprint.entities)
                player.cursor_stack.set_blueprint_tiles(selection.blueprint.tiles)
                local ghosts = player.cursor_stack.build_blueprint{
                    force = player.force,
                    surface = player.surface,
                    direction = bp_rotation,
                    position = selection.blueprint.placed_at,
                    force_build = true, -- This won't cause any harm because we never get here if there was a conflict unless the player forced it with shift
                }

                for _, ghost in pairs(ghosts) do
                    if not raise_built_entity(ghost, player) then
                        printf("invalid ghost returned by build_blueprint?")
                    end
                end

                printf("rebuilt blueprint")
            end

            for _, replacement in pairs(reconnect_replaced) do
                local entity = player.surface.find_entity('entity-ghost', replacement.position)
                if entity and entity.ghost_name == replacement.name then
                    for _, def in pairs(replacement.definitions) do
                        entity.connect_neighbour(def)
                    end
                end
            end

            for _, src_ent in pairs(source and source.entities or {}) do
                local dest_pos = map_point(
                    src_ent.position,
                    source.center_pos,
                    src_ent.direction,
                    bp_place_pos,
                    bp_rotation
                )

                local dest_entity = find_entity_or_ghost_at(player.surface, src_ent.name, dest_pos)

                if not dest_entity then
                    printf("destination entity %s not found at %s", src_ent.name, dest_pos)
                end

                local reconnect_wires = get_setting(player, mod.setting_names.reconnect_wires)
                if dest_entity and selection.cut and reconnect_wires then
                    for _, def in pairs(src_ent.reconnect) do
                        local target = def.target_entity
                        if target.valid then
                            dest_entity.connect_neighbour(def)
                        end
                    end
                end

                local copy_items = get_setting(player, mod.setting_names.copy_items)
                copy_items = copy_items == mod.setting_values.copy_items.always or (
                             copy_items == mod.setting_values.copy_items.move_only and selection.cut)

                if dest_entity and copy_items and src_ent.items then

                    if dest_entity.type == 'entity-ghost' then
                        dest_entity.item_requests = src_ent.items
                        printf("set item requests: %s", items)
                    else
                        local proxy = player.surface.create_entity{
                            name = 'item-request-proxy',
                            force = player.force,
                            position = dest_entity.position,
                            target = dest_entity,
                            modules = src_ent.items,
                        }

                        if raise_built_entity(proxy, player) then
                            printf("created request proxy: %s %s", items, proxy.item_requests)
                        else
                            printf("failed to create request proxy")
                        end
                    end
                end
            end

            if selection.cut then
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

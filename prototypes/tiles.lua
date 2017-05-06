local dummy_tile = {
    picture = "__base__/graphics/terrain/blank.png",
    count = 1,
    size = 1,
}

local function make_placeholder(name)
    data:extend{
        {
            type = "tile",
            name = name,
            needs_correction = false,
            collision_mask = {},
            layer = 100,
            variants = {
                main = { dummy_tile },
                inner_corner = dummy_tile,
                outer_corner = dummy_tile,
                side = dummy_tile,
            },
            map_color={r=0, g=0, b=0},
            ageing=0,
            vehicle_friction_modifier = concrete_vehicle_speed_modifier
        },
    }
end

-- Invisible tiles used to detect blueprint placement direction
make_placeholder(mod.placeholders.center)
make_placeholder(mod.placeholders.top)

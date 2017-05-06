data:extend{
    {
        -- This item is used to select a zone to cut & paste
        type = "selection-tool",
        name = mod.tools.cut,
        icon = mod.dir .. "/graphics/icons/cut-tool.png",
        flags = {"goes-to-quickbar"},
        subgroup = "tool",
        order = "c[automated-construction]-a[blueprint]",
        stack_size = 1,
        stackable = false,
        selection_color = { r = 1, g = 0.5, b = 0 },
        alt_selection_color = { r = 1, g = 0.5, b = 0 },
        selection_mode = {"blueprint"},
        alt_selection_mode = {"any-tile"},
        selection_cursor_box_type = "copy",
        alt_selection_cursor_box_type = "copy",
    },

    {
        -- This item is used to select a zone to copy & paste
        type = "selection-tool",
        name = mod.tools.copy,
        icon = mod.dir .. "/graphics/icons/copy-tool.png",
        flags = {"goes-to-quickbar"},
        subgroup = "tool",
        order = "c[automated-construction]-a[blueprint]",
        stack_size = 1,
        stackable = false,
        selection_color = { r = 1, g = 0.5, b = 0 },
        alt_selection_color = { r = 1, g = 0.5, b = 0 },
        selection_mode = {"blueprint"},
        alt_selection_mode = {"any-tile"},
        selection_cursor_box_type = "copy",
        alt_selection_cursor_box_type = "copy",
    },

    {
        -- This blueprint type is used to contain the user's selection
        type = "blueprint",
        name = mod.blueprints.copy,
        icon = mod.dir .. "/graphics/icons/blueprint.png",
        flags = {"goes-to-quickbar", "hidden"},
        subgroup = "tool",
        order = "c[automated-construction]-a[blueprint]",
        stack_size = 1,
        stackable = false,
        selection_color = { r = 0, g = 1, b = 0 },
        alt_selection_color = { r = 0, g = 1, b = 0 },
        selection_mode = {"cancel-deconstruct"},
        alt_selection_mode = {"cancel-deconstruct"},
        selection_cursor_box_type = "not-allowed",
        alt_selection_cursor_box_type = "not-allowed"
    },
    {
        -- This blueprint type is used to contain the user's selection
        type = "blueprint",
        name = mod.blueprints.cut,
        icon = mod.dir .. "/graphics/icons/blueprint.png",
        flags = {"goes-to-quickbar", "hidden"},
        subgroup = "tool",
        order = "c[automated-construction]-a[blueprint]",
        stack_size = 1,
        stackable = false,
        selection_color = { r = 0, g = 1, b = 0 },
        alt_selection_color = { r = 0, g = 1, b = 0 },
        selection_mode = {"cancel-deconstruct"},
        alt_selection_mode = {"cancel-deconstruct"},
        selection_cursor_box_type = "not-allowed",
        alt_selection_cursor_box_type = "not-allowed"
    },
}

local function make_placeholder_item(name)
    data:extend{
        {
            -- Not a real item, just needs to exist for the tile
            -- to be able to be in a blueprint.

            type = "item",
            name = name,
            icon = mod.dir .. "/graphics/icons/empty.png",
            flags = {"hidden"},
            order = "a",
            place_as_tile = {
                result = name,
                condition = { },
                condition_size = 0,
            },
            stack_size = 1,
        },

    }
end

make_placeholder_item(mod.placeholders.top)
make_placeholder_item(mod.placeholders.center)

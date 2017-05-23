require('defines')

data:extend{
	{
		type = "string-setting",
		name = mod.setting_names.replace_mode,
		setting_type = "runtime-per-user",
		default_value = mod.setting_values.replace_mode.when_different,
		allowed_values = {
			mod.setting_values.replace_mode.when_different,
			mod.setting_values.replace_mode.always,
			mod.setting_values.replace_mode.never,
		},
		order = "a",
	},
	{
		type = "string-setting",
		name = mod.setting_names.copy_items,
		setting_type = "runtime-per-user",
		default_value = mod.setting_values.copy_items.move_only,
		allowed_values = {
			mod.setting_values.copy_items.move_only,
			mod.setting_values.copy_items.always,
			mod.setting_values.copy_items.never,
		},
		order = "b",
	},
	{
		type = "bool-setting",
		name = mod.setting_names.keep_tiles,
		setting_type = "runtime-per-user",
		default_value = false,
		order = "c",
	},
	{
		type = "bool-setting",
		name = mod.setting_names.reconnect_wires,
		setting_type = "runtime-per-user",
		default_value = true,
		order = "d",
	},
	{
		type = "bool-setting",
		name = mod.setting_names.reuse_copy_blueprint,
		setting_type = "runtime-per-user",
		default_value = false,
		order = "e",
	},
}

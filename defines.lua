mod = {}

mod.name = 'cut-and-paste'
mod.prefix = mod.name .. '-'
mod.dir = '__' .. mod.name .. '__'

mod.tools = {
    cut  = mod.prefix .. 'tool-cut',
    copy = mod.prefix .. 'tool-copy',
}
mod.blueprints = {
    cut  = mod.prefix .. 'blueprint-cut',
    copy = mod.prefix .. 'blueprint-copy'
}

mod.placeholders = {
    top    = mod.prefix .. 'placeholder-top',
    center = mod.prefix .. 'placeholder-center',
}

mod.setting_names = {
    replace_mode         = mod.prefix .. 'replace-mode',
    reuse_copy_blueprint = mod.prefix .. 'reuse-copy-blueprint',
    reconnect_wires      = mod.prefix .. 'reconnect-wires',
    keep_tiles           = mod.prefix .. 'keep-tiles',
}
mod.setting_values = {
    replace_mode = {
        when_different = 'When different',
        always = 'Always',
        never = 'Never',
    }
}

item_state = {
    moving_to_hand = 1,
    in_hand = 2,
    placing = 3,
}


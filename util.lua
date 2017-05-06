DEBUG = false

function dump(obj)
    return serpent.block(obj, {comment = false})
end

function dump_entity(ent)
    local type = ent.type
    local name = ent.name
    if type == 'entity-ghost' or type == 'tile-ghost' then
        name = string.format("%s (%s)", ent.ghost_name, ent.name)
        type = string.format("%s (%s)", ent.ghost_type, ent.type)
    end
    return dump{
        name = name,
        type = type,
        position = ent.position,
        direction = ent.direction
    }

end

function printf(s, ...)
    if not DEBUG then
        return
    end

    local args = table.pack(...)
    for i = 1, args.n do
        if type(args[i]) == 'table' then
            args[i] = dump(args[i])
        end
    end
    print(string.format(s, table.unpack(args, 1, args.n)))
end



local my = { 
    keys = {},
    bindings = { escape = 'escape' }
}

function registerBindings(t)
    my.bindings = t
end

function getBinding(code)
    if my.bindings[code] then
        return my.bindings[code]
    end
    print('binding not found')
    return 'unknown'
end

function love.keypressed(key, code)
    my.keys[code] = true
end

function pollInputs(input)
    for key,_ in pairs(my.keys) do
        my.keys[key] = nil
        if my.bindings[key] then
            input.code = my.bindings[key]
            return true
        end
    end
    return false
end

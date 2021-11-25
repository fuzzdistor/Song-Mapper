-- Song Mapper v0.9
-- por FuzzDistor - fuzzdistor@gmail.com


json = require('json')

require('InputManager')

local lang_en = {
    lang = 'en',
    instructions = 
    '> Press Space to start and pause recording inputs\n'..
    '> Use the Up and Down arrows to navigate the map\n'..
    '> Use Left and Right to adjust the zoom\n'..
    '> Press R to highlight a zone\n'..
    '\t> Press X to remove highlighted notes\n'..
    '> Use shift while navigating for precise movement\n'..
    '> Press C to change modes\n'..
    '> Press U to save the map',
    ready = 'Ready!',
    map_load_success = 'Loaded map succesfully!',
    song_load_success = 'Loaded song succesfully!',
    rec_stop = 'Stopped recording',
    dd_instr = 'Drag and drop a music file into the window!',
    rec_start = 'Recording input...',
    saved_in = 'Saved in',
    note_parse_fail = 'failed to recognize channel for note code',
    time = 'Time',
    zoom = 'Zoom',
    song = 'Song',
    no_song_sel = 'No song selected!',
}

local lang_es = {
    lang = 'es',
    instructions = 
    '> Presiona Espacio para iniciar o parar la grabación\n'..
    '> Usa las flechas de Arriba y Abajo para navegar el mapa\n'..
    '> Usa las flechas de Izq. y Der. para ajustar el zoom\n'..
    '> Presiona R para resaltar una zona\n'..
    '\t > Presiona X para borrar las notas resaltadas\n'..
    '> Usa shift para navegar con más precisión\n'..
    '> Presiona C para cambiar de modo\n'..
    '> Presiona U para guardar el mapa',
    ready = 'Listo!',
    map_load_success = 'Mapa cargado con éxito!',
    song_load_success = 'Canción cargada con éxito!',
    rec_stop = 'Grabación pausada',
    dd_instr = 'Arrastra una canción adentro de la ventana!',
    rec_start = 'Grabando inputs...',
    saved_in = 'Guardado en',
    note_parse_fail = 'No se pudo reconocer el canal para el código',
    time = 'Tiempo',
    zoom = 'Zoom',
    song = 'Canción',
    no_song_sel = 'No se ha elegido una canción',
}

local text = lang_es

-- aliases for convenience
lg = love.graphics
la = love.audio
lk = love.keyboard

-- custom clamp function (unused)
function math.clamp(n, low, high) return math.min(math.max(n, low), high) end

-- beeeg table for storing state
local my = {}

-- repurpouse print() for showing log in-app
oldprint = print
my.log = {}
print = function(...)
    for i = 1, select('#',...) do
        my.log[#my.log+1] = tostring(select(i,...))
    end
    oldprint(...)
end

function love.load()
    my.time = 0
    my.start = false;
    my.song_data = {};
    local font = lg.newImageFont('media/imagefont.png'
    , ' abcdefghijklmnñopqrstuvwxyzABCDEFGHIJKLMNÑOPQRSTUVWXYZ0123456789.,!?-_+/():;%&`\'*#=[]<>"áéíóú' )
    font:setFilter('nearest', 'nearest')
    lg.setFont(font)

    my.offset = 0;
    my.scale = 60;
    -- TODO implement canvas for log printing
    my.console_canvas = lg.newCanvas(200,400)

    my.mode = 'Viewer'

    -- my.source = la.newSource('usseewa.wav', 'stream')
    -- my.source:setVolume(0.3)

    local bindings = {}
    bindings['escape'] = 'escape' 
    bindings['a'] = 'note_a'; bindings['h'] = 'note_a'
    bindings['s'] = 'note_b'; bindings['j'] = 'note_b' 
    bindings['d'] = 'note_c'; bindings['k'] = 'note_c' 
    bindings['f'] = 'note_d'; bindings['l'] = 'note_d' 
    bindings['g'] = 'note_e'; bindings[';'] = 'note_e' 
    bindings['c'] = 'mode' 
    bindings['x'] = 'erase' 
    bindings['w'] = 'start' 
    bindings['p'] = 'change lang' 
    bindings['space'] = 'play-pause' 
    bindings['return'] = 'confirm' 
    bindings['r'] = 'toggle block' 
    bindings['up'] = 'scroll up' 
    bindings['down'] = 'scroll down' 
    bindings['left'] = 'scale down' 
    bindings['right'] = 'scale up' 
    bindings['u'] = 'save' 

    registerBindings(bindings)

    print(text.ready)
end

function love.filedropped(file)
    if string.sub(file:getFilename(), -4) == 'json' then
        file:open("r")
        local contents = file:read()
        file:close()
        my.song_data = json.decode(contents)
        print(text.map_load_success)
    else
        _, my.song_filename = file:getFilename():match("(.-)([^\\/]-%.?([^%.\\/]*))$")
        my.source = la.newSource(file, 'stream')
        my.source:setVolume(0.3)
        print(text.song_load_success)
    end
end

function toggleRecording()
    if my.start then
        pauseRecording()
    else
        resumeRecording()
    end
end

function pauseRecording()
    my.mode = my.oldMode
    my.start = false
    my.source:stop()
    sortData()
    print(text.rec_stop)
end

function resumeRecording()
    if my.source == nil then 
        print(text.dd_instr)
        return false
    end
    if my.start then return end
    my.oldMode = my.mode
    my.mode = 'Recording'
    my.start = true
    my.source:seek(my.time)
    my.source:play()
    print(text.rec_start)
end

function saveData()
    if not my.start then
        local filename = my.song_filename or "map_data"
        json.encode_file(filename, my.song_data)
        print(text.saved_in..' '..filename..'.json')
    end
end

function eraseNote(note)
    ArrayRemove(my.song_data, function(t, a)
        return t[a].note == note
            and t[a].time > my.time - 10/my.scale
            and t[a].time < my.time + 2/my.scale
        end)
end

function sortData()
    table.sort(my.song_data, function(a, b) return a.time < b.time end)
end

function cycleMode()
    if my.mode == 'Viewer' then my.mode = 'Erase' return end
    if my.mode == 'Erase' then my.mode = 'Write' return end
    if my.mode == 'Write' then my.mode = 'Viewer' return end
end

function ArrayRemove(t, fnKeep)
    local j, n = 1, #t;

    for i=1,n do
        if (not fnKeep(t, i, j)) then
            -- Move i's kept value to j's position, if it's not already there.
            if (i ~= j) then
                t[j] = t[i];
                t[i] = nil;
            end
            j = j + 1; -- Increment position of where we'll place the next kept value.
        else
            t[i] = nil;
        end
    end
    return t;
end

function eraseBlock()
    if my.block_start then
        ArrayRemove(my.song_data, function(t, a)
            return t[a].time > my.block_start and t[a].time < my.time
                or t[a].time < my.block_start and t[a].time > my.time
            end)
        sortData()
        my.block_start = nil
    end
end

function visualBlock()
    if my.block_start then my.block_start = nil
    else my.block_start = my.time
    end
end

function love.update(dt)
    -- poll inputs
    local input = {}
    while pollInputs(input) do  
        if string.sub(input.code,1,4) == 'note' then registerNote(input.code)
        elseif input.code == 'escape' then love.event.quit()
        elseif input.code == 'play-pause' then toggleRecording()
        elseif input.code == 'start' then resumeRecording()
        elseif input.code == 'stop' then pauseRecording()
        elseif input.code == 'scale up' then my.scale = math.min(my.scale * 2, 960)
        elseif input.code == 'scale down' then my.scale = math.max(my.scale * 0.5, 15)
        elseif input.code == 'save' then saveData()
        elseif input.code == 'mode' then cycleMode()
        elseif input.code == 'toggle block' then visualBlock()
        elseif input.code == 'erase' then eraseBlock()
        elseif input.code == 'change lang' then text = text.lang == 'en' and lang_es or lang_en
        end
    end

    if my.start then
        -- if playing advance time
        my.time = my.time + dt
    else
        -- if not playing use up and down to navigate
        local step = lk.isDown('lshift') and 3 or 10
        if lk.isDown('down') then my.time = my.time + step / my.scale end
        if lk.isDown('up') then my.time = math.max(my.time - step / my.scale, 0) end
    end

    -- calculate offset for ui map elements
    my.offset = my.time * my.scale
end

function registerNote(code)
    if my.mode == 'Erase' then eraseNote(code)
    elseif my.mode == 'Write' or my.start then
        local noteData = {}
        noteData.time = my.time
        noteData.note = code
        print(my.time, code)
        table.insert(my.song_data, noteData)
    end
end

function drawBackground()
    -- draw channel board
    lg.setColor(0.1, 0.1, 0.1, 1)
    lg.rectangle('fill', 58, 0, 56, 800)
    lg.rectangle('fill', 118, 0, 56, 800)
    lg.rectangle('fill', 178, 0, 56, 800)
    lg.rectangle('fill', 238, 0, 56, 800)
    lg.rectangle('fill', 298, 0, 56, 800)

    -- draw visual block
    if my.block_start then
        lg.setColor(1,1,1,0.5)
        lg.rectangle('fill', 58, my.block_start * my.scale + 500 - my.offset, 298, (my.time - my.block_start) * my.scale)
    end

    -- draw write line
    lg.setColor(1,1,1,1)
    lg.rectangle('fill', 0, 500, 440, 2)
    lg.setColor(0, 1, 0, 1)
end

function buildMap()
    local channel
    for _,value in ipairs(my.song_data) do
        if value.time * my.scale + 500 - my.offset > -20 
            and value.time * my.scale + 500 - my.offset < 800 then
            channel = getChannelFromNote(value.note)
            lg.rectangle('fill', channel * 60 , value.time * my.scale + 500 - my.offset, 50, 10)
        end
    end
end    

function getChannelFromNote(code)
    char = string.sub(code, 6)
    if char == 'a' then return 1 end
    if char == 'b' then return 2 end
    if char == 'c' then return 3 end
    if char == 'd' then return 4 end
    if char == 'e' then return 5 end
    print(text.note_parse_fail..': '..code)
    return 0
end

function drawFront()
    buildMap()
end

function drawText()


    -- Print() messages
    lg.setColor(0.7,1,0.7,1)
    lg.printf(my.log[#my.log], 400, 450, 400)
    lg.setColor(1,1,1,1)
    lg.print(text.time..': '..my.time, 400, 486)
    lg.print(text.zoom..' x'..my.scale/15, 400, 500)

    -- Instructions
    lg.printf(text.instructions, 400, 200, 380)

    -- Print timecode
    local timecodeY = -my.time * my.scale + 500 - 6
    local timecode = 0
    local step = 1
    if my.scale / 60 < 0.5 then step = 2 end
    if my.scale / 60 > 2 then step = 0.5 end

    while timecodeY < 700 do
        if timecodeY > 0 then
            lg.printf(timecode, 0, math.floor(timecodeY), 50, 'right') 
        end
        timecodeY = timecodeY + my.scale * step
        timecode = timecode + step
    end
    -- Channels labels
    lg.setColor(1,1,1,0.5)
    lg.printf('a/h', 58, 540, 56, 'center')
    lg.printf('s/j', 118, 540, 56, 'center')
    lg.printf('d/k', 178, 540, 56, 'center')
    lg.printf('f/l', 238, 540, 56, 'center')
    lg.printf('g/;/ñ', 298, 540, 56, 'center')
    lg.setColor(1,1,1,1)

    -- Mode
    lg.printf(my.mode..' mode', 400, 100, 200, 'left', 0, 2)

    -- Song Name
    local songName = my.song_filename and text.song..': '..my.song_filename or text.no_song_sel
    lg.printf(songName, 400, 130, 200, 'left', 0, 2)

end

function love.draw()
    lg.clear()
    drawBackground()
    drawFront()
    drawText()
end

-- if my.overwrite then
--     my.overwrite_stack = my.overwrite_stack or 0
--     for i,v in ipairs(my.song_data) do
--         if v.time < my.time and v.time > my.time - 0.1 then
--             v.time = 1000
--             my.overwrite_stack = my.overwrite_stack + 1
--         elseif v.time > my.time and v.time < 1000 then 
--             break 
--         end
--     end
-- end

-- if my.overwrite then
--     print(my.overwrite_stack)
--     for i = 0, my.overwrite_stack do
--         my.song_data[#my.song_data - i] = nil
--         print("borrado my.song_data["..#my.song_data - i..']')
--     end
--     my.overwrite_stack = 0
-- end

-- local channel_data = {}
-- for _,v in ipairs(my.song_data) do
--     if v.note == note then
--         table.insert(channel_data, v)
--     end
-- end
-- local index = binSearch:Search(channel_data, my.time, function(a,b) 
    --     else return 0
    --     end
    -- end)
    -- if index then 
    --     channel_data[index].time = 1000
    --     sortData()
    --     my.song_data[#my.song_data] = nil
    -- end

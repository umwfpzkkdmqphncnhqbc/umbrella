local unloaded = false
local screensize = getscreendimensions()
local last_state = false

local library = {
    unload = function(self)
        unloaded = true

        for _, entry in self.drawings do
            entry.object:Remove()
        end

        table.clear(self.drawings)
        table.clear(self)
    end,

    theme = {
        text = {255, 255, 255},
        accent = {128, 142, 166},
        accent2 = {76, 86, 100},
        inline = {35, 35, 35},
        outline = {0, 0, 0},
        contrast = {25, 25, 25}
    },

    flags = {},
    drawings = {},

    font = 5,
    fontsize = 12
}

local theme = library.theme
local create = function(class, props)
    local parent = props.Parent
    local created = Drawing.new(class)

    local size_udim2, position_udim2
    local zindex = #library.drawings + 1

    local update_size = function()
        if size_udim2 then
            local s_scale = {x = size_udim2[1], y = size_udim2[3]}
            local s_offset = {x = size_udim2[2], y = size_udim2[4]}

            local s_scaled = {x = parent.AbsoluteSize.x * s_scale.x + s_offset.x, y = parent.AbsoluteSize.y * s_scale.y + s_offset.y}
            created.Size = {s_scaled.x, s_scaled.y}
        end
    end

    local update_position = function()
        if position_udim2 then
            local p_scale = {x = position_udim2[1], y = position_udim2[3]}
            local p_offset = {x = position_udim2[2], y = position_udim2[4]}

            local p_scaled = {x = parent.AbsoluteSize.x * p_scale.x + p_offset.x, y = parent.AbsoluteSize.y * p_scale.y + p_offset.y}
            created.Position = {parent.AbsolutePosition.x + p_scaled.x, parent.AbsolutePosition.y + p_scaled.y}
        end
    end

    for key, value in props do
        if key == 'Size' and parent then
            if class == 'Text' then
                created.Size = value
            else
                size_udim2 = {value[1], value[2], value[3], value[4]}
                update_size()
            end
        elseif key == 'Position' and parent then
            position_udim2 = {value[1], value[2], value[3], value[4]}
            update_position()
        elseif key ~= 'Parent' then
            created[key] = value
        end
    end

    local began_callbacks = {}
    local ended_callbacks = {}

    local mt = setmetatable({}, {
        __index = function(self, key)
            if key == 'AbsoluteSize' then
                return created.Size
            elseif key == 'AbsolutePosition' then
                return created.Position
            elseif key == 'Size' then
                return size_udim2 or created.Size
            elseif key == 'Position' then
                return position_udim2 or created.Position
            elseif key == 'ClickBegan' then
                return {
                    Connect = function(_, callback)
                        began_callbacks[#began_callbacks + 1] = callback
                    end
                }
            elseif key == 'ClickEnded' then
                return {
                    Connect = function(_, callback)
                        ended_callbacks[#ended_callbacks + 1] = callback
                    end
                }
            elseif key == 'Object' then
                return created
            elseif key == 'ZIndex' then
                return zindex
            elseif key == 'CallClickBegan' then
                return function()
                    for _, callback in began_callbacks do
                        callback()
                    end
                end
            elseif key == 'CallClickEnded' then
                return function()
                    for _, callback in ended_callbacks do
                        callback()
                    end
                end
            elseif key == 'Parent' then
                return parent
            else
                return created[key]
            end
        end,

        __newindex = function(self, key, value)
            if key == 'Size' and parent then
                if class == 'Text' then
                    created.Size = value
                else
                    size_udim2 = {value[1], value[2], value[3], value[4]}
                    update_size()
                end
            elseif key == 'Position' and parent then
                position_udim2 = {value[1], value[2], value[3], value[4]}
                update_position()
            elseif key ~= 'Parent' then
                created[key] = value
            end
        end
    })

    library.drawings[#library.drawings + 1] = {
        meta = mt,
        class = class,
        object = created,
        pressed = false,
        update = function()
            update_size()
            update_position()
        end
    }

    return mt
end

local handler = function()
    while true do
        if unloaded then
            return 
        end

        local mousepos = getmouseposition()
        local leftpressed = isleftpressed()

        for _, tbl in library.drawings do
            local meta = tbl.meta
            local class = tbl.class

            if class == 'Square' and meta.Visible and meta.ZIndex then
                local size = meta.AbsoluteSize
                local position = meta.AbsolutePosition

                if size and position then
                    local inside = mousepos.x >= position.x and mousepos.x <= position.x + size.x and mousepos.y >= position.y and mousepos.y <= position.y + size.y

                    if inside and leftpressed and not last_state and not tbl.pressed then
                        tbl.pressed = true
                        meta:CallClickBegan()
                    end
                end

                if not leftpressed and tbl.pressed then
                    tbl.pressed = false
                    meta:CallClickEnded()
                end
            end
        end

        last_state = leftpressed
        wait(1 / 30)
    end
end

local gradient = function(start_color, end_color, numpoints)
    local grad = {}

    for i = 1, numpoints do
        local ratio = numpoints > 1 and (i - 1) / (numpoints - 1) or 0
        grad[i] = {
            start_color[1] * (1 - ratio) + end_color[1] * ratio,
            start_color[2] * (1 - ratio) + end_color[2] * ratio,
            start_color[3] * (1 - ratio) + end_color[3] * ratio
        }
    end

    return grad
end

library.window = function(self, cfg)
    local config = {
        name = cfg.name or 'Window',
        size = cfg.size or {350, 360},
        position = cfg.position or nil
    }

    if not config.position then
        config.position = {(screensize.x / 2) - (config.size[1] / 2), (screensize.y / 2) - (config.size[2] / 2)}
    end

    local window = {
        size = config.size,
        pages = {},
        drawings = {},
        elements = {}
    }

    local outline1 = create('Square', {
        Color = theme.outline,
        Size = config.size,
        Position = config.position,
        Thickness = 1,
        Transparency = 1,
        Visible = true,
        Filled = true
    })

    local inline1 = create('Square', {
        Color = theme.inline,
        Size = {1, -2, 1, -2},
        Position = {0, 1, 0, 1},
        Thickness = 1,
        Transparency = 1,
        Visible = true,
        Filled = true,
        Parent = outline1
    })

    local outline2 = create('Square', {
        Color = theme.outline,
        Size = {1, -2, 1, -2},
        Position = {0, 1, 0, 1},
        Thickness = 1,
        Transparency = 1,
        Visible = true,
        Filled = true,
        Parent = inline1
    })
    window.drawings.outline2 = outline2

    local accent1 = create('Square', {
        Color = theme.accent,
        Size = {1, -2, 0, 20},
        Position = {0, 1, 0, 1},
        Thickness = 1,
        Transparency = 1,
        Visible = true,
        Filled = true,
        Parent = outline2
    })

    local gradient1 = gradient(theme.accent, theme.accent2, 18)
    for i = 1, #gradient1 do
        create('Square', {
            Color = gradient1[i],
            Size = {1, -2, 0, 1},
            Position = {0, 1, 0, i},
            Thickness = 1,
            Transparency = 1,
            Visible = true,
            Filled = true,
            Parent = accent1
        })
    end

    local click = create('Square', {
        Size = {1, 0, 1, 0},
        Position = {0, 0, 0, 0},
        Thickness = 1,
        Transparency = 0,
        Visible = true,
        Filled = true,
        Parent = accent1
    })

    local dragging = false
    local dragpos = nil

    click.ClickBegan:Connect(function()
        dragging = true
        dragpos = getmouseposition()
    end)

    click.ClickEnded:Connect(function()
        dragging = false
    end)

    spawn(function()
        while true do
            if unloaded then
                break
            end

            if dragging then
                local mousepos = getmouseposition()
                local diff = {x = mousepos.x - dragpos.x, y = mousepos.y - dragpos.y}
                dragpos = mousepos

                outline1.Position = {outline1.Position.x + diff.x, outline1.Position.y + diff.y}

                for _, tbl in library.drawings do
                    tbl.update()  
                end
            end

            wait(1 / 144)
        end
    end)

    local label1 = create('Text', {
        Color = theme.text,
        Text = config.name,
        Size = library.fontsize,
        Font = library.font,
        Position = {0, 5, 0, 4},
        Outline = true,
        Visible = true,
        Transparency = 1,
        Parent = accent1
    })

    local inline2 = create('Square', {
        Color = theme.inline,
        Size = {1, -2, 1, -23},
        Position = {0, 1, 0, 22},
        Thickness = 1,
        Transparency = 1,
        Visible = true,
        Filled = true,
        Parent = outline2
    })

    local contrast1 = create('Square', {
        Color = theme.contrast,
        Size = {1, -2, 1, -2},
        Position = {0, 1, 0, 1},
        Thickness = 1,
        Transparency = 1,
        Visible = true,
        Filled = true,
        Parent = inline2
    })
    window.drawings.contrast1 = contrast1

    return setmetatable(window, {__index = library})
end

library.toggle = function(self, cfg)
    local config = {
        name = cfg.name or 'Toggle',
        flag = cfg.flag or math.random(1, 100000),
        side = cfg.side or 'left',
        state = cfg.state or false,
        xoffset = cfg.xoffset or 0,
        callback = cfg.callback or nil
    }

    local toggle = {
        side = config.side,
        size = 10,
        state = false
    }

    local left_offset = 0
    local elements = self.elements
    for _, element in elements do
        if element.side == 'left' then
            local size = element.size
            left_offset = left_offset + size + 5
        end
    end

    local right_offset = 0
    local elements = self.elements
    for _, element in elements do
        if element.side == 'right' then
            local size = element.size
            right_offset = right_offset + size + 5
        end
    end

    elements[#elements+1] = toggle

    local outline1 = create('Square', {
        Color = theme.outline,
        Size = {0, 10, 0, 10},
        Position = config.side == 'left' and {0, 5 + config.xoffset, 0, 5 + left_offset} or {0.5, 5 + config.xoffset, 0, 5 + right_offset},
        Thickness = 1,
        Transparency = 1,
        Visible = true,
        Filled = true,
        Parent = self.drawings.contrast1
    })

    local contrast1 = create('Square', {
        Color = theme.contrast,
        Size = {1, -2, 1, -2},
        Position = {0, 1, 0, 1},
        Thickness = 1,
        Transparency = 1,
        Visible = true,
        Filled = true,
        Parent = outline1
    })

    local outline2 = create('Square', {
        Color = theme.outline,
        Size = {1, -2, 1, -2},
        Position = {0, 1, 0, 1},
        Thickness = 1,
        Transparency = 1,
        Visible = true,
        Filled = true,
        Parent = contrast1
    })

    local accent2 = create('Square', {
        Color = theme.accent2,
        Size = {1, -2, 1, -2},
        Position = {0, 1, 0, 1},
        Thickness = 1,
        Transparency = 1,
        Visible = false,
        Filled = true,
        Parent = outline1
    })

    local accent1 = create('Square', {
        Color = theme.accent,
        Size = {1, -2, 1, -2},
        Position = {0, 1, 0, 1},
        Thickness = 1,
        Transparency = 1,
        Visible = false,
        Filled = true,
        Parent = accent2
    })

    local label1 = create('Text', {
        Color = theme.text,
        Text = config.name,
        Size = library.fontsize,
        Font = library.font,
        Position = {0, 13, 0, -1},
        Outline = true,
        Visible = true,
        Transparency = 1,
        Parent = outline1
    })

    local click = create('Square', {
        Size = config.side == 'left' and {0, 166 - config.xoffset, 1, 0} or {0, 161 - config.xoffset, 1, 0},
        Position = {0, 0, 0, 0},
        Visible = true,
        Filled = true,
        Transparency = 0,
        Parent = outline1
    })

    function toggle.set(boolean)
        accent1.Visible = boolean
        accent2.Visible = boolean

        toggle.state = boolean

        library.flags[config.flag] = boolean
        if config.callback then
            config.callback(boolean)
        end
    end

    click.ClickBegan:Connect(function()
        toggle.set(not toggle.state)
    end)

    toggle.set(config.state)
    return setmetatable(toggle, {__index = library})
end

library.slider = function(self, cfg)
    local config = {
        min = cfg.min or -5,
        max = cfg.max or 5,
        float = cfg.float or 0.1,
        value = cfg.value or 1,
        name = cfg.name or 'Slider',
        flag = cfg.flag or math.random(1, 100000),
        side = cfg.side or 'left',
        xoffset = cfg.xoffset or 0,
        callback = cfg.callback or nil
    }

    local slider = {
        side = config.side,
        size = 10,
        value = 0
    }

    local left_offset = 0
    local elements = self.elements
    for _, element in elements do
        if element.side == 'left' then
            local size = element.size
            left_offset = left_offset + size + 5
        end
    end

    local right_offset = 0
    local elements = self.elements
    for _, element in elements do
        if element.side == 'right' then
            local size = element.size
            right_offset = right_offset + size + 5
        end
    end

    elements[#elements+1] = slider

    local outline1 = create('Square', {
        Color = theme.outline,
        Size = config.side == 'left' and {0, 166 - config.xoffset, 0, 10} or {0, 161 - config.xoffset, 0, 10},
        Position = config.side == 'left' and {0, 5 + config.xoffset, 0, 5 + left_offset} or {0.5, 5 + config.xoffset, 0, 5 + right_offset},
        Thickness = 1,
        Transparency = 1,
        Visible = true,
        Filled = true,
        Parent = self.drawings.contrast1
    })

    local bounds = create('Square', {
        Size = {1, -2, 1, -2},
        Position = {0, 1, 0, 1},
        Visible = true,
        Filled = true,
        Transparency = 0,
        Parent = outline1
    })

    local frame = create('Square', {
        Color = theme.accent,
        Size = {1, 0, 1, 0},
        Position = {0, 0, 0, 0},
        Thickness = 1,
        Transparency = 1,
        Visible = true,
        Filled = true,
        Parent = bounds
    })

    local label1 = create('Text', {
        Color = theme.text,
        Text = config.name .. ': ' .. 1000 .. '/' .. 5000,
        Size = library.fontsize,
        Font = library.font,
        Position = {0.5, 0, 0, -1},
        Outline = true,
        Visible = true,
        Center = true,
        Transparency = 1,
        Parent = outline1
    })

    local click = create('Square', {
        Size = {1, 0, 1, 0},
        Position = {0, 0, 0, 0},
        Visible = true,
        Filled = true,
        Transparency = 0,
        Parent = outline1
    })

    function slider.set(number)
        local rounded = math.floor(number * (1 / config.float) + 0.5) / (1 / config.float)
		local clamped = math.clamp(rounded, config.min, config.max)

        local scale = (clamped - config.min) / (config.max - config.min)
        frame.Size = {scale, 0, 1, 0}

        label1.Text = config.name .. ': ' .. clamped .. '/' .. config.max

        slider.value = clamped
        library.flags[config.flag] = clamped
        if config.callback then
            config.callback(clamped)
        end
    end

    local dragging = false
	click.ClickBegan:Connect(function()
		dragging = true
		local size = (getmouseposition().x - click.AbsolutePosition.x) / click.AbsoluteSize.x
		slider.set(config.min + (size * (config.max - config.min)))
	end)

	click.ClickEnded:Connect(function()
        dragging = false
	end)

    spawn(function()
        while true do
            if unloaded then
                break
            end

            if dragging then
                local size = (getmouseposition().x - click.AbsolutePosition.x) / click.AbsoluteSize.x
                slider.set(config.min + (size * (config.max - config.min)))
            end
            
            wait(1 / 144)
        end
    end)

    slider.set(config.value)
    return setmetatable(slider, {__index = library})
end

spawn(handler)
return library

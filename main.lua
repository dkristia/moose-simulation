local hirvet = {}
-- Baari (paikka missä hirvi syö/juo) on sijainti x, y
local baarit = {}

local args = { ... }
-- args[1] has filename
local alue = tonumber(args[2] or 40000)      -- ha
local hirviTiheys = tonumber(args[3] or 3.1) -- hirvi/1000ha
local baariTiheys = tonumber(args[4] or 12)  -- baari/1000ha
local vasaTiheys = tonumber(args[5] or 0.05) -- vasa/hirvi
local time = tonumber(args[6] or 0)          -- tunti, mod 24 == 0 on keskiyö

local states = { eating = 1, sleeping = 2, resting = 3, wandering = 4, searching = 5 }

local width = math.floor(math.sqrt(alue or 0) + .5)

function love.load()
    do -- Generate baarit
        local baariLkm = alue / 1000 * baariTiheys
        for i = 1, baariLkm do
            local x, y = math.random(0, width), math.random(0, width)
            baarit[i] = { x = x, y = y }
        end
    end
    do -- Generate hirvet
        local i = 1
        local hirviLkm = alue / 1000 * hirviTiheys
        local baariLkm = #baarit
        local hirviPerVasa = math.floor(1 / vasaTiheys + .5)
        while i <= hirviLkm do
            local vasaAmount = ((math.random(0, hirviPerVasa) == 0) and 1 or 0) +
                ((math.random(0, hirviPerVasa) == 0) and 1 or 0)
            local baari = baarit[math.random(1, baariLkm)]
            table.insert(hirvet,
                {
                    x = (baari.x + math.random(-100, 100) / 10) % width,
                    y = (baari.y + math.random(-100, 100) / 10) % width,
                    speed1 = math.random(200, 400), -- search hm/h
                    speed2 = math.random(100, 200), -- wandering hm/h
                    direction = false,
                    sleep = 0,                      -- minuutteina
                    state = states.wandering,
                    amount = (1 + vasaAmount),
                    hunger = math.random(0, 300),
                    nearest = Nearest,         -- metodi
                    randdir = RandomDirection, --metodi
                    last = nil,
                })

            i = i + 1 + vasaAmount
        end
    end
    love.window.setMode(width * 6, width * 5, { resizable = true, vsync = false })
end

function love.update(_dt)
    local dt = 1 / 60
    local sleeptime = 0
    if time <= 24 then
        dt = 1 / 5
        sleeptime = 0
    else
        dt = 1 / 60
        sleeptime = 0.01
    end
    time = time + dt / 60
    for i, hirvi in ipairs(hirvet) do
        -- Update hirvi movement
        local nearestBar, secondNearestBar = hirvi:nearest(baarit)
        local bar
        if nearestBar == hirvi.last then bar = secondNearestBar else bar = nearestBar end
        -- Decrease/increase hunger
        if hirvi.state == states.eating then
            hirvi.hunger = math.max(hirvi.hunger - 10 * dt, 0)
            if hirvi.hunger == 0 then
                hirvi.state = states.wandering
                hirvi.direction = hirvi:randdir()
            end
        else
            hirvi.hunger = hirvi.hunger + 1 * dt
        end

        if hirvi.state ~= states.sleeping and hirvi.state ~= states.resting then
            if nearestBar.distance < 1 then
                if hirvi.hunger >= 100 then
                    hirvi.state = states.eating
                    hirvi.direction = false
                else
                    hirvi.state = states.wandering
                    hirvi.direction = hirvi:randdir()
                end
                hirvi.last = nearestBar
            else
                if hirvi.hunger >= 200 and hirvi.state ~= states.searching then
                    hirvi.state = states.searching
                    hirvi.direction = math.atan2(bar.bar.x - hirvi.x, bar.bar.y - hirvi.y)
                end
            end
        end

        local speed
        if hirvi.state == states.wandering then
            hirvi.direction = hirvi:randdir()
            speed = hirvi.speed2
            if math.random(10) == 1 then
                hirvi.direction = false
                hirvi.state = states.resting
            end
        else
            speed = hirvi.speed1
        end
        if hirvi.direction and hirvi.state >= 4 then
            local dx, dy = math.sin(hirvi.direction) * speed * dt / 60, math.cos(hirvi.direction) * speed * dt / 60
            if hirvi.x + dx >= width or hirvi.x + dx < 0 or hirvi.y + dy >= width or hirvi.y + dy < 0 then
                hirvi.direction = false
                hirvi.direction = hirvi:randdir()
            else
                hirvi.x = hirvi.x + dx
                hirvi.y = hirvi.y + dy
            end
        elseif hirvi.state == 5 and hirvi.hunger >= bar.r / speed then
            hirvi.x = bar.x
            hirvi.y = bar.y
        end
        if hirvi.state == states.sleeping then
            hirvi.sleep = math.max(0, hirvi.sleep - dt)
            if hirvi.sleep == 0 then
                hirvi.state = states.resting
            end
        end
        if hirvi.state == states.resting then
            if math.random(20) == 1 then
                hirvi.direction = hirvi:randdir()
                hirvi.state = states.wandering
            end
        end
    end
    love.timer.sleep(sleeptime)
end

function RandomDirection(hirvi)
    local direction = hirvi.direction
    if not hirvi.direction then
        direction = math.rad(math.random(1, 720) / 2)
    end
    return direction
end

function Nearest(self, data)
    local x, y = self.x, self.y
    local mr, q, w = false, nil, nil
    for i, v in ipairs(data) do
        local x1, y1 = v.x, v.y
        local r = (x1 - x) ^ 2 + (y1 - y) ^ 2
        if not mr or r < mr then
            mr = r
            w = q
            q = { bar = v, distance = r }
        end
    end
    return q, w
end

local colors = { { 0, 0, 1 }, { 1, 0, 1 }, { 0.5, 0, 1 }, { 1, 0, 0 }, { 1, 1, 0 } }
function love.draw()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local w2, h2 = w / 2, h / 2
    love.graphics.setColor(0.6, 0.7, 0.4)
    love.graphics.rectangle("fill", w2 - h2, 0, h, h)
    love.graphics.setColor(0.2, 0.1, 1, 0.2)
    local unit = math.max(1, h / width)
    for i, v in ipairs(baarit) do
        local x, y = w2 - h2 + v.x / width * h, h - v.y / width * h
        love.graphics.rectangle("fill", x - unit, y - unit, unit * 0.5, unit * 0.5)
    end
    for i, v in ipairs(hirvet) do
        local x, y = w2 - h2 + v.x / width * h, h - v.y / width * h
        love.graphics.setColor(0.8, 0.1, 0)
        if v.amount == 2 then
            love.graphics.setColor(0.8, 0.5, 0)
        elseif v.amount == 3 then
            love.graphics.setColor(0.8, 0.1, 0.5)
        end
        love.graphics.circle("fill", x, y, math.max(1, 0.3 * unit))
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(time / 24, 0, 0)
end

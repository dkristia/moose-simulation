local hirvet = {}
-- Baari (paikka missä hirvi syö/juo) on sijainti x, y
local baarit = {}

local alue = 80000          -- ha
local hirviTiheys = math.pi -- hirvi/1000ha
local baariTiheys = 12      -- baari/1000ha
local vasaTiheys = 0.05     -- vasa/hirvi
local sleepReq = 8          -- tuntia
local startTime = 12        -- tunti, mod 24 == 0 on keskiyö
local droneSpeed = 300      -- hm/h


local states = { eating = 1, sleeping = 2, resting = 3, wandering = 4, searching = 5 }

local width = math.floor(math.sqrt(alue or 0) + .5)

-- Drone, x, y, path (table)
local drone = {
    x = width / 2,
    y = width / 2,
    ws = false,
    wl = false,
    w = 3, -- dronen näkökentän ulottuvuudet (hm)
    h = 3,
    path = {},
    waypoint = 1,
    count = 0,     -- nähdyt hirvet
    area = 0,      -- alue tarkastettu (ha)
}
drone.ws = drone.w -- ei tarvii säätää
drone.area = drone.w * drone.h

-- Magic numbers
local minWSpeed, maxWSpeed = 50, 150  -- wandering speed, hm/h
local minSSpeed, maxSSpeed = 200, 400 -- search speed, hm/h
local eatingSpeed = 10                -- minutes/minutes (minutes of food (energy) per minute of eating)
local eatThreshold = 100              -- hunger level when moose starts eating
local searchThreshold = 200           -- hunger level when moose starts searching for food
local restChance = 0.1                -- chance to start resting while wandering (per minute)
local wanderChance = 0.05             -- chance to start wandering while resting (per minute)
local sleepChance = 0.05              -- chance to start sleeping after eating (per times done eating)


function love.load()
    print("Started program")
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
                    speed1 = math.random(minSSpeed, maxSSpeed), -- search hm/h
                    speed2 = math.random(minWSpeed, maxWSpeed), -- wandering hm/h
                    direction = false,
                    sleep = 0,                                  -- minuutteina
                    state = states.wandering,
                    amount = (1 + vasaAmount),
                    hunger = math.random(0, 300),
                    nearest = Nearest,         -- metodi
                    randdir = RandomDirection, --metodi
                    last = nil,
                    detected = false,
                })

            i = i + 1 + vasaAmount
        end
    end
    do
        -- make waypoint mission
        local x, y = width / 2, width / 2
        local dir, r, i = 0, 1, 1
        while x > drone.w * 2 and x < width - drone.w * 2 and y > drone.h * 2 and y < width - drone.h * 2 do
            -- do a spiral sweep
            if not drone.wl then
                x, y = x + i * r * drone.ws / 2 * math.sin(dir), y + i * r * drone.h / 2 * math.cos(dir)
            else
                x, y = x + drone.wl * 2 * math.sin(dir), y + i * r * drone.h / 2 * math.cos(dir)
                x = math.min(math.max(x, -drone.wl), drone.wl)
            end
            dir = dir + math.pi / 2
            drone.path[i] = { x, y }
            i = i + 1
        end
    end

    love.window.setMode(width * 6, width * 5, { resizable = true, vsync = false })
end

local tick = 0
local dt = 1 / 5
local sleeptime = 1 / 60
local sun = 0

local time = startTime - 2

function love.update(_dt)
    for runs = 1, 1 do
        local isFirstDay = time - startTime < 0
        tick = tick + 1
        --[[if time <= 24 then
            dt = 1 / 5
            sleeptime = false
        else
            dt = 1 / 60
            sleeptime = 0.01
        end
        ]]
        time = time + dt / 60
        sun = ((1 + math.cos(math.rad(time * 15))) / 2) ^ 1
        local eep = 1 - sun
        local droneCorners = {
            { drone.x - drone.w / 2, drone.y + drone.h / 2 },
            { drone.x + drone.w / 2, drone.y + drone.h / 2 },
            { drone.x + drone.w / 2, drone.y - drone.h / 2 },
            { drone.x - drone.w / 2, drone.y - drone.h / 2 }
        }
        for _, hirvi in ipairs(hirvet) do
            -- Check if hirvi is in drone's view using droneCorner
            local detected = false
            if not isFirstDay then
                detected =
                    hirvi.x >= droneCorners[1][1]
                    and hirvi.x <= droneCorners[2][1]
                    and hirvi.y <= droneCorners[1][2]
                    and hirvi.y >= droneCorners[4][2]

                if detected and not hirvi.detected then drone.count = drone.count + hirvi.amount end
            end
            hirvi.detected = detected

            -- Decrease/increase hunger
            if hirvi.state == states.eating then
                hirvi.hunger = hirvi.hunger - eatingSpeed * dt
                if hirvi.hunger <= 0 then
                    if math.random(1000) / 1000 <= sleepChance then
                        hirvi.state = states.sleeping
                        hirvi.sleep = sleepReq * 60 * eep
                    else
                        hirvi.state = states.wandering
                        hirvi.direction = hirvi:randdir()
                    end
                end
            else
                hirvi.hunger = hirvi.hunger + 1 * dt
            end

            if hirvi.state == states.sleeping then
                hirvi.sleep = hirvi.sleep - dt
                if hirvi.sleep <= 0 then
                    hirvi.state = states.resting
                end
                goto continue
            end

            local nearestBar, secondNearestBar = hirvi:nearest(baarit)
            local bar
            if nearestBar == hirvi.last then bar = secondNearestBar else bar = nearestBar end

            if hirvi.state ~= states.resting then
                if nearestBar.distance < 1 then
                    if hirvi.hunger >= eatThreshold then
                        hirvi.state = states.eating
                        hirvi.direction = false
                    end
                    hirvi.last = nearestBar
                else
                    if hirvi.hunger >= searchThreshold and hirvi.state ~= states.searching then
                        hirvi.state = states.searching
                        hirvi.direction = math.atan2(bar.bar.x - hirvi.x, bar.bar.y - hirvi.y)
                    end
                end
            end

            local speed
            if hirvi.state == states.wandering then
                hirvi.direction = hirvi:randdir()
                speed = hirvi.speed2
                if tick % (1 / dt) == 0 then
                    if math.random(1000) / 1000 <= restChance then
                        hirvi.direction = false
                        hirvi.state = states.resting
                    end
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
            if hirvi.state == states.resting then
                if tick % (1 / dt) == 0 then
                    if math.random(1000) / 1000 <= wanderChance then
                        hirvi.direction = hirvi:randdir()
                        hirvi.state = states.wandering
                        if math.random(1000) / 1000 <= sleepChance then
                            hirvi.state = states.sleeping
                            hirvi.sleep = sleepReq * 60 / 3 * eep
                        end
                    end
                end
            end
            ::continue::
        end
        if not isFirstDay then
            do
                -- move drone to next waypoint
                ::sus::
                local x, y = drone.x, drone.y
                local wx, wy = drone.path[drone.waypoint][1], drone.path[drone.waypoint][2]
                local dx, dy = wx - x, wy - y
                local dist = math.sqrt(dx ^ 2 + dy ^ 2)
                if dist < 2 then
                    drone.waypoint = drone.waypoint % #drone.path + 1
                    goto sus
                end
                local speed = droneSpeed
                local d = math.min(speed * dt / 60, dist)
                local gox, goy = dx / dist * d, dy / dist * d
                drone.x = x + gox
                drone.y = y + goy

                drone.area = drone.area + math.abs(gox) * drone.h + math.abs(goy) * drone.w
            end
        end
        if sleeptime then
            love.timer.sleep(sleeptime)
        end
    end
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

local colors = { { 0, 0, 1 }, { 1, 1, 1 }, { 0.5, 0, 1 }, { 1, 0, 0 }, { 1, 1, 0 } }
function love.draw()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local w2, h2 = w / 2, h / 2
    love.graphics.setColor(0.6 - 0.2 * sun, 0.6 - 0.2 * sun, 0.5)
    love.graphics.rectangle("fill", w2 - h2, 0, h, h)
    love.graphics.setColor(0.2, 0.1, 1, 0.2)
    local unit = math.max(1, h / width)
    for i, v in ipairs(baarit) do
        local x, y = w2 - h2 + v.x / width * h, h - v.y / width * h
        love.graphics.rectangle("fill", x - unit, y - unit, unit * 2, unit * 2)
    end
    for i, v in ipairs(hirvet) do
        local x, y = w2 - h2 + v.x / width * h, h - v.y / width * h
        love.graphics.setColor(unpack(colors[v.state]))
        love.graphics.circle("fill", x, y, math.max(1, 0.6 * unit))
    end
    love.graphics.setColor(1, 1, 0, 0.5)
    love.graphics.rectangle("fill", w2 - h2 + drone.x / width * h - unit / 2 * drone.w,
        h - drone.y / width * h - unit / 2 * drone.h, unit * drone.w,
        unit * drone.h)
    for i, v in ipairs(drone.path) do
        local x, y = w2 - h2 + v[1] / width * h, h - v[2] / width * h
        love.graphics.circle("fill", x, y, 1 * unit)
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(time, 0, 0)
    love.graphics.print(drone.count, 0, 10)
    love.graphics.print(drone.area, 0, 20)
    love.graphics.print(1000 * drone.count / drone.area, 0, 30)
end

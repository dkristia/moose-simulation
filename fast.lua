#!/usr/bin/env luajit
local hirvet = {}
-- Baari (paikka missä hirvi syö/juo) on sijainti x, y
local baarit = {}

local args = { ... }
-- args[1] has filename
local alue = tonumber(args[2] or 80000)          -- ha
local hirviTiheys = tonumber(args[3] or math.pi) -- hirvi/1000ha
local baariTiheys = tonumber(args[4] or 12)      -- baari/1000ha
local vasaTiheys = tonumber(args[5] or 0.05)     -- vasa/hirvi
local sleepReq = tonumber(args[6] or 8)          -- tuntia
local time = tonumber(args[7] or 0)              -- tunti, mod 24 == 0 on keskiyö


local states = { eating = 1, sleeping = 2, resting = 3, wandering = 4, searching = 5 }

local width = math.floor(math.sqrt(alue or 0) + .5)

-- Drone, x, y, path (table)
local drone = {
    x = width / 2,
    y = width / 2,
    ws = false,
    wl = false,
    w = tonumber(args[8] or 10), -- dronen näkökentän ulottuvuudet (hm)
    h = tonumber(args[9] or 10),
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

do
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
        local dir, r = 0, 1
        for i = 1, 20 do
            -- do a spiral sweep
            if not drone.wl then
                x, y = x + i * r * drone.ws / 2 * math.sin(dir), y + i * r * drone.h / 2 * math.cos(dir)
            else
                x, y = x + drone.wl * 2 * math.sin(dir), y + i * r * drone.h / 2 * math.cos(dir)
                x = math.min(math.max(x, -drone.wl), drone.wl)
            end
            dir = dir + math.pi / 2
            drone.path[i] = { x, y }
        end
    end
end

local tick = 0
local dt = 1 / 5
local sun = 0
local run = true
local runtime = 2 -- hours

while time <= runtime do
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
        local detected =
            hirvi.x >= droneCorners[1][1]
            and hirvi.x <= droneCorners[2][1]
            and hirvi.y <= droneCorners[1][2]
            and hirvi.y >= droneCorners[4][2]

        if detected and not hirvi.detected then drone.count = drone.count + hirvi.amount end
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
        local speed = 1200
        local d = math.min(speed * dt / 60, dist)
        local gox, goy = dx / dist * d, dy / dist * d
        drone.x = x + gox
        drone.y = y + goy

        drone.area = drone.area + math.abs(gox) * drone.h + math.abs(goy) * drone.w
    end
end

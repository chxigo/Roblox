local FLAG_NAMES = {
    --[[ #Example

    "Enabled",
    "Aimbot",
    "FOVCircle",
    "TeamCheck",
    "WallCheck",
    "Tracer",
    "Skeleton",
    "SnapLine",

    ]]
}

local IS_FLAG = {}
for _, name in ipairs(FLAG_NAMES) do
    IS_FLAG[name] = true
end

if type(_G.__YOUR_FLAGS) ~= "table" then
    _G.__YOUR_FLAGS = {}
end

for _, name in ipairs(FLAG_NAMES) do
    if _G.__YOUR_FLAGS[name] == nil then
        _G.__YOUR_FLAGS[name] = false
    end
end

local flags = _G.__YOUR_FLAGS

if type(_G.__YOUR_SETTINGS) ~= "table" then
    _G.__YOUR_SETTINGS = {}
end

local settings = _G.__YOUR_SETTINGS

local DEFAULT_SETTINGS = {
    --[[ #Exampel

    FOVRadius = 120,
    Smoothness = 5,
    AimPart = "Head",
    FOVColor = Color3.fromRGB(255, 255, 255),
    Skeleton = true
    Headdot = false
    
    ]]
}

for key, defaultValue in next, DEFAULT_SETTINGS do
    if settings[key] == nil then
        settings[key] = defaultValue
    end
end

local Config = setmetatable({}, {

    __newindex = function(self, key, value)
        if IS_FLAG[key] then
            flags[key] = value
        else
            settings[key] = value
        end
    end,

    __index = function(self, key)
        if IS_FLAG[key] then
            return flags[key]
        end
        return settings[key]
    end,
})

return Config

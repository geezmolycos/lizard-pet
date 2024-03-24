
local user_config = {}

local log = require "log"
local json = require "json"

user_config.config_file_name = "user_config.json"

user_config.config = {}

function user_config.get(key)
    return user_config.config[key]
end

function user_config.set(key, value)
    user_config.config[key] = value
end

function user_config.set_default(key, default_value)
    if user_config.config[key] == nil then
        user_config.config[key] = default_value
    end
end

function user_config.save_to_file()
    local encoded = json.encode(user_config.config)
    local success, message = love.filesystem.write(user_config.config_file_name, encoded)
    if not success then
        log.error("Failed to save user config: " .. message)
        return false
    end
    return true
end

function user_config.load_from_file()
    local content, errormsg = love.filesystem.read(user_config.config_file_name)
    if content == nil then
        log.error("Failed to load user config: " .. errormsg)
        return false
    else
        local success, result = pcall(json.decode, content)
        if success then
            user_config.config = result
            return true
        else
            log.error("json decode error: " .. result)
            return false
        end
    end
end


return user_config

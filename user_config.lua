
local user_config = {}

local json = require "json"

user_config.config_file_name = "user_config.json"

user_config.config = {}

function user_config.save_to_file()
    local encoded = json.encode(user_config.config)
    love.filesystem.write(user_config.config_file_name, encoded)
end

function user_config.load_from_file()
    if love.filesystem.getInfo(user_config.config_file_name) then
        local content, errormsg = love.filesystem.read(user_config.config_file_name)
    else
        
    end
end


return user_config

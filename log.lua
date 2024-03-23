local log = {}

local inspect = require "inspect"

log.level_to_name = {'fatal', 'error', 'warn', 'info', 'debug', 'trace'}
log.name_to_level = {fatal = 1, error = 2, warn = 3, info = 4, debug = 5, trace = 6}

log.console_colors = {
    "\027[35m",
    "\027[31m",
    "\027[33m",
    "\027[32m",
    "\027[36m",
    "\027[34m",
}

function log.write_console(line)
    print(line)
end

log.output_file_name = "log.txt"
function log.write_file(line)
    love.filesystem.append(log.output_file_name, line .. "\n")
end

function log.remove_file()
    love.filesystem.remove(log.output_file_name)
end

log.output_console_use_color = true
log.history = {}
log.render_line_amount = 5
function log.write_history(line)
    if #log.history == log.render_line_amount then
        table.remove(log.history, #log.history)
    end
    table.insert(log.history, 1, line)
end

log.output_to_console_level = 5
log.output_to_file_level = 4
log.output_to_history_level = 0

function log.log_text(depth, level, text)
    local time = os.date("%H:%M:%S")
    local lineinfo = ''
    if debug then
        local debug_line = debug.getinfo(depth+1, "Sl")
        lineinfo = debug_line.short_src .. ":" .. debug_line.currentline
    end
    local level_name = log.level_to_name[level]
    local prelude = string.format("%-6s%s", level_name, time)
    if log.output_to_console_level >= level then
        if log.output_console_use_color then
            log.write_console(string.format("%s[%s]\027[0m %s: %s", log.console_colors[level], prelude, lineinfo, text))
        else
            log.write_console(string.format("[%s] %s: %s", prelude, lineinfo, text))
        end
    end
    if log.output_to_file_level >= level then
        log.write_file(string.format("[%s] %s: %s", prelude, lineinfo, text))
    end
    if log.output_to_history_level >= level then
        log.write_history(string.format("[%s] %s: %s", prelude, lineinfo, text))
    end
end

function log.render()

end

function log.log(depth, level, ...)
    local rest = {...}
    if #rest == 0 then
        return
    end
    if #rest == 1 and type(rest[1]) == "string" then
        return log.log_text(depth, level, rest[1])
    end
    local s = ""
    for i = 1, #rest do
        if type(rest[i]) == "string" then
            s = s .. rest[i] .. '  '
        elseif type(rest[i]) == "number" or type(rest[i]) == "boolean" then
            s = s .. tostring(rest[i]) .. '  '
        else
            s = s .. inspect(rest[i]) .. '  '
        end
    end
    return log.log_text(depth, level, s)
end

function log.fatal(...) return log.log(1, 1, ...) end
function log.error(...) return log.log(1, 2, ...) end
function log.warn (...) return log.log(1, 3, ...) end
function log.info (...) return log.log(1, 4, ...) end
function log.debug(...) return log.log(1, 5, ...) end
function log.trace(...) return log.log(1, 6, ...) end

return log

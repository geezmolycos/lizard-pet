local log = require "log"

local status, ffi = pcall(require, "ffi")
if not status then
    log.warn("No FFI module available")
    love.window.showMessageBox( "Warning", "No FFI module available", "warning", false )
    return require "port.dummy"
end

log.info("FFI reported OS: ", ffi.os)
if ffi.os == "Windows" then
    return require "port.windows"
end

log.warn("OS is not Windows, not implemented")
love.window.showMessageBox( "Warning", "OS is not Windows, not implemented", "warning", false )

return require "port.dummy"

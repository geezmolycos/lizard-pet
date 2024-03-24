local status, ffi = pcall(require, "ffi")
if not status then
    print("No FFI module available")
    return require "port.dummy"
end

print("FFI reported OS: ", ffi.os)
if ffi.os == "Windows" then
    return require "port.windows"
end

print("OS is not Windows, not implemented")
love.window.showMessageBox( "Warning", "OS is not Windows, not implemented", "warning", false )

return require "port.dummy"

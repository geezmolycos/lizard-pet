
function love.conf(t)
    t.console = false
    if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
        t.console = false
    end
    if arg[2] == 'debug' or arg[2] == 'console' then
        t.console = true
    end
    t.window = nil
end

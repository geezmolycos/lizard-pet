local windows = {}

local ffi = require "ffi"

local log = require "log"

local comctl32 = ffi.load('comctl32.dll')
local dwmapi = ffi.load('dwmapi.dll')

ffi.cdef[[

typedef void *HWND;
typedef void *HMONITOR;
typedef void *HRGN;

typedef int BOOL;
typedef unsigned long COLORREF;
typedef unsigned char BYTE;
typedef unsigned long DWORD;
typedef unsigned int UINT;
typedef long LONG;
typedef short SHORT;

typedef intptr_t LONG_PTR;
typedef LONG_PTR LRESULT;
typedef uintptr_t UINT_PTR;
typedef uintptr_t ULONG_PTR;
typedef ULONG_PTR DWORD_PTR;
typedef UINT_PTR WPARAM;
typedef LONG_PTR LPARAM;
typedef LONG HRESULT;

typedef LRESULT (*SUBCLASSPROC)(
  HWND hWnd,
  UINT uMsg,
  WPARAM wParam,
  LPARAM lParam,
  UINT_PTR uIdSubclass,
  DWORD_PTR dwRefData
);

typedef struct tagWINDOWPOS {
  HWND hwnd;
  HWND hwndInsertAfter;
  int  x;
  int  y;
  int  cx;
  int  cy;
  UINT flags;
} WINDOWPOS, *LPWINDOWPOS, *PWINDOWPOS;

typedef struct tagPOINT {
  LONG x;
  LONG y;
} POINT, *PPOINT, *NPPOINT, *LPPOINT;

typedef struct tagRECT {
  LONG left;
  LONG top;
  LONG right;
  LONG bottom;
} RECT, *PRECT, *NPRECT, *LPRECT;

typedef struct _DWM_BLURBEHIND {
  DWORD dwFlags;
  BOOL  fEnable;
  HRGN  hRgnBlur;
  BOOL  fTransitionOnMaximized;
} DWM_BLURBEHIND, *PDWM_BLURBEHIND;

HWND GetActiveWindow(

);

BOOL GetWindowRect(
  HWND   hWnd,
  LPRECT lpRect
);

BOOL SetLayeredWindowAttributes(
  HWND     hwnd,
  COLORREF crKey,
  BYTE     bAlpha,
  DWORD    dwFlags
);

DWORD __stdcall GetLastError(void);

BOOL SetWindowPos(
  HWND hWnd,
  HWND hWndInsertAfter,
  int  X,
  int  Y,
  int  cx,
  int  cy,
  UINT uFlags
);

LONG SetWindowLongA(
  HWND     hWnd,
  int      nIndex,
  LONG dwNewLong
);

LONG GetWindowLongA(
  HWND hWnd,
  int  nIndex
);

BOOL SetWindowSubclass(
  HWND         hWnd,
  SUBCLASSPROC pfnSubclass,
  UINT_PTR     uIdSubclass,
  DWORD_PTR    dwRefData
);

LRESULT DefSubclassProc(
  HWND   hWnd,
  UINT   uMsg,
  WPARAM wParam,
  LPARAM lParam
);

BOOL RemoveWindowSubclass(
  HWND         hWnd,
  SUBCLASSPROC pfnSubclass,
  UINT_PTR     uIdSubclass
);

HMONITOR MonitorFromPoint(
  POINT pt,
  DWORD dwFlags
);

HRGN CreateRectRgn(
  int x1,
  int y1,
  int x2,
  int y2
);

HRESULT DwmEnableBlurBehindWindow(
  HWND                 hWnd,
  const DWM_BLURBEHIND *pBlurBehind
);

BOOL SetProcessDPIAware();

BOOL GetCursorPos(
  LPPOINT lpPoint
);

SHORT GetAsyncKeyState(
  int vKey
);

int GetSystemMetrics(
  int nIndex
);

]]


function windows.get_hwnd()
    return ffi.C.GetActiveWindow()
end

function windows.subclass_window_proc(hWnd, uMsg, wParam, lParam, uIdSubclass, dwRefData)
    if uMsg == 0x0082 then -- WM_NCDESTROY
        comctl32.RemoveWindowSubclass(hWnd, windows.subclass_window_proc_cb, uIdSubclass)
    elseif uMsg == 0x0046 then -- WM_WINDOWPOSCHANGING
        local windowpos = ffi.cast("WINDOWPOS*", lParam)
        if windows.at_bottom then
            -- https://stackoverflow.com/questions/2027536/setting-a-windows-form-to-be-bottommost
            windowpos.flags = bit.bor(windowpos.flags, 0x0004) -- SWP_NOZORDER
        end
        windowpos.flags = bit.bor(windowpos.flags, 0x0002) -- SWP_NOMOVE
    elseif uMsg == 0x0084 then -- WM_NCHITTEST
        local result = comctl32.DefSubclassProc(hWnd, uMsg, wParam, lParam);
        if result == 1 then -- HTCLIENT
            local x = tonumber(bit.band(lParam, 0xffff))
            if x > 0x8000 then x = x - 0x10000 end
            local y = tonumber(bit.band(bit.rshift(lParam, 16), 0xffff))
            if y > 0x8000 then y = y - 0x10000 end
            local rect = ffi.new('RECT[1]')
            local result = ffi.C.GetWindowRect(hWnd, rect)
            if result == 0 then
                log.error("error getting window rect")
                return 1
            end
            x = x - rect[0].left
            y = y - rect[0].top
            local hit = windows.hittest(x, y)
            local code = ({
                client = 1,
                caption = 2,
                close = 20
            })[hit] or 1
            return code
        end
        return result
    end
    return comctl32.DefSubclassProc(hWnd, uMsg, wParam, lParam)
end

windows.subclass_window_proc_cb = ffi.cast("SUBCLASSPROC", windows.subclass_window_proc)

function windows.register_subclass_window_proc()
    windows.at_bottom = false
    -- https://stackoverflow.com/questions/63143237/change-wndproc-of-the-window
    local result = comctl32.SetWindowSubclass(windows.hwnd, windows.subclass_window_proc_cb, 1, 0)
    if result == 1 then return true else return false end
end

-- z order

function windows.set_bottom()
    -- set to HWND_BOTTOM
    local result = ffi.C.SetWindowPos(windows.hwnd, ffi.cast("HWND", 1), 0, 0, 0, 0, 0x0013) -- SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE
    if result ~= 0 then
        windows.at_bottom = true
        return true
    else
        return false, ffi.C.GetLastError()
    end
end

function windows.set_orderable()
    windows.at_bottom = false
    local result = ffi.C.SetWindowPos(windows.hwnd, ffi.cast("HWND", -2), 0, 0, 0, 0, 0x0013) -- SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE
    if result ~= 0 then
        return true
    else
        return false, ffi.C.GetLastError()
    end
end

function windows.set_top()
    windows.at_bottom = false
    -- set to HWND_TOPMOST
    local result = ffi.C.SetWindowPos(windows.hwnd, ffi.cast("HWND", -1), 0, 0, 0, 0, 0x0013) -- SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE
    if result ~= 0 then
        return true
    else
        return false, ffi.C.GetLastError()
    end
end

-- transparency

-- use DwmEnableBlurBehindWindow which works on modern windows
function windows.set_transparent()
    local orig_style = ffi.C.GetWindowLongA(windows.hwnd, -16)
    orig_style = bit.band(orig_style, bit.bnot(0x00cf0000)) -- WS_OVERLAPPEDWINDOW
    orig_style = bit.bor(orig_style, 0x80000000) -- WS_POPUP
    ffi.C.SetWindowLongA(windows.hwnd, -16, orig_style)
    local bb = ffi.new('DWM_BLURBEHIND[1]')
    local hRgn = ffi.C.CreateRectRgn(0, 0, -1, -1) -- create an invisible region
    bb[0].dwFlags = 3 -- DWM_BB_ENABLE | DWM_BB_BLURREGION
    bb[0].hRgnBlur = hRgn
    bb[0].fEnable = true
    local result = dwmapi.DwmEnableBlurBehindWindow(windows.hwnd, bb);
    if result == 0 then return true else return false, result end
end

function windows.set_opaque()
    local bb = ffi.new('DWM_BLURBEHIND[1]')
    local hRgn = ffi.C.CreateRectRgn(0, 0, -1, -1) -- create an invisible region
    bb[0].dwFlags = 1 -- DWM_BB_ENABLE
    bb[0].hRgnBlur = hRgn
    bb[0].fEnable = false
    local result = dwmapi.DwmEnableBlurBehindWindow(windows.hwnd, bb);
    if result == 0 then return true else return false, result end
end

-- click through and hide taskbar

function windows.set_click_through(enabled)
    local orig_ex = ffi.C.GetWindowLongA(windows.hwnd, -20)
    if enabled then
        orig_ex = bit.bor(orig_ex, 0x00080020)
    else
        orig_ex = bit.band(orig_ex, bit.bnot(0x00080020))
    end -- WS_EX_LAYERED | WS_EX_TRANSPARENT
    local result = ffi.C.SetWindowLongA(windows.hwnd, -20, orig_ex)
    if result ~= 0 then
        return true
    else
        return false, ffi.C.GetLastError()
    end
end

function windows.set_hide_taskbar(enabled)
    local orig_ex = ffi.C.GetWindowLongA(windows.hwnd, -20)
    if enabled then
        orig_ex = bit.bor(orig_ex, 0x08000080)
    else
        orig_ex = bit.band(orig_ex, bit.bnot(0x08000080))
    end -- WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE
    local result = ffi.C.SetWindowLongA(windows.hwnd, -20, orig_ex)
    if result ~= 0 then
        return true
    else
        return false, ffi.C.GetLastError()
    end
end


windows.mouse_window_pos_x = 0
windows.mouse_window_pos_y = 0
windows.mouse_window_width = 0
windows.mouse_window_height = 0

function windows.update_mouse_window_pos()
    local rect = ffi.new("RECT[1]")
    local status = ffi.C.GetWindowRect(windows.hwnd, rect)
    if status == 0 then log.error("init display pos get window rect error") end
    windows.mouse_window_pos_x = tonumber(rect[0].left)
    windows.mouse_window_pos_y = tonumber(rect[0].top)
    windows.mouse_window_width = tonumber(rect[0].right - rect[0].left)
    windows.mouse_window_height = tonumber(rect[0].bottom - rect[0].top)
end

-- because window is transparent, mouse events can't be captured by love
-- we capture mouse state with windows api
-- and call relevant handlers in try_mouse_event
function windows.get_mouse_pos()
    local point = ffi.new("POINT[1]")
    local status = ffi.C.GetCursorPos(point)
    if status == 0 then log.error("get cursor pos error") end
    local x = point[0].x - windows.mouse_window_pos_x
    local y = point[0].y - windows.mouse_window_pos_y
    if x < 0 then x = 0 end
    if x >= windows.mouse_window_width then x = windows.mouse_window_width end
    if y < 0 then y = 0 end
    if y >= windows.mouse_window_height then y = windows.mouse_window_height end
    return x, y
end

windows.mouse_last_x = 0
windows.mouse_last_y = 0
windows.mouse_left_button_last_down = false
windows.mouse_right_button_last_down = false

function windows.try_mouse_event(pressed, released, moved)
    local x, y = windows.get_mouse_pos()
    local dx = x - windows.mouse_last_x
    local dy = y - windows.mouse_last_y
    if x ~= windows.mouse_last_x or y ~= windows.mouse_last_y then
        moved(x, y, dx, dy, false)
    end
    windows.mouse_last_x = x
    windows.mouse_last_y = y
    if bit.band(ffi.C.GetAsyncKeyState(0x01), 0x8000) ~= 0 then
        -- VK_LBUTTON
        if not windows.mouse_left_button_last_down then
            pressed(x, y, 1, false, 1)
        end
        windows.mouse_left_button_last_down = true
    elseif windows.mouse_left_button_last_down then
        if windows.mouse_left_button_last_down then
            released(x, y, 1, false, 1)
        end
        windows.mouse_left_button_last_down = false
    end
    if bit.band(ffi.C.GetAsyncKeyState(0x02), 0x8000) ~= 0 then
        -- VK_RBUTTON
        if not windows.mouse_right_button_last_down then
            pressed(x, y, 2, false, 1)
        end
        windows.mouse_right_button_last_down = true
    elseif windows.mouse_right_button_last_down then
        if windows.mouse_right_button_last_down then
            released(x, y, 2, false, 1)
        end
        windows.mouse_right_button_last_down = false
    end
end

windows.should_try_mouse_event = false
windows.original_mouse_functions = {}
function windows.override_mouse_functions()
    if windows.should_try_mouse_event == false then -- has not saved original
        windows.should_try_mouse_event = true
        windows.original_mouse_functions.getPosition = love.mouse.getPosition
        windows.original_mouse_functions.isDown = love.mouse.isDown
        windows.original_mouse_functions.hasFocus = love.window.hasFocus
        windows.original_mouse_functions.hasMouseFocus = love.window.hasMouseFocus
    end

    love.mouse.getPosition = windows.get_mouse_pos
    love.mouse.isDown = function (...)
        local buttons = {...}
        for i, button in pairs(buttons) do
            if button == 1 and windows.mouse_left_button_last_down then
                return true
            end
            if button == 2 and windows.mouse_right_button_last_down then
                return true
            end
        end
        return false
    end
    love.window.hasFocus = function () return true end
    love.window.hasMouseFocus = function () return true end
end

function windows.recover_mouse_functions()
    windows.should_try_mouse_event = false
    love.mouse.getPosition = windows.original_mouse_functions.getPosition
    love.mouse.isDown = windows.original_mouse_functions.isDown
    love.window.hasFocus = windows.original_mouse_functions.hasFocus
    love.window.hasMouseFocus = windows.original_mouse_functions.hasMouseFocus
end

function windows.set_window_position(display_index, x, y, w, h)
    if x == nil then x = 0 end
    if y == nil then y = 0 end
    local display_w, display_h = love.window.getDesktopDimensions(display_index)
    if w == nil then w = display_w - 1 end -- -1 is to ensure transparency
    if h == nil then h = display_h end
    log.debug("set display index", display_index)
    love.window.setMode(
        w, h,
        { borderless = true, resizable = false, vsync = 0, msaa = 4,
          display = display_index, x = x, y = y,
          highdpi = true, usedpiscale = false }
    )
    -- probably window creation
    windows.hwnd = windows.get_hwnd()
    local status, err = windows.register_subclass_window_proc()
    if not status then
        log.error("error registering subclass proc", err)
    end
    windows.update_mouse_window_pos()
end

windows.user_config = {}

function windows.update_user_config(key, value)
    if windows.user_config[key] == value then return false end
    log.debug("update usr config", key, value)
    if key == "z_order" then
        if value == "bottom" then windows.set_bottom() end
        if value == "top" then windows.set_top() end
        if value == "orderable" then windows.set_orderable() end
    end
    if key == "transparency" then
        if value then
            windows.set_transparent()
        else
            windows.set_opaque()
        end
    end
    if key == "click_through" then
        windows.set_click_through(value)
        if value and not windows.should_try_mouse_event then
            windows.override_mouse_functions()
        end
        if not value and windows.should_try_mouse_event then
            windows.recover_mouse_functions()
        end
    end
    if key == "hide_taskbar" then windows.set_hide_taskbar(value) end
    if key == "window_position" then
        windows.set_window_position(value.display_index, value.x, value.y, value.w, value.h)
        local original_user_config = windows.user_config
        windows.user_config = {}
        for k, v in pairs(original_user_config) do
            if k ~= "window_position" then
                windows.update_user_config(k, v)
            end
        end
    end
    windows.user_config[key] = value
    return true
end

function windows.user_config_gui()
    
end

windows.hittest = function () return 'client' end

function windows.init(user_config)
    -- create a small window first to prevent flashing
    windows.update_user_config("window_position", {display_index = 1, x = 0, y = 0, w = 1, h = 1})
    windows.update_user_config("window_position", {display_index = 2})
    
    windows.update_user_config("z_order", "bottom")
    windows.update_user_config("transparency", true)
    windows.update_user_config("click_through", true)
    windows.update_user_config("hide_taskbar", true)

    love.graphics.setBackgroundColor(0, 0, 0, 0)
end

return windows
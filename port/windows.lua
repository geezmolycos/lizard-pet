local windows = {}

local ffi = require "ffi"

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

-- use DwmEnableBlurBehindWindow which works on modern windows
function windows.set_transparent(hwnd)
    local orig_style = ffi.C.GetWindowLongA(hwnd, -16)
    local orig_exstyle = ffi.C.GetWindowLongA(hwnd, -20)
    orig_style = bit.band(orig_style, bit.bnot(0x00cf0000)) -- WS_OVERLAPPEDWINDOW
    orig_style = bit.bor(orig_style, 0x80000000)
    ffi.C.SetWindowLongA(hwnd, -16, orig_style)
    local bb = ffi.new('DWM_BLURBEHIND[1]')
    local hRgn = ffi.C.CreateRectRgn(0, 0, -1, -1) -- create an invisible region
    bb[0].dwFlags = 3 -- DWM_BB_ENABLE | DWM_BB_BLURREGION
    bb[0].hRgnBlur = hRgn
    bb[0].fEnable = true
    local result = dwmapi.DwmEnableBlurBehindWindow(hwnd, bb);
    if result == 0 then return true else return false, result end
end

function windows.subclass_window_proc(hWnd, uMsg, wParam, lParam, uIdSubclass, dwRefData)
    if uMsg == 0x0082 then -- WM_NCDESTROY
        comctl32.RemoveWindowSubclass(hWnd, window.subclass_window_proc_cb, uIdSubclass)
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
                print("error getting window rect")
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

function windows.register_subclass_window_proc(hwnd)
    windows.set_bottom(hwnd)
    -- https://stackoverflow.com/questions/63143237/change-wndproc-of-the-window
    local result = comctl32.SetWindowSubclass(hwnd, windows.subclass_window_proc_cb, 1, 0)
    if result == 1 then return true else return false end
end

function windows.set_bottom(hwnd)
    -- set to HWND_BOTTOM
    local result = ffi.C.SetWindowPos(hwnd, ffi.cast("HWND", 1), 0, 0, 0, 0, 0x0013) -- SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE
    if result ~= 0 then
        windows.at_bottom = true
        return true
    else
        return false, ffi.C.GetLastError()
    end
end

function windows.set_top(hwnd)
    windows.at_bottom = false
    -- set to HWND_TOPMOST
    local result = ffi.C.SetWindowPos(hwnd, ffi.cast("HWND", -1), 0, 0, 0, 0, 0x0013) -- SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE
    if result ~= 0 then
        return true
    else
        return false, ffi.C.GetLastError()
    end
end

function windows.hide_taskbar_and_disable_click(hwnd)
    local orig_ex = ffi.C.GetWindowLongA(hwnd, -20)
    local result = ffi.C.SetWindowLongA(hwnd, -20, bit.bor(orig_ex, 0x080800a0)) -- WS_EX_TOOLWINDOW | WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_NOACTIVATE
    if result ~= 0 then
        return true
    else
        return false, ffi.C.GetLastError()
    end
end

windows.display_pos_x = 0
windows.display_pos_y = 0
windows.display_width = 0
windows.display_height = 0

function windows.init_display_pos(hwnd, display_index)
    local rect = ffi.new("RECT[1]")
    local status = ffi.C.GetWindowRect(hwnd, rect)
    if status == 0 then print("init display pos get window rect error") end
    windows.display_pos_x = tonumber(rect[0].left)
    windows.display_pos_y = tonumber(rect[0].top)
    windows.display_width, windows.display_height = love.window.getDesktopDimensions(display_index)
end

-- because window is transparent, mouse events can't be captured by love
-- we capture mouse state with windows api
-- and call relevant handlers in try_mouse_event
function windows.get_mouse_pos()
    local point = ffi.new("POINT[1]")
    local status = ffi.C.GetCursorPos(point)
    if status == 0 then print("get cursor pos error") end
    local x = point[0].x - windows.display_pos_x
    local y = point[0].y - windows.display_pos_y
    if x < 0 then x = 0 end
    if x >= windows.display_width then x = windows.display_width end
    if y < 0 then y = 0 end
    if y >= windows.display_height then y = windows.display_height end
    return x, y
end

windows.mouse_last_x = 0
windows.mouse_last_y = 0
windows.mouse_last_down = false

function windows.try_mouse_event(pressed, released, moved)
    local x, y = windows.get_mouse_pos()
    if x ~= windows.mouse_last_x or y ~= windows.mouse_last_y then
        moved(x, y)
    end
    windows.mouse_last_x = x
    windows.mouse_last_y = y
    if bit.band(ffi.C.GetAsyncKeyState(0x01), 0x8000) ~= 0 then
        -- VK_LBUTTON
        if not windows.mouse_last_down then
            moved(x, y)
            pressed(x, y, 1)
        end
        windows.mouse_last_down = true
    else
        if windows.mouse_last_down then
            moved(x, y)
            released(x, y, 1)
        end
        windows.mouse_last_down = false
    end
end

function windows.get_hwnd()
    return ffi.C.GetActiveWindow()
end

function windows.init(display_index)
    if not ffi.C.SetProcessDPIAware() then
        print("set dpi awareness failed")
    end
    windows.hittest = function () return 'client' end
    local display_width, display_height = love.window.getDesktopDimensions(display_index)
    love.window.setMode(
        display_width - 1, display_height, -- window will be opaque if not -1
        { borderless = true, resizable = false, vsync = 0, msaa = 4,
          display = display_index, x = 0, y = 0,
          highdpi = true, usedpiscale = false }
    )
    local hwnd = windows.get_hwnd()
    windows.hwnd = hwnd
    local status, err = windows.set_transparent(hwnd)
    print("hWnd:", hwnd)
    windows.set_bottom(hwnd)
    if not status then
        print("error setting transparent", err)
    end
    local status, err = windows.register_subclass_window_proc(hwnd)
    if not status then
        print("error registering subclass proc", err)
    end
    local status, err = windows.hide_taskbar_and_disable_click(hwnd)
    if not status then
        print("error hiding taskbar", err)
    end

    -- hasFocus, etc are used in cimgui-love to detect if mouse is in focus
    -- we override it because the windows is set to transparent
    -- and mouse events can't arrive by normal means
    love.window.hasFocus = function () return true end
    love.window.hasMouseFocus = function () return true end
    windows.init_display_pos(hwnd, display_index)

    love.graphics.setBackgroundColor(0, 0, 0, 0)
end

return windows
#!/bin/bash
# 微信自动化基础操作库
# source 后使用各函数

# ============================================================
# 内部辅助：保存/恢复前台应用（用于后台模式）
# ============================================================
_wechat_saved_app=""
_wechat_saved_clipboard=""

_wechat_save_frontmost() {
    _wechat_saved_app=$(osascript -e '
    tell application "System Events"
        set frontApp to name of first application process whose frontmost is true
        return frontApp
    end tell' 2>/dev/null || echo "")
}

_wechat_restore_frontmost() {
    if [ -n "$_wechat_saved_app" ] && [ "$_wechat_saved_app" != "WeChat" ]; then
        osascript -e "tell application \"$_wechat_saved_app\" to activate" 2>/dev/null
    fi
    _wechat_saved_app=""
}

_wechat_save_clipboard() {
    _wechat_saved_clipboard=$(pbpaste 2>/dev/null || true)
}

_wechat_restore_clipboard() {
    if [ -n "$_wechat_saved_clipboard" ]; then
        printf '%s' "$_wechat_saved_clipboard" | pbcopy 2>/dev/null || true
    fi
    _wechat_saved_clipboard=""
}

# ============================================================
# 基础操作：截屏
# ============================================================
wechat_screenshot() {
    local output="${1:-/tmp/wechat-screenshot.png}"
    screencapture -x "$output"
    echo "$output"
}

# ============================================================
# 基础操作：激活微信并置顶
# ============================================================
wechat_activate() {
    osascript -e '
    tell application "WeChat" to activate
    delay 0.5
    tell application "System Events"
        tell process "WeChat"
            set frontmost to true
        end tell
    end tell
    delay 0.3'
}

# ============================================================
# 基础操作：获取微信窗口位置和大小
# 返回: x,y,width,height
# ============================================================
wechat_window_info() {
    osascript -e '
    tell application "System Events"
        tell process "WeChat"
            tell window "微信"
                set winPos to position
                set winSize to size
            end tell
            return (item 1 of winPos as text) & "," & (item 2 of winPos as text) & "," & (item 1 of winSize as text) & "," & (item 2 of winSize as text)
        end tell
    end tell'
}

# ============================================================
# 基础操作：点击指定坐标
# ============================================================
wechat_click() {
    local x=$1 y=$2
    cliclick "c:${x},${y}"
    sleep 0.3
}

# ============================================================
# 基础操作：移动鼠标到指定坐标
# ============================================================
wechat_move_mouse() {
    local x=$1 y=$2
    cliclick "m:${x},${y}"
    sleep 0.1
}

# ============================================================
# 基础操作：通过剪贴板粘贴文本（支持中文/emoji）
# ============================================================
wechat_paste_text() {
    local text="$1"
    printf '%s' "$text" | pbcopy
    sleep 0.1
    osascript -e '
    tell application "System Events"
        tell process "WeChat"
            keystroke "v" using command down
        end tell
    end tell'
    sleep 0.3
}

# ============================================================
# 基础操作：按键
# key code 参考: 36=回车, 53=ESC, 51=删除, 116=PageUp, 121=PageDown
#                125=下箭头, 126=上箭头, 123=左箭头, 124=右箭头, 48=Tab
# ============================================================
wechat_key() {
    local keycode=$1
    osascript -e "
    tell application \"System Events\"
        tell process \"WeChat\"
            key code ${keycode}
        end tell
    end tell"
    sleep 0.2
}

# ============================================================
# 基础操作：快捷键 (Cmd + key)
# ============================================================
wechat_shortcut() {
    local key="$1"
    osascript -e "
    tell application \"System Events\"
        tell process \"WeChat\"
            keystroke \"${key}\" using command down
        end tell
    end tell"
    sleep 0.3
}

# ============================================================
# 基础操作：滚动（在鼠标当前位置）
# 参数: 方向 up/down, 次数(默认10)
# ============================================================
wechat_scroll() {
    local direction="${1:-up}" count="${2:-10}"
    local delta=5
    if [ "$direction" = "down" ]; then
        delta=-5
    fi
    osascript -l JavaScript -e "
    ObjC.import('CoreGraphics');
    for (var i = 0; i < ${count}; i++) {
        var event = $.CGEventCreateScrollWheelEvent(null, 0, 1, ${delta});
        $.CGEventPost(0, event);
        delay(0.05);
    }"
    sleep 0.3
}

# ============================================================
# 组合操作：点击聊天区域中心（用于聚焦聊天记录）
# ============================================================
wechat_focus_chat() {
    local info
    info=$(wechat_window_info)
    IFS=',' read -r wx wy ww wh <<< "$info"
    local cx=$(( wx + 200 + (ww - 200) / 2 ))
    local cy=$(( wy + wh / 2 ))
    wechat_click "$cx" "$cy"
}

# ============================================================
# 组合操作：点击消息输入框
# ============================================================
wechat_focus_input() {
    local info
    info=$(wechat_window_info)
    IFS=',' read -r wx wy ww wh <<< "$info"
    local cx=$(( wx + 200 + (ww - 200) / 2 ))
    local cy=$(( wy + wh - 55 ))
    wechat_click "$cx" "$cy"
}

# ============================================================
# 组合操作：在聊天区域滚动
# 参数: 方向 up/down, 次数(默认10)
# ============================================================
wechat_scroll_chat() {
    local direction="${1:-up}" count="${2:-10}"
    local info
    info=$(wechat_window_info)
    IFS=',' read -r wx wy ww wh <<< "$info"
    local cx=$(( wx + 200 + (ww - 200) / 2 ))
    local cy=$(( wy + wh / 2 ))
    wechat_move_mouse "$cx" "$cy"
    sleep 0.2
    wechat_scroll "$direction" "$count"
}

# ============================================================
# 组合操作：搜索并进入会话
# ============================================================
wechat_open_chat() {
    local contact="$1"
    local info
    info=$(wechat_window_info)
    IFS=',' read -r wx wy ww wh <<< "$info"

    # 点击左侧搜索栏
    wechat_click $(( wx + 120 )) $(( wy + 33 ))
    sleep 0.5

    # 粘贴搜索关键词
    wechat_paste_text "$contact"
    sleep 1.5

    # 回车选择第一个结果
    wechat_key 36
    sleep 1.0

    # 点击输入框并清空残留内容
    wechat_focus_input
    wechat_shortcut "a"
    sleep 0.1
    wechat_key 51
}

# ============================================================
# 组合操作：在当前会话发送消息
# ============================================================
wechat_send_message() {
    local message="$1"
    wechat_focus_input
    wechat_paste_text "$message"
    sleep 0.2
    wechat_key 36
}

# ============================================================
# 高级操作：向指定联系人/群发送消息（完整流程）
# 支持后台模式：操作完自动切回之前的应用
# ============================================================
wechat_send_to() {
    local contact="$1" message="$2" background="${3:-true}"

    _wechat_save_clipboard
    [ "$background" = "true" ] && _wechat_save_frontmost

    wechat_activate
    wechat_open_chat "$contact"
    wechat_send_message "$message"

    _wechat_restore_clipboard
    [ "$background" = "true" ] && _wechat_restore_frontmost

    echo "✓ 已向「${contact}」发送消息：${message}"
}

# ============================================================
# 高级操作：读取当前会话聊天记录（截屏方式）
# 参数: 向上滚动次数(默认0=当前屏), 输出路径
# ============================================================
wechat_read_chat() {
    local scroll_up="${1:-0}" output="${2:-/tmp/wechat-chat.png}" background="${3:-true}"

    [ "$background" = "true" ] && _wechat_save_frontmost

    wechat_activate
    wechat_focus_chat

    if [ "$scroll_up" -gt 0 ]; then
        wechat_scroll_chat up "$scroll_up"
    fi

    wechat_screenshot "$output"

    [ "$background" = "true" ] && _wechat_restore_frontmost

    echo "$output"
}

# ============================================================
# 高级操作：打开指定会话并截屏查看
# ============================================================
wechat_view_chat() {
    local contact="$1" scroll_up="${2:-0}" output="${3:-/tmp/wechat-chat.png}" background="${4:-true}"

    _wechat_save_clipboard
    [ "$background" = "true" ] && _wechat_save_frontmost

    wechat_activate
    wechat_open_chat "$contact"
    wechat_focus_chat

    if [ "$scroll_up" -gt 0 ]; then
        wechat_scroll_chat up "$scroll_up"
    fi

    wechat_screenshot "$output"

    _wechat_restore_clipboard
    [ "$background" = "true" ] && _wechat_restore_frontmost

    echo "$output"
}

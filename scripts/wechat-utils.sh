#!/bin/bash
# 微信 macOS 自动化操作库 v2
# 基于实际操控经验整理的最佳实践版本
#
# 核心原则：
#   1. 所有文本输入必须走剪贴板（keystroke 不支持中文/emoji）
#   2. 多步 AppleScript 合并为单次 osascript 调用，减少开销
#   3. 坐标操作前先获取窗口信息，动态计算
#   4. 关键操作后截屏验证状态
#   5. 滚动前必须确保鼠标在目标区域上
#
# 已知限制：
#   - Cmd+F 是全局搜索（含网络搜索），不能用来找会话
#   - Cmd+N 是新建群聊，不是搜索已有会话
#   - 微信 AXUIElement 暴露极少，无法用辅助功能 API 定位搜索框
#   - 侧边栏搜索框没有键盘快捷键，只能靠坐标点击
#   - 会话列表排序随新消息变化，不能靠固定位置选会话

# ============================================================
# 配置
# ============================================================
WECHAT_SIGNATURE=" ʕ•ᴥ•ʔ"

# ============================================================
# 内部状态
# ============================================================
_wechat_saved_app=""
_wechat_saved_clipboard=""
_wechat_win_x=""
_wechat_win_y=""
_wechat_win_w=""
_wechat_win_h=""

# ============================================================
# 内部辅助
# ============================================================
_wechat_save_context() {
    _wechat_saved_clipboard=$(pbpaste 2>/dev/null || true)
    _wechat_saved_app=$(osascript -e '
    tell application "System Events"
        set frontApp to name of first application process whose frontmost is true
        return frontApp
    end tell' 2>/dev/null || echo "")
}

_wechat_restore_context() {
    if [ -n "$_wechat_saved_clipboard" ]; then
        printf '%s' "$_wechat_saved_clipboard" | pbcopy 2>/dev/null || true
    fi
    if [ -n "$_wechat_saved_app" ] && [ "$_wechat_saved_app" != "WeChat" ]; then
        osascript -e "tell application \"$_wechat_saved_app\" to activate" 2>/dev/null
    fi
    _wechat_saved_app=""
    _wechat_saved_clipboard=""
}

_wechat_update_window() {
    local info
    info=$(osascript -e '
    tell application "System Events"
        tell process "WeChat"
            tell window "微信"
                set winPos to position
                set winSize to size
            end tell
            return (item 1 of winPos as text) & "," & (item 2 of winPos as text) & "," & (item 1 of winSize as text) & "," & (item 2 of winSize as text)
        end tell
    end tell' 2>/dev/null)
    IFS=',' read -r _wechat_win_x _wechat_win_y _wechat_win_w _wechat_win_h <<< "$info"
}

# ============================================================
# 基础操作：激活微信
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
    _wechat_update_window
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
# 基础操作：通过剪贴板粘贴文本
# 这是唯一正确的文本输入方式，keystroke 不支持中文/emoji
# ============================================================
wechat_paste() {
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
# 基础操作：按键 / 快捷键
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

wechat_cmd() {
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
# 基础操作：点击 / 移动鼠标
# ============================================================
wechat_click() {
    cliclick "c:${1},${2}"
    sleep 0.3
}

wechat_move() {
    cliclick "m:${1},${2}"
    sleep 0.1
}

# ============================================================
# 基础操作：滚动
# 必须先确保鼠标在目标区域上，否则会滚错窗口
# ============================================================
wechat_scroll() {
    local direction="${1:-up}" count="${2:-10}"
    local delta=5
    [ "$direction" = "down" ] && delta=-5
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
# 组合操作：搜索并进入会话
#
# 最佳实践（踩坑总结）：
#   ✅ 点击侧边栏搜索框 → 粘贴关键词 → 回车
#   ❌ Cmd+F → 全局搜索含网络结果
#   ❌ Cmd+N → 新建群聊
#
# 搜索框坐标通过截屏确认后动态微调。
# 搜索结果选中后，用 ESC 关闭搜索面板避免残留。
# ============================================================
wechat_open_chat() {
    local contact="$1"
    [ -z "$_wechat_win_x" ] && _wechat_update_window

    osascript <<APPLESCRIPT
    tell application "System Events"
        tell process "WeChat"
            set frontmost to true
            delay 0.2

            -- 点击侧边栏搜索框
            -- 搜索框在窗口顶部左侧区域，宽度约为侧边栏宽度
            click at {${_wechat_win_x} + 120, ${_wechat_win_y} + 35}
            delay 0.8

            -- 清空搜索框可能的残留内容
            keystroke "a" using command down
            delay 0.1
            key code 51
            delay 0.2
        end tell
    end tell
APPLESCRIPT

    # 粘贴搜索关键词（必须用剪贴板）
    wechat_paste "$contact"
    sleep 1.5

    # 回车选中第一个结果进入会话
    wechat_key 36
    sleep 1.0

    # ESC 确保关闭搜索面板
    wechat_key 53
    sleep 0.3
}

# ============================================================
# 组合操作：在聊天区域滚动
# 先移动鼠标到聊天区域中心，再滚动，避免滚错窗口
# ============================================================
wechat_scroll_chat() {
    local direction="${1:-up}" count="${2:-10}"
    [ -z "$_wechat_win_x" ] && _wechat_update_window
    local cx=$(( _wechat_win_x + 200 + (_wechat_win_w - 200) / 2 ))
    local cy=$(( _wechat_win_y + _wechat_win_h / 2 ))
    wechat_move "$cx" "$cy"
    sleep 0.2
    wechat_scroll "$direction" "$count"
}

# ============================================================
# 组合操作：聚焦输入框并发送消息
#
# 点击输入框区域 → 清空 → 粘贴消息 → 回车发送
# 合并为单次操作减少延迟
# ============================================================
wechat_send_message() {
    local message="$1"
    [ -z "$_wechat_win_x" ] && _wechat_update_window

    local cx=$(( _wechat_win_x + 200 + (_wechat_win_w - 200) / 2 ))
    local cy=$(( _wechat_win_y + _wechat_win_h - 55 ))

    # 点击输入框
    wechat_click "$cx" "$cy"

    # 清空可能的残留内容
    wechat_cmd "a"
    sleep 0.1
    wechat_key 51
    sleep 0.1

    # 粘贴消息并发送
    wechat_paste "${message}${WECHAT_SIGNATURE}"
    sleep 0.2
    wechat_key 36
}

# ============================================================
# 高级操作：向指定联系人/群发送消息
# background=true 时操作完自动切回之前的应用
# ============================================================
wechat_send_to() {
    local contact="$1" message="$2" background="${3:-true}"

    [ "$background" = "true" ] && _wechat_save_context || _wechat_saved_clipboard=$(pbpaste 2>/dev/null || true)

    wechat_activate
    wechat_open_chat "$contact"
    wechat_send_message "$message"

    [ "$background" = "true" ] && _wechat_restore_context || {
        [ -n "$_wechat_saved_clipboard" ] && printf '%s' "$_wechat_saved_clipboard" | pbcopy 2>/dev/null || true
    }

    echo "✓ 已向「${contact}」发送消息：${message}"
}

# ============================================================
# 高级操作：查看当前会话聊天记录
# scroll_up: 向上滚动量（0=当前屏）
# ============================================================
wechat_read_chat() {
    local scroll_up="${1:-0}" output="${2:-/tmp/wechat-chat.png}" background="${3:-true}"

    [ "$background" = "true" ] && _wechat_save_context

    wechat_activate

    # 聚焦聊天区域
    [ -z "$_wechat_win_x" ] && _wechat_update_window
    local cx=$(( _wechat_win_x + 200 + (_wechat_win_w - 200) / 2 ))
    local cy=$(( _wechat_win_y + _wechat_win_h / 2 ))
    wechat_click "$cx" "$cy"

    [ "$scroll_up" -gt 0 ] && wechat_scroll_chat up "$scroll_up"

    wechat_screenshot "$output"

    [ "$background" = "true" ] && _wechat_restore_context

    echo "$output"
}

# ============================================================
# 高级操作：打开指定会话并截屏
# ============================================================
wechat_view_chat() {
    local contact="$1" scroll_up="${2:-0}" output="${3:-/tmp/wechat-chat.png}" background="${4:-true}"

    [ "$background" = "true" ] && _wechat_save_context || _wechat_saved_clipboard=$(pbpaste 2>/dev/null || true)

    wechat_activate
    wechat_open_chat "$contact"

    [ -z "$_wechat_win_x" ] && _wechat_update_window
    local cx=$(( _wechat_win_x + 200 + (_wechat_win_w - 200) / 2 ))
    local cy=$(( _wechat_win_y + _wechat_win_h / 2 ))
    wechat_click "$cx" "$cy"

    [ "$scroll_up" -gt 0 ] && wechat_scroll_chat up "$scroll_up"

    wechat_screenshot "$output"

    [ "$background" = "true" ] && _wechat_restore_context || {
        [ -n "$_wechat_saved_clipboard" ] && printf '%s' "$_wechat_saved_clipboard" | pbcopy 2>/dev/null || true
    }

    echo "$output"
}

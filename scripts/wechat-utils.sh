#!/bin/bash
# WeChat macOS automation library v4
# For WeChat 4.x (verified on WeChat 4.1.13)
#
# Architecture:
#   - Finding chats, reading, sending and listing chats are delegated to
#     WeChat-MCP's command line tool `wechat-cli` (Python + Accessibility API).
#     It confirms the right chat is open, writes the text into the input field
#     through Accessibility and reads it back, sends, then checks the newest
#     bubble. It never types blindly.
#   - This file keeps only what the shell is good at: activating / restoring
#     apps, screenshots, scrolling, key presses.
#
# Prerequisites:
#   - WeChat-MCP set up with `uv sync` (default: the sibling directory
#     ../WeChat-MCP of this skill, or WECHAT_MCP_DIR; a `wechat-cli` on PATH
#     is used directly)
#   - Accessibility and Screen Recording permissions for the terminal / claude
#   - cliclick installed (only needed to move the pointer before scrolling)

# ============================================================
# Configuration
# ============================================================
WECHAT_BUNDLE_ID="com.tencent.xinWeChat"
WECHAT_PROCESS="WeChat"
# Signature appended to every message; empty by default. export WECHAT_SIGNATURE=" ʕ•ᴥ•ʔ" to enable
WECHAT_SIGNATURE="${WECHAT_SIGNATURE:-}"

_wechat_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" 2>/dev/null && pwd)"
WECHAT_MCP_DIR="${WECHAT_MCP_DIR:-$(cd "${_wechat_script_dir}/../../WeChat-MCP" 2>/dev/null && pwd)}"

# ============================================================
# Internal state
# ============================================================
_wechat_saved_app=""
_wechat_win_x=""
_wechat_win_y=""
_wechat_win_w=""
_wechat_win_h=""

# ============================================================
# CLI invocation
# ============================================================
wechat_cli() {
    if command -v wechat-cli >/dev/null 2>&1; then
        wechat-cli "$@"
    elif [ -n "$WECHAT_MCP_DIR" ] && [ -f "$WECHAT_MCP_DIR/pyproject.toml" ]; then
        uv run --quiet --directory "$WECHAT_MCP_DIR" wechat-cli "$@"
    else
        echo "✗ wechat-cli not found: install WeChat-MCP (pip install wechat-mcp-server) or set WECHAT_MCP_DIR" >&2
        return 127
    fi
}

# ============================================================
# Internal helpers
# ============================================================
_wechat_save_context() {
    _wechat_saved_app=$(osascript -e '
    tell application "System Events"
        set frontApp to name of first application process whose frontmost is true
        return frontApp
    end tell' 2>/dev/null || echo "")
}

_wechat_restore_context() {
    if [ -n "$_wechat_saved_app" ] && [ "$_wechat_saved_app" != "$WECHAT_PROCESS" ]; then
        osascript -e "tell application \"$_wechat_saved_app\" to activate" 2>/dev/null
    fi
    _wechat_saved_app=""
}

# Main window frame: first standard window (independent of the UI language)
_wechat_update_window() {
    local info
    info=$(osascript -e "
    tell application \"System Events\"
        tell process \"$WECHAT_PROCESS\"
            set w to missing value
            try
                set w to first window whose subrole is \"AXStandardWindow\"
            end try
            if w is missing value then set w to window 1
            set winPos to position of w
            set winSize to size of w
            return (item 1 of winPos as text) & \",\" & (item 2 of winPos as text) & \",\" & (item 1 of winSize as text) & \",\" & (item 2 of winSize as text)
        end tell
    end tell" 2>/dev/null)
    IFS=',' read -r _wechat_win_x _wechat_win_y _wechat_win_w _wechat_win_h <<< "$info"
}

# Centre of the message area (WeChat 4.x default layout: 60px tab bar + 240px session list)
_wechat_chat_center() {
    [ -z "$_wechat_win_x" ] && _wechat_update_window
    echo "$(( _wechat_win_x + 300 + (_wechat_win_w - 300) / 2 )) $(( _wechat_win_y + _wechat_win_h / 2 ))"
}

# ============================================================
# Basics: activate WeChat / screenshot / keys / pointer / scroll
# ============================================================
wechat_activate() {
    osascript -e "
    tell application id \"$WECHAT_BUNDLE_ID\" to activate
    delay 0.5
    tell application \"System Events\"
        tell process \"$WECHAT_PROCESS\"
            set frontmost to true
        end tell
    end tell
    delay 0.3" >/dev/null 2>&1
    _wechat_update_window
}

# Captures the WeChat main window by default; pass `full` as 2nd argument for the whole screen
wechat_screenshot() {
    local output="${1:-/tmp/wechat-screenshot.png}" mode="${2:-window}"
    [ -z "$_wechat_win_x" ] && _wechat_update_window
    if [ "$mode" = "window" ] && [ -n "$_wechat_win_x" ]; then
        screencapture -x -R "${_wechat_win_x},${_wechat_win_y},${_wechat_win_w},${_wechat_win_h}" "$output"
    else
        screencapture -x "$output"
    fi
    echo "$output"
}

wechat_key() {
    osascript -e "
    tell application \"System Events\"
        tell process \"$WECHAT_PROCESS\"
            key code ${1}
        end tell
    end tell" >/dev/null 2>&1
    sleep 0.2
}

wechat_move() {
    cliclick "m:${1},${2}"
    sleep 0.1
}

# Scroll at the current pointer position; move the pointer over the target first
wechat_scroll() {
    local direction="${1:-up}" count="${2:-10}"
    local delta=5
    [ "$direction" = "down" ] && delta=-5
    osascript -l JavaScript -e "
    ObjC.import('CoreGraphics');
    for (var i = 0; i < ${count}; i++) {
        var event = \$.CGEventCreateScrollWheelEvent(null, 0, 1, ${delta});
        \$.CGEventPost(0, event);
        delay(0.05);
    }"
    sleep 0.3
}

# Scroll the message area: move the pointer first (no click, a click could open a photo / file)
wechat_scroll_chat() {
    local direction="${1:-up}" count="${2:-10}"
    local cx cy
    read -r cx cy <<< "$(_wechat_chat_center)"
    wechat_move "$cx" "$cy"
    sleep 0.2
    wechat_scroll "$direction" "$count"
}

# ============================================================
# Chats / messages (all via wechat-cli)
# ============================================================

# Name of the chat that is open
wechat_current_chat() {
    wechat_cli --text current 2>/dev/null | sed -n 's/^current_chat: //p'
}

# Open a chat: session list first, then exact search match; non-zero if another chat ends up open
wechat_open_chat() {
    local contact="$1"
    wechat_cli --text open "$contact"
}

# Send a message to a chat (confirms the chat, writes via Accessibility, verifies)
wechat_send_message() {
    local contact="$1" message="$2"
    wechat_cli --text send "$contact" "${message}${WECHAT_SIGNATURE}"
}

# Last N messages (text: [sender] text; pass --json for structured output)
wechat_fetch() {
    local contact="$1" last_n="${2:-20}" fmt="${3:---text}"
    wechat_cli "$fmt" fetch "$contact" -n "$last_n"
}

# Sidebar chat list (name / last message / time / muted)
wechat_list_chats() {
    local max="${1:-30}" fmt="${2:---text}"
    wechat_cli "$fmt" chats --max "$max"
}

# WeChat version / UI compatibility report (run first after a WeChat update)
wechat_check() {
    wechat_cli --text check
}

# ============================================================
# High-level operations
# ============================================================

# Send to a contact / group. wechat-cli restores the previously active app itself.
wechat_send_to() {
    local contact="$1" message="$2"
    if wechat_send_message "$contact" "$message"; then
        echo "✓ Sent to \"${contact}\": ${message}"
        return 0
    fi
    echo "✗ Could not send to \"${contact}\" (see the reason above); take a screenshot to check" >&2
    return 1
}

# View a chat: prefer wechat_fetch (faster, exact); screenshot only to look at photos / stickers
wechat_view_chat() {
    local contact="$1" scroll_up="${2:-0}" output="${3:-/tmp/wechat-chat.png}" background="${4:-true}"
    local rc=0

    [ "$background" = "true" ] && _wechat_save_context

    wechat_cli --text open "$contact" >/dev/null || rc=1
    wechat_activate

    if [ "$scroll_up" -gt 0 ]; then
        wechat_scroll_chat up "$scroll_up"
    fi

    wechat_screenshot "$output" >/dev/null

    [ "$background" = "true" ] && _wechat_restore_context

    echo "$output"
    return $rc
}

# Screenshot the current chat (does not switch chats)
wechat_read_chat() {
    local scroll_up="${1:-0}" output="${2:-/tmp/wechat-chat.png}" background="${3:-true}"

    [ "$background" = "true" ] && _wechat_save_context
    wechat_activate
    [ "$scroll_up" -gt 0 ] && wechat_scroll_chat up "$scroll_up"
    wechat_screenshot "$output" >/dev/null
    [ "$background" = "true" ] && _wechat_restore_context

    echo "$output"
}

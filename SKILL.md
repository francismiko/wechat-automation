---
name: wechat-automation
description: Automate the WeChat desktop client on macOS (WeChat 4.x). Reads messages, sends messages, lists and searches chats through WeChat-MCP's wechat-cli (macOS Accessibility API), with screenshots and scrolling for visual checks. Trigger when the user mentions WeChat / 微信, sending a message to someone, posting in a group, checking what a group is talking about, WeChat automation, or scheduled WeChat messages. Restores the previously active app when done.
---

# WeChat macOS Automation

Controls the WeChat 4.x desktop client through WeChat-MCP's command line tool `wechat-cli`. Every chat and message operation goes through the Accessibility API and is verified step by step: confirm the right chat is open, write the text into the input field and read it back, send, then check the newest bubble. It **never** clicks blind coordinates or simulates keyboard typing.

## Prerequisites

1. **WeChat for Mac 4.x** installed and signed in (verified on 4.1.13; 3.x has a different UI and is not supported)
2. **WeChat-MCP** installed: either the sibling directory `../WeChat-MCP` of this skill (after `uv sync`), or `pip install wechat-mcp-server` so that `wechat-cli` is on PATH, or `export WECHAT_MCP_DIR=/path/to/WeChat-MCP`
3. **Accessibility** and **Screen Recording** permissions granted to the terminal app and the claude CLI (System Settings → Privacy & Security)
4. **cliclick** installed (`brew install cliclick`, only needed for scrolling before screenshots)

If the user hits a permission error ("not allowed assistive access"), point them to System Settings and the apps that need to be added: the terminal (Terminal, Warp, iTerm2, ...) and `/opt/homebrew/Caskroom/claude-code/*/claude`.

## Library

```bash
source ~/.agents/skills/wechat-automation/scripts/wechat-utils.sh
```

## Operations

### Chats and messages (via wechat-cli; a non-zero return means failure)

| Function | Arguments | Description |
|----------|-----------|-------------|
| `wechat_check` | — | WeChat version / UI compatibility report. **Run this first after a WeChat update** |
| `wechat_list_chats [max] [--json]` | count | Sidebar chats: time, name, last message, muted |
| `wechat_fetch "name" [n] [--json]` | chat, count | Last n messages as `[sender] text`; group messages carry the member name, `---` lines are timestamps / notices |
| `wechat_open_chat "name"` | chat | Open a chat (session list first, then exact search match); fails if a different chat ends up open |
| `wechat_send_message "name" "text"` | chat, text | Confirm the chat, send, verify |
| `wechat_send_to "name" "text"` | chat, text | Same, with a human readable success / failure line |
| `wechat_current_chat` | — | Name of the chat that is open |

`wechat-cli` can also be called directly: `wechat_cli --text fetch "Group" -n 50`, `wechat_cli moment "text" --draft`, `wechat_cli add-contact wxid_xxx --message "hi"`. Drop `--text` to get JSON.

### Screenshots and scrolling (only for visual checks: photos, stickers, file previews)

| Function | Arguments | Description |
|----------|-----------|-------------|
| `wechat_activate` | — | Bring WeChat to the front and cache the window frame |
| `wechat_screenshot [path] [full]` | output path | Capture the WeChat main window (`full` for the whole screen) |
| `wechat_scroll_chat dir count` | up/down, count | Move the pointer over the message area, then scroll (move only, no click) |
| `wechat_view_chat "name" [scroll] [path] [bg]` | chat, scroll, path, background | Open the chat → scroll → screenshot |
| `wechat_read_chat [scroll] [path] [bg]` | scroll, path, background | Screenshot the current chat |
| `wechat_key keycode` / `wechat_move x y` / `wechat_scroll dir count` | low-level key / pointer / scroll | Rarely needed directly |

## Patterns

### Send a message

```bash
source ~/.agents/skills/wechat-automation/scripts/wechat-utils.sh
wechat_send_to "Alice" "Meeting tomorrow at 3pm"
```

### What is a group talking about (prefer text over screenshots)

```bash
source ~/.agents/skills/wechat-automation/scripts/wechat-utils.sh
wechat_fetch "Project Group" 50
```

### Which chats have new messages

```bash
wechat_list_chats 20
```

### Screenshot only when you need to see images or stickers

```bash
wechat_view_chat "Project Group" 0 /tmp/chat.png
# then Read /tmp/chat.png
```

## Rules

- **Only send through the functions above.** Never type into WeChat yourself with `keystroke` or `cliclick`: if the focus is not in the expected input field the text goes to the wrong contact (this has happened).
- Chat names must match **exactly** (case-insensitive, group names without the member-count suffix). When the name is not exact, `wechat_open_chat` fails and lists candidates; confirm the right one with the user before sending.
- When a function returns non-zero, stop and tell the user. Do not try other "clever" ways to send.
- "File Transfer" (文件传输助手) cannot be found through search, but it is in the session list (the tool scrolls to find it).
- If tools fail after a WeChat update, run `wechat_check` first: it shows whether the version is verified and which UI elements are missing.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `wechat-cli not found` | WeChat-MCP not installed / wrong path | `uv sync` in the WeChat-MCP directory, or `export WECHAT_MCP_DIR=...` |
| "not allowed assistive access" / no messages read | Missing Accessibility or Screen Recording permission | System Settings → Privacy & Security, add the terminal and the claude CLI |
| A different chat opened | Inexact chat name | Confirm the exact name via `wechat_list_chats` or the candidate list |
| `warnings` about an unverified version | WeChat was updated | `wechat_check`; once verified, add the version to `compat.py` in WeChat-MCP |
| Sender UNKNOWN / empty group member names | No Screen Recording permission or the window is covered | Grant Screen Recording; bring the WeChat window to the front if needed |

Key codes and the UI layout are in `references/key-codes.md`. 中文版见 `SKILL_zh.md`。

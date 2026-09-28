<h1 align="center">WeChat Automation Skill</h1>

<p align="center">
  <strong>Claude Code skill for automating the WeChat desktop client (4.x) on macOS</strong>
</p>

<p align="center">English | <a href="README_zh.md">中文</a></p>

---

This skill is a shell wrapper around the `wechat-cli` command of [WeChat-MCP](../WeChat-MCP): every chat and message operation runs through the macOS Accessibility API with step-by-step verification, while the shell only handles screenshots, scrolling and switching back to the previous app.

## Features

- **Send messages** — confirms the right chat is open, writes the text into the input field and reads it back, sends, then checks the newest bubble (Chinese / emoji supported)
- **Read messages** — plain text with sender (including group member names), kind (text / image / file / sticker / ...) and timestamps
- **Chat list** — name, last message, time, muted state
- **Compatibility check** — warns when WeChat was updated to an unverified version, needs a restart, or UI elements are missing
- **Screenshot verification** — captures the WeChat window when you need to look at photos or stickers
- **Background mode** — gives the foreground back to the app you were using

## Prerequisites

| Dependency | Notes |
|------------|-------|
| macOS | macOS only |
| [WeChat for Mac 4.x](https://mac.weixin.qq.com/) | Installed and signed in (verified on 4.1.13) |
| [WeChat-MCP](../WeChat-MCP) | Sibling directory `../WeChat-MCP` after `uv sync`, or `pip install wechat-mcp-server`, or set `WECHAT_MCP_DIR` |
| [cliclick](https://github.com/BlueM/cliclick) | `brew install cliclick` (needed for scrolling before screenshots) |
| Accessibility + Screen Recording permissions | Both for the terminal app and the claude CLI |

## Installation

```bash
git clone https://github.com/Francismiko/wechat-automation.git ~/.agents/skills/wechat-automation
ln -s ../../.agents/skills/wechat-automation ~/.claude/skills/wechat-automation
# WeChat-MCP
git clone https://github.com/BiboyQG/WeChat-MCP.git ~/.agents/skills/WeChat-MCP && (cd ~/.agents/skills/WeChat-MCP && uv sync)
```

## Usage

```
> Send Alice a WeChat message: "meeting tomorrow at 3pm"
> What has the "Project Group" been talking about?
> Which groups have new messages?
```

### Programmatic usage

```bash
source ~/.agents/skills/wechat-automation/scripts/wechat-utils.sh

wechat_check                                  # version / UI compatibility
wechat_list_chats 20                          # chat list
wechat_fetch "Work Group" 50                  # last 50 messages (text)
wechat_send_to "Alice" "hello"                # send and verify
wechat_view_chat "Work Group" 0 /tmp/chat.png # screenshot when you need to see images
wechat_cli fetch "Work Group" -n 50           # raw JSON
```

## How it works

```
Claude Code
  └─ wechat-automation skill (bash)
       ├─ wechat_fetch / wechat_send_to / wechat_list_chats ─▶ wechat-cli (WeChat-MCP, Python)
       │                                                        └─ macOS Accessibility API + window capture
       └─ wechat_screenshot / wechat_scroll_chat ─▶ screencapture / CGEvent
                                                    ▼
                                             WeChat for Mac 4.x
```

## Limitations

- macOS only, needs a graphical session
- WeChat 3.x is not supported; after a new WeChat release run `wechat_check` first
- Group member names are recovered with OCR and may occasionally contain a wrong character

## License

[MIT](LICENSE)

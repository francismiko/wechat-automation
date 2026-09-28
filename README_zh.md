<h1 align="center">WeChat Automation Skill</h1>

<p align="center"><a href="README.md">English</a> | 中文</p>

<p align="center">
  <strong>macOS 微信桌面客户端（4.x）自动化操控 skill，适用于 Claude Code</strong>
</p>

---

本 skill 是 [WeChat-MCP](../WeChat-MCP) 命令行工具 `wechat-cli` 的 shell 封装：会话、消息相关操作全部通过辅助功能 API 完成并逐步校验，shell 只负责截屏、滚动和切回原应用。

## Features

- **发送消息** — 先确认打开了正确会话，再写入输入框并核对，发送后核对最新气泡（支持中文 / emoji）
- **读取消息** — 直接拿到文本：发送者（含群成员名）、类型（文字 / 图片 / 文件 / 表情…）、时间
- **会话列表** — 名称、最后一条消息、时间、是否免打扰
- **兼容性检查** — 微信升级到未验证版本、升级后未重启、界面元素缺失时给出提示
- **截屏验证** — 需要看图片 / 表情时截取微信窗口，交给 Claude 视觉分析
- **后台模式** — 操作完自动把前台切回之前的应用

## Prerequisites

| 依赖 | 说明 |
|------|------|
| macOS | 仅支持 macOS |
| [微信 for Mac 4.x](https://mac.weixin.qq.com/) | 已安装并登录（验证于 4.1.13） |
| [WeChat-MCP](../WeChat-MCP) | 同级目录 `../WeChat-MCP` 且已 `uv sync`，或 `pip install wechat-mcp-server`，或设置 `WECHAT_MCP_DIR` |
| [cliclick](https://github.com/BlueM/cliclick) | `brew install cliclick`（滚动截屏时需要） |
| 辅助功能 + 屏幕录制权限 | 终端应用与 claude CLI 均需授权 |

## Installation

```bash
git clone https://github.com/Francismiko/wechat-automation.git ~/.agents/skills/wechat-automation
ln -s ../../.agents/skills/wechat-automation ~/.claude/skills/wechat-automation
# WeChat-MCP
git clone https://github.com/BiboyQG/WeChat-MCP.git ~/.agents/skills/WeChat-MCP && (cd ~/.agents/skills/WeChat-MCP && uv sync)
```

## Usage

```
> 给张三发一条微信说"明天下午开会"
> 看看"项目讨论群"最近在聊什么
> 哪些群有新消息
```

### Programmatic Usage

```bash
source ~/.agents/skills/wechat-automation/scripts/wechat-utils.sh

wechat_check                                  # 版本 / 界面兼容性
wechat_list_chats 20                          # 会话列表
wechat_fetch "工作群" 50                       # 最近 50 条消息（文本）
wechat_send_to "张三" "你好"                    # 发送并校验
wechat_view_chat "工作群" 0 /tmp/chat.png       # 需要看图时截屏
wechat_cli fetch "工作群" -n 50                 # 原始 JSON
```

## How It Works

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

- 仅 macOS，需要图形界面
- 微信 3.x 不支持；新版本微信发布后先运行 `wechat_check`
- 群聊中的成员名通过 OCR 识别，偶有个别字符误差

## License

[MIT](LICENSE)

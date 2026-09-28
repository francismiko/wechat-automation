---
name: wechat-automation
description: 微信 macOS 桌面客户端自动化操控（微信 4.x）。通过 WeChat-MCP 的 wechat-cli（辅助功能 API）读消息、发消息、列会话、搜索会话，配合截屏/滚动做视觉确认。当用户提到微信、WeChat、发消息给某人、给群里发消息、看看群里在聊啥、微信自动化、定时发微信等需求时触发此 skill。操作完自动切回之前的应用，不打断用户工作。
---

# WeChat macOS Automation

通过 WeChat-MCP 的命令行工具 `wechat-cli` 控制微信 4.x 桌面客户端。所有会话/消息操作都经由辅助功能 API 完成并逐步校验：先确认打开的是正确会话，再把文字写入输入框并核对，发送后再核对最新一条气泡。**不会**盲目点击坐标或模拟键盘粘贴。

## 前提条件

1. **微信 macOS 版 4.x** 已安装并登录（验证于 4.1.13；3.x 界面不同，不支持）
2. **WeChat-MCP** 已安装：默认在本 skill 的同级目录 `../WeChat-MCP`（已 `uv sync`），或 `pip install wechat-mcp-server` 后 `wechat-cli` 在 PATH 中，或 `export WECHAT_MCP_DIR=/path/to/WeChat-MCP`
3. **辅助功能** 和 **屏幕录制** 权限已授予终端应用和 claude CLI（系统设置 → 隐私与安全性）
4. **cliclick** 已安装（`brew install cliclick`，仅滚动截屏时需要）

如果用户遇到权限错误（"不允许辅助访问"），引导他们到系统设置添加对应程序：终端应用（如 Terminal、Warp、iTerm2）和 `/opt/homebrew/Caskroom/claude-code/*/claude`。

## 工具库

```bash
source ~/.agents/skills/wechat-automation/scripts/wechat-utils.sh
```

## 可用操作

### 会话 / 消息（经由 wechat-cli，返回非 0 即失败）

| 函数 | 参数 | 说明 |
|------|------|------|
| `wechat_check` | — | 微信版本 / 界面兼容性报告。**微信升级后先跑这个** |
| `wechat_list_chats [max] [--json]` | 数量 | 侧边栏会话列表：时间、名称、最后一条消息、是否免打扰 |
| `wechat_fetch "名称" [n] [--json]` | 会话名、条数 | 读取最近 n 条消息：`[发送者] 内容`，群聊会带成员名，`---` 行是时间/系统提示 |
| `wechat_open_chat "名称"` | 会话名 | 进入会话（会话列表优先，其次搜索精确匹配）；打开的不是目标会话时失败 |
| `wechat_send_message "名称" "消息"` | 会话名、消息 | 确认会话后发送并校验 |
| `wechat_send_to "名称" "消息"` | 会话名、消息 | 同上，附带人类可读的成功/失败提示 |
| `wechat_current_chat` | — | 当前打开的会话名 |

`wechat-cli` 还可以直接调用：`wechat_cli --text fetch "群名" -n 50`、`wechat_cli moment "文字" --draft`、`wechat_cli add-contact wxid_xxx --message "你好"`。去掉 `--text` 得到 JSON。

### 截屏 / 滚动（仅用于视觉确认，例如看图片、表情、文件预览）

| 函数 | 参数 | 说明 |
|------|------|------|
| `wechat_activate` | — | 激活微信窗口并缓存窗口坐标 |
| `wechat_screenshot [path] [full]` | 输出路径 | 截取微信主窗口（传 `full` 截全屏） |
| `wechat_scroll_chat dir count` | up/down, 次数 | 鼠标移到聊天区域后滚动（只移动不点击） |
| `wechat_view_chat "名称" [scroll] [path] [bg]` | 会话、滚动、路径、后台 | 打开会话 → 滚动 → 截屏 |
| `wechat_read_chat [scroll] [path] [bg]` | 滚动、路径、后台 | 截屏当前会话 |
| `wechat_key keycode` / `wechat_move x y` / `wechat_scroll dir count` | 底层按键 / 鼠标 / 滚动 | 一般不需要直接用 |

## 使用模式

### 发消息

```bash
source ~/.agents/skills/wechat-automation/scripts/wechat-utils.sh
wechat_send_to "张三" "明天下午开会"
```

### 看看群里在聊什么（优先用文本，不用截屏）

```bash
source ~/.agents/skills/wechat-automation/scripts/wechat-utils.sh
wechat_fetch "项目讨论群" 50
```

### 哪些会话有新消息

```bash
wechat_list_chats 20
```

### 需要看图片 / 表情时再截屏

```bash
wechat_view_chat "群名" 0 /tmp/chat.png
# 然后 Read /tmp/chat.png
```

## 必须遵守

- **只用上面的函数发消息**。不要自己用 `keystroke` / `cliclick` 往微信里打字：一旦焦点不在预期的输入框，文字就会发给错误的联系人（发生过）
- 会话名必须**完全一致**（大小写不敏感，群名不含人数后缀）。名称不精确时 `wechat_open_chat` 会失败并列出候选，把候选给用户确认后再发
- 函数返回非 0 就停下来告诉用户，不要重试其它「聪明」办法
- 「文件传输助手 / File Transfer」搜索不到，但会话列表里能找到（工具会自动滚动查找）
- 微信升级后如果工具报错，先 `wechat_check`：会显示版本是否已验证、缺了哪些界面元素

## 故障排查

| 症状 | 原因 | 解决 |
|------|------|------|
| `找不到 wechat-cli` | WeChat-MCP 未安装 / 路径不对 | 在 WeChat-MCP 目录 `uv sync`，或 `export WECHAT_MCP_DIR=...` |
| "不允许辅助访问" / 读不到消息 | 缺少辅助功能或屏幕录制权限 | 系统设置 → 隐私与安全性，添加终端和 claude CLI |
| 打开了别的会话 | 会话名不精确 | 用 `wechat_list_chats` 或候选列表确认准确名称 |
| `warnings` 提示版本未验证 | 微信升级了 | `wechat_check`；确认可用后在 WeChat-MCP 的 `compat.py` 加入版本号 |
| 发送方 UNKNOWN / 群成员名为空 | 未授予屏幕录制权限或窗口被遮挡 | 授权屏幕录制；必要时把微信窗口放到前面 |

按键码见 `references/key-codes_zh.md`；English version: `SKILL.md`。

<h1 align="center">WeChat Automation Skill</h1>

<p align="center">
  <strong>macOS 微信桌面客户端自动化操控 skill，适用于 Claude Code</strong>
</p>

<p align="center">
  <a href="https://github.com/Francismiko/wechat-automation/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License"></a>
  <a href="https://skills.sh"><img src="https://img.shields.io/badge/platform-Claude_Code-blueviolet" alt="Platform"></a>
  <a href="https://github.com/Francismiko/wechat-automation/stargazers"><img src="https://img.shields.io/github/stars/Francismiko/wechat-automation?style=flat" alt="Stars"></a>
</p>

---

通过 AppleScript + cliclick 实现对 macOS 微信桌面客户端的程序化控制。支持发送消息、搜索会话、浏览聊天记录等操作，并内置后台模式——操作完自动切回用户之前的前台应用，不打断工作流。

## Features

- **发送消息** — 向任意联系人或群聊发送文本消息（完整支持中文 / emoji）
- **搜索会话** — 按名称搜索并进入指定联系人或群聊
- **浏览记录** — 滚动查看聊天记录，配合截屏分析聊天内容
- **后台模式** — 操作完自动切回之前的前台应用，对用户无感
- **截屏验证** — 每步操作可截屏确认，应对 UI 自动化的不确定性
- **模块化设计** — 基础操作原子化，可自由组合应对复杂场景

## Prerequisites

| 依赖 | 说明 |
|------|------|
| macOS | 仅支持 macOS 系统 |
| [微信 for Mac](https://mac.weixin.qq.com/) | 需已安装并登录 |
| [cliclick](https://github.com/BlueM/cliclick) | 鼠标模拟工具，`brew install cliclick` |
| 辅助功能权限 | 终端应用 + claude CLI 需在「系统设置 → 隐私与安全性 → 辅助功能」中授权 |

## Installation

```bash
npx skills add Francismiko/wechat-automation --agent claude-code -y
```

或手动安装：

```bash
git clone https://github.com/Francismiko/wechat-automation.git ~/.agents/skills/wechat-automation
ln -s ../../.agents/skills/wechat-automation ~/.claude/skills/wechat-automation
```

安装后确保 cliclick 可用：

```bash
brew install cliclick
```

## Usage

Skill 安装后会被 Claude Code 自动识别。直接用自然语言即可触发：

```
> 给张三发一条微信说"明天下午开会"
> 看看"项目讨论群"最近在聊什么
> 给妈妈发微信问她周末有空吗
```

### Programmatic Usage

也可以直接在 shell 中 source 工具库使用：

```bash
source ~/.agents/skills/wechat-automation/scripts/wechat-utils.sh

# 发送消息（后台模式，操作完自动切回）
wechat_send_to "张三" "你好" true

# 查看某个群的聊天记录
wechat_view_chat "工作群" 80 /tmp/chat.png true

# 自由组合操作
wechat_activate
wechat_open_chat "李四"
wechat_scroll_chat up 50
wechat_screenshot /tmp/history.png
wechat_send_message "收到，我看看"
```

## API Reference

### 基础操作

| 函数 | 参数 | 说明 |
|------|------|------|
| `wechat_activate` | — | 激活微信窗口并置顶 |
| `wechat_screenshot [path]` | 输出路径 | 截取当前屏幕 |
| `wechat_window_info` | — | 返回 `x,y,width,height` |
| `wechat_click x y` | 坐标 | 点击指定位置 |
| `wechat_move_mouse x y` | 坐标 | 移动鼠标 |
| `wechat_paste_text "text"` | 文本 | 通过剪贴板粘贴（支持中文 / emoji） |
| `wechat_key keycode` | [macOS key code](references/key-codes.md) | 模拟按键 |
| `wechat_shortcut "key"` | 字符 | 模拟 Cmd+key |
| `wechat_scroll dir count` | up/down, 次数 | 在鼠标位置滚动 |

### 组合操作

| 函数 | 参数 | 说明 |
|------|------|------|
| `wechat_focus_chat` | — | 聚焦聊天区域 |
| `wechat_focus_input` | — | 聚焦消息输入框 |
| `wechat_scroll_chat dir count` | up/down, 次数 | 在聊天区域滚动 |
| `wechat_open_chat "name"` | 联系人 / 群名 | 搜索并进入会话 |
| `wechat_send_message "msg"` | 消息文本 | 在当前会话发送消息 |

### 高级操作

| 函数 | 参数 | 说明 |
|------|------|------|
| `wechat_send_to "name" "msg" [bg]` | 联系人、消息、后台模式 | 完整发送流程 |
| `wechat_read_chat [scroll] [path] [bg]` | 滚动次数、输出路径、后台 | 截屏当前会话 |
| `wechat_view_chat "name" [scroll] [path] [bg]` | 联系人、滚动、路径、后台 | 打开会话并截屏 |

> 所有高级操作默认开启后台模式（`bg=true`），操作完自动切回之前的前台应用。

## How It Works

```
┌─────────────────────────────────────────────┐
│  Claude Code                                │
│  ┌───────────────────────────────────────┐  │
│  │  wechat-automation skill              │  │
│  │  ┌─────────┐  ┌──────────┐           │  │
│  │  │ source  │→ │ activate │→ ...      │  │
│  │  │ utils   │  │ WeChat   │           │  │
│  │  └─────────┘  └──────────┘           │  │
│  └───────────────────────────────────────┘  │
│       │              │              │       │
│  AppleScript    cliclick      screencapture │
│  (System Events) (mouse)      (verify)      │
│       │              │              │       │
│       └──────────────┼──────────────┘       │
│                      ▼                      │
│              WeChat for Mac                 │
└─────────────────────────────────────────────┘
```

1. **激活** — 通过 AppleScript 将微信置顶
2. **定位** — 读取窗口坐标，计算 UI 元素位置
3. **操作** — cliclick 模拟鼠标，AppleScript 模拟键盘
4. **验证** — screencapture 截屏，Claude 视觉分析确认结果
5. **恢复** — 后台模式下自动切回原前台应用

## Limitations

- **仅 macOS** — 依赖 AppleScript 和 macOS 辅助功能 API
- **需要屏幕** — UI 自动化需要图形界面，无法在纯 headless 环境运行
- **微信 UI 变更** — 微信更新可能导致 UI 布局变化，需要调整坐标计算
- **单窗口** — 当前仅支持微信主窗口操作
- **短暂前台** — 后台模式下微信仍需短暂成为前台应用（约 3-5 秒）

## Contributing

欢迎 PR 和 Issue！

1. Fork 本仓库
2. 创建分支 (`git checkout -b feature/xxx`)
3. 提交更改 (`git commit -m 'Add xxx'`)
4. 推送到远程 (`git push origin feature/xxx`)
5. 创建 Pull Request

## License

[MIT](LICENSE)

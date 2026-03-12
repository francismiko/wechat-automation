---
name: wechat-automation
description: 微信 macOS 桌面客户端自动化操控。通过 AppleScript + cliclick 实现发消息、读聊天记录、搜索会话、滚动浏览等操作。当用户提到微信、WeChat、发消息给某人、给群里发消息、看看群里在聊啥、微信自动化、定时发微信等需求时触发此 skill。支持后台模式——操作完自动切回之前的应用，不打断用户工作。
---

# WeChat macOS Automation

通过 macOS 辅助功能 API 控制微信桌面客户端，实现消息收发和聊天记录浏览。

## 前提条件

1. **微信 macOS 版**已安装并登录
2. **辅助功能权限**已授予终端应用和 claude CLI（系统设置 → 隐私与安全性 → 辅助功能）
3. **cliclick** 已安装（`brew install cliclick`）

如果用户遇到权限错误（"不允许辅助访问"），引导他们到系统设置添加对应程序。需要授权的程序：终端应用（如 Warp、iTerm2）和 `/opt/homebrew/Caskroom/claude-code/*/claude`。

## 工具库

所有操作封装在 `scripts/wechat-utils.sh` 中。使用前先 source：

```bash
source ~/.agents/skills/wechat-automation/scripts/wechat-utils.sh
```

## 踩坑指南（必读）

以下是实际操控中验证过的经验，违反这些规则会导致操作失败：

### 绝对不要做

| 操作 | 后果 | 正确做法 |
|------|------|---------|
| 用 `Cmd+F` 搜索会话 | 打开全局搜索（含网络/公众号搜索），不是会话搜索 | 用 `wechat_open_chat` 点击侧边栏搜索框 |
| 用 `Cmd+N` 找已有会话 | 创建新群聊 | 用 `wechat_open_chat` |
| 用 `keystroke` 输入中文/emoji | 输入为空或乱码 | 用 `wechat_paste` 通过剪贴板粘贴 |
| 不移动鼠标直接滚动 | 滚到别的窗口 | 先 `wechat_move` 到聊天区域再 `wechat_scroll` |
| 用 Page Up/Down 翻页 | 焦点跳到别的应用 | 用 `wechat_scroll_chat` |
| 搜索后不清理输入框 | 残留文字被当消息发出 | `wechat_open_chat` 已内置清理；`wechat_send_message` 也会先清空 |

### 必须做

- **截屏验证**：UI 自动化天生不稳定。关键操作后调用 `wechat_screenshot` + Read 工具确认状态
- **激活后缓存窗口信息**：`wechat_activate` 会自动缓存窗口坐标，后续操作复用，避免重复查询
- **滚动前定位鼠标**：`wechat_scroll_chat` 已内置移动鼠标逻辑，直接用它而不是裸调 `wechat_scroll`

## 可用操作

### 基础操作

| 函数 | 参数 | 说明 |
|------|------|------|
| `wechat_activate` | — | 激活微信窗口、置顶、缓存窗口坐标 |
| `wechat_screenshot [path]` | 输出路径 | 截取当前屏幕 |
| `wechat_paste "文本"` | 文本内容 | 通过剪贴板粘贴（唯一正确的输入方式） |
| `wechat_key keycode` | [key code](references/key-codes.md) | 模拟按键（36=回车, 53=ESC, 51=删除） |
| `wechat_cmd "key"` | 字符 | 模拟 Cmd+key |
| `wechat_click x y` | 坐标 | 点击 |
| `wechat_move x y` | 坐标 | 移动鼠标（滚动前必须调用） |
| `wechat_scroll dir count` | up/down, 次数 | 在鼠标当前位置滚动 |

### 组合操作

| 函数 | 参数 | 说明 |
|------|------|------|
| `wechat_open_chat "名称"` | 联系人/群名 | 点击侧边栏搜索 → 粘贴 → 回车 → ESC 关闭搜索面板 |
| `wechat_scroll_chat dir count` | up/down, 次数 | 移动鼠标到聊天区域 → 滚动 |
| `wechat_send_message "消息"` | 消息文本 | 点击输入框 → 清空 → 粘贴 → 回车，自动追加签名 |

### 高级操作（支持后台模式）

| 函数 | 参数 | 说明 |
|------|------|------|
| `wechat_send_to "名称" "消息" [bg]` | 联系人、消息、后台(默认true) | 完整流程：激活 → 搜索 → 发送 → 切回 |
| `wechat_read_chat [scroll] [path] [bg]` | 滚动次数、路径、后台 | 截屏当前会话 |
| `wechat_view_chat "名称" [scroll] [path] [bg]` | 联系人、滚动、路径、后台 | 搜索会话 → 截屏 |

后台模式（默认开启）：操作前保存当前前台应用和剪贴板，操作后恢复。微信只需短暂前台 3-5 秒。

## 使用模式

### 发消息

```bash
source ~/.agents/skills/wechat-automation/scripts/wechat-utils.sh
wechat_send_to "张三" "你好" true
```

### 查看聊天记录

截屏 + Read 工具读取分析：

```bash
source ~/.agents/skills/wechat-automation/scripts/wechat-utils.sh
wechat_view_chat "群名" 80 /tmp/chat.png true
# 然后 Read /tmp/chat.png 查看内容
```

### 连续浏览历史

如果已在目标会话中，不要再调 `wechat_open_chat`（会重新搜索），直接滚动：

```bash
source ~/.agents/skills/wechat-automation/scripts/wechat-utils.sh
wechat_activate
# 假设已在目标会话中
for i in 1 2 3 4 5; do
    wechat_scroll_chat up 100
    wechat_screenshot "/tmp/chat-${i}.png"
done
# 批量 Read 截图分析
```

### 截屏驱动的操控模式

对于不确定的场景，采用「截屏 → 分析 → 操作 → 截屏验证」循环：

```bash
source ~/.agents/skills/wechat-automation/scripts/wechat-utils.sh
wechat_activate
wechat_screenshot /tmp/step1.png   # 看当前状态，Read 分析
# 根据截图决定下一步...
wechat_open_chat "某人"
wechat_screenshot /tmp/step2.png   # 确认进入正确会话
wechat_send_message "你好"
wechat_screenshot /tmp/step3.png   # 确认发送成功
```

## 故障排查

| 症状 | 原因 | 解决 |
|------|------|------|
| "不允许辅助访问" | 缺少辅助功能权限 | 系统设置 → 辅助功能，添加终端和 claude CLI |
| 搜索打开了网络结果 | 误用了 Cmd+F | 用 `wechat_open_chat`（点击侧边栏搜索框） |
| 滚动滚到了别的窗口 | 鼠标不在微信上 | 用 `wechat_scroll_chat` 而非裸调 `wechat_scroll` |
| 发出了群名当消息 | 搜索残留未清理 | `wechat_send_message` 已内置清空逻辑 |
| 点到了公众号/其他页面 | 窗口坐标偏移 | 先 `wechat_activate` 刷新坐标缓存 |

详细的按键码和 UI 布局信息见 `references/key-codes.md`。

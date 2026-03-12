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

如果用户遇到权限错误，引导他们到系统设置添加相应权限。

## 工具库

所有操作封装在 `scripts/wechat-utils.sh` 中。使用前先 source：

```bash
source ~/.agents/skills/wechat-automation/scripts/wechat-utils.sh
```

## 可用操作

### 基础操作

| 函数 | 参数 | 说明 |
|------|------|------|
| `wechat_activate` | 无 | 激活微信窗口并置顶 |
| `wechat_screenshot [path]` | 输出路径（默认 /tmp/wechat-screenshot.png） | 截取当前屏幕 |
| `wechat_window_info` | 无 | 返回 `x,y,width,height` |
| `wechat_click x y` | 坐标 | 点击指定位置 |
| `wechat_move_mouse x y` | 坐标 | 移动鼠标 |
| `wechat_paste_text "文本"` | 文本内容 | 通过剪贴板粘贴（支持中文/emoji） |
| `wechat_key keycode` | macOS key code | 模拟按键 |
| `wechat_shortcut "key"` | 按键字符 | 模拟 Cmd+key |
| `wechat_scroll direction count` | up/down, 次数 | 在鼠标位置滚动 |

### 组合操作

| 函数 | 参数 | 说明 |
|------|------|------|
| `wechat_focus_chat` | 无 | 点击聊天区域中心 |
| `wechat_focus_input` | 无 | 点击消息输入框 |
| `wechat_scroll_chat direction count` | up/down, 次数 | 在聊天区域滚动 |
| `wechat_open_chat "名称"` | 联系人/群名 | 搜索并进入指定会话 |
| `wechat_send_message "消息"` | 消息文本 | 在当前会话发送消息 |

### 高级操作（支持后台模式）

| 函数 | 参数 | 说明 |
|------|------|------|
| `wechat_send_to "名称" "消息" [background]` | 联系人、消息、是否后台(默认true) | 完整发送流程 |
| `wechat_read_chat [scroll_up] [output] [background]` | 向上滚动次数、输出路径、是否后台 | 截屏当前会话 |
| `wechat_view_chat "名称" [scroll_up] [output] [background]` | 联系人、滚动次数、输出路径、是否后台 | 打开会话并截屏 |

## 使用模式

### 发送消息

```bash
source ~/.agents/skills/wechat-automation/scripts/wechat-utils.sh
wechat_send_to "张三" "你好" true
```

后台模式（第三个参数 `true`）会在操作完成后自动切回用户之前的前台应用，减少干扰。

### 查看聊天记录

使用截屏 + Read 工具查看聊天内容：

```bash
source ~/.agents/skills/wechat-automation/scripts/wechat-utils.sh
wechat_view_chat "群名" 80 /tmp/chat.png true
```

然后用 Read 工具读取截图分析聊天内容。`scroll_up` 参数控制向上滚动的幅度（每单位约半行）。

### 连续浏览历史记录

先进入会话，然后多次滚动截屏：

```bash
source ~/.agents/skills/wechat-automation/scripts/wechat-utils.sh
wechat_activate
wechat_open_chat "群名"
for i in 1 2 3; do
    wechat_scroll_chat up 80
    wechat_screenshot "/tmp/chat-${i}.png"
done
```

### 自由组合操作

基础操作可以自由组合来应对复杂场景。每一步之后建议截屏确认状态。例如：

```bash
source ~/.agents/skills/wechat-automation/scripts/wechat-utils.sh
wechat_activate
wechat_screenshot /tmp/step1.png   # 看当前状态
# 通过 Read 工具查看截图，决定下一步操作
wechat_open_chat "某人"
wechat_screenshot /tmp/step2.png   # 确认进入了正确的会话
wechat_send_message "你好"
wechat_screenshot /tmp/step3.png   # 确认消息已发送
```

## 关键注意事项

- **中文/emoji 必须通过剪贴板**：`keystroke` 只支持 ASCII，所有中文和 emoji 内容使用 `wechat_paste_text` 粘贴
- **不要用 Cmd+F 搜索会话**：Cmd+F 打开的是全局搜索（包含网络搜索），用 `wechat_open_chat` 点击左侧搜索栏
- **不要用 Cmd+N**：Cmd+N 是新建群聊，不是搜索已有会话
- **搜索后清理输入框**：`wechat_open_chat` 已内置 Cmd+A + Delete 清理逻辑
- **截屏验证**：UI 自动化天然不稳定，重要操作后截屏确认
- **后台模式**：高级操作默认开启后台模式，操作完切回用户之前的应用
- **延迟调整**：如果网络慢或电脑卡，搜索结果可能加载不及时，可以手动在操作间增加 sleep

## 故障排查

如果操作失败，按以下顺序检查：
1. 微信是否已登录且窗口存在
2. 辅助功能权限是否已授予终端和 claude CLI
3. cliclick 是否已安装
4. 截屏当前状态分析 UI 是否符合预期

详细的按键码和 UI 布局信息见 `references/key-codes.md`。

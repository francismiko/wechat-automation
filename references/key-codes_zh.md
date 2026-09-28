# macOS Key Codes 速查

| Key Code | 按键 | 用途 |
|----------|------|------|
| 36 | Return | 发送消息/确认选择 |
| 48 | Tab | 切换焦点 |
| 49 | Space | 空格 |
| 51 | Delete | 删除（退格） |
| 53 | Escape | 取消/关闭搜索弹层 |
| 116 | Page Up | 向上翻页 |
| 121 | Page Down | 向下翻页 |
| 123 | Left Arrow | 左箭头 |
| 124 | Right Arrow | 右箭头 |
| 125 | Down Arrow | 下箭头 |
| 126 | Up Arrow | 上箭头 |

# 微信 macOS 快捷键

| 快捷键 | 功能 |
|--------|------|
| Cmd+N | 发起会话（新建群聊，不是搜索！） |
| Cmd+F | 全局搜索（包含网络搜索，不推荐用于查找会话） |
| ⌥⌘E | 发送表情面板 |
| ⌃⌘A | 截屏 |

# 微信 4.x UI 布局（相对于主窗口）

```
+----+----------------------+-----------------------------------+
| 60 |  搜索框 (AXTextArea   |  会话标题 current_chat_name_label  |
| px |  title "Search")     |-----------------------------------|
| 标 |----------------------|                                   |
| 签 |  会话列表             |  消息列表 chat_message_list        |
| 栏 |  session_list        |  （每条气泡 chat_bubble_item_view） |
|    |  行 id：             |                                   |
|    |  session_item_<名称>  |-----------------------------------|
|    |  默认宽 240px（可拖动）|  输入框 chat_input_field           |
|    |                      |  工具栏 … [Send]                   |
+----+----------------------+-----------------------------------+
```

- 主窗口标题随界面语言变化（"WeChat" / "微信"），按 `AXStandardWindow` 定位
- 搜索弹层是独立的无标题 `AXDialog` 窗口，列表 id `search_list`，结果行 id `search_item_<名称>`，分区标题 Contacts / Group Chats / Official Accounts / Internet search results …
- 「文件传输助手 / File Transfer」搜索不到，只能在会话列表里找
- 会话列表和消息列表都是虚拟化的：辅助功能只暴露当前渲染出来的行，找不到就要滚动
- 滚轮事件按**鼠标实际位置**投递，滚动前必须先移动鼠标（脚本已内置）
- 朋友圈在主窗口内渲染（发现 → 朋友圈，列表 id `sns_list`），长按「发表」进入纯文字编辑
- `keystroke` 不支持中文/emoji；本 skill 不再用键盘输入文字，全部由 `wechat-cli` 通过 AX 写入

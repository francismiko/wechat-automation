# macOS key codes

| Key code | Key | Use |
|----------|-----|-----|
| 36 | Return | Send message / confirm selection |
| 48 | Tab | Move focus |
| 49 | Space | Space |
| 51 | Delete | Backspace |
| 53 | Escape | Cancel / close the search popover |
| 116 | Page Up | Page up |
| 121 | Page Down | Page down |
| 123 | Left Arrow | Left |
| 124 | Right Arrow | Right |
| 125 | Down Arrow | Down |
| 126 | Up Arrow | Up |

# WeChat for Mac shortcuts

| Shortcut | Function |
|----------|----------|
| Cmd+N | New chat (creates a group, it is not search!) |
| Cmd+F | Global search (includes web search; not suitable for finding chats) |
| ⌥⌘E | Sticker panel |
| ⌃⌘A | Screenshot |

# WeChat 4.x UI layout (relative to the main window)

```
+----+----------------------+-----------------------------------+
| 60 |  Search field        |  Chat title current_chat_name_label|
| px |  (AXTextArea         |-----------------------------------|
| tab|   title "Search")    |                                   |
| bar|----------------------|  Message list chat_message_list   |
|    |  Session list        |  (each bubble chat_bubble_item_view)|
|    |  session_list        |                                   |
|    |  row id:             |-----------------------------------|
|    |  session_item_<name> |  Input chat_input_field           |
|    |  240px by default    |  toolbar … [Send]                 |
+----+----------------------+-----------------------------------+
```

- The main window title follows the UI language ("WeChat" / "微信"); locate it by `AXStandardWindow` instead
- The search popover is a separate untitled `AXDialog` window: list id `search_list`, result rows `search_item_<name>`, section headers Contacts / Group Chats / Official Accounts / Internet search results ...
- "File Transfer" (文件传输助手) cannot be found through search; it is only in the session list
- Both the session list and the message list are virtualised: Accessibility exposes only the rendered rows, so scrolling is needed to find others
- Scroll-wheel events are delivered to the widget under the **actual pointer**; move the pointer first (built into the scripts)
- Moments renders inside the main window (Discover → Moments, list id `sns_list`); a long press on "Post" opens the text-only composer
- `keystroke` cannot type Chinese / emoji; this skill no longer types at all, `wechat-cli` writes text through Accessibility

中文版见 `key-codes_zh.md`。

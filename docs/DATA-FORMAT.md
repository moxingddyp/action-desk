# Action Desk Data Format

[English](DATA-FORMAT.md) · [简体中文](DATA-FORMAT.zh-CN.md)

Action Desk reads three locations within the configured data directory:

- `PROJECT.md`: work items and calendar entries.
- `PROJECTS.md`: project names.
- `tools/desktop-action-desk/thread-links.json`: project-to-Codex-thread mappings.

Files use UTF-8. The headings `## 事项安排` and `## 日常安排`, and the Chinese category names, are part of the current parser format. They must not be translated merely because the documentation language changes.

The work table has nine columns, in order: item ID, item/project, categories, current status, next action, owner, deliverable/dependency, actual deadline/schedule, and source.

Keep one row and one stable ID per item. IDs use either 16 lowercase hexadecimal characters or `NNNN-A` followed by at least two digits. Escape literal pipes inside cells as `\|`.

Choose exactly one of `正在做` (In Progress), `当前可做` (Ready), and `条件做` (Conditional). `优先做` (Priority) is an optional additional flag. Separate categories with `、`.

The calendar table has eight columns: date, time, activity, location, status, project, source, and notes. Dates must be valid `yyyy-MM-dd` values. Item deadlines do not automatically become calendar events.

Set `sourceDirectory` to an absolute path and `chiefThread` to your own main Codex thread UUID. Map four-digit project numbers to existing threads. Unmapped items fall back to the main thread; demonstration UUIDs cannot be opened.

The display cache is not a task database. Editing it does not update the source plan, and refreshes regenerate it. The current calendar timezone is fixed to `Asia/Shanghai`.

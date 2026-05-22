# AI Call Audit Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a bottom AI audit panel that streams a structured read-only explanation of the current call hierarchy diagram.

**Architecture:** Keep call graph rendering in `lua/dora/call_hierarchy.lua` and put prompt assembly, provider selection, stream parsing, report panel UI, and evidence navigation in a new `lua/dora/call_audit.lua` module. The call hierarchy module passes the current root, options, diagram text, and node line map into the audit module when the user presses `E`.

**Tech Stack:** Neovim Lua, `vim.fn.jobstart`, scratch buffers, headless Lua tests, Claude Code stream JSON, Codex exec JSONL.

---

### Task 1: Pure Audit Context And Stream Logic

**Files:**
- Create: `lua/dora/call_audit.lua`
- Create: `tests/call_audit_spec.lua`

- [ ] **Step 1: Write failing tests**

Create `tests/call_audit_spec.lua` with tests for:

```lua
local audit = require("dora.call_audit")

local root = {
  item = {
    name = "submit(SubmitFormCommand command) : SubmitFormResult",
    detail = "com.demo.RuntimeFormSubmissionService",
    uri = vim.uri_from_fname("/tmp/RuntimeFormSubmissionService.java"),
    selectionRange = { start = { line = 95, character = 2 }, ["end"] = { line = 95, character = 8 } },
  },
  children = {},
}

local context = audit.build_context(root, {
  title = "Business ASCII Diagram",
  diagram_lines = { "Business ASCII Diagram", "┌──┐", "│ [服务] RuntimeFormSubmissionService.submit │" },
  graph = require("dora.call_hierarchy"),
})

assert(context.prompt:match("只读代码审计"))
assert(context.prompt:match("Business ASCII Diagram"))
assert(context.prompt:match("RuntimeFormSubmissionService%.submit"))
assert(#context.evidence >= 1)
assert(context.evidence[1].line == 96)

local claude = audit.parse_claude_stream_json('{"type":"assistant","message":{"content":[{"type":"text","text":"hello"}]}}')
assert(claude.text == "hello")

local codex = audit.parse_codex_event_json('{"type":"agent_message_delta","delta":"world"}')
assert(codex.text == "world")

local sections = audit.initial_report_lines({ provider = "claude" })
assert(table.concat(sections, "\n"):match("链路结论"))
assert(table.concat(sections, "\n"):match("异常与风险"))
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
nvim --headless -u NONE --cmd 'set rtp+=/Users/raymond/.config/nvim' -l /Users/raymond/.config/nvim/tests/call_audit_spec.lua
```

Expected: failure because `dora.call_audit` does not exist.

- [ ] **Step 3: Implement minimal pure module**

Create `lua/dora/call_audit.lua` with:

```lua
local M = {}

function M.build_context(root, opts)
  -- Walk root nodes, collect labels, file locations, snippets, diagram text, and evidence entries.
end

function M.initial_report_lines(opts)
  -- Return the stable B-layout report skeleton.
end

function M.parse_claude_stream_json(line)
  -- Return { text = "..." } for assistant content text chunks.
end

function M.parse_codex_event_json(line)
  -- Return { text = "..." } for Codex message delta/final text events.
end

return M
```

- [ ] **Step 4: Run test to verify it passes**

Run the same `call_audit_spec.lua` command. Expected: all tests pass.

### Task 2: Provider Command Selection

**Files:**
- Modify: `lua/dora/call_audit.lua`
- Modify: `tests/call_audit_spec.lua`

- [ ] **Step 1: Write failing tests**

Add tests:

```lua
local claude_cmd = audit.provider_command("claude", "/repo", "PROMPT")
assert(claude_cmd[1] == "claude")
assert(vim.tbl_contains(claude_cmd, "--output-format"))
assert(vim.tbl_contains(claude_cmd, "stream-json"))

local codex_cmd = audit.provider_command("codex", "/repo", "PROMPT")
assert(codex_cmd[1] == "codex")
assert(vim.tbl_contains(codex_cmd, "exec"))
assert(vim.tbl_contains(codex_cmd, "--json"))

local ok, err = audit.provider_command("missing", "/repo", "PROMPT")
assert(ok == nil)
assert(err:match("Unsupported provider"))
```

- [ ] **Step 2: Run test to verify it fails**

Run `call_audit_spec.lua`. Expected: failure because `provider_command` is undefined.

- [ ] **Step 3: Implement provider command builder**

Add `M.provider_command(provider, cwd, prompt)` returning read-only non-interactive command arrays for `claude` and `codex`.

- [ ] **Step 4: Run test to verify it passes**

Run `call_audit_spec.lua`. Expected: all tests pass.

### Task 3: Bottom Audit Panel UI

**Files:**
- Modify: `lua/dora/call_audit.lua`
- Modify: `tests/call_audit_spec.lua`

- [ ] **Step 1: Write failing tests**

Add tests for `audit.render_panel_lines(context, state)`:

```lua
local lines, maps = audit.render_panel_lines(context, { status = "streaming", provider = "claude", report = { "正文" } })
local text = table.concat(lines, "\n")
assert(text:match("审计目录"))
assert(text:match("AI 审计报告"))
assert(text:match("证据与操作"))
assert(text:match("正文"))
assert(#maps.evidence_lines >= 1)
```

- [ ] **Step 2: Run test to verify it fails**

Run `call_audit_spec.lua`. Expected: failure because `render_panel_lines` is undefined.

- [ ] **Step 3: Implement panel renderer**

Add a pure renderer that creates three textual columns:

- left TOC
- middle report
- right evidence and key help

Use rose-pine-friendly labels but keep the function pure so it is testable.

- [ ] **Step 4: Run test to verify it passes**

Run `call_audit_spec.lua`. Expected: all tests pass.

### Task 4: Streaming Job And Keymaps

**Files:**
- Modify: `lua/dora/call_audit.lua`
- Modify: `lua/dora/call_hierarchy.lua`

- [ ] **Step 1: Add audit entry points**

Implement:

```lua
function M.open(root, opts)
  -- Build context, open bottom panel, start provider job.
end

function M.stop()
  -- Stop current job and mark panel stopped.
end

function M.copy_report()
  -- Copy report markdown to clipboard.
end
```

- [ ] **Step 2: Wire graph keymaps**

In `open_text_buffer` and tree keymaps in `call_hierarchy.lua`, map:

- `E` to `require("dora.call_audit").open(M._last_root, audit_opts)`
- `S` to `require("dora.call_audit").stop()`
- `C` to `require("dora.call_audit").copy_report()`

Pass diagram lines from `M.to_ascii_diagram(root, opts)` when available.

- [ ] **Step 3: Manual smoke**

Run:

```bash
nvim --headless '+lua require("dora.call_audit"); require("dora.call_hierarchy"); print("audit loaded")' '+qa!'
```

Expected: `audit loaded`.

### Task 5: Visual Highlights And Docs

**Files:**
- Modify: `lua/dora/call_audit.lua`
- Modify: `README.md`

- [ ] **Step 1: Add audit highlights**

Use highlight groups:

- `DoraCallAuditTitle`
- `DoraCallAuditStreaming`
- `DoraCallAuditEvidence`
- `DoraCallAuditRisk`
- `DoraCallAuditMuted`
- `DoraCallAuditBorder`

- [ ] **Step 2: Document keymaps**

Update README call hierarchy section with:

- `E`: start/refresh AI audit
- `S`: stop AI audit
- `C`: copy report
- `Enter`: jump from evidence item
- `[` / `]`: previous/next evidence

- [ ] **Step 3: Final verification**

Run:

```bash
nvim --headless -u NONE --cmd 'set rtp+=/Users/raymond/.config/nvim' -l /Users/raymond/.config/nvim/tests/call_audit_spec.lua
nvim --headless -u NONE --cmd 'set rtp+=/Users/raymond/.config/nvim' -l /Users/raymond/.config/nvim/tests/call_hierarchy_spec.lua
nvim --headless '+qa!'
git diff --check
```

Expected: all commands exit 0.

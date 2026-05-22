vim.opt.runtimepath:append(vim.fn.getcwd())
package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

local audit = require("dora.call_audit")
local graph = require("dora.call_hierarchy")

local function assert_eq(actual, expected, label)
  if actual ~= expected then
    error(("%s\nexpected: %s\nactual:   %s"):format(label or "assert_eq failed", vim.inspect(expected), vim.inspect(actual)), 2)
  end
end

local function assert_match(value, pattern, label)
  if not tostring(value):match(pattern) then
    error(("%s\npattern: %s\nvalue:   %s"):format(label or "assert_match failed", pattern, tostring(value)), 2)
  end
end

local function assert_not_match(value, pattern, label)
  if tostring(value):match(pattern) then
    error(("%s\npattern: %s\nvalue:   %s"):format(label or "assert_not_match failed", pattern, tostring(value)), 2)
  end
end

local function assert_contains(list, value, label)
  if not vim.tbl_contains(list, value) then
    error(("%s\nmissing: %s\nlist: %s"):format(label or "assert_contains failed", value, vim.inspect(list)), 2)
  end
end

local function assert_not_contains(list, value, label)
  if vim.tbl_contains(list, value) then
    error(("%s\nunexpected: %s\nlist: %s"):format(label or "assert_not_contains failed", value, vim.inspect(list)), 2)
  end
end

local function run(name, fn)
  fn()
  print("ok - " .. name)
end

local function temp_java(lines, name)
  local path = vim.fn.tempname() .. "-" .. (name or "Audit.java")
  vim.fn.writefile(lines, path)
  return path
end

local function item(name, detail, path, line)
  return {
    name = name,
    detail = detail,
    uri = vim.uri_from_fname(path),
    selectionRange = {
      start = { line = line or 0, character = 2 },
      ["end"] = { line = line or 0, character = 12 },
    },
    range = {
      start = { line = line or 0, character = 0 },
      ["end"] = { line = line or 0, character = 20 },
    },
  }
end

run("builds read-only audit context with diagram, snippets, and evidence", function()
  local path = temp_java({
    "class RuntimeFormSubmissionService {",
    "  public SubmitFormResult submit(SubmitFormCommand command) {",
    "    requireMatchingTenant(command.tenantId());",
    "    return accepted(command.traceId());",
    "  }",
    "}",
  }, "RuntimeFormSubmissionService.java")
  local root = graph.new_node(item(
    "submit(SubmitFormCommand command) : SubmitFormResult",
    "com.demo.RuntimeFormSubmissionService",
    path,
    1
  ), 0)

  local context = audit.build_context(root, {
    title = "Business ASCII Diagram",
    diagram_lines = {
      "Business ASCII Diagram",
      "┌────────────────────────────────────┐",
      "│ [服务] RuntimeFormSubmissionService.submit │",
    },
    graph = graph,
  })

  assert_match(context.prompt, "只读代码审计", "prompt states read-only audit")
  assert_match(context.prompt, "Business ASCII Diagram", "prompt includes diagram title")
  assert_match(context.prompt, "RuntimeFormSubmissionService%.submit", "prompt includes node label")
  assert_match(context.prompt, "requireMatchingTenant", "prompt includes source snippet")
  assert_eq(#context.evidence >= 1, true, "context includes evidence")
  assert_eq(context.evidence[1].line, 2, "evidence line is 1-based")
end)

run("parses Claude and Codex stream text chunks", function()
  local claude = audit.parse_claude_stream_json(
    '{"type":"assistant","message":{"content":[{"type":"text","text":"hello"}]}}'
  )
  assert_eq(claude.text, "hello", "Claude assistant message text is parsed")

  local claude_delta = audit.parse_claude_stream_json(
    '{"type":"content_block_delta","delta":{"type":"text_delta","text":" world"}}'
  )
  assert_eq(claude_delta.text, " world", "Claude text delta is parsed")

  local wrapped_claude_delta = audit.parse_claude_stream_json(
    '{"type":"stream_event","event":{"type":"content_block_delta","delta":{"type":"text_delta","text":" wrapped"}}}'
  )
  assert_eq(wrapped_claude_delta.text, " wrapped", "Claude wrapped text delta is parsed")

  local wrapped_thinking = audit.parse_claude_stream_json(
    '{"type":"stream_event","event":{"type":"content_block_delta","delta":{"type":"thinking_delta","thinking":"hidden"}}}'
  )
  assert_eq(wrapped_thinking, nil, "Claude thinking deltas are not rendered into the report")

  local codex = audit.parse_codex_event_json('{"type":"agent_message_delta","delta":"codex"}')
  assert_eq(codex.text, "codex", "Codex delta is parsed")

  local codex_message = audit.parse_codex_event_json('{"type":"agent_message","message":" final"}')
  assert_eq(codex_message.text, " final", "Codex message is parsed")
end)

run("creates stable initial report skeleton", function()
  local lines = audit.initial_report_lines({ provider = "claude", status = "idle" })
  local text = table.concat(lines, "\n")

  assert_match(text, "链路结论", "skeleton includes chain summary")
  assert_match(text, "架构视角", "skeleton includes architecture section")
  assert_match(text, "异常与风险", "skeleton includes risk section")
  assert_match(text, "claude", "skeleton includes provider")
end)

run("selects provider commands for Claude and Codex", function()
  local claude_cmd = audit.provider_command("claude", "/repo", "PROMPT")
  assert_match(claude_cmd[1], "claude$", "Claude command starts with resolved claude executable")
  assert_contains(claude_cmd, "-p", "Claude command uses print mode")
  assert_not_contains(claude_cmd, "--bare", "Claude command keeps the normal local Claude environment")
  assert_contains(claude_cmd, "--output-format", "Claude command requests output format")
  assert_contains(claude_cmd, "stream-json", "Claude command requests stream json")
  assert_not_contains(claude_cmd, "PROMPT", "Claude prompt is sent through stdin to avoid variadic option capture")
  assert_eq(audit.provider_stdin("claude", "PROMPT"), "PROMPT", "Claude prompt is available as stdin")

  local codex_cmd = audit.provider_command("codex", "/repo", "PROMPT")
  assert_match(codex_cmd[1], "codex$", "Codex command starts with resolved codex executable")
  assert_contains(codex_cmd, "exec", "Codex command uses exec")
  assert_contains(codex_cmd, "--json", "Codex command requests json events")
  assert_eq(audit.provider_stdin("codex", "PROMPT"), nil, "Codex keeps prompt in argv")

  local ok, err = audit.provider_command("missing", "/repo", "PROMPT")
  assert_eq(ok, nil, "unsupported provider returns nil command")
  assert_match(err, "Unsupported provider", "unsupported provider returns useful error")
end)

run("resolves user-local provider executables when Neovim PATH is sparse", function()
  local resolved = audit.resolve_executable("claude", {
    "/definitely/not/claude",
    vim.fn.expand("~/.local/bin/claude"),
  })

  assert_match(resolved or "", "claude$", "Claude resolves from ~/.local/bin when needed")
end)

run("computes B-style audit panel geometry", function()
  local layout = audit.panel_layout(200, 50, {
    panel_ratio = 0.42,
    toc_width = 30,
    evidence_width = 44,
  })

  assert_eq(layout.total_width, 200, "panel spans the available width")
  assert_eq(layout.height, 21, "panel height follows configured ratio")
  assert_eq(layout.toc_width, 30, "toc keeps a readable fixed width")
  assert_eq(layout.evidence_width, 44, "evidence column keeps a readable fixed width")
  assert_eq(layout.report_width, 126, "report receives the remaining main area")
end)

run("uses a roomier default audit layout", function()
  local layout = audit.panel_layout(200, 50, {})

  assert_eq(layout.height, 24, "default panel is tall enough for a readable report")
  assert_eq(layout.toc_width, 24, "default toc is compact")
  assert_eq(layout.evidence_width, 34, "default evidence column is compact")
  assert_eq(layout.report_width, 142, "default report area gets the primary space")
end)

run("renders markdown into a reading view and keeps section positions", function()
  local lines = audit.render_markdown_view({
    "# AI 审计报告",
    "",
    "状态: complete  Provider: claude",
    "",
    "## 链路结论",
    "> 这条链路到底做什么",
    "- 校验租户",
    "正文包含 **重点** 和 `tenantId`。",
    "",
    "## 功能拆解",
    "1. 入口",
  })
  local text = table.concat(lines, "\n")
  local positions = audit.report_section_positions(lines)

  assert_eq(lines[1], "AI 审计报告", "top heading is rendered without markdown marker")
  assert_not_match(text, "^#", "rendered report hides raw markdown heading markers")
  assert_not_match(text, "\n##", "rendered report hides raw second-level heading markers")
  assert_match(text, "• 校验租户", "rendered report uses readable bullets")
  assert_match(text, "重点", "rendered report keeps bold text content")
  assert_not_match(text, "%*%*", "rendered report hides bold markers")
  assert_eq(positions[1], 5, "section one points at 链路结论")
  assert_eq(positions[3], 10, "section three points at 功能拆解")
end)

run("renders markdown tables as aligned reading tables", function()
  local lines = audit.render_markdown_view({
    "## 功能拆解",
    "",
    "| 步骤 | 组件 | 职责 |",
    "| --- | --- | --- |",
    "| 1. 参数校验 | AdminOperationGuard 24 | 校验 reason 长度、confirmToken、adminUserId、apiEndpoint |",
    "| 2. 悲观读锁 | NodeSnapshotRepository.findForUpdate 628 | SELECT ... FOR UPDATE 获取行锁，同时验证 TenantContext 已设置 |",
    "",
    "## 数据流",
  }, { table_width = 92 })
  local text = table.concat(lines, "\n")

  assert_not_match(text, "|%s*---", "rendered table hides markdown separator row")
  assert_not_match(text, "\n|%s*步骤", "rendered table hides raw markdown pipe rows")
  assert_match(text, "┌", "rendered table has a top border")
  assert_match(text, "├", "rendered table has a header separator")
  assert_match(text, "└", "rendered table has a bottom border")
  assert_match(text, "│ 步骤", "rendered table keeps header cells")
  assert_match(text, "AdminOperationGuard", "rendered table keeps component content")
  assert_match(text, "TenantContext", "rendered table wraps long responsibility content")
  for _, line in ipairs(lines) do
    if line:match("^[┌├│└]") then
      assert_eq(vim.fn.strdisplaywidth(line) <= 92, true, "rendered table respects target width")
    end
  end
end)

run("renders B-style audit panel lines with report and evidence maps", function()
  local path = temp_java({
    "class RuntimeFormSubmissionService {",
    "  public SubmitFormResult submit(SubmitFormCommand command) {",
    "    return accepted(command.traceId());",
    "  }",
    "}",
  }, "RuntimeFormSubmissionService.java")
  local root = graph.new_node(item("submit", "com.demo.RuntimeFormSubmissionService", path, 1), 0)
  local context = audit.build_context(root, {
    diagram_lines = { "Business ASCII Diagram", "│ [服务] RuntimeFormSubmissionService.submit │" },
    graph = graph,
  })

  local lines, maps = audit.render_panel_lines(context, {
    status = "streaming",
    provider = "claude",
    report = { "正文" },
  })
  local text = table.concat(lines, "\n")

  assert_match(text, "审计目录", "panel includes toc")
  assert_match(text, "AI 审计报告", "panel includes report heading")
  assert_match(text, "证据与操作", "panel includes evidence column")
  assert_match(text, "正文", "panel includes streamed report")
  assert_eq(#maps.evidence_lines >= 1, true, "panel maps evidence lines")
end)

run("opens locked audit windows with numeric section keymaps", function()
  local path = temp_java({
    "class ForceClaimController {",
    "  long parseSnapshotId(String id) { return Long.parseLong(id); }",
    "}",
  }, "ForceClaimController.java")
  local root = graph.new_node(item("parseSnapshotId", "com.demo.ForceClaimController", path, 1), 0)

  audit.open(root, {
    start = false,
    graph = graph,
    diagram_lines = { "Business ASCII Diagram", "[入口] ForceClaimController.parseSnapshotId" },
    provider = "claude",
  })

  local toc_win
  local audit_windows = 0
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    local name = vim.api.nvim_buf_get_name(buf)
    if name:match("Call Audit") then
      audit_windows = audit_windows + 1
      assert_eq(vim.bo[buf].buftype, "nofile", "audit buffers are scratch buffers")
      assert_eq(vim.bo[buf].buflisted, false, "audit buffers do not enter normal buffer switching")
      if vim.fn.exists("+winfixbuf") == 1 then
        assert_eq(vim.wo[win].winfixbuf, true, "audit windows keep their assigned buffers")
      end
      if name:match("TOC") then toc_win = win end
    end
  end

  assert_eq(audit_windows, 3, "audit panel opens exactly three managed windows")
  assert_eq(toc_win ~= nil, true, "toc window exists")
  vim.api.nvim_set_current_win(toc_win)
  local mapping = vim.fn.maparg("3", "n", false, true)
  assert_match(mapping.desc or "", "section 3", "toc supports numeric section navigation")

  audit.close()
end)

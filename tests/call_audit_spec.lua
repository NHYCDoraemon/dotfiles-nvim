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

run("builds evidence-based call explanation context with diagram and snippets", function()
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
    direction = "incoming",
    diagram_lines = {
      "Business ASCII Diagram",
      "┌────────────────────────────────────┐",
      "│ [服务] RuntimeFormSubmissionService.submit │",
    },
    graph = graph,
  })

  assert_match(context.prompt, "调用链讲解员", "prompt gives the agent a focused explanation role")
  assert_match(context.prompt, "不做架构设计评审", "prompt excludes architecture review")
  assert_match(context.prompt, "不得猜测", "prompt rejects speculative assertions")
  assert_match(context.prompt, "只输出一次最终讲解", "prompt suppresses verbose progress narration")
  assert_match(context.prompt, "最外层调用者 → 直接调用者 → 当前方法", "prompt explains incoming execution direction")
  assert_match(context.prompt, "Business ASCII Diagram", "prompt includes diagram title")
  assert_match(context.prompt, "RuntimeFormSubmissionService%.submit", "prompt includes node label")
  assert_match(context.prompt, "requireMatchingTenant", "prompt includes source snippet")
  assert_eq(context.prompt:find(path, 1, true) ~= nil, true, "prompt includes an exact source path")
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

  local codex_completed = audit.parse_codex_event_json(
    '{"type":"item.completed","item":{"id":"item_3","type":"agent_message","text":" report"}}'
  )
  assert_eq(codex_completed.text, " report", "Codex completed agent message is parsed")
  assert_eq(codex_completed.interim, true, "Codex agent messages are kept out of the final report")
  assert_eq(codex_completed.activity, "已完成一阶段核验", "Codex agent message updates compact activity")

  local codex_command = audit.parse_codex_event_json(
    '{"type":"item.completed","item":{"id":"item_4","type":"command_execution"}}'
  )
  assert_eq(codex_command.command_done, true, "Codex command completions can update the read counter")

  local codex_done = audit.parse_codex_event_json('{"type":"turn.completed","usage":{"output_tokens":12}}')
  assert_eq(codex_done.done, true, "Codex completed turn is parsed")
  assert_eq(codex_done.activity, "讲解完成", "Codex completed turn updates live activity")

  local codex_started = audit.parse_codex_event_json('{"type":"turn.started"}')
  assert_match(codex_started.activity, "Ultra", "Codex started turn exposes model activity")

  local stderr = audit.provider_stderr_text("codex", {
    "Reading additional input from stdin...",
    "",
  })
  assert_eq(stderr, "", "Codex stdin notice is hidden from the audit report")
end)

run("creates focused call explanation skeleton", function()
  local lines = audit.initial_report_lines({ provider = "claude", status = "idle" })
  local text = table.concat(lines, "\n")

  assert_match(text, "调用结论", "skeleton includes call summary")
  assert_match(text, "执行过程", "skeleton includes chronological walkthrough")
  assert_match(text, "数据与状态", "skeleton includes data and state flow")
  assert_match(text, "正确性核验", "skeleton includes correctness verification")
  assert_match(text, "上下文边界", "skeleton includes evidence boundaries")
  assert_not_match(text, "架构视角", "skeleton excludes architecture review")
  assert_not_match(text, "改进建议", "skeleton excludes unsolicited suggestions")
  assert_match(text, "claude", "skeleton includes provider")
end)

run("selects provider commands for Claude and Codex", function()
  assert_eq(audit.defaults.provider, "codex", "Codex is the default audit provider")

  local claude_cmd = audit.provider_command("claude", "/repo", "PROMPT")
  assert_match(claude_cmd[1], "claude$", "Claude command starts with resolved claude executable")
  assert_contains(claude_cmd, "-p", "Claude command uses print mode")
  assert_not_contains(claude_cmd, "--bare", "Claude command keeps the normal local Claude environment")
  assert_contains(claude_cmd, "--output-format", "Claude command requests output format")
  assert_contains(claude_cmd, "stream-json", "Claude command requests stream json")
  assert_not_contains(claude_cmd, "PROMPT", "Claude prompt is sent through stdin to avoid variadic option capture")
  assert_eq(audit.provider_stdin("claude", "PROMPT"), "PROMPT", "Claude prompt is available as stdin")

  local codex_cmd = audit.provider_command("codex", "/repo", "PROMPT", "/tmp/final-message.md")
  assert_match(codex_cmd[1], "codex$", "Codex command starts with resolved codex executable")
  assert_eq(
    codex_cmd[2],
    "--dangerously-bypass-approvals-and-sandbox",
    "Codex audit bypasses approvals and sandboxing"
  )
  assert_eq(codex_cmd[3], "exec", "Codex command uses exec after global options")
  assert_not_contains(codex_cmd, "-a", "Codex bypass mode does not mix approval policies")
  assert_not_contains(codex_cmd, "--sandbox", "Codex bypass mode does not mix sandbox policies")
  assert_contains(codex_cmd, "gpt-5.6-sol", "Codex audit pins GPT-5.6 Sol")
  assert_contains(codex_cmd, 'model_reasoning_effort="ultra"', "Codex audit uses the highest intelligence level")
  assert_contains(codex_cmd, "--json", "Codex command requests json events")
  assert_contains(codex_cmd, "--output-last-message", "Codex writes only the final answer to a dedicated file")
  assert_contains(codex_cmd, "/tmp/final-message.md", "Codex receives the dedicated final-answer path")
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

run("renders compact background progress without agent narration", function()
  local lines = audit.progress_report_lines({ evidence = { {}, {}, {} } }, {
    provider = "codex",
    activity = "正在读取项目证据",
    elapsed = "12:34",
    commands_completed = 17,
    reasoning_rounds = 3,
    show_log = false,
  })
  local text = table.concat(lines, "\n")

  assert_match(text, "后台核验中", "progress view makes the background state explicit")
  assert_match(text, "耗时: 12:34", "progress view shows elapsed time")
  assert_match(text, "工具读取: 17 次", "progress view shows compact evidence activity")
  assert_match(text, "图中证据: 3 个节点", "progress view shows the known graph scope")
  assert_match(text, "按 q 收起面板继续工作", "progress view explains background handoff")
  assert_not_match(text, "我会严格按", "progress view does not expose agent narration")

  local with_log = audit.progress_report_lines({ evidence = {} }, {
    show_log = true,
    progress_events = {
      { elapsed = "00:05", text = "已读取项目证据" },
    },
  })
  assert_match(table.concat(with_log, "\n"), "00:05  已读取项目证据", "process log is opt-in")
end)

run("renders markdown into a reading view and keeps section positions", function()
  local lines = audit.render_markdown_view({
    "# AI 调用讲解",
    "",
    "状态: complete  Provider: claude",
    "",
    "## 调用结论",
    "> 这条链路做什么，是否正确",
    "- 校验租户",
    "正文包含 **重点** 和 `tenantId`。",
    "",
    "## 数据与状态",
    "1. 入口",
  })
  local text = table.concat(lines, "\n")
  local positions = audit.report_section_positions(lines)

  assert_eq(lines[1], "AI 调用讲解", "top heading is rendered without markdown marker")
  assert_not_match(text, "^#", "rendered report hides raw markdown heading markers")
  assert_not_match(text, "\n##", "rendered report hides raw second-level heading markers")
  assert_match(text, "• 校验租户", "rendered report uses readable bullets")
  assert_match(text, "重点", "rendered report keeps bold text content")
  assert_not_match(text, "%*%*", "rendered report hides bold markers")
  assert_eq(positions[1], 5, "section one points at 调用结论")
  assert_eq(positions[3], 10, "section three points at 数据与状态")
end)

run("renders markdown tables as aligned reading tables", function()
  local lines = audit.render_markdown_view({
    "## 执行过程",
    "",
    "| 步骤 | 组件 | 职责 |",
    "| --- | --- | --- |",
    "| 1. 参数校验 | AdminOperationGuard 24 | 校验 reason 长度、confirmToken、adminUserId、apiEndpoint |",
    "| 2. 悲观读锁 | NodeSnapshotRepository.findForUpdate 628 | SELECT ... FOR UPDATE 获取行锁，同时验证 TenantContext 已设置 |",
    "",
    "## 数据与状态",
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

run("renders call explanation panel lines with report and evidence maps", function()
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

  assert_match(text, "讲解目录", "panel includes toc")
  assert_match(text, "AI 调用讲解", "panel includes report heading")
  assert_match(text, "证据与操作", "panel includes evidence column")
  assert_match(text, "正文", "panel includes streamed report")
  assert_eq(#maps.evidence_lines >= 1, true, "panel maps evidence lines")
end)

run("opens locked explanation windows with numeric section keymaps", function()
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

  local muted_hl = vim.api.nvim_get_hl(0, { name = "DoraCallAuditMuted", link = true })
  assert_eq(muted_hl.link, "Comment", "muted explanation text follows the active colorscheme")

  local toc_win
  local audit_windows = 0
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    local name = vim.api.nvim_buf_get_name(buf)
    if name:match("Call Explanation") then
      audit_windows = audit_windows + 1
      assert_eq(vim.bo[buf].buftype, "nofile", "explanation buffers are scratch buffers")
      assert_eq(vim.bo[buf].buflisted, false, "explanation buffers do not enter normal buffer switching")
      assert_eq(vim.bo[buf].filetype, "call_audit", "explanation buffers do not trigger Markdown note plugins")
      assert_not_match(
        vim.wo[win].winhighlight,
        "DoraCallAuditNormal",
        "explanation windows inherit the active colorscheme background"
      )
      if vim.fn.exists("+winfixbuf") == 1 then
        assert_eq(vim.wo[win].winfixbuf, true, "audit windows keep their assigned buffers")
      end
      if name:match("TOC") then toc_win = win end
    end
  end

  assert_eq(audit_windows, 3, "explanation panel opens exactly three managed windows")
  assert_eq(toc_win ~= nil, true, "toc window exists")
  vim.api.nvim_set_current_win(toc_win)
  local mapping = vim.fn.maparg("3", "n", false, true)
  assert_match(mapping.desc or "", "section 3", "toc supports numeric section navigation")

  local background_mapping = vim.fn.maparg("q", "n", false, true)
  assert_match(background_mapping.desc or "", "background", "q sends a running explanation to the background")
  local background_all_mapping = vim.fn.maparg("Q", "n", false, true)
  assert_match(background_all_mapping.desc or "", "background", "Q also hides all three panes without stopping the task")
  local log_mapping = vim.fn.maparg("L", "n", false, true)
  assert_match(log_mapping.desc or "", "process log", "L toggles the optional process log")

  audit.hide()
  local hidden_windows = 0
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
    if name:match("Call Explanation") then hidden_windows = hidden_windows + 1 end
  end
  assert_eq(hidden_windows, 0, "hiding the explanation closes its windows")

  audit.open(root, {
    start = false,
    graph = graph,
    diagram_lines = { "Business ASCII Diagram", "[入口] ForceClaimController.parseSnapshotId" },
    provider = "claude",
  })
  local reopened_windows = 0
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
    if name:match("Call Explanation") then reopened_windows = reopened_windows + 1 end
  end
  assert_eq(reopened_windows, 3, "E can reopen the existing explanation without rerunning it")

  audit.close()
end)

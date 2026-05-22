# AI Call Audit Panel Design

Date: 2026-05-22

## Goal

Add an AI-assisted explanation panel for the existing call hierarchy diagram. The feature should help a developer understand what a selected entry-to-downstream chain does from both architecture and implementation perspectives.

The approved visual direction is option B from the mockup: keep code and ASCII call diagram in the upper region, and use the bottom region as a structured, streaming audit report.

## Non-Goals

- Do not let the AI modify files.
- Do not let the AI run build, test, git, or shell commands.
- Do not replace the existing call hierarchy tree, compact ASCII graph, or boxed ASCII diagram.
- Do not require a web browser for the runtime feature. The browser mockup is only for design review.

## Layout

The Neovim workspace should use a bottom audit region when the user starts an AI explanation from a call graph.

Top region:

- Left pane: source code context, unchanged from normal editing.
- Right pane: boxed ASCII call diagram, still navigable with existing graph keymaps.

Bottom region:

- Left column: audit table of contents.
- Middle column: streaming markdown report.
- Right column: evidence and operations.

The bottom audit region is preferred over a right-side panel because the user selected it as the target visual style. It preserves the call graph width and gives the report enough horizontal room for code evidence and detailed explanations.

## Report Sections

The AI report should be structured, not chat-like. It should stream into stable sections:

- Chain Summary: what the full chain does.
- Architecture View: how Controller, Service, Domain, Port, Adapter, and Repository roles participate.
- Functional Breakdown: what each meaningful node does.
- Data Flow: important values, request fields, IDs, tenant/user context, and outputs.
- Exceptions and Risks: validation, transaction, idempotency, permission, optimistic lock, retry, and boundary concerns.
- Suggestions: review notes and improvements, without applying changes.

The table of contents should show these sections even before all text has streamed, so the report shape is predictable.

## Evidence Model

The audit prompt should be assembled from local information already available to the call hierarchy module:

- ASCII diagram text.
- Rendered hierarchy nodes.
- Role labels.
- Method summaries, including intent, actions, inputs, outputs, and exceptions.
- File paths and line numbers.
- Source snippets around each call hierarchy item.

Each evidence item should keep a jump target:

- file URI
- selection range
- node label
- section or finding that references it

In the audit panel, pressing `Enter` on an evidence item should jump to the referenced source location. `[` and `]` should move between evidence items.

## AI Provider

The first implementation should support a configurable provider:

- Default: `claude`
- Alternative: `codex`

Local availability has been verified on this machine:

- `claude` is available as Claude Code.
- `codex` is available as Codex CLI.

Provider behavior:

- Claude should use non-interactive print mode with stream JSON when available.
- Codex should use non-interactive exec mode with JSON events when available.
- The abstraction should normalize both into streamed text chunks and final completion status.

The prompt must tell the provider to perform read-only audit and to avoid editing files or running commands.

## Interaction

Graph and tree keymaps:

- `E`: start or refresh AI audit for the current call graph.
- `S`: stop the currently running audit job.
- `C`: copy the current report as markdown.
- `Enter`: jump to source when cursor is on an evidence item.
- `[` and `]`: move between evidence items.

Existing keymaps should continue to work:

- `G`: compact ASCII graph.
- `A`: boxed ASCII diagram.
- `P`: Graphviz preview.
- `K`: jump and hover.
- `y`: copy graph text.

The audit should not auto-start when a graph opens. It should start only when the user asks, so it does not spend tokens unexpectedly.

## Streaming States

The audit panel should expose clear states:

- Idle: no audit started.
- Preparing context: collecting node snippets and prompt content.
- Streaming: provider output is arriving.
- Stopped: user cancelled the job.
- Failed: provider command failed or returned no useful output.
- Complete: final report is available.

Failures should stay inside the audit panel and explain the next action, for example:

- provider executable not found
- provider command exited non-zero
- provider produced malformed stream JSON
- no call graph is available
- source snippets could not be read

## Safety

The provider command should be run in a read-only posture where practical.

Required prompt rules:

- Read and explain only the context provided.
- Do not propose shell commands as actions to execute.
- Do not edit files.
- Use file and line evidence from the prompt.
- Mark uncertain inferences explicitly.

The plugin should not pass secrets or unrelated files. It should only include snippets from files represented in the call hierarchy and only around relevant line ranges.

## Visual Style

Use the existing rose-pine-dawn palette and Liga font assumptions.

Suggested highlights:

- Section titles: iris or pine.
- Streaming status: rose.
- Evidence chips: foam/pine.
- Risk section: love.
- Muted metadata: muted.
- Panel borders: overlay/line.

The report should be markdown-like, but not rendered through an external browser. It can use standard Neovim highlights and buffer-local syntax.

## Testing

Add focused tests for pure logic:

- Prompt context assembly includes graph text, nodes, snippets, and evidence references.
- Provider command selection chooses `claude` or `codex` based on config.
- Stream parser accepts representative Claude stream JSON chunks.
- Stream parser accepts representative Codex JSON event chunks.
- Audit section skeleton is created before provider output.
- Evidence entries preserve file and line targets.
- Missing provider produces a clear failure message.

Manual verification:

- Open a Java call graph with `<leader>chd`.
- Press `E` and confirm the bottom audit panel opens.
- Confirm text streams into the report area.
- Press `S` and confirm the job stops.
- Press `C` and confirm markdown is copied.
- Jump from an evidence item back to source.

## Implementation Boundaries

The call hierarchy module is already large. Implementation should avoid adding all AI provider and stream parsing logic directly into it.

Suggested split:

- `lua/dora/call_hierarchy.lua`: keep graph building and graph UI entry points.
- `lua/dora/call_audit.lua`: audit panel, prompt assembly, provider process, stream parser, report buffer, evidence navigation.
- `tests/call_audit_spec.lua`: prompt/provider/parser/evidence tests.

The call hierarchy module should call into `dora.call_audit` with the current root, options, rendered diagram lines, and line map.

## Self-Review

- No placeholders remain.
- The design matches the approved B mockup.
- Runtime browser dependency is explicitly excluded.
- AI execution is read-only by design.
- The first implementation is scoped to one provider abstraction and a structured bottom report panel.

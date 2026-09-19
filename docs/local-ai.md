# Local AI Panel

Added 2026-09-18. The preview uses synthetic fixtures. The production host now connects to the separate model-manager daemon; it no longer launches the `ai-status.sh` poller.

## Current Production Integration

- Backend: `~/repositories/model-manager`, a Python asyncio daemon supervised by `systemctl --user` as `model-manager.service`. Its README documents installation, presets, CLI commands, ownership, and recovery.
- Transport: versioned newline-delimited JSON over `$XDG_RUNTIME_DIR/model-manager/control.sock`. `host/Services/ModelManager.qml` reconnects automatically and supplies panel state without spawning status scripts. Socket permissions and peer UID checks restrict access to the current user.
- The panel lists all configured vLLM/Ollama presets, keeps selected and observed model identities separate, and shows operation progress, runtime metrics, ownership, and OpenCode configuration status. Disconnect/stale state disables actions and throughput, without claiming the runtime stopped.
- Start/switch verify model readiness before atomically updating OpenCode's default provider/model. Configuration failure is separately visible and can be retried using **Settings > Use in OpenCode** without reloading a model. The panel reports a saved default, not an active-session switch: OpenCode must be restarted, including its v2 background server where applicable. Project configuration, session selections, and agent model pins may override the global default. The canonical `opencode-setup` repo intentionally pins Orchestraor to its OpenAI model; model-manager preserves that routing and all permission/MCP/plugin settings.
- Existing containers remain external/read-only until the pin action is explicitly confirmed. Adoption records the verified container ID without restarting it. Stop/switch require interruption confirmation and manage only owned instances. A global operation lock prevents concurrent lifecycle changes.
- OpenClaw integration is deprecated: no automatic configuration reads/writes, restarts, or deletion. Its existing deployment is left untouched.
- Images/weights are not downloaded automatically. Newly created runtime containers do not auto-restart. Daemon startup performs discovery only; interrupted operations are reconciled rather than replayed.

The picker defaults to the last verified model, persisted by model-manager across stops/restarts. The gear opens settings independently of runtime availability. Each desktop profile can override the default preset or inherit **Last loaded**; changing a profile/default does not switch or start a runtime automatically. **Use in OpenCode** is a separate explicit command inside settings. The restart icon supports the already-selected loaded model as well as switching to another one, with interruption confirmation in both cases.

Startup shows stage-specific progress, elapsed time, and vLLM's real shard/graph percentages when available. Compilation, initialization, and Ollama loading use an indeterminate bar rather than an invented overall percentage. A newly started owned container is **Starting**, not **Unreachable**; losing an already-ready endpoint remains a connectivity failure. Recognized KV-cache/OOM failures produce sanitized actionable errors. Qwen3.8's runtime and client context were reduced together to 180,000 tokens with user approval after 195,000 exceeded available KV-cache memory.

The panel uses compact unframed sections and content-fitted drawers in both preview and production. Battery meters are 28px high. Native tests cover settings/restart clicks, measured/unknown progress, and actual drawer widths of 320, 375, 414, and 768 pixels.

GPU telemetry continues to use the existing desktop sampler. Ollama request/token rates and inference-driven suspend inhibition are not implemented. The older architecture/acceptance sections below remain the broader target, not claims that every item is complete.

Verification: model-manager unit tests use fake runtimes and temporary client configs; `tests/test_model_manager.py` exercises actual Quickshell sockets with late server startup, replies, external-runtime guards, and reconnection. Existing preview lifecycle/meter tests remain applicable. Live discovery and non-disruptive client configuration can be verified without unloading a model; real model switching still requires a disruptive acceptance run.

## Confirmed Scope

- A bar icon opens a side panel for the local vLLM runtime.
- Display runtime status and the currently loaded model.
- Start, stop and switch models.
- Show each GPU separately: RTX 5090 (32 GB nominal) and RTX 3080 (10 GB nominal), with GPU utilization and used/total VRAM.
- Use segmented battery-like meters inspired by the supplied image, with solid filled blocks and patterned unfilled blocks. Keep theme colors; the reference's cyan is not an approved palette change.
- Include output tokens/sec when the runtime exposes suitable metrics.

The nvtop comparison establishes per-device visibility, not a requirement to embed nvtop or reproduce its entire process interface. Per-process rows, temperature, power and history graphs remain optional follow-up decisions.

## Preview Behavior

The chip icon opens a right-side overlay without resizing the simulated desktop. Escape, the close icon, clicking the wallpaper or pressing the bar icon again dismisses it. The panel scrolls when necessary.

Model names, memory consumption, utilization, request count and token rate are explicitly synthetic fixtures. Model A/B are not recommended models or claims about GPU fit. GPU totals use convenient fixture values; production must use reported bytes converted consistently to GiB.

Select a candidate model, then use the switch icon. Stop and switch require confirmation because real requests could be interrupted. The loaded-model label changes only after the mock transition succeeds. Duplicate actions are disabled during transitions. A simulated failed launch shows an error and leaves no loaded model; start is available to retry. Reset restores the initial fixture and cancels outstanding transitions.

The shared `SegmentedMeter` uses 20 segments, clamped to 0-100%, rounded down to whole segments. Numeric labels retain precision. Invalid or unavailable measurements produce an empty meter and N/A labels, not a claim of zero activity. Painting happens on value/size changes, with no animation timer per meter.

## Production Architecture

1. `LocalAIService` owns runtime/model/operation state and normalizes endpoint observations. It supplies the panel and bar; neither view launches processes or scrapes metrics.
2. A narrow runtime controller owns only explicitly configured vLLM instances, preferably a user service if suitable for the eventual deployment. A container-based setup needs its own adapter. Service manager choice is not yet approved.
3. Existing `TelemetryService` supplies whole-device metrics to the AI panel, bar and system monitor. Use one sampler at the agreed couple-second cadence, stable GPU UUID/PCI mapping and bounded non-overlapping requests.
4. Model presets define local model identity, served name, quantization, context limit, GPU UUID assignment, launch arguments and readiness timeout. UI actions select preset IDs, not arbitrary executable strings. Secrets and model weights remain outside Git and chezmoi.
5. `IdlePolicyService` consumes verified active-inference state. A loaded idle server alone must not inhibit suspend. Active jobs may inhibit suspend while locking remains allowed. Handle stale observations explicitly rather than releasing inhibitors on one failed request.

Runtime states: unavailable, stopped, starting, running-idle, running-active, stopping, switching and error. Track observation timestamp/staleness separately. Unknown connectivity is not proof that a process stopped. A crash, OOM or driver reset must not leave a permanent Running indicator.

## Backend Contracts to Verify

Pin the deployed vLLM version before implementing its adapter. Research on 2026-09-18 used the developer-preview [metrics documentation](https://docs.vllm.ai/en/latest/design/metrics/), which documents Prometheus `/metrics`, `vllm:generation_tokens_total`, `vllm:prompt_tokens_total` and `vllm:num_requests_running`. The deployed release may differ.

- Health/readiness and served-model identity: verify supported health and models endpoints for the deployed version. A responding API alone does not prove the requested model has loaded successfully.
- Output tok/s: compute generated-token counter deltas over monotonic elapsed time for the selected server/model. Label it server aggregate, not per-request speed. Deduplicate worker/API-server series according to the actual exporter semantics. On restart, counter decrease, model change, stale samples or missing metrics, reset the baseline and show unavailable until two valid samples exist. Valid idle intervals show 0, not N/A.
- Prompt processing throughput is separate from output generation. Do not use an obsolete average-throughput metric or infer tokens/sec from GPU utilization. A full Prometheus server is not required merely to consume the endpoint; use an established parser in the eventual adapter.
- GPU metrics: verify NVIDIA NVML or a maintained structured sampler. Report whole-device VRAM and GPU utilization independently of vLLM availability. KV-cache occupancy and vLLM's configured memory fraction are not equivalent to physical used VRAM.
- Do not add 32 GB and 10 GB into one usable model-capacity number. Heterogeneous GPU sharding compatibility and performance need validation; no automatic model placement or fit claims.

## Lifecycle Safety

Start/stop/switch are controller operations, not assumed OpenAI-compatible API capabilities. Do not use broad process-name kills. Stop only an instance the controller owns; present external instances as read-only unless explicitly adopted. Use argument arrays and an allowlisted preset registry, not interpolated shell commands.

For base-model switching: confirm disruption, serialize operations, stop/drain according to the approved request policy, verify the owned process exits, start the new preset, then wait for readiness and matching model identity. Keep requested and observed model separate. Surface timeouts and sanitized error details; do not report success simply because a command was accepted. Auto-download, auto-retry loops, force-kill and rollback behavior require explicit policy.

Switching may temporarily unload the previous model and fail to load the next. Report that state accurately. Do not start additional instances merely because a readiness probe timed out.

## Implementation Sequence

1. Completed: shared segmented meter, mock lifecycle, bar entry, side panel, per-GPU sections and output-rate presentation.
2. Inventory actual vLLM version, runtime manager, model presets and GPU UUIDs. Agree stop/drain policy and controller ownership.
3. Read-only telemetry and vLLM observations with contract fixtures for missing/stale data, restarts and counter resets.
4. Explicit owned-instance lifecycle controller; wire start/stop/switch after dry-run and failure-path tests.
5. Connect inference activity to idle policy; measure polling and rendering overhead during gaming/inference on CachyOS.

## Acceptance

Preview tests cover panel activation, both GPU meters, stop cancellation/confirmation, disabled actions during transitions, start/switch success, launch failure, unavailable telemetry, invalid/underflow/overflow meter values and screenshot capture. Production tests must add process ownership, duplicate actions, active requests, readiness mismatch, OOM, GPU disappearance, metrics timeout/reset, shell restart during transitions, counter aggregation and suspend-inhibitor release.

## Remaining Decisions

Pin the deployed runtime image/version; choose GPU UUID assignments per preset; validate real stop/switch and failure recovery on the GPUs; decide whether true draining/proxy admission control is needed; determine whether process rows/history and suspend inhibition are useful. The current workflow serializes operations globally, uses explicit interruption confirmation, and does not infer that heterogeneous GPUs can pool their memory.
# Local AI Panel

Added 2026-09-18. The first implementation is an interactive mock in the WSL preview. No vLLM server is installed, queried, started, stopped or modified by this code.

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

## Decisions Still Needed

How vLLM is launched (user service, container or another supervisor); installed version and endpoint; actual local model inventory; GPU assignment per model; one server versus multiple servers; graceful draining versus explicit interruption; sampling/rate window; whether process rows/history are useful. No hardware or runtime choices are implied by the mock.
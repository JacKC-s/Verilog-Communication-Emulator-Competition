# Protocol Emulator ASIC — Project Checklist

> Competition: [Can you design a chip? Protocol emulator ASIC competition](https://blog.janestreet.com/protocol-emulator-asic-competition/)
> Process: IHP CMOS5L via Tiny Tapeout · Area: **8x4 tiles** · Clock target: **50 MHz** (`info.yaml`)
> **Submission deadline: 2027-01-18** · Target shuttle: March 2027 (CMOS5L)
> Repo: tiny CPU that bit-bangs UART / SPI / I2C from firmware; reprogrammable after fabrication.

This file is the single source of truth for progress. It is organized into
**parallel workstreams** so several people (or agents) can make progress at the
same time without blocking each other.

---

## How to use this checklist

- `[ ]` not started · `[~]` in progress · `[x]` done · `[!]` blocked (note why) · `[-]` dropped
- Every task has a **priority** (`P0` = required to submit, `P1` = competitive, `P2` = stretch) and a **lane** (`W1`–`W9`).
- Add `owner:` when claiming a task, e.g. `- [~] (W2, P0, owner: @name)`.
- **Parallel safety rule:** only one person edits a given file at a time. Use the
  [file ownership matrix](#file-ownership--conflict-avoidance) to split work.
- Anything that changes the ISA, pinout, or memory map must update **W1 decisions**
  + `docs/info.md` + `README.md` in the same PR.
- Update this file whenever a task changes state. Do not let it drift.

### Current baseline (what already exists)

- [x] Tiny Tapeout IHP Verilog template integrated; `info.yaml` = `8x4`, 50 MHz
- [x] Top level `tt_um_jackc_protocol_emulator` + byte-wise host loader
- [x] Basic CPU: PC, 256x16 instruction memory, decoder, execution controller
- [x] ISA v0: `NOP, SET, WAIT, JMP, READ, JMP_HIGH` (16-bit word, 4-bit opcode, 12-bit operand)
- [x] One cocotb test (blink + PC check) and a module-level testbench
- [x] CI: test, GDS, precheck, gate-level, docs, and (disabled) FPGA workflows
- [x] `synchronous_fifo.v` written but **not instantiated**
- [ ] Anything protocol-specific (UART/SPI/I2C firmware/toolchain) — not started
- [ ] Local GDS run / precheck / area & timing report — not verified yet

---

## Critical path (must all be green by 2027-01-18)

```
W1 architecture/ISA ──> W2 RTL core ──> W7 GDS + precheck ──> W8 submission
        │                     │                    ▲
        ├──> W4 assembler ────┼──> W6 firmware ────┤
        ├──> W3 host I/F ─────┘                    │
        └──> W5 verification ──────────────────────┘
                          W9 FPGA validation ──────┘
```

**Rule:** W7 (GDS/precheck) cannot be marked done until W4 + W6 exist, because the
judges require working example programs and a toolchain. Start W7 area/timing
experiments early even while RTL is in flux.

---

## W1 — Architecture & ISA (design authority)

Owner: `________` · Blocks W2, W3, W4, W5, W6 · Files: `docs/architecture.md`, `docs/isa.md`

- [ ] (P0) Freeze **ISA v1**: instruction width, operand width, opcode table, flags/status register
- [ ] (P0) Decide **GPIO model**: how many input/output/bidirectional pins the engine owns vs host (max 24 digital: 8 in / 8 out / 8 bidi)
- [ ] (P0) Decide **timing model**: cycles-per-instruction (1? multi-cycle?), deterministic `WAIT`, max frequency assumption
- [ ] (P0) Decide **program memory**: depth/width, SRAM macro vs flops, how host writes it
- [ ] (P0) Define **reset + power-down** behavior (flops do not reset to 0 on ASIC; must reload after deselection)
- [ ] (P0) Publish `docs/isa.md`: opcode table, bit fields, cycle timing, worked example
- [ ] (P1) Add block diagram and memory map to `docs/architecture.md`
- [ ] (P1) Decide **RX path**: FIFO/register for received bits+timestamp, DMA-less buffering
- [ ] (P1) Decide **multiple engines / concurrency** (run UART+SPI+I2C simultaneously?) and cost it
- [ ] (P1) Decide **branch/loop** support: conditional jump set, zero/carry flags, subroutine call/return?
- [ ] (P2) Evaluate eFPGA / pipeline-sharing alternative for the write-up (document why CPU chosen)
- [ ] (P2) Consider PIO/PRU-inspired features (side-set, autopush, clock dividers) and pick any worth the area

**Exit criteria:** ISA v1 document merged; W2/W4 agree on one encoding; no silent changes afterwards.

---

## W2 — RTL core & GPIO

Owner: `________` · Files: `src/project.v`, `src/execution_controller.v`, `src/instruction_decoder.v`, `src/instruction_mem.v`, `src/program_counter.v`, `src/synchronous_fifo.v`

- [ ] (P0) Refactor top level: remove hard-coded single `PIN0`; expose a **pin vector**
- [ ] (P0) Implement multi-bit `SET` / `CLR` / `TOGGLE` on configurable pin groups
- [ ] (P1) Implement **IN** (sample all inputs) and **conditional branch on input/flag**
- [ ] (P1) Implement `WAIT` (cycles) and `WAIT_UNTIL` (event/pin edge) with correct multi-cycle behavior
- [ ] (P0) Fix `NOP` semantics: current `NOP` drives `PIN0` low — that is not a no-op
- [ ] (P0) Latch received bits into a readable register/FIFO (instantiate `synchronous_fifo`)
- [ ] (P1) Add status flags (last bit, received byte ready, timer expired) readable by branches
- [ ] (P1) Add cycle/timestamp counter usable for timing recovery
- [ ] (P1) Add **bidirectional pin** support (`uio_oe` per pin, tri-state model for I2C)
- [ ] (P1) Pipeline/retime if 50 MHz does not close; document CPI
- [ ] (P2) Clock divider / fractional timing for low baud rates
- [ ] (P2) Second execution engine (true concurrency) if area allows
- [ ] (P0) Keep synthesis clean: no latches, no inferred async resets except `rst_n`

**Exit criteria:** core builds with `iverilog -g2012`; every opcode covered by a directed test.

---

## W3 — Host interface, program loading & control

Owner: `________` · Files: `src/project.v`, `src/host_loader.v` (new), `src/*.v`

- [ ] (P0) Document the host protocol (currently byte-wise high/low via `ui_in` + `uio_in`)
- [ ] (P0) Make loading robust: explicit write-address, size/length register, done/err status
- [ ] (P0) Decide host transport on the demo board: **SPI** (recommended, fast) vs UART vs parallel
- [ ] (P1) Implement host read-back of program memory / status for verification
- [ ] (P1) Implement `START` / `STOP` / `RESET` control and a **running** status bit
- [ ] (P1) Support reload after deselect (state is lost when the design is powered down)
- [ ] (P2) Boot ROM / default program so the chip does something without a host
- [ ] (P2) Host-side driver script (Python over RP2350 or FTDI) + protocol doc

**Exit criteria:** a scripted host can load a program, run it, and read status deterministically.

---

## W4 — Toolchain & assembler

Owner: `________` · Files: `tools/asm.py` (new), `tools/examples/*.asm` (new), `tools/README.md`

- [ ] (P0) Define assembly syntax + mnemonic table matching ISA v1
- [ ] (P0) Write assembler producing the exact 16-bit word stream + load image
- [ ] (P0) Add labels, `WAIT` with cycles→baud helper, `.byte`/`.word`/constants, error messages
- [ ] (P0) Emit a format the host loader and cocotb tests can consume (hex/coe/bin)
- [ ] (P1) Add a tiny **reference emulator/interpreter** in Python to pre-validate programs
- [ ] (P1) Unit tests for assembler (golden encodings, label resolution, error cases)
- [ ] (P2) Macro support / include files for common protocol timing
- [ ] (P2) Optional disassembler for debugging dumps

**Exit criteria:** `python tools/asm.py tools/examples/uart_tx.asm` produces a loadable image used by tests.

---

## W5 — Verification (judges weigh this heavily)

Owner: `________` · Files: `test/test.py`, `test/tb.v`, `test/*.py`, `test/Makefile`, `formal/` (new)

- [ ] (P0) Split tests: loader, decoder, ALU/flags, PC/branch, WAIT timing, GPIO read/write, FIFO
- [ ] (P0) Directed tests for every opcode incl. edge cases (back-to-back jumps, WAIT 0, wraparound)
- [ ] (P0) **Cycle-accurate timing tests** (bit period correctness, not just "eventually toggles")
- [ ] (P0) Reset test: unknown flop state → `rst_n` → known state; reload-after-reset test
- [ ] (P0) Keep cocotb running on open-source tools (Icarus) so judges can rerun
- [ ] (P1) Constrained-random / scoreboard testbench with reference model
- [ ] (P1) Functional coverage: opcodes, pin states, branch outcomes, FIFO full/empty
- [ ] (P1) **Formal** (SymbiYosys/`sby`): no lockup, PC in range, loader address bounded, no multi-driver
- [ ] (P1) Gate-level simulation with the hardened netlist (`make GATES=yes`) + PDK models
- [ ] (P1) Lint clean (`verilator --lint-only`, Tiny Tapeout linter already enabled)
- [ ] (P2) Protocol-level assertions (UART frame valid, SPI mode timing, I2C START/STOP)
- [ ] (P2) CI matrix: RTL sim, formal, GLS on every PR

**Exit criteria:** `cd test && make` passes; CI green; GLS passes; coverage report archived.

---

## W6 — Protocol firmware & demos

Owner: `________` · Files: `tools/examples/*.asm`, `docs/protocols.md`, `docs/demo.md`

- [ ] (P0) **UART TX** at a standard baud (e.g. 115200 and 9600), 8N1, correct stop/start timing
- [ ] (P0) **UART RX** with mid-bit sampling and framing-error detection
- [ ] (P0) **SPI controller** all 4 modes (CPOL/CPHA), configurable bit order, CS handling
- [ ] (P0) **I2C controller** START/STOP, ACK/NACK, 100 kHz and 400 kHz
- [ ] (P1) UART loopback / echo demo driven from host
- [ ] (P1) SPI target (slave) role in addition to controller
- [ ] (P1) I2C target role with address match
- [ ] (P1) Concurrent operation demo (e.g. UART echo while SPI shifts)
- [ ] (P2) **Low-speed USB** (line coding, CRC5/16, bit-stuffing, NRZI) — document what is/isn't done
- [ ] (P2) **10BASE-T Ethernet** (Manchester, CRC32, framing) — document feasibility
- [ ] (P2) One of JTAG / SWD / PS/2 / CAN as a novelty demo
- [ ] (P1) `docs/protocols.md`: which protocols work, at what speed, with what pinout, and limits

**Exit criteria:** each required protocol has an example program + a passing simulation test.

---

## W7 — Physical design, area, timing & precheck

Owner: `________` · Files: `info.yaml`, `src/config.json`, workflow files, `docs/pd.md`

- [ ] (P0) Confirm `info.yaml`: `tiles: 8x4`, `clock_hz`, top module, complete source list
- [ ] (P0) Run **local hardening** (LibreLane / `tt-gds-action`) and commit the report
- [ ] (P0) **Synthesis area check**: mapped cell area per tile; leave headroom for CTS + routing
- [ ] (P0) **Place & route**: clean timing at chosen clock (validated 60 MHz is allowed; we list 50 MHz)
- [ ] (P0) **Tiny Tapeout precheck passes** (no LVS/DRC/antenna/pin issues)
- [ ] (P0) Gate-level netlist + GLS passes (hand-off with W5)
- [ ] (P1) Evaluate **IHP SRAM macro** for instruction memory (follow Ken Pettit walkthrough) vs flops
- [ ] (P1) Track area/timing dashboard per commit; flag regressions
- [ ] (P1) Validate `uio_oe`/pin muxing against Tiny Tapeout pin rules
- [ ] (P1) Check the 6-hour GitHub Actions limit; use local flow if exceeded
- [ ] (P2) Power estimate / IR-drop sanity check
- [ ] (P2) Keep `src/config.json` overrides minimal and documented

**Exit criteria:** GDS artifact + precheck pass + timing report + GLS green, reproducible from a clean clone.

---

## W8 — Documentation, write-up & submission

Owner: `________` · Files: `README.md`, `docs/info.md`, `CHECKLIST.md`, `docs/writeup.md`

Judges explicitly weigh the write-up: readability, novelty, verification approach, AI usage.

- [ ] (P0) Keep `README.md` accurate (architecture, ISA, pinout, build/test, examples)
- [ ] (P0) Update `docs/info.md` datasheet: how it works, how to test, external hardware
- [ ] (P0) `docs/writeup.md`: problem, architecture, ISA, why it is flexible, novelty, limits
- [ ] (P0) Verification write-up: what is tested, how, coverage, formal, GLS, known gaps
- [ ] (P0) Toolchain docs: install, assemble, load, run, example commands
- [ ] (P0) Document **AI usage** and any non-standard flows/tools
- [ ] (P0) Public repo + open-source license verified (Apache-2.0)
- [ ] (P0) Final submission: repo link + passing GDS/precheck + docs + examples
- [ ] (P1) Add block diagrams / waveform screenshots / demo video
- [ ] (P1) Cite references (RP2040 PIO, TI PRU, Tiny Tapeout docs, SRAM walkthrough)
- [ ] (P1) Internal review pass by someone who did not write the section
- [ ] (P2) Short demo video on FPGA or TT ASIC sim

**Exit criteria:** a reader can clone, run tests, load a UART program, and understand the design without asking questions.

---

## W9 — FPGA / pre-silicon validation (parallel, not blocking)

Owner: `________` · Files: `.github/workflows/fpga.yaml`, `fpga/` (optional)

- [ ] (P1) Enable/parameterize the ICE40UP5K FPGA workflow and generate a bitstream
- [ ] (P1) Run UART/SPI/I2C firmware on an FPGA (or TT ASIC sim) with real timing
- [ ] (P1) Loopback test at target baud/clock to validate timing assumptions
- [ ] (P2) Record FPGA demo for the write-up
- [ ] (P2) Compare FPGA vs gate-level simulation results

---

## File ownership & conflict avoidance

Work in separate files to keep lanes parallel. Claim files in this table before editing.

| File / dir | Primary lane | Notes |
|---|---|---|
| `docs/isa.md`, `docs/architecture.md` | W1 | design authority; changes ripple everywhere |
| `src/project.v` | W2 / W3 | **highest contention** — coordinate W2+W3 |
| `src/execution_controller.v` | W2 | core datapath |
| `src/instruction_*.v`, `program_counter.v`, `synchronous_fifo.v` | W2 | |
| `src/host_loader.v` (new) | W3 | keep loader out of the core files |
| `tools/asm.py`, `tools/examples/` | W4 | independent once ISA frozen |
| `test/` | W5 | test-only changes are safe in parallel |
| `tools/examples/*.asm` (protocols) | W6 | separate files per protocol |
| `info.yaml`, `src/config.json`, workflows | W7 | physical flow only |
| `README.md`, `docs/info.md`, `docs/writeup.md` | W8 | docs owner merges |
| `fpga/`, `fpga.yaml` | W9 | isolated |

**Merge discipline:** small PRs, one lane each; never reformat a file another lane owns; rebase before merging.

---

## Milestones (working backwards from 2027-01-18)

| Date | Milestone | Gate |
|---|---|---|
| 2026-11-30 | ISA v1 frozen; architecture doc merged | W1 exit |
| 2026-12-15 | Core RTL v1 + multi-pin GPIO; all opcodes tested | W2 exit, `make` green |
| 2026-12-15 | Assembler v1 + UART TX/RX examples | W4 + W6 partly |
| 2026-12-31 | SPI + I2C firmware; host loader v2 | W3 + W6 exit |
| 2027-01-05 | **First full GDS + precheck + GLS** | W7 exit (hard gate) |
| 2027-01-10 | Verification write-up + coverage + formal | W5 + W8 |
| 2027-01-14 | Docs, examples, demo polished; internal review | W8 exit |
| 2027-01-18 | **Submit** (public repo, GDS/precheck, docs, toolchain) | final |

If a milestone slips, cut **P2** items first, then P1. Never cut precheck/GLS/docs.

---

## Definition of done (competition rubric)

A submission is complete only when **all** are true:

- [ ] Reprogrammable **after** fabrication; adding a new protocol needs no new silicon
- [ ] UART, SPI, I2C demonstrated with example firmware and passing tests
- [ ] Architecture + ISA documented clearly enough to implement a new driver from the docs
- [ ] Open-source repo with RTL, tests, toolchain, example programs
- [ ] Clean Tiny Tapeout GDS + precheck; gate-level sim passes
- [ ] Verification approach written up (directed, random, formal, coverage, GLS)
- [ ] Fits 8x4 tiles with timing closed; area/timing evidence included
- [ ] Write-up explains novelty, limits, and AI usage

---

## Risks & open decisions

| Risk | Impact | Mitigation | Owner |
|---|---|---|---|
| ISA churn mid-project | W2/W4/W6 thrash | Freeze ISA v1 by 2026-11-30; changes require version bump | W1 |
| Too many pins assumed | Cannot route on 24 digital pads | Fix pin budget in W1; verify vs `uio_oe` rules | W1/W7 |
| Instruction memory too big for tiles | Fails area/precheck | Prototype SRAM macro early; track area per commit | W7 |
| 50 MHz does not close | Late redesign | Try 60 MHz budget, reduce logic depth, pipeline | W2/W7 |
| Only 1 output pin today | Protocols cannot coexist | Multi-pin GPIO is P0 in W2 | W2 |
| No local GDS run yet | Precheck surprise late | Run hardening at 2026-12-01 and 2027-01-05 | W7 |
| Write-up rushed | Judges weight it heavily | Draft continuously; review before deadline | W8 |

**Open decisions to resolve now:** instruction width (16 vs 32) · operand width ·
SRAM vs flops · number of engine pins · host transport (SPI/UART/parallel) ·
single vs multiple engines · reset/reload policy · whether to include USB/Ethernet.

---

## Weekly sync checklist (copy for each week)

- [ ] Each lane reports: done / next / blocked / ETA
- [ ] CI green on `main` (test, GDS, precheck, GLS)
- [ ] Area & timing changed since last week? Recorded?
- [ ] ISA unchanged or version bumped?
- [ ] Docs updated in the same PR as code?
- [ ] Next milestone still achievable? Re-cut P2 if not
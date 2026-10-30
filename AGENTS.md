# Project 3 handoff

## Current state and preferences

- Workspace: `/home/cen598/Documents/cen598/Project3`.
- Assignment: `CSECEN_598_Project_3_Handout.pdf`.
- Part 1 RTL, module verification, CRP collection, and required HD calculations are complete. Task 4 discussion was provided in chat. Following the read-only report review, the user requested SEL=0 coverage in the existing mux bench; this is now complete. Report corrections have not been applied to the DOCX.
- Part 2 RTL and the Quartus implementation were added on October 28; physical verification, hardware CRPs, the Part 2 report, and the appendix remain unfinished. The user will attach Python scripts during submission; do not treat those acknowledged report omissions as review findings.
- Use four spaces per indentation level in files created or edited. Preserve existing RTL, teammate work, results, and spreadsheet sheets.
- The user subsequently authorized SEL=0 coverage in the existing `tb_mux.v`; its focused update is complete. Do not add separate extended mux or process-delay benches. Reuse completed verification; rerun only for necessary evidence or regression.
- Keep progress updates concise. The user prefers Excel work delegated to the existing `excel_results` subagent and does not want raw spreadsheet context pasted into chat. No other delegation was requested.

## Design and verification

Sources are under `project3_part1/src/`:

- `arbiter_puf.v` instantiates `R_BITS` copies of `puf_1rbit`, defined in `puf_1r_bit.v`.
- Each response has `C_BITS` stages, two muxes per stage, and a `d_ff` arbiter. Final top path drives D; bottom drives CLK. Reset is asynchronous and active high.
- Challenge MSB controls the first stage; LSB controls the last. Select 1 routes straight; select 0 crosses paths.
- Top-level DELAY width is `8*C_BITS*R_BITS`. Response r receives `DELAY[r*(8*C_BITS) +: (8*C_BITS)]`. Within a response, stage s uses top nibble `[8*s +: 4]` and bottom nibble `[8*s+4 +: 4]`. Each mux nibble assigns `[1:0]` to input a's delay and `[3:2]` to b's delay.
- DELAY is an elaboration-time parameter, not a runtime signal. Simulations use `1ps/1ps`.

Saved evidence under `project3_part1/tb/`:

- `tb_d_ff.v`: 27 passing checks; `tb_d_ff_output.txt` and `tb_d_ff.wlf`.
- `tb_process_delay_model_output.txt`: unchanged supplied bench; input rise 26 ps/output rise 36 ps, input fall 46 ps/output fall 56 ps. Short 3–6 ps pulse is filtered; initial X settles at 16 ps.
- `tb_mux.v`: 8 passing checks for both select values, both selected-input logic levels, B rising/falling before and after its 2 ps delay, and an unselected A transition. `tb_mux_output.txt` and `tb_mux.wlf` contain the updated evidence; `tb_mux_select_output.txt` and `tb_mux_select.wlf` are the direct ModelSim run artifacts. Original SEL=1-only evidence is preserved as `tb_mux_output_sel1_original.txt` and `tb_mux_sel1_original.wlf`. DUT DELAY remains `4'd8` (A=0 ps, B=2 ps). Periodic `$display` samples at input/select transitions can precede same-time combinational settling; use the explicit PASS checks and waveform when interpreting timing.
- `tb_puf_1rbit_4_16.v` and corresponding `_output.txt`: 252 passing checks. All 16 four-bit challenges twice; 44 selected sixteen-bit challenges twice. Original `tb_puf_1rbit.v` additionally covers C_BITS=1.
- `tb_arbiter_puf.v` and `_output.txt`: 215 passing checks for `(C_BITS,R_BITS)` = `(1,1)`, `(4,4)`, `(7,3)`, `(4,32)`. The original 32-bit smoke test repeats four known delay profiles; it is separate from Task 3 collection.

## Task 3 data and spreadsheet

`project3_part1/tb/crp_results/` contains:

- `crp_canonical.csv`: 256 configuration–challenge records.
- `crp_samples.csv`: 512 measurements, two identical runs per CRP.
- `configurations.json`: exact 1,024-bit profiles and provenance. PUF_00 preserves the original `tb/delay_params.v`; PUF_01–15 use unchanged `modelsim/delay.py:gen_delay`, seeded once with 598. Its `int(random.uniform(0,15))` normally samples nibble values 0–14. No profiles were filtered for favorable results.
- Per-device directories hold delay includes, two logs, and two WLF recordings. Collection has zero X/Z responses, errors, or warnings.
- There are 1,031 analytically tied bit races across the canonical 8,192 response bits. All 14,322 unequal-arrival reference comparisons across both runs passed. Actual tied responses are retained.

The current report workbook is **`project3_part1/tb/crp_results/crp_tables_for_report.xlsx`**. Preserve its existing sheets:

1. `CRP Tables`: all 16 PUF blocks stacked vertically, merged headings, two columns. Values use `[0xF] 1111` for challenges and eight-digit hex plus 32-bit binary for responses. No tie-mask columns.
2. `Single_Chip_HD`: 16 summaries, variation and repeatability clearly separated.
3. `Multi_Chip_HD`: 16 challenge summaries plus overall.
4. `Multi_Chip_Pairs`: 120 pair averages.
5. `Multi_Chip_Matrix`: symmetric 16×16 percentages, zero diagonal.

## HD methods and conclusions

Scripts: `project3_part1/modelsim/analyze_single_chip_hd.py` and `analyze_multi_chip_hd.py`. Outputs are under `project3_part1/tb/task4_results/`. Run with `python3 <script-path>` from any directory. Multi-chip script imports the single-chip helper, so submit both.

- Primary HD calculations include all 32 actual bits, including ties. Masked diagnostics and plots were deferred as the user chose incremental work.
- Single-chip variation: average XOR/popcount over all 120 unordered challenge pairs within each PUF, normalized by 32. Per-PUF means range 46.8229%–51.1719%. Independent, unbiased-response benchmark: 50%.
- Same-challenge repeatability: compare runs 1 and 2, averaging 16 comparisons per PUF. All are 0 bits/0%, the ideal for repeatability. This is fixed-condition RTL evidence, not physical environmental reliability.
- Multi-chip: different devices under the SAME challenge; 120 unordered device pairs ×16 challenges =1,920 comparisons. Overall mean **15.7890625 bits / 49.3408203125%**; 30,315 mismatches across 61,440 compared bits. Individual HD ranges 6–25 bits. Per-challenge means range 47.2917%–51.1979%.
- Raw-response verification confirmed 16 distinct responses and zero colliding device pairs for EVERY challenge. Minimum HD for challenges 0000–1111: `8,7,10,11,8,7,6,9,10,8,9,8,10,9,9,9`.
- One common challenge and one reference response per device distinguish these 16 simulated configurations. Do not generalize this to arbitrary populations or noisy physical operation.
- Conditional IID collision bound for N devices and m independent 32-bit CRPs: `C(N,2)*2^(-32*m)`. For N=16,m=1: about 2.8e-8. This is theoretical, not measured entropy or collision probability.
- A 32-bit response has at most 32 bits of entropy. Concatenating responses does not prove independent secret entropy. Four-bit challenges allow exhaustive enumeration of 16 responses through unrestricted access. Increasing challenge width alone does not establish modeling-attack resistance.

## Latest report review: pending corrections

Actual file: `/home/cen598/Downloads/HST_Project3(1).docx` (no space before `(1)`). Read-only review verified all 256 copied CRPs, 16 single-chip rows, and 17 multi-chip rows against saved data; no numerical mismatches. Both embedded diagrams were inspected.

Comments already delivered to the user:

1. Task 2 incorrectly says not all four-bit patterns were tested. Correct to all 16 twice; sixteen-bit testing sampled 44 patterns twice.
2. Task 4 says single-chip HD is "across different PUFs." Correct to different challenges within each PUF. Explicitly distinguish 50% variation benchmark from 0% repeatability ideal.
3. Replace the broad claim that 100% HD means responses can be "figured out easily." Explain the independent unbiased-bit 50% expectation; a complementary pair does not alone establish predictability.
4. Change DELAY "given at run time" to elaboration-time, fixed per instance.
5. Strengthen generic verification conclusions with actual tested behavior and avoid overstating coverage. After the review, the user requested and obtained 8 passing mux checks covering SEL=1 and SEL=0; the report can now describe that updated coverage.
6. Replace "16 delay values" with 16 complete delay configurations, each containing 256 four-bit mux-delay values. Say "16 possible four-bit challenges."
7. Qualify the multi-chip limitation as "multi-chip HD alone"; separate repeat tests did establish fixed-condition repeatability.
8. Qualify larger challenge width as increasing enumeration cost, not proving security. Add citations for modeling attacks and key extraction.
9. Remove Figure 1 caption's claim enable is absent; it is shown. Replace Figure 2's "D-Flip Flop is also an output" with a separate d_ff module. Make the complete module hierarchy explicit.
10. Restore four-bit leading-zero challenge labels in the collision table. Correct "top status" to "top stays" and "32 registered" to "32 registers." Align the claimed `hamming_distance.py` filename with the scripts actually submitted.

Useful primary references: https://www.cs.bu.edu/~reyzin/fuzzy.html and https://dspace.mit.edu/entities/publication/5e912542-bc7a-4b9c-ba4e-918d7bc90f1f . The user's ndac.re.kr PDF could not be retrieved; do not claim to have read it.

## Tool notes

- ModelSim is installed and on PATH, but historically requires execution outside the sandbox. `modelsim/verify_and_collect.py` has an approved command prefix and stages isolated builds without editing existing RTL/benches.
- Use focused compilation with `-timescale 1ps/1ps`; avoid compiling `delay_params.v` as a standalone module via a wildcard.
- Do not rerun the full simulation collection just to regenerate HD tables.
- Existing Task 1–3 PDFs and generation scripts are under `project3_part1/report/`. These may be ignored by git but exist locally. Shared files can be changed concurrently by the user/teammate; do not overwrite unrelated changes.

## Part 2 implementation update — October 28, 2026

- The user approved and requested implementation of the cross-gated RO PUF plan. Part 1 files and the DOCX remain unchanged.
- `project3_part2/sources/ro_counter.v` reuses the provided saturating-counter logic with default W=16, asynchronous active-high reset, and no enable port. Saturation occurs after 65,535 rising edges.
- `Counter_group` selects two of 16 ROs. `clk0 = RO_out[Cha0] & ~done1`; `clk1 = RO_out[Cha1] & ~done0`. `Response = done1`; `Done = done0 | done1`; `Invalid = Done && (count0 == count1)`. Read after completion/settling and discard invalid results.
- `PUF.v` preserves 64 original `gen_Ro[i].ro_inst` instances and four cg0–cg3 groups. Added Invalid[3:0] and overall Done (AND of group completion). RO Enable remains ~reset; no synchronizing/system clock is used.
- Board mapping: KEY0 inverted to reset; SW[3:0]/SW[7:4] to Cha0/Cha1; LEDG[3:0] responses, LEDG[4] overall completion, LEDR[3:0] invalid flags. Other LEDs low. Hold reset while setting challenges, then release and wait for completion.
- RO topology is unchanged: NAND + eight NOT gates in feedback, not_9 as output inverter. Native `/* synthesis keep = 1 */` on each gate-output net is necessary in the installed Quartus. The initially attempted `(* keep = "true" *)` form reduced each RO to one logic cell; the current directive retains ten cells per RO. Do not revert without checking synthesis.
- Quartus targets 5CGXFC5C6F27C7. Fixed stale C5G_Default entity qualifiers on the original I/O standards, preserving pin locations and voltage values. Registered ro_counter, placement TCL, and SDC. Gated-clock conversion explicitly off.
- `scripts/generate_placement.py` generates 640 assignments: 64 distinct Fitter-validated LABs in X columns 11,13,15,17,21,23 / Y rows 2–12, first 64 in X/Y order; gate slots N=0,6,...,54. Coordinates are device-specific, not a full-device enumeration. Outputs: quartus/ro_placement.tcl and .csv.
- `scripts/build_fpga.py` successfully ran map, fit, physical-node checks, assembler, and timing. All 640 stages match assigned ALMs. Bitstream: `project3_part2/quartus/output_files/Project3.sof`. Build/status/source hashes: output_files/build_status.json. Fitted usage: 819 ALMs, 189 registers; synthesis had 136 registers and Fitter duplicated 53 for routing. No RAM/DSP/PLL usage.
- SDC defines eight gated-clock analysis roots at an assumed 5ns period. All four reported device corners meet setup/hold/pulse checks; minimum margins: setup 0.941ns, hold 0.080ns, pulse width 1.786ns. These are steady-clock analysis results, not measured RO frequencies or proof against asynchronous gating/reset hazards. Intentional combinational-loop and unconstrained external-I/O warnings remain visible.
- Self-checking benches exist under tb/: tb_ro_counter.sv, tb_counter_group.sv, tb_ro_basic.sv, tb_puf_top.sv. `modelsim/run_tests.py` generates a delayed copy of current RO RTL and uses a separate controlled-period RO model for integration. Simulation models are not in Quartus. Tests have NOT run successfully: vlib/vlog/vsim terminate with SIGSYS (-31) inside the current sandbox before compilation. Run `python3 project3_part2/modelsim/run_tests.py` from a normal terminal; tb/verification_status.json currently correctly says passed=false. Do not report passing test counts.
- No JTAG hardware was detected by the final `quartus_pgm -l` check; programming, physical repeatability, frequency measurements, and hardware CRPs are pending. The 32-row tb/hardware_crp_template.csv is deliberately unmeasured (16 proposed challenge pairs, two repeats).
- `scripts/analyze_crps.py` excludes invalid/incomplete attempts, compares canonical four-bit responses across challenges, and separately computes repeatability across repeats. Synthetic fixture checks passed (normalization, exclusions, changed repeats, duplicate rejection); no hardware results were invented.
- `scripts/render_placement.py` creates implementation/ro_placement.svg and ro00_detail.svg from fitted coordinates/fanout. These are diagrams, not Chip Planner screenshots. The X11 display is inaccessible; actual GUI screenshots remain pending.
- Read `project3_part2/IMPLEMENTATION.txt` for commands and operational details. Part 2 .gitignore excludes generated compiler databases/build outputs but retains the test runner. All artifacts still exist locally. Reuse the successful build unless RTL/settings change; do not rerun Part 1 verification.

## Part 2 Task 5 update — October 29, 2026

- Hardware programming succeeded in the user's session. The completed CRP source is `project3_part2/tb/ro_puf_256_crps.xlsx`, SHA256 `31cb68a766893f65d01c25427342866157cbc8b8a7dc70602a3a4031aac6c7ed`. It contains all 256 challenge responses; do not recreate it with the original 16-response template script.
- The user explicitly confirmed that all 238 blank invalid-mask cells mean all four red LEDs were off after Done became high. One row explicitly records `0000`; 17 rows have nonzero masks. All 256 challenges were reportedly measured after five fresh resets with unchanged responses. Only one canonical response per challenge is stored; individual raw repeats are unavailable.
- Task 5 uses all 239 valid four-bit CRPs and excludes the complete response for each of the 17 flagged rows (16 equal-index challenges, one different-index challenge). It does not choose the earlier response-balanced subset of 16.
- Single-chip challenge variation: 28,441 unordered pairs, 56,810 differing bits / 113,764 compared bits, mean **1.9974684434443233 bits / 49.93671108610808%**. Histogram for distances 0–4: `2103,7098,10088,7072,2080`. Independent per-bit ones-times-zeros totals agree. Response[3:0] ones counts are `121,137,119,118`; Response[2] is biased to one in 57.3222% of valid responses.
- Repeatability is reported as 0% observed HD from the user's five unchanged-trial confirmation, separately labeled from raw-data calculations. Do not invent repeated rows or claim environmental reliability. The 50% benchmark is for different-challenge variation; 0% is the same-challenge repeatability ideal.
- Run `python3 project3_part2/scripts/analyze_task5.py`; it imports unchanged `analyze_crps.py` and the Excel helper `task5_workbook.py`. All three scripts must accompany the submission. Requires openpyxl (session-local installation at `/tmp/puf_excel_deps` is supported). Existing results are preserved; use a fresh `--output-dir` for reruns. Source-specific confirmations are bound to the input hash and require review if the source changes.
- Outputs are under `project3_part2/tb/task5_results/`: separate `ro_puf_task5_results.xlsx`, summary JSON, normalized/valid/excluded CRP CSVs, all pairwise HDs, per-challenge averages, bit balance, response frequencies, report-ready `task5_report_answer.txt`, and checks. The Excel work was delegated to `excel_results`; the original CRPs sheet's values, styles, comments, and validations are preserved in the separate results workbook. The original source file remains byte-identical.
- The older Part 2 pending-simulation notes are superseded by `tb/verification_status.json` and saved passing logs: counter 196,611 checks; counter group 84; RO 6; top PUF 23, each with zero errors/warnings. Do not rerun completed verification for this analysis. Kiran's bonus measurements have not yet been supplied; `for_kiran.zip` packages the original SOF and the earlier 16 measured challenge inputs for his collection.

## Submission assembly — October 29, 2026

- The user explicitly excluded the unfinished Part 2 bonus and all Kiran transfer/data files. They are not included in `submission/`. Required Part 1 multi-chip analysis remains included.
- `submission/` now contains the complete available supporting files in preserved `project3_part1/` and `project3_part2/` layouts: 299 files, approximately 33.39 MB at assembly time. `TASK_FILE_REFERENCES.txt` provides the requested report-ready `See: (file)` lines for all nine mandatory tasks. All 86 exact file references were checked. `FILE_MANIFEST.csv` records original/copy SHA256 hashes and the one documented relative-path transformation in the submission CDF.
- Existing loose RTL, counter benches, delayed model and placement Tcl were organized into their expected subdirectories. Part 1 transcripts previously moved into `submission/tb_outupts/` were organized beside their benches. Missing working copies were restored from these byte-identical files; the active working project remains available outside submission.
- The submission includes the original successful SOF, all saved verification evidence, the 16 Part 1 delay configurations and CRP results, both Part 1 HD analyses, the measured Part 2 workbook, and all Task 5 results/helpers. No simulations or Quartus rebuild were rerun. Verification hashes, data/bitstream hashes, Python syntax and relative Quartus source/settings paths passed checks.
- Quartus saved removal of `-entity cyclone_v_top` qualifiers on the I/O standard assignments during assembly; the copied QSF was refreshed to match the user's current working file. The original working QSF was not edited by this assembly operation.
- The combined final report PDF is not available locally and was not fabricated from the old DOCX. Before zipping, the user must export their latest report into `submission/`, including their annotated Chip Planner screenshots and measured response-time/frequency answer. Generated placement SVGs are not GUI screenshots. `README_FIRST.txt` records this remaining external deliverable and packaging instructions.

## Submission cleanup — October 29, 2026

- The user subsequently requested a lean submission without unnecessary files such as `wave.do`. This supersedes the earlier full-copy inventory: `submission/` now contains 137 files, approximately 8.79 MB; 162 redundant files (24.59 MB) were removed from this folder only.
- Removed obsolete waveform/load/run helpers, saved WLF binaries, duplicate compiler/invocation logs and old SEL=1 evidence, component draft PDFs and their rendering scripts, redundant older workbooks, unused legacy Part 2 benches, figure/template generators, example/unverified GUI Tcl helpers, optional CDF and stale build status, detailed timing dumps, duplicate figure formats, draft answer text and the assembly manifest. Original working files outside `submission/` remain available.
- Retained required RTL, verified benches and text outputs, simulation models/runners, all sixteen Part 1 delay configurations and CRPs, both mandatory Part 1 HD analyses, measured Part 2 data and Task 5 scripts/results, placement generator/Tcl/CSV, Quartus project/SDC, build/check helpers, essential compiler reports and the original SOF. All retained file hashes, verification dependencies and task references passed checks. No simulation or synthesis was rerun.
- `TASK_FILE_REFERENCES.txt` and `README_FIRST.txt` were updated for the lean contents. Do not reintroduce the removed extras or Kiran bonus files into the submission. The final combined report PDF is still to be added by the user.

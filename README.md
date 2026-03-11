Verification Objectives:
The goal is to verify functional correctness, interface behavior, timing/latency, and data‑flow integrity of:
Systolic Array (NxN) module
Sub‑system integrating FIFOs + controller + systolic array

The verification must ensure the DUT correctly computes:
C= A*B
for arbitrary matrix dimensions 
N*M and M*N with:
signed arithmetic
streaming input protocol
multi‑cycle accumulation
correct out_valid timing
correct FIFO behavior (sub‑system level)
correct handling of M (via M_minus_one)
correct behavior across different clock ratios (sys_clk vs sr_clk)

DUT Features to Verify:
Systolic Array :
Correct accumulation across M cycles.
Correct propagation of A and B streams.
Correct computation of each output element C[i][j].
Correct assertion of out_valid exactly when the last partial sum is ready.
Reset behavior clears internal state.
Handling of different M values (via plusarg or parameter).
Signed arithmetic correctness.

Sub‑System :
FIFO write/read behavior under sys_clk.
FIFO full/empty signaling.
Correct unpacking of A and B from BUS_WIDTH input.
Correct packing of C into BUS_WIDTH output.
Correct M_minus_one handling.
Correct synchronization between sys_clk and sr_clk.
Correct throughput across multiple matrix multiplications.
No data loss or duplication across FIFO boundaries.

Verification Strategy
1. Constrained‑Random Stimulus
Randomize:
Matrix dimensions M 
Matrix values
Clock ratios (sys_clk : sr_clk)
FIFO read/write timing
Back‑to‑back matrix operations
Ensure legal and illegal scenarios:
FIFO full conditions
FIFO empty reads
Reset during operation
Random stalls in driver

2. Golden Reference Model
A cycle‑accurate or functional model computes:
C[i][j]=sumation of k = Om-1A[i][k]. B[k][j]
This model is used in the scoreboard to compare DUT output vs expected.

3. Self‑Checking Scoreboard
Receives transactions from both systolic and sub‑system monitors.
Compares DUT output matrix C with golden reference.
Logs mismatches with full context (A, B, M, N, cycle count).

4. Functional Coverage
Coverage points include:
Stimulus coverage
Range of M values
Range of A and B values
Signed corner cases: -128, -1, 0, 1, 127
FIFO full/empty transitions
Clock ratio variations
Cross coverage
(M × clock ratio)
(A value × B value)
(FIFO full × wr_fifo timing)

Protocol coverage
in_valid pulse patterns
out_valid timing
correct number of cycles per matrix

5. Assertions
SystemVerilog Assertions (SVA) for:
out_valid must assert exactly when k_cnt == M
No FIFO overflow/underflow
Reset clears internal state
c_dout stable when out_valid is low
in_valid must not be high when FIFO is full (sub‑system)

UVM Testbench Architecture
Agents
Systolic Agent
Driver: drives A, B, c_din, in_valid
Monitor: captures c_dout, out_valid
Sequencer: issues mat_tr transactions

Sub‑System Agent
Driver: drives din, wr_fifo, rd_fifo, M_minus_one
Monitor: captures dout, out_fifo_empty
Sequencer: issues mat_tr transactions

Environment
Contains:
systolic_agent
sub_sys_agent
systolic_scoreboard
Connects analysis ports to scoreboard.

Sequences
mat_seq: generates random matrices A, B, M


Tests
systolic_test: full constrained random


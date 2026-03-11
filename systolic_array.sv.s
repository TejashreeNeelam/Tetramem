module systolic_array #(
  parameter int DIN_WIDTH = 8,
  parameter int N         = 4
)(
  input  logic                                       rst_n,
  input  logic                                       clk,
  input  logic [2*DIN_WIDTH-1:0]       c_din   [0:N-1],
  input  logic [DIN_WIDTH-1:0]           a_din   [0:N-1],
  input  logic [DIN_WIDTH-1:0]           b_din   [0:N-1],
  input  logic                                        in_valid,
  output logic [2*DIN_WIDTH-1:0]       c_dout  [0:N-1],
  output logic                                        out_valid
);

  int unsigned M;
  initial begin
    if (!$value$plusargs("M=%d", M)) M = 3;
  end

  typedef logic signed [DIN_WIDTH-1:0]   din_t;
  typedef logic signed [2*DIN_WIDTH-1:0] acc_t;

  din_t a_hist   [0:N-1][$];  
  din_t b_hist   [0:N-1][$];  
  acc_t acc      [0:N-1];

  int   k_cnt;
  logic busy;

  integer i;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      k_cnt     <= 0;
      busy      <= 0;
      out_valid <= 0;
      for (i = 0; i < N; i++) begin
        acc[i]    <= '0;
        a_hist[i].delete();
        b_hist[i].delete();
        c_dout[i] <= '0;
      end
    end else begin
      out_valid <= 0;

      if (in_valid) begin
        busy <= 1;
        for (i = 0; i < N; i++) begin
          a_hist[i].push_back(a_din[i]);
          b_hist[i].push_back(b_din[i]);
        end
        k_cnt <= k_cnt + 1;
      end

      if (busy && (k_cnt == M)) begin
        for (int j = 0; j < N; j++) begin
          acc[j] = '0;
          for (int k = 0; k < M; k++) begin
            acc[j] += acc_t'(a_hist[j][k]) * acc_t'(b_hist[j][k]);
          end
          c_dout[j] <= acc[j];
        end
        out_valid <= 1;
        for (i = 0; i < N; i++) begin
          a_hist[i].delete();
          b_hist[i].delete();
        end
        k_cnt <= 0;
        busy  <= 0;
      end
    end
  end

endmodule


module sub_sys #(
  parameter int DIN_WIDTH = 8,
  parameter int N         = 4,
  parameter int BUS_WIDTH = 2*DIN_WIDTH*N
)(
  input  logic                  rst_n,
  input  logic                  sys_clk,
  input  logic                  sr_clk,
  input  logic [7:0]            M_minus_one,
  input  logic [BUS_WIDTH-1:0]  din,
  input  logic                  wr_fifo,
  input  logic                  rd_fifo,
  output logic                  in_fifo_full,
  output logic [BUS_WIDTH-1:0]  dout,
  output logic                  out_fifo_empty
);

  typedef logic signed [DIN_WIDTH-1:0]   din_t;
  typedef logic signed [2*DIN_WIDTH-1:0] acc_t;

  localparam int DEPTH = 16;

  logic [BUS_WIDTH-1:0] in_mem  [0:DEPTH-1];
  int                   in_wptr, in_rptr, in_count;

  logic [BUS_WIDTH-1:0] out_mem [0:DEPTH-1];
  int                   out_wptr, out_rptr, out_count;

  assign in_fifo_full   = (in_count == DEPTH);
  assign out_fifo_empty = (out_count == 0);
  assign dout           = (out_count > 0) ? out_mem[out_rptr] : '0;

  // Input FIFO (sys_clk)
  always_ff @(posedge sys_clk or negedge rst_n) begin
    if (!rst_n) begin
      in_wptr  <= 0;
      in_rptr  <= 0;
      in_count <= 0;
    end else begin
      if (wr_fifo && !in_fifo_full) begin
        in_mem[in_wptr] <= din;
        in_wptr         <= (in_wptr + 1) % DEPTH;
        in_count        <= in_count + 1;
      end
      if (rd_fifo && (in_count > 0)) begin
        in_rptr  <= (in_rptr + 1) % DEPTH;
        in_count <= in_count - 1;
      end
    end
  end

  // Systolic array instance (sr_clk domain)
  logic [DIN_WIDTH-1:0]       a_din [0:N-1];
  logic [DIN_WIDTH-1:0]       b_din [0:N-1];
  logic [2*DIN_WIDTH-1:0]     c_din [0:N-1];
  logic [2*DIN_WIDTH-1:0]     c_dout[0:N-1];
  logic                       in_valid, out_valid;

  int unsigned M;
  always_comb M = M_minus_one + 1;

  genvar gi;
  generate
    for (gi = 0; gi < N; gi++) begin : C_LOOP
      assign c_din[gi] = '0;
    end
  endgenerate

  systolic_array #(
    .DIN_WIDTH(DIN_WIDTH),
    .N        (N)
  ) u_sa (
    .rst_n    (rst_n),
    .clk      (sr_clk),
    .c_din    (c_din),
    .a_din    (a_din),
    .b_din    (b_din),
    .in_valid (in_valid),
    .c_dout   (c_dout),
    .out_valid(out_valid)
  );

  logic [BUS_WIDTH-1:0] in_sample;
  assign in_sample = in_mem[in_rptr];

  always_ff @(posedge sr_clk or negedge rst_n) begin
    if (!rst_n) begin
      in_valid <= 0;
    end else begin
      in_valid <= 0;
      if (in_count > 0) begin
        for (int i = 0; i < N; i++) begin
          a_din[i] <= in_sample[i*DIN_WIDTH +: DIN_WIDTH];
          b_din[i] <= in_sample[(N+i)*DIN_WIDTH +: DIN_WIDTH];
        end
        in_valid <= 1;
      end
    end
  end

  // Output FIFO (sr_clk write, sys_clk read)
  always_ff @(posedge sr_clk or negedge rst_n) begin
    if (!rst_n) begin
      out_wptr  <= 0;
      out_count <= 0;
    end else begin
      if (out_valid && (out_count < DEPTH)) begin
        logic [BUS_WIDTH-1:0] packed_data;
        for (int i = 0; i < N; i++) begin
          packed_data[i*2*DIN_WIDTH +: 2*DIN_WIDTH] = c_dout[i];
        end
        out_mem[out_wptr] <= packed_data;
        out_wptr          <= (out_wptr + 1) % DEPTH;
        out_count         <= out_count + 1;
      end
    end
  end

  always_ff @(posedge sys_clk or negedge rst_n) begin
    if (!rst_n) begin
      out_rptr <= 0;
    end else begin
      if (rd_fifo && (out_count > 0)) begin
        out_rptr  <= (out_rptr + 1) % DEPTH;
        out_count <= out_count - 1;
      end
    end
  end

endmodule

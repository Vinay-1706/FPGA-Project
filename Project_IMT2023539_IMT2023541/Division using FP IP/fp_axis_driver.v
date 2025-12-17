module fp_axis_driver (
  input  wire        clk,
  input  wire        rstn,

  // AXIS A
  output reg  [31:0] s_axis_a_tdata,
  output reg         s_axis_a_tvalid,
  input  wire        s_axis_a_tready,

  // AXIS B
  output reg  [31:0] s_axis_b_tdata,
  output reg         s_axis_b_tvalid,
  input  wire        s_axis_b_tready,

  // AXIS result - connected to IP result
  input  wire [31:0] m_axis_result_tdata,
  input  wire        m_axis_result_tvalid,
  output reg         m_axis_result_tready
);

  // small test vector ROM (IEEE-754 single, hex). We'll provide pairs (A,B) to compute A/B.
  // Example: 32'h3f800000 = 1.0f, 0x40000000 = 2.0f, etc.
  localparam NUM_VECTORS = 8;
  reg [31:0] vect_a [0:NUM_VECTORS-1];
  reg [31:0] vect_b [0:NUM_VECTORS-1];
  integer idx;

  initial begin
    // fill test vectors (hex IEEE-754 single)
    vect_a[0] = 32'h3f800000; // 1.0
    vect_b[0] = 32'h40000000; // 2.0 -> 1/2 = 0.5
    vect_a[1] = 32'h40400000; // 3.0
    vect_b[1] = 32'h3f800000; // 1.0 -> 3.0
    vect_a[2] = 32'hc1200000; // -10.0
    vect_b[2] = 32'h41200000; // 10.0 -> -1.0
    vect_a[3] = 32'h00000000; // 0.0
    vect_b[3] = 32'h3f800000; // 1.0 -> 0.0
    vect_a[4] = 32'h3f800000; // 1.0
    vect_b[4] = 32'h00000000; // 0.0 -> Inf (div by zero)
    vect_a[5] = 32'h7f800000; // +Inf
    vect_b[5] = 32'h3f800000; // 1.0 -> Inf
    vect_a[6] = 32'h7fc00000; // NaN
    vect_b[6] = 32'h3f800000; // NaN
    vect_a[7] = 32'h3f000000; // 0.5
    vect_b[7] = 32'h3f800000; // 1.0 -> 0.5
  end

  reg [3:0] state;
  localparam S_IDLE = 0, S_SEND = 1, S_WAIT = 2, S_DONE = 3;

  initial begin
    s_axis_a_tdata = 32'd0;
    s_axis_a_tvalid = 1'b0;
    s_axis_b_tdata = 32'd0;
    s_axis_b_tvalid = 1'b0;
    m_axis_result_tready = 1'b1; // always ready to accept result
    state = S_IDLE;
    idx = 0;
  end

  always @(posedge clk) begin
    if (!rstn) begin
      s_axis_a_tvalid <= 1'b0;
      s_axis_b_tvalid <= 1'b0;
      idx <= 0;
      state <= S_IDLE;
    end else begin
      case (state)
        S_IDLE: begin
          if (idx < NUM_VECTORS) begin
            s_axis_a_tdata <= vect_a[idx];
            s_axis_b_tdata <= vect_b[idx];
            s_axis_a_tvalid <= 1'b1;
            s_axis_b_tvalid <= 1'b1;
            state <= S_SEND;
          end else begin
            s_axis_a_tvalid <= 1'b0;
            s_axis_b_tvalid <= 1'b0;
            state <= S_DONE;
          end
        end

        S_SEND: begin
          // Wait until both s_axis_* accepted by IP (tready asserted)
          if (s_axis_a_tready && s_axis_b_tready) begin
            s_axis_a_tvalid <= 1'b0;
            s_axis_b_tvalid <= 1'b0;
            state <= S_WAIT;
          end
        end

        S_WAIT: begin
          // wait for a result (m_axis_result_tvalid from IP); m_axis_result_tready kept high
          if (m_axis_result_tvalid) begin
            // The result is visible on m_axis_result_tdata. The top-level exposes it.
            idx <= idx + 1;
            state <= S_IDLE;
          end
        end

        S_DONE: begin
          // no-op
        end
      endcase
    end
  end
endmodule

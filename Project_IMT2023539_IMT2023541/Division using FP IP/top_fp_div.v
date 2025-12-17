// top_fp_div.v
// Top wrapper that instantiates the generated Xilinx Floating-Point IP (Divide, single-precision, AXI-Stream)
// It provides a simple interface: send operand A & B via internal driver (or external pins).

module top_fp_div (
    input  wire clk,
    input  wire rstn,
    // optional external I/O could be added here to feed operands in hardware
    output wire [31:0] result_out,
    output wire        result_valid_out
);

  // wires for AXI-Stream A (dividend), B (divisor), and result
  wire [31:0] s_axis_a_tdata;
  wire        s_axis_a_tvalid;
  wire        s_axis_a_tready;

  wire [31:0] s_axis_b_tdata;
  wire        s_axis_b_tvalid;
  wire        s_axis_b_tready;

  wire [31:0] m_axis_result_tdata;
  wire        m_axis_result_tvalid;
  wire        m_axis_result_tready;

  // expose result
  assign result_out = m_axis_result_tdata;
  assign result_valid_out = m_axis_result_tvalid;

  // Instantiate the generated Floating-Point IP
  // Replace floating_point_0 with the exact module name your Vivado generated.
  floating_point_0 fp_div_inst (
    .aclk(clk),
    //.aresetn(rstn),

    // operand A (dividend) AXIS
    .s_axis_a_tvalid(s_axis_a_tvalid),
    .s_axis_a_tready(s_axis_a_tready),
    .s_axis_a_tdata(s_axis_a_tdata),

    // operand B (divisor) AXIS
    .s_axis_b_tvalid(s_axis_b_tvalid),
    .s_axis_b_tready(s_axis_b_tready),
    .s_axis_b_tdata(s_axis_b_tdata),

    // result AXIS
    .m_axis_result_tvalid(m_axis_result_tvalid),
    .m_axis_result_tready(m_axis_result_tready),
    .m_axis_result_tdata(m_axis_result_tdata)
  );

  // Simple internal driver: for simulation/demo we create a small FSM driver
  // In real hardware you will drive tvalid/tdata from an AXIS master or DMA.

  // We'll instantiate a small driver module (below) that will produce s_axis_* signals for testbench/hardware use.
  fp_axis_driver driver (
    .clk(clk),
    .rstn(rstn),
    .s_axis_a_tdata(s_axis_a_tdata),
    .s_axis_a_tvalid(s_axis_a_tvalid),
    .s_axis_a_tready(s_axis_a_tready),
    .s_axis_b_tdata(s_axis_b_tdata),
    .s_axis_b_tvalid(s_axis_b_tvalid),
    .s_axis_b_tready(s_axis_b_tready),
    .m_axis_result_tdata(m_axis_result_tdata),
    .m_axis_result_tvalid(m_axis_result_tvalid),
    .m_axis_result_tready(m_axis_result_tready)
  );

endmodule

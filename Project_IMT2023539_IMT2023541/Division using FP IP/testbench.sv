// tb_fp_div.v
`timescale 1ns/1ps
module tb_fp_div;

  reg clk;
  reg rstn;

  wire [31:0] result_out;
  wire        result_valid_out;

  // instantiate DUT
  top_fp_div uut (
    .clk(clk),
    .rstn(rstn),
    .result_out(result_out),
    .result_valid_out(result_valid_out)
  );

  // Clock: 10 ns period => 100 MHz
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Reset sequence
  initial begin
    rstn = 0;
    #100;
    rstn = 1;
  end

  // Monitor results and display as float/hex
  integer i;
  reg [31:0] result_reg;
  reg [31:0] cycle;
  initial begin
    cycle = 0;
    $display("Time(ns)\tResult(hex)\tResult(float)\tvalid");
    forever begin
      @(posedge clk);
      cycle = cycle + 1;
        if (result_valid_out) begin
            result_reg = result_out;
            $display("Time=%0dns | A=0x%08h | B=0x%08h | Result=0x%08h | float=%f",
                     $time,
                     uut.driver.vect_a[uut.driver.idx],
                     uut.driver.vect_b[uut.driver.idx],
                     result_reg,
                     $bitstoshortreal(result_reg));
        end
    end
  end
    
    initial begin
        #0;
        $display("Starting simulation");
        #5000;       // <-- enough time for all 8 outputs
        $display("Finished simulation");
        $finish;
    end


endmodule

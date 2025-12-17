`timescale 1ns/1ps

module tb_fp_div_iterative_pipe_stream;

    reg clk = 0;
    always #5 clk = ~clk;   // 100 MHz

    reg rst_n;
    reg valid_in;
    reg [31:0] a, b;

    wire ready;
    wire valid_out;
    wire [31:0] result;

    fp_div_iterative_pipe dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (valid_in),
        .a        (a),
        .b        (b),
        .ready    (ready),
        .valid_out(valid_out),
        .result   (result)
    );

    // simple test vector arrays
    reg [31:0] A_vec [0:3];
    reg [31:0] B_vec [0:3];
    integer i;
    integer issue_cycle0, first_out_cycle, cycle_counter;
    integer out_idx;

    initial begin
        // 6/2, 1/3, 0/5, 5/0
        A_vec[0] = 32'h40C00000;  B_vec[0] = 32'h40000000; // 6/2
        A_vec[1] = 32'h3F800000;  B_vec[1] = 32'h40400000; // 1/3
        A_vec[2] = 32'h00000000;  B_vec[2] = 32'h40A00000; // 0/5
        A_vec[3] = 32'h40A00000;  B_vec[3] = 32'h00000000; // 5/0

        rst_n     = 0;
        valid_in  = 0;
        a         = 0;
        b         = 0;
        out_idx   = 0;
        cycle_counter = 0;

        #40;
        rst_n = 1;

        // wait one clock after reset
        @(posedge clk);

        // ---------- FEED 4 INPUTS BACK-TO-BACK ----------
        issue_cycle0 = cycle_counter;  // remember cycle count at first issue

        for (i = 0; i < 4; i = i + 1) begin
            @(posedge clk);
            a        <= A_vec[i];
            b        <= B_vec[i];
            valid_in <= 1'b1;
        end

        // stop issuing after 4 inputs
        @(posedge clk);
        valid_in <= 1'b0;
    end

    // simple free-running cycle counter for measurement
    always @(posedge clk) begin
        if (!rst_n)
            cycle_counter <= 0;
        else
            cycle_counter <= cycle_counter + 1;
    end

    // monitor outputs: this will show 1 result per cycle once pipeline is full
    always @(posedge clk) begin
        if (valid_out) begin
            if (out_idx == 0)
                first_out_cycle = cycle_counter;  // mark when first result appears

            $display("OUT[%0d] at cycle %0d: res = 0x%h",
                     out_idx, cycle_counter, result);
            out_idx = out_idx + 1;
        end
    end

    // Stop after some time
    initial begin
        #2000;
        $display("Simulation finished.");
        $finish;
    end

endmodule
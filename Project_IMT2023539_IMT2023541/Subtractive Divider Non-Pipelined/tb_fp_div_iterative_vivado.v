// tb_fp_div_iterative.v
`timescale 1ns/1ps

module tb_fp_div_iterative;

    reg clk = 0;
    always #5 clk = ~clk;   // 100 MHz

    reg rst_n;
    reg valid_in;
    reg [31:0] a, b;

    wire ready;
    wire valid_out;
    wire [31:0] result;

    // DUT
    fp_div_iterative dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (valid_in),
        .a        (a),
        .b        (b),
        .ready    (ready),
        .valid_out(valid_out),
        .result   (result)
    );

    integer cycles;

    initial begin
        rst_n    = 0;
        valid_in = 0;
        a        = 32'd0;
        b        = 32'd0;

        #40;
        rst_n = 1;

        @(posedge clk);

        // 6.0 / 2.0 = 3.0
        run_case(32'h40C00000, 32'h40000000, "6/2");

        // 1.0 / 3.0 ≈ 0.3333
        run_case(32'h3F800000, 32'h40400000, "1/3");

        // 0 / 5 = 0
        run_case(32'h00000000, 32'h40A00000, "0/5");

        // 5 / 0 = +inf
        run_case(32'h40A00000, 32'h00000000, "5/0");

        #200;
        $display("TB finished");
        $finish;
    end

    task run_case;
        input [31:0] ta;
        input [31:0] tb;
        input [79:0] label;
        begin
            // wait until DUT is ready
            while (!ready) @(posedge clk);

            @(posedge clk);
            a        = ta;
            b        = tb;
            valid_in = 1'b1;
            cycles   = 0;

            @(posedge clk);
            valid_in = 1'b0;

            // wait for result
            while (!valid_out) begin
                @(posedge clk);
                cycles = cycles + 1;
                if (cycles > 200) begin
                    $display("TIMEOUT on %0s", label);
                    disable run_case;
                end
            end

            $display("%0s: a=0x%h b=0x%h -> res=0x%h (cycles=%0d)",
                     label, ta, tb, result, cycles);
        end
    endtask

endmodule

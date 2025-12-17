// fp_div_iterative_pipe.v
// Fully pipelined IEEE-754 single-precision divider
// Restoring (subtractive) division on mantissas, 24 pipeline stages.
// One result per clock after initial latency (about 25 cycles).
//
// Rounding: truncate mantissa (no guard/round/sticky).
// Ready is always 1 (streaming interface).

module fp_div_iterative_pipe (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        valid_in,
    input  wire [31:0] a,
    input  wire [31:0] b,

    output wire        ready,      // always ready to take new data
    output reg         valid_out,
    output reg  [31:0] result
);

    assign ready = 1'b1;

    // ------------------------------------------------------------
    // Parameters
    // ------------------------------------------------------------
    localparam N_STAGES = 24;               // quotient bits
    localparam signed [9:0] EXP_BIAS = 10'sd127;

    // ------------------------------------------------------------
    // Break out IEEE-754 fields
    // ------------------------------------------------------------
    wire sign_a = a[31];
    wire sign_b = b[31];
    wire [7:0] exp_a  = a[30:23];
    wire [7:0] exp_b  = b[30:23];
    wire [22:0] frac_a = a[22:0];
    wire [22:0] frac_b = b[22:0];

    // Special cases
    wire a_zero = (exp_a == 8'd0 && frac_a == 23'd0);
    wire b_zero = (exp_b == 8'd0 && frac_b == 23'd0);
    wire a_inf  = (exp_a == 8'hFF && frac_a == 23'd0);
    wire b_inf  = (exp_b == 8'hFF && frac_b == 23'd0);
    wire a_nan  = (exp_a == 8'hFF && frac_a != 23'd0);
    wire b_nan  = (exp_b == 8'hFF && frac_b != 23'd0);

    // ------------------------------------------------------------
    // Stage 0 decode / pre-processing (combinational)
    // ------------------------------------------------------------
    reg        is_special0;
    reg [31:0] special_result0;
    reg [23:0] mant_a0, mant_b0;
    reg        res_sign0;
    reg signed [9:0] exp_diff0;

    always @(*) begin
        // defaults
        is_special0      = 1'b0;
        special_result0  = 32'd0;
        mant_a0          = 24'd0;
        mant_b0          = 24'd0;
        res_sign0        = 1'b0;
        exp_diff0        = 10'sd0;

        if (!valid_in) begin
            // leave defaults; valid flag will be 0 so it won't matter
        end
        else if (a_nan || b_nan) begin
            is_special0     = 1'b1;
            special_result0 = {1'b0, 8'hFF, 1'b1, 22'd0}; // quiet NaN
        end
        else if (a_inf && b_inf) begin
            is_special0     = 1'b1;
            special_result0 = {1'b0, 8'hFF, 1'b1, 22'd0}; // NaN
        end
        else if (a_inf) begin
            is_special0     = 1'b1;
            special_result0 = {sign_a ^ sign_b, 8'hFF, 23'd0}; // inf
        end
        else if (b_inf) begin
            is_special0     = 1'b1;
            special_result0 = {sign_a ^ sign_b, 8'd0, 23'd0};  // 0
        end
        else if (b_zero) begin
            if (a_zero) begin
                is_special0     = 1'b1;
                special_result0 = {1'b0, 8'hFF, 1'b1, 22'd0}; // 0/0 -> NaN
            end else begin
                is_special0     = 1'b1;
                special_result0 = {sign_a ^ sign_b, 8'hFF, 23'd0}; // x/0 -> inf
            end
        end
        else if (a_zero) begin
            is_special0     = 1'b1;
            special_result0 = {sign_a ^ sign_b, 8'd0, 23'd0};   // 0/x -> 0
        end
        else begin
            // normal case
            if (exp_a == 8'd0)
                mant_a0 = {1'b0, frac_a}; // subnormal approx
            else
                mant_a0 = {1'b1, frac_a};

            if (exp_b == 8'd0)
                mant_b0 = {1'b0, frac_b};
            else
                mant_b0 = {1'b1, frac_b};

            res_sign0 = sign_a ^ sign_b;

            // exp_diff = exp_a - exp_b (signed)
            exp_diff0 = $signed({2'b00, exp_a}) -
                        $signed({2'b00, exp_b});
        end
    end

    // ------------------------------------------------------------
    // Pipeline registers for mantissa division and meta-data
    // ------------------------------------------------------------
    reg [48:0]        rem_pipe  [0:N_STAGES];   // remainder per stage
    reg [23:0]        quot_pipe [0:N_STAGES];   // quotient per stage
    reg [23:0]        dvsr_pipe [0:N_STAGES];   // divisor mantissa per stage

    reg signed [9:0]  exp_diff_pipe [0:N_STAGES];
    reg               res_sign_pipe [0:N_STAGES];
    reg               is_special_pipe [0:N_STAGES];
    reg [31:0]        special_result_pipe [0:N_STAGES];
    reg               valid_pipe [0:N_STAGES];

    integer i;

    // ------------------------------------------------------------
    // Pipeline update
    // ------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i <= N_STAGES; i = i + 1) begin
                rem_pipe[i]           <= 49'd0;
                quot_pipe[i]          <= 24'd0;
                dvsr_pipe[i]          <= 24'd0;
                exp_diff_pipe[i]      <= 10'sd0;
                res_sign_pipe[i]      <= 1'b0;
                is_special_pipe[i]    <= 1'b0;
                special_result_pipe[i]<= 32'd0;
                valid_pipe[i]         <= 1'b0;
            end
            result    <= 32'd0;
            valid_out <= 1'b0;
        end else begin
            // ---- Stage 0 load from inputs ----
            rem_pipe[0]            <= (is_special0 || !valid_in) ? 49'd0 : {mant_a0, 24'd0};
            quot_pipe[0]           <= 24'd0;
            dvsr_pipe[0]           <= mant_b0;
            exp_diff_pipe[0]       <= exp_diff0;
            res_sign_pipe[0]       <= res_sign0;
            is_special_pipe[0]     <= is_special0;
            special_result_pipe[0] <= special_result0;
            valid_pipe[0]          <= valid_in;

            // ---- Mantissa division stages (1..N_STAGES) ----
            for (i = 0; i < N_STAGES; i = i + 1) begin
                // propagate meta-data one stage down
                exp_diff_pipe[i+1]       <= exp_diff_pipe[i];
                res_sign_pipe[i+1]       <= res_sign_pipe[i];
                is_special_pipe[i+1]     <= is_special_pipe[i];
                special_result_pipe[i+1] <= special_result_pipe[i];
                valid_pipe[i+1]          <= valid_pipe[i];
                dvsr_pipe[i+1]           <= dvsr_pipe[i];

                if (is_special_pipe[i] || !valid_pipe[i]) begin
                    // no mantissa division for specials or invalid
                    rem_pipe[i+1]  <= 49'd0;
                    quot_pipe[i+1] <= 24'd0;
                end else begin
                    if (rem_pipe[i][48:24] >= {1'b0, dvsr_pipe[i]}) begin
                        rem_pipe[i+1]  <= (rem_pipe[i] - {dvsr_pipe[i], 24'd0}) << 1;
                        quot_pipe[i+1] <= {quot_pipe[i][22:0], 1'b1};
                    end else begin
                        rem_pipe[i+1]  <= rem_pipe[i] << 1;
                        quot_pipe[i+1] <= {quot_pipe[i][22:0], 1'b0};
                    end
                end
            end

            // ---- Register final result from combinational block below ----
            result    <= result_next;
            valid_out <= valid_out_next;
        end
    end

    // ------------------------------------------------------------
    // Final normalization and exponent adjust (combinational)
    // uses stage N_STAGES outputs
    // ------------------------------------------------------------
    reg [31:0] result_next;
    reg        valid_out_next;
    reg signed [9:0] exp_tmp;
    reg [23:0] mant_tmp;

    always @(*) begin
        valid_out_next = valid_pipe[N_STAGES];

        if (!valid_pipe[N_STAGES]) begin
            result_next = 32'd0;
        end else if (is_special_pipe[N_STAGES]) begin
            result_next = special_result_pipe[N_STAGES];
        end else begin
            // normalize quotient mantissa
            if (quot_pipe[N_STAGES][23] == 1'b1) begin
                mant_tmp = quot_pipe[N_STAGES];
                exp_tmp  = exp_diff_pipe[N_STAGES] + EXP_BIAS;
            end else begin
                mant_tmp = quot_pipe[N_STAGES] << 1;
                exp_tmp  = exp_diff_pipe[N_STAGES] + EXP_BIAS - 10'sd1;
            end

            // exponent range checks
            if (exp_tmp >= 10'sd255) begin
                result_next = {res_sign_pipe[N_STAGES], 8'hFF, 23'd0};
            end else if (exp_tmp <= 10'sd0) begin
                result_next = {res_sign_pipe[N_STAGES], 8'd0, 23'd0};
            end else begin
                // truncate mantissa (no rounding)
                result_next = {res_sign_pipe[N_STAGES], exp_tmp[7:0], mant_tmp[22:0]};
            end
        end
    end

endmodule

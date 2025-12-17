module fp_div_iterative (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        valid_in,   
    input  wire [31:0] a,          // dividend 
    input  wire [31:0] b,          // divisor 

    output reg         ready,      // high when unit can accept new input
    output reg         valid_out,  // 1-cycle pulse when result is valid
    output reg  [31:0] result      
);

    // ----------------------------------------------------------------
    // Parameters and FSM states
    // ----------------------------------------------------------------
    localparam signed [9:0] EXP_BIAS = 10'sd127;

    localparam [2:0]
        S_IDLE = 3'd0,
        S_PREP = 3'd1,
        S_LOAD = 3'd2,
        S_ITER = 3'd3,
        S_NORM = 3'd4,
        S_DONE = 3'd5;

    reg [2:0] state, next_state;

    // ----------------------------------------------------------------
    // Break out IEEE-754 fields
    // ----------------------------------------------------------------
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

    wire special_case =
           a_nan || b_nan ||
           (a_inf && b_inf) ||
           a_inf || b_inf ||
           b_zero || a_zero;

    // ----------------------------------------------------------------
    // Internal registers
    // ----------------------------------------------------------------
    reg [23:0] mant_a, mant_b;    // 1.frac (24 bits)
    reg        res_sign;

    // exponent difference and result exponent (signed, 10 bits)
    reg  signed [9:0] exp_diff;
    reg  signed [9:0] exp_res_dbg;  // optional debug (not required)

    // Restoring divider registers
    reg [48:0] rem;               // remainder
    reg [23:0] dvsr;              // divisor mantissa
    reg [23:0] quot;              // quotient mantissa
    reg [5:0]  iter;              // 24 iterations

    // temporaries for normalization (used inside S_NORM)
    reg  signed [9:0] exp_tmp;
    reg [23:0] mant_tmp;

    // ----------------------------------------------------------------
    // FSM state + handshake
    // ----------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            ready     <= 1'b1;
            valid_out <= 1'b0;
        end else begin
            state <= next_state;

            case (next_state)
                S_IDLE: begin
                    ready     <= 1'b1;
                    valid_out <= 1'b0;
                end
                S_DONE: begin
                    ready     <= 1'b1;
                    valid_out <= 1'b1;
                end
                default: begin
                    ready     <= 1'b0;
                    valid_out <= 1'b0;
                end
            endcase
        end
    end

    // ----------------------------------------------------------------
    // Next-state logic
    // ----------------------------------------------------------------
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (valid_in && ready)
                    next_state = S_PREP;
            end

            S_PREP: begin
                if (special_case)
                    next_state = S_DONE;
                else
                    next_state = S_LOAD;
            end

            S_LOAD: begin
                next_state = S_ITER;
            end

            S_ITER: begin
                if (iter == 6'd0)
                    next_state = S_NORM;
            end

            S_NORM: begin
                next_state = S_DONE;
            end

            S_DONE: begin
                next_state = S_IDLE;
            end

            default: next_state = S_IDLE;
        endcase
    end

    // ----------------------------------------------------------------
    // Datapath
    // ----------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mant_a   <= 24'd0;
            mant_b   <= 24'd0;
            res_sign <= 1'b0;
            exp_diff <= 10'sd0;
            exp_res_dbg <= 10'sd0;
            rem      <= 49'd0;
            dvsr     <= 24'd0;
            quot     <= 24'd0;
            iter     <= 6'd0;
            result   <= 32'd0;
        end else begin
            case (state)
                // ----------------------------------------------------
                S_IDLE: begin
                    // nothing
                end

                // ----------------------------------------------------
                // Special Cases
                // ----------------------------------------------------
                S_PREP: begin
                    if (a_nan || b_nan) begin
                        // quiet NaN
                        result <= {1'b0, 8'hFF, 1'b1, 22'd0};
                    end else if (a_inf && b_inf) begin
                        // inf/inf -> NaN
                        result <= {1'b0, 8'hFF, 1'b1, 22'd0};
                    end else if (a_inf) begin
                        // inf / finite -> inf
                        result <= {sign_a ^ sign_b, 8'hFF, 23'd0};
                    end else if (b_inf) begin
                        // finite / inf -> 0
                        result <= {sign_a ^ sign_b, 8'd0, 23'd0};
                    end else if (b_zero) begin
                        if (a_zero)
                            result <= {1'b0, 8'hFF, 1'b1, 22'd0};  // 0/0 -> NaN
                        else
                            result <= {sign_a ^ sign_b, 8'hFF, 23'd0}; // x/0 -> inf
                    end else if (a_zero) begin
                        // 0/x -> 0
                        result <= {sign_a ^ sign_b, 8'd0, 23'd0};
                    end else begin
                        // normal operands
                        if (exp_a == 8'd0)
                            mant_a <= {1'b0, frac_a};  // subnormal approx
                        else
                            mant_a <= {1'b1, frac_a};

                        if (exp_b == 8'd0)
                            mant_b <= {1'b0, frac_b};
                        else
                            mant_b <= {1'b1, frac_b};

                        res_sign <= sign_a ^ sign_b;

                        // exp_diff = exp_a - exp_b (signed)
                        exp_diff <= $signed({2'b00, exp_a}) -
                                    $signed({2'b00, exp_b});
                    end
                end

                // ----------------------------------------------------
                // Initialize restoring divider after mant_a/b latched
                // ----------------------------------------------------
                S_LOAD: begin
                    rem  <= {mant_a, 24'd0};  // mant_a << 24
                    dvsr <= mant_b;
                    quot <= 24'd0;
                    iter <= 6'd24;
                end

                // ----------------------------------------------------
                // Restoring division core: 1 quotient bit per cycle
                // ----------------------------------------------------
                S_ITER: begin
                    if (iter != 6'd0) begin
                        if (rem[48:24] >= {1'b0, dvsr}) begin
                            rem  <= (rem - {dvsr, 24'd0}) << 1;
                            quot <= {quot[22:0], 1'b1};
                        end else begin
                            rem  <= rem << 1;
                            quot <= {quot[22:0], 1'b0};
                        end
                        iter <= iter - 6'd1;
                    end
                end

                // ----------------------------------------------------
                // Normalize mantissa and compute final exponent
                // ----------------------------------------------------
                S_NORM: begin
                    // Use temporaries with blocking assignment
                    if (quot[23] == 1'b1) begin
                        mant_tmp = quot;                                // 1.xxxx
                        exp_tmp  = exp_diff + EXP_BIAS;                // +127
                    end else begin
                        mant_tmp = quot << 1;                           // shift if leading 0
                        exp_tmp  = exp_diff + EXP_BIAS - 10'sd1;       // +126
                    end

                    exp_res_dbg <= exp_tmp; // optional debug

                    // Handle overflow / underflow
                    if (exp_tmp >= 10'sd255) begin
                        // overflow -> inf
                        result <= {res_sign, 8'hFF, 23'd0};
                    end else if (exp_tmp <= 10'sd0) begin
                        // underflow -> 0 (subnormals flushed)
                        result <= {res_sign, 8'd0, 23'd0};
                    end else begin
                        // normal case: truncate mantissa (no rounding)
                        result <= {res_sign, exp_tmp[7:0], mant_tmp[22:0]};
                    end
                end

                // ----------------------------------------------------
                S_DONE: begin
                    // result stable
                end
            endcase
        end
    end

endmodule

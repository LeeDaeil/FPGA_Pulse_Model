module fp32_adder (
    input  [31:0] a,
    input  [31:0] b,
    output [31:0] result
);
    wire sign_a = a[31];
    wire sign_b = b[31];
    wire [7:0] exp_a = a[30:23];
    wire [7:0] exp_b = b[30:23];
    wire [23:0] mant_a = (exp_a == 0) ? {1'b0, a[22:0]} : {1'b1, a[22:0]};
    wire [23:0] mant_b = (exp_b == 0) ? {1'b0, b[22:0]} : {1'b1, b[22:0]};

    reg [7:0] exp_diff;
    reg [23:0] aligned_a, aligned_b;
    reg [7:0] exp_res;
    reg [24:0] mant_sum;
    reg sign_res;
    reg [22:0] frac_res;

    always @(*) begin
        // 지수 맞춤
        if (exp_a > exp_b) begin
            exp_diff = exp_a - exp_b;
            aligned_a = mant_a;
            aligned_b = mant_b >> exp_diff;
            exp_res = exp_a;
            sign_res = sign_a;
        end else begin
            exp_diff = exp_b - exp_a;
            aligned_a = mant_a >> exp_diff;
            aligned_b = mant_b;
            exp_res = exp_b;
            sign_res = sign_b;
        end

        // 같은 부호만 지원 (간단 버전)
        if (sign_a == sign_b) begin
            mant_sum = aligned_a + aligned_b;
            if (mant_sum[24]) begin
                mant_sum = mant_sum >> 1;
                exp_res = exp_res + 1;
            end
        end else begin
            // 부호 다르면 뺄셈인데, 여기선 간단히 무시
            mant_sum = 0;
        end

        frac_res = mant_sum[22:0];
    end

    assign result = {sign_res, exp_res, frac_res};
endmodule

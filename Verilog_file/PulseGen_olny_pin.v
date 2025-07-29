`timescale 1ns / 1ps

module PulseGen(
    input wire clk,
    input wire [31:0] cps,
    output reg [31:0] bram_addr,
    output reg [31:0] bram_data_in,
    output reg bram_we_pin,
    output reg ena_pin,
    output reg bram_we_pulse,
    output reg ena_pulse
);
    reg [9:0] lfsr = 10'b1010101010;  // 10비트 초기값
    reg [31:0] count = 0;
    reg [31:0] prev_cps = 0;

    always @(posedge clk) begin
        if (cps == 0) begin
            bram_addr <= 0;
            lfsr <= 10'b1010101010;
            count <= 0;
            prev_cps <= 0;
            bram_we <= 0;
            ena <= 0;
        end else begin
            // cps가 변경되었을 경우 재시작
            if (cps != prev_cps) begin
                count <= 0;
                lfsr <= 10'b1010101010;
                prev_cps <= cps;
                ena <= 0;
                bram_we <= 0;
            end else if (count < cps) begin
                // 10비트 LFSR: x^10 + x^7 + 1
                lfsr <= {lfsr[8:0], lfsr[9] ^ lfsr[6]};

                bram_data_in <= 1;                   // 예시값
                bram_addr <= lfsr * 4;                // 0 ~ 1023 개 가능
                bram_we <= 1;
                ena <= 1;
                count <= count + 1;
            end else begin
                bram_we <= 0;
                ena <= 0;
            end 
        end
    end
endmodule


module tb_PulseGen();

    // Inputs
    reg clk;
    reg [31:0] cps;

    // Outputs
    wire [31:0] bram_addr;
    wire [31:0] bram_data_in;
    wire bram_we;
    wire ena;

    // Instantiate the Unit Under Test (UUT)
    PulseGen uut (
        .clk(clk),
        .cps(cps),
        .bram_addr(bram_addr),
        .bram_data_in(bram_data_in),
        .bram_we(bram_we),
        .ena(ena)
    );

    // Clock generation: 10ns period
    always #5 clk = ~clk;

    initial begin
        $dumpfile("Verilog_file/PulseGen.vcd");
        $dumpvars(0, tb_PulseGen);
        // Initialize inputs
        clk = 0;
        cps = 0;

        // Wait for global reset
        #20;

        // Test 1: cps = 0 → 모듈 초기화 상태 유지
        cps = 0;
        #50;

        // Test 2: cps = 10 → 10개의 pulse 발생
        cps = 10;
        #1000;

        // Test 3: cps = 5 → 다시 시작됨 (변경된 cps 값)
        cps = 5;
        #500;

        // Test 4: cps = 0 → 종료
        cps = 0;
        #100;

        $finish;
    end

endmodule
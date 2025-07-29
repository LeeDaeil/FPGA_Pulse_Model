`timescale 1ns / 1ps

module PulseGenStM(
    input wire clk,
    input wire [31:0] cps,
    output reg [31:0] bram_addr,
    output reg [31:0] bram_data_in,
    output reg [31:0] bram_data_pulse_in,
    output reg bram_we,
    output reg ena
);
    // 상태 정의
    parameter IDLE = 2'b00,
              INIT = 2'b01,
              RUN  = 2'b10,
              DONE = 2'b11;
    parameter GEN_LFSR = 2'b00;
    parameter READ_MEM = 2'b01;

    reg [1:0] state = IDLE;
    reg [1:0] sub_state = GEN_LFSR;

    reg [9:0] lfsr = 10'b1010101010;
    reg [31:0] count = 0;
    reg [31:0] sub_count = 0;
    reg [31:0] prev_cps = 0;

    always @(posedge clk) begin
        case (state)
            IDLE: begin
                bram_we <= 0;
                ena <= 0;
                bram_addr <= 0;
                bram_data_in <= 0;
                count <= 0;
                lfsr <= 10'b1010101010;

                sub_count <= 0;
                sub_state <= GEN_LFSR;

                if (cps > 0) begin
                    prev_cps <= cps;
                    state <= INIT;
                end
            end

            INIT: begin
                count <= 0;
                lfsr <= 10'b1010101010;
                bram_we <= 0;
                ena <= 0;
                state <= RUN;

                sub_count <= 0;
                sub_state <= GEN_LFSR;
            end

            RUN: begin
                if (cps != prev_cps) begin
                    prev_cps <= cps;
                    state <= INIT;

                    sub_count <= 0;
                    sub_state <= GEN_LFSR;
                end else if (count < cps) begin
                    case (sub_state)
                        GEN_LFSR: begin
                            // LFSR를 이용하여 주소 생성
                            lfsr <= {lfsr[8:0], lfsr[9] ^ lfsr[6]};
                            bram_addr <= lfsr * 4;  // 예시로 4배수 주소 사용
                            bram_data_in <= 1;      // 예시 데이터
                            bram_we <= 1;
                            ena <= 1;
                            count <= count + 1;
                            
                            sub_count <= 0;
                            sub_state <= READ_MEM; // 계속 LFSR 생성
                        end
                        READ_MEM: begin
                            // 현재 펄스 발생 시점 주소값 보내기
                            bram_addr <= bram_addr + sub_count * 4;  // 예시로 4배수 주소 사용
                            bram_data_in <= sub_count + 2;

                            sub_count <= sub_count + 1;

                            if (sub_count >= 10) begin
                                sub_state <= GEN_LFSR; // 다음 LFSR 생성으로 전환
                            end else begin
                                sub_state <= READ_MEM; // 계속 읽기 상태 유지
                            end

                        end

                        default: begin
                            bram_we <= 0;
                            ena <= 0;
                        end
                    endcase

                end else begin
                    state <= DONE;
                end
            end

            DONE: begin
                bram_we <= 0;
                ena <= 0;
                if (cps == 0) begin
                    state <= IDLE;
                end else if (cps != prev_cps) begin
                    prev_cps <= cps;
                    state <= INIT;
                end
            end

            default: state <= IDLE;
        endcase
    end

endmodule


module tb_PulseGenStM();

    // Inputs
    reg clk;
    reg [31:0] cps;

    // Outputs
    wire [31:0] bram_addr;
    wire [31:0] bram_data_in;
    wire bram_we;
    wire ena;

    // Instantiate the Unit Under Test (UUT)
    PulseGenStM uut (
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
        $dumpfile("Verilog_file/PulseGenStM.vcd");
        $dumpvars(0, tb_PulseGenStM);
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
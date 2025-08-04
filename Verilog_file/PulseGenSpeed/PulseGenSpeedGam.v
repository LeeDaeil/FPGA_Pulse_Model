`timescale 1ns / 1ps
`include "./Verilog_file/PulseGenSpeed/BRAM_Model.v"
`include "./Verilog_file/PulseGenSpeed/fp32_adder.v"

module PulseGenSpeedGam(
    input wire clk,
    input wire [31:0] cps,
    output reg [31:0] bram_addr,
    output reg [31:0] bram_data_in,
    output reg bram_we,
    output reg bram_ena,
    input wire [31:0] bram_data_out
);
    // reg [9:0] lfsr = 10'b1010101010;  // 10비트 초기값
    reg [10:0] lfsr = 11'b10101010101;  // 11비트 초기값
    reg [31:0] count = 0;
    reg [31:0] prev_cps = 0;
    reg [31:0] mem_count = 0;
    reg [1:0]  mem_gam_count = 0;
    reg [3:0]  mem_control_state = 0;

    // Neutron Pulse Data Table
    reg [31:0] float_data [0:12];

    initial begin
        float_data[0] = 32'h3D7C5048; // 0.0616
        float_data[1] = 32'h3E99652C; // 0.2996
        float_data[2] = 32'h3E0E3BCD; // 0.1389
        float_data[3] = 32'h3D83126F; // 0.0640
        float_data[4] = 32'h3CF1A9FC; // 0.0295
        float_data[5] = 32'h3C5ED289; // 0.0136
        float_data[6] = 32'h3BCE703B; // 0.0063
        float_data[7] = 32'h3B3E0DED; // 0.0029
        float_data[8] = 32'h3AAA64C3; // 0.0013
        float_data[9] = 32'h3A1D4952; // 0.0006
        float_data[10] = 32'h399D4952; // 0.0003
        float_data[11] = 32'h38D1B717; // 0.0001
        float_data[12] = 32'h38D1B717; // 0.0001
    end

    reg [31:0] save_data [0:12];
    initial begin
        save_data[0] = 32'd0;
        save_data[1] = 32'd0;
        save_data[2] = 32'd0;
        save_data[3] = 32'd0;
        save_data[4] = 32'd0;
        save_data[5] = 32'd0;
        save_data[6] = 32'd0;
        save_data[7] = 32'd0;
        save_data[8] = 32'd0;
        save_data[9] = 32'd0;
        save_data[10] = 32'd0;
        save_data[11] = 32'd0;
        save_data[12] = 32'd0;
    end
    
    reg [2:0] state;

    wire [31:0] float_add_result_0;
    wire [31:0] float_add_result_1;
    wire [31:0] float_add_result_2;
    wire [31:0] float_add_result_3;
    wire [31:0] float_add_result_4;
    wire [31:0] float_add_result_5;
    wire [31:0] float_add_result_6;
    wire [31:0] float_add_result_7;
    wire [31:0] float_add_result_8;
    wire [31:0] float_add_result_9;
    wire [31:0] float_add_result_10;
    wire [31:0] float_add_result_11;
    wire [31:0] float_add_result_12;
    // fp32_adder 모듈 인스턴스화
    fp32_adder adder0 (
        .a(save_data[0]),
        .b(float_data[0]),
        .result(float_add_result_0)
    );
    fp32_adder adder1 (
        .a(save_data[1]),
        .b(float_data[1]),
        .result(float_add_result_1)
    );
    fp32_adder adder2 (
        .a(save_data[2]),
        .b(float_data[2]),
        .result(float_add_result_2)
    );
    fp32_adder adder3 (
        .a(save_data[3]),
        .b(float_data[3]),
        .result(float_add_result_3)
    );
    fp32_adder adder4 (
        .a(save_data[4]),
        .b(float_data[4]),
        .result(float_add_result_4)
    );
    fp32_adder adder5 (
        .a(save_data[5]),
        .b(float_data[5]),
        .result(float_add_result_5)
    );
    fp32_adder adder6 (
        .a(save_data[6]),
        .b(float_data[6]),
        .result(float_add_result_6)
    );
    fp32_adder adder7 (
        .a(save_data[7]),
        .b(float_data[7]),
        .result(float_add_result_7)
    );
    fp32_adder adder8 (
        .a(save_data[8]),
        .b(float_data[8]),
        .result(float_add_result_8)
    );
    fp32_adder adder9 (
        .a(save_data[9]),
        .b(float_data[9]),
        .result(float_add_result_9)
    );
    fp32_adder adder10 (
        .a(save_data[10]),
        .b(float_data[10]),
        .result(float_add_result_10)
    );
    fp32_adder adder11 (
        .a(save_data[11]),
        .b(float_data[11]),
        .result(float_add_result_11)
    );
    fp32_adder adder12 (
        .a(save_data[12]),
        .b(float_data[12]),
        .result(float_add_result_12)
    );

    always @(posedge clk) begin
        if (cps == 0) begin
            // Module Input Section
                bram_addr <= 0;         // Bram 주소 초기화
                bram_we <= 0;           // Bram 쓰기 비활성화
                bram_ena <= 0;          // Bram 비활성화

            // Module Local Variables
            // lfsr <= 10'b1010101010;
            // lfsr <= 11'b10101010101; // 11비트 초기값
            lfsr <= {lfsr[9:0], lfsr[10] ^ lfsr[7]}; // 11비트 LFSR로 변경 (이전 변경 값을 가져다 씀)
            count <= 0;
            prev_cps <= 0;

            mem_count <= 0;
            mem_control_state <= 0;
        end else begin
            // cps가 변경되었을 경우 재시작
            if (cps != prev_cps) begin
                // Module Input Section
                bram_addr <= 0;         // Bram 주소 초기화
                bram_we <= 0;           // Bram 쓰기 비활성화
                bram_ena <= 1;          // Bram 활성화

                // Module Local Variables
                // lfsr <= 10'b1010101010;
                // lfsr <= 11'b10101010101; // 11비트 초기값
                lfsr <= {lfsr[9:0], lfsr[10] ^ lfsr[7]}; // 11비트 LFSR로 변경 (이전 변경 값을 가져다 씀)

                count <= 0;
                prev_cps <= cps;

                mem_count <= 0;
                mem_gam_count <= 0;     // 감마의 경우 2배
                mem_control_state <= 0;
            end else if (count < cps) begin
                case (mem_control_state)
                    0: begin
                        // 읽기 상태: Bram에서 데이터 읽기
                        // Module Input Section
                        bram_addr <= mem_count * 4; // 주소 설정 [0]
                        bram_we <= 0;               // Bram 쓰기 비활성화
                        bram_ena <= 1;              // Bram 활성화
                        // Module Local Variables
                        mem_count <= mem_count + 1; // 다음 인덱스로 이동
                        mem_control_state <= 1; // 다음 상태로 전환
                    end

                    1: begin
                        // 저장 상태: Bram에서 읽은 데이터 저장
                        bram_addr <= mem_count * 4; // 주소 설정 [1]
                        bram_we <= 0;               // Bram 쓰기 비활성화
                        bram_ena <= 1;              // Bram 활성화

                        // Module Local Variables
                        save_data[mem_count] <= bram_data_out; // 데이터 입력

                        if (mem_count < 13) begin
                            mem_count <= mem_count + 1; // 다음 인덱스로 이동
                        end else begin
                            mem_control_state <= 2; // 다음 상태로 전환
                            mem_count <= 0; // 인덱스 초기화
                        end
                    end

                    2: begin
                        // 계산 상태: 저장된 데이터와 Neutron Pulse Data Table의 데이터 더하기
                        save_data[0] <= float_add_result_0;
                        save_data[1] <= float_add_result_1;
                        save_data[2] <= float_add_result_2;
                        save_data[3] <= float_add_result_3;
                        save_data[4] <= float_add_result_4;
                        save_data[5] <= float_add_result_5;
                        save_data[6] <= float_add_result_6;
                        save_data[7] <= float_add_result_7;
                        save_data[8] <= float_add_result_8;
                        save_data[9] <= float_add_result_9;
                        save_data[10] <= float_add_result_10;
                        save_data[11] <= float_add_result_11;
                        save_data[12] <= float_add_result_12;
                        mem_control_state <= 3; // 다음 상태로 전환
                    end

                    3: begin
                        // 쓰기 상태: 계산된 데이터를 Bram에 쓰기
                        bram_addr <= mem_count * 4; // 주소 설정 [1]
                        bram_we <= 1;               // Bram 쓰기 활성화
                        bram_ena <= 1;              // Bram 활성화
                        // Module Local Variables
                        bram_data_in <= save_data[mem_count]; // 저장된 데이터 쓰기

                        if (mem_count < 13) begin
                            mem_count <= mem_count + 1; // 다음 인덱스로 이동
                        end else begin
                            mem_count <= 0; // 인덱스 초기화
                            mem_control_state <= 4; // 다음 상태로 전환
                        end
                    end

                    4: begin
                        // 완료 상태: 모든 작업 완료 후 초기화
                        bram_we <= 0;               // Bram 쓰기 비활성화
                        bram_ena <= 0;              // Bram 비활성화

                        if (mem_gam_count == 1) begin
                            count <= count + 1;         // CPS 카운트 증가
                            mem_gam_count <= 0;
                        end else begin
                            mem_gam_count <= mem_gam_count + 1;
                        end
                        
                        mem_control_state <= 0;     // 상태 초기화
                    end
                endcase
            end
        end
    end
endmodule


module tb_PulseGenSpeedGam();

    // Inputs
    reg clk;
    reg [31:0] cps;

    // Outputs
    wire [31:0] bram_addr;
    wire [31:0] bram_data_in;
    wire bram_we;
    wire bram_ena;

    wire [31:0] bram_data_out;

    // Instantiate the Unit Under Test (UUT)
    PulseGenSpeedGam uut (
        .clk(clk),
        .cps(cps),
        .bram_addr(bram_addr),
        .bram_data_in(bram_data_in),
        .bram_we(bram_we),
        .bram_ena(bram_ena),
        .bram_data_out(bram_data_out)
    );

    bram pulse_bram_inst (
        .clka(clk),
        .ena(bram_ena),
        .wea(bram_we),
        .addra(bram_addr),
        .dina(bram_data_in),
        .douta(bram_data_out)
    );

    // Clock generation: 10ns period
    always #5 clk = ~clk;

    initial begin
        $dumpfile("Verilog_file/PulseGenSpeed/PulseGenSpeedGam.vcd");
        $dumpvars(0, tb_PulseGenSpeedGam);
        // Initialize inputs
        clk = 0;
        cps = 0;

        // Wait for global reset
        #20;

        // Test 1: cps = 0 → 모듈 초기화 상태 유지
        cps = 0;
        #50;

        // Test 2: cps = 10 → 10개의 pulse 발생
        cps = 1;
        #2000;

        cps = 0;
        #50

        // Test 2: cps = 10 → 10개의 pulse 발생
        cps = 1;
        #2000;

        cps = 0;
        #50

        // // Test 2: cps = 10 → 10개의 pulse 발생
        // cps = 1;
        // #1000;

        // // Test 3: cps = 5 → 다시 시작됨 (변경된 cps 값)
        // cps = 5;
        // #500;

        // // Test 4: cps = 0 → 종료
        // cps = 0;
        // #100;

        $finish;
    end

endmodule
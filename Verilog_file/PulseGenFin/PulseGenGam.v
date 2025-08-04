`timescale 1ns / 1ps
`include "./Verilog_file/BRAM_Model.v"
`include "./Verilog_file/fp32_adder.v"

module PulseGenGam(
    input wire clk,
    input wire [31:0] cps,
    output reg [31:0] bram_addr,
    output reg [31:0] bram_data_in,
    output reg ena,
    output reg bram_we,
    input wire [31:0] bram_data_out
);
    // reg [9:0] lfsr = 10'b1010101010;  // 10비트 초기값
    reg [10:0] lfsr = 11'b10101010101;  // 11비트 초기값

    reg [31:0] count = 0;
    reg [31:0] prev_cps = 0;

    reg [31:0] mem_count = 0;
    reg [31:0] count_gam = 0;

    reg [3:0] mem_control_state = 0;

    // Gamma Pulse Data Table
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

    wire [31:0] fp_add_result;
    reg [31:0] fp_table_input;

    fp32_adder adder_inst (
        .a(bram_data_out),
        .b(fp_table_input),         // IEEE 754
        .result(fp_add_result)
    );

    always @(posedge clk) begin
        if (cps == 0) begin
            // Input/Output Parameter --
            bram_addr <= 0;
            ena <= 0;
            bram_we <= 0;

            // Local Parameter --
            // lfsr <= 10'b1010101010;
            // lfsr <= 11'b10101010101; // 11비트 초기값
            lfsr <= {lfsr[9:0], lfsr[10] ^ lfsr[7]}; // 11비트 LFSR로 변경 (이전 변경 값을 가져다 씀)
            
            count <= 0;
            prev_cps <= 0;

            mem_count <= 0;
            count_gam <= 0;

            mem_control_state <= 0;
        end else begin
            // cps가 변경되었을 경우 재시작
            if (cps != prev_cps) begin
                // Input/Output Parameter --
                bram_addr <= 0;
                ena <= 0;
                bram_we <= 0;

                // Local Parameter --
                // lfsr <= 10'b1010101010;
                // lfsr <= 11'b10101010101; // 11비트 초기값
                lfsr <= {lfsr[9:0], lfsr[10] ^ lfsr[7]}; // 11비트 LFSR로 변경 (이전 변경 값을 가져다 씀)

                count <= 0;
                prev_cps <= cps;

                mem_count <= 0;
                count_gam <= 0;

                mem_control_state <= 0;
            end else if (count < cps) begin
                if (mem_count == 0) begin
                    // Input/Output Parameter --
                    // bram_addr <= 32'b100; // lfsr * 4;                // 0 ~ 1023 개 가능
                    bram_addr <= lfsr * 4;                // 11비트 0 ~ 2047 개 가능
                    bram_data_in <= 0;                    // Pulse Initialization
                    ena <= 1;                             // 활성화         
                    bram_we <= 0;                         // 펄스 읽기

                    // Local Parameter --
                    // 10비트 LFSR: x^10 + x^7 + 1
                    // lfsr <= {lfsr[8:0], lfsr[9] ^ lfsr[6]};
                    lfsr <= {lfsr[9:0], lfsr[10] ^ lfsr[7]}; // 11비트 LFSR로 변경
                    
                    // Pulse 메모리에 1 부터 증가하는 값 쓰기
                    mem_count <= 1;                 // 메모리 카운트 증가

                    mem_control_state <= 1;
                end else begin
                    if (mem_count > 13) begin
                        // 메모리 카운트가 13 이상이면 펄스 종료
                        // Input/Output Parameter --
                        ena <= 0;                             // 비횔성화      
                        bram_we <= 0;                         // 펄스 읽기
                        // Local Parameter --
                        mem_count <= 0;                 // 메모리 카운트 초기화

                        mem_control_state <= 0;         // BRAM 제어 상태 초기화
                        // Gamma Pulse 카운트 증가 (1 cps = 2 pulse)
                        if (count_gam == 1) begin
                            count <= count + 1;
                            count_gam <= 0;
                        end else begin
                            count_gam <= count_gam + 1;
                        end

                    end else begin
                        case (mem_control_state)
                            0: begin
                                bram_addr <= bram_addr + 4;
                                bram_we <= 0;                   // 펄스 읽기
                                ena <= 1;                       // 활성화
                                // 주소 유지
                                mem_control_state <= 1;
                            end
                            1: begin
                                // 대기 
                                bram_we <= 0;                   // 펄스 읽기
                                ena <= 0;                       // 비활성화
                                //
                                fp_table_input <= float_data[mem_count - 1]; // 0.1 ~ 0.6
                                mem_control_state <= 2;
                            end
                            2: begin
                                // write 완료, 다음 주소로 이동
                                bram_addr <= bram_addr;
                                bram_data_in <= fp_add_result;

                                bram_we <= 1;                   // 펄스 쓰기
                                ena <= 1;                       // 활성화
                                //
                                mem_count <= mem_count + 1;
                                mem_control_state <= 0; // 다음 루프
                            end
                        endcase
                    end
                end

            end else begin
                bram_we <= 0;                   
                ena <= 0;

                mem_count <= 0;
            end 
        end
    end
endmodule


module tb_PulseGenGam();

    // Inputs
    reg clk;
    reg [31:0] cps;

    // Outputs
    wire [31:0] bram_addr;
    wire [31:0] bram_data_in;
    wire ena;
    wire bram_we;
    wire [31:0] bram_data_out;

    // Instantiate the Unit Under Test (UUT)
    PulseGenGam uut (
        .clk(clk),
        .cps(cps),
        .bram_addr(bram_addr),
        .bram_data_in(bram_data_in),
        .ena(ena),
        .bram_we(bram_we),
        .bram_data_out(bram_data_out)
    );

    bram pulse_bram_inst (
        .clka(clk),
        .ena(ena),
        .wea(bram_we),
        .addra(bram_addr),
        .dina(bram_data_in),
        .douta(bram_data_out)  // Read output not used in this test
    );

    // Clock generation: 10ns period
    always #5 clk = ~clk;

    initial begin
        $dumpfile("Verilog_file/PulseGenFin/PulseGenGam.vcd");
        $dumpvars(0, tb_PulseGenGam);
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
        #500;

        // // Test 3: cps = 5 → 다시 시작됨 (변경된 cps 값)
        // cps = 5;
        // #500;

        // // Test 4: cps = 0 → 종료
        // cps = 0;
        // #100;

        $finish;
    end

endmodule
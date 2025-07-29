`timescale 1ns / 1ps
`include "./Verilog_file/BRAM_Model.v"
`include "./Verilog_file/fp32_adder.v"

module PulseGen(
    input wire clk,
    input wire [31:0] cps,
    output reg [31:0] bram_addr,
    output reg [31:0] bram_data_in,
    output reg bram_we_pin,
    output reg ena_pin,

    output reg [31:0] bram_addr_pulse,
    output reg [31:0] bram_data_in_pulse,
    output reg bram_we_pulse,
    output reg ena_pulse,

    input wire [31:0] bram_data_out_pulse
);
    reg [9:0] lfsr = 10'b1010101010;  // 10비트 초기값
    reg [31:0] count = 0;
    reg [31:0] prev_cps = 0;

    reg [31:0] mem_count = 0;

    reg [3:0] mem_control_state = 0;
    reg [31:0] prev_mem_val = 0;

    // Data Table
    reg [31:0] float_data [0:4];

    initial begin
        float_data[0] = 32'h3DCCCCCD; // 0.1
        float_data[1] = 32'h3E4CCCCD; // 0.2
        float_data[2] = 32'h3E99999A; // 0.3
        float_data[3] = 32'h3ECCCCCD; // 0.4
        float_data[4] = 32'h3F000000; // 0.5
    end

    wire [31:0] fp_add_result;
    reg [31:0] fp_table_input;

    fp32_adder adder_inst (
        .a(bram_data_out_pulse),
        .b(fp_table_input), // 1.0 in IEEE 754
        .result(fp_add_result)
    );

    always @(posedge clk) begin
        if (cps == 0) begin
            bram_addr <= 0;
            
            lfsr <= 10'b1010101010;
            count <= 0;
            prev_cps <= 0;
            bram_we_pin <= 0;
            ena_pin <= 0;

            bram_we_pulse <= 0;
            ena_pulse <= 0;
            bram_addr_pulse <= 0;

            mem_count <= 0;
            mem_control_state <= 0;

        end else begin
            // cps가 변경되었을 경우 재시작
            if (cps != prev_cps) begin
                count <= 0;
                lfsr <= 10'b1010101010;
                prev_cps <= cps;
                ena_pin <= 0;
                bram_we_pin <= 0;

                bram_we_pulse <= 0;
                ena_pulse <= 0;
                mem_count <= 0;
                mem_control_state <= 0;

            end else if (count < cps) begin
                if (mem_count == 0) begin
                    // 10비트 LFSR: x^10 + x^7 + 1
                    lfsr <= {lfsr[8:0], lfsr[9] ^ lfsr[6]};

                    bram_data_in <= 1;                    // 펄스 발생 시점 값
                    bram_addr <= 32'b100; // lfsr * 4;                // 0 ~ 1023 개 가능

                    bram_data_in_pulse <= 1;              // 펄스 값
                    bram_addr_pulse <= 32'b100; //lfsr * 4;          // 0 ~ 1023 개 가능

                    // Pin 메모리에 1 값 쓰기.
                    bram_we_pin <= 1;
                    ena_pin <= 1;
                    
                    // Pulse 메모리에 1 부터 증가하는 값 쓰기
                    bram_we_pulse <= 0;             // 펄스 읽기
                    ena_pulse <= 1;                 // 활성화
                    mem_count <= 1;                 // 메모리 카운트 증가

                    mem_control_state <= 1;

                end else begin
                    if (mem_count > 5) begin
                        // 메모리 카운트가 5 이상이면 펄스 종료
                        bram_we_pulse <= 0;             // 펄스 종료
                        ena_pulse <= 0;                 // 비활성화
                        mem_count <= 0;                 // 메모리 카운트 초기화

                        mem_control_state <= 0;         // BRAM 제어 상태 초기화

                        // Pin 메모리 정지
                        bram_we_pin <= 0;
                        ena_pin <= 0;
                        count <= count + 1;

                    end else begin
                        case (mem_control_state)
                            0: begin
                                bram_addr_pulse <= bram_addr_pulse + 4;
                                bram_we_pulse <= 0;     // 펄스 읽기
                                ena_pulse <= 1;
                                // 주소 유지
                                mem_control_state <= 1;
                            end
                            1: begin
                                // 대기 
                                bram_we_pulse <= 0;     // 펄스 읽기
                                ena_pulse <= 0;

                                fp_table_input <= float_data[mem_count - 1]; // 0.1 ~ 0.6

                                mem_control_state <= 2;
                            end
                            2: begin
                                // write 완료, 다음 주소로 이동
                                bram_we_pulse <= 1;     // 펄스 쓰기
                                ena_pulse <= 1;
                                
                                bram_data_in_pulse <= fp_add_result;

                                bram_addr_pulse <= bram_addr_pulse;

                                mem_count <= mem_count + 1;
                                mem_control_state <= 0; // 다음 루프
                            end
                        endcase
                    end
                end

            end else begin
                bram_we_pin <= 0;
                ena_pin <= 0;

                bram_we_pulse <= 0;
                ena_pulse <= 0;
                mem_count <= 0;
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
    wire bram_we_pin;
    wire ena_pin;

    wire [31:0] bram_addr_pulse;
    wire [31:0] bram_data_in_pulse;
    wire bram_we_pulse;
    wire ena_pin_pulse;

    wire [31:0] bram_data_out_pulse;

    // Instantiate the Unit Under Test (UUT)
    PulseGen uut (
        .clk(clk),
        .cps(cps),
        .bram_addr(bram_addr),
        .bram_data_in(bram_data_in),
        .bram_we_pin(bram_we_pin),
        .ena_pin(ena_pin),
        .bram_addr_pulse(bram_addr_pulse),
        .bram_data_in_pulse(bram_data_in_pulse),
        .bram_we_pulse(bram_we_pulse),
        .ena_pulse(ena_pulse),
        .bram_data_out_pulse(bram_data_out_pulse)
    );

    bram pin_bram_inst (
        .clka(clk),
        .ena(ena_pin),
        .wea(bram_we_pin),
        .addra(bram_addr),
        .dina(bram_data_in),
        .douta()  // Read output not used in this test
    );

    bram pulse_bram_inst (
        .clka(clk),
        .ena(ena_pulse),
        .wea(bram_we_pulse),
        .addra(bram_addr_pulse),
        .dina(bram_data_in_pulse),
        .douta(bram_data_out_pulse)  // Read output not used in this test
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
        cps = 1;
        #500;

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
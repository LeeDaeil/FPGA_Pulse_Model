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
    // reg [9:0] lfsr = 10'b1010101010;  // 10비트 초기값
    reg [10:0] lfsr = 11'b10101010101;  // 11비트 초기값

    reg [31:0] count = 0;
    reg [31:0] prev_cps = 0;

    reg [31:0] mem_count = 0;

    reg [3:0] mem_control_state = 0;
    reg [31:0] prev_mem_val = 0;

    // Neutron Pulse Data Table
    reg [31:0] float_data [0:49];

    initial begin
        float_data[0] = 32'h3DA339C1; // 0.0797
        float_data[1] = 32'h3F59AD43; // 0.8503
        float_data[2] = 32'h3F73A29C; // 0.9517
        float_data[3] = 32'h3F652546; // 0.8951
        float_data[4] = 32'h3F4EC56D; // 0.8077
        float_data[5] = 32'h3F388CE7; // 0.7209
        float_data[6] = 32'h3F242C3D; // 0.6413
        float_data[7] = 32'h3F11EB85; // 0.57
        float_data[8] = 32'h3F01A9FC; // 0.5065
        float_data[9] = 32'h3EE67382; // 0.4501
        float_data[10] = 32'h3ECCBFB1; // 0.3999
        float_data[11] = 32'h3EB5F6FD; // 0.3554
        float_data[12] = 32'h3EA1B08A; // 0.3158
        float_data[13] = 32'h3E8FAACE; // 0.2806
        float_data[14] = 32'h3E7F4880; // 0.2493
        float_data[15] = 32'h3E62D0E5; // 0.2215
        float_data[16] = 32'h3E4985F0; // 0.1968
        float_data[17] = 32'h3E3318FC; // 0.1749
        float_data[18] = 32'h3E1F212D; // 0.1554
        float_data[19] = 32'h3E0D6A16; // 0.1381
        float_data[20] = 32'h3DFB4A23; // 0.1227
        float_data[21] = 32'h3DDF3B64; // 0.109
        float_data[22] = 32'h3DC67382; // 0.0969
        float_data[23] = 32'h3DB05532; // 0.0861
        float_data[24] = 32'h3D9CAC08; // 0.0765
        float_data[25] = 32'h3D8B4396; // 0.068
        float_data[26] = 32'h3D7765FE; // 0.0604
        float_data[27] = 32'h3D5B8BAC; // 0.0536
        float_data[28] = 32'h3D436113; // 0.0477
        float_data[29] = 32'h3D2DAB9F; // 0.0424
        float_data[30] = 32'h3D1A0275; // 0.0376
        float_data[31] = 32'h3D08CE70; // 0.0334
        float_data[32] = 32'h3CF34D6A; // 0.0297
        float_data[33] = 32'h3CD844D0; // 0.0264
        float_data[34] = 32'h3CC08312; // 0.0235
        float_data[35] = 32'h3CAA64C3; // 0.0208
        float_data[36] = 32'h3C978D50; // 0.0185
        float_data[37] = 32'h3C872B02; // 0.0165
        float_data[38] = 32'h3C6F34D7; // 0.0146
        float_data[39] = 32'h3C54FDF4; // 0.013
        float_data[40] = 32'h3C3C6A7F; // 0.0115
        float_data[41] = 32'h3C28C155; // 0.0103
        float_data[42] = 32'h3C15182B; // 0.0091
        float_data[43] = 32'h3C04B5DD; // 0.0081
        float_data[44] = 32'h3BEBEDFA; // 0.0072
        float_data[45] = 32'h3BD1B717; // 0.0064
        float_data[46] = 32'h3BBAC711; // 0.0057
        float_data[47] = 32'h3BA3D70A; // 0.005
        float_data[48] = 32'h3B9374BC; // 0.0045
        float_data[49] = 32'h3B83126F; // 0.004
    end

    wire [31:0] fp_add_result;
    reg [31:0] fp_table_input;

    fp32_adder adder_inst (
        .a(bram_data_out_pulse),
        .b(fp_table_input),         // IEEE 754
        .result(fp_add_result)
    );

    always @(posedge clk) begin
        if (cps == 0) begin
            bram_addr <= 0;
            // lfsr <= 10'b1010101010;
            // lfsr <= 11'b10101010101; // 11비트 초기값
            lfsr <= {lfsr[9:0], lfsr[10] ^ lfsr[7]}; // 11비트 LFSR로 변경 (이전 변경 값을 가져다 씀)
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
                // lfsr <= 10'b1010101010;
                // lfsr <= 11'b10101010101; // 11비트 초기값
                lfsr <= {lfsr[9:0], lfsr[10] ^ lfsr[7]}; // 11비트 LFSR로 변경 (이전 변경 값을 가져다 씀)

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
                    // lfsr <= {lfsr[8:0], lfsr[9] ^ lfsr[6]};

                    lfsr <= {lfsr[9:0], lfsr[10] ^ lfsr[7]}; // 11비트 LFSR로 변경

                    bram_data_in <= 1;                    // 펄스 발생 시점 값
                    // bram_addr <= 32'b100; // lfsr * 4;                // 0 ~ 1023 개 가능
                    bram_addr <= lfsr * 4;                // 11비트 0 ~ 2047 개 가능

                    bram_data_in_pulse <= 1;              // 펄스 값
                    // bram_addr_pulse <= 32'b100; //lfsr * 4;          // 0 ~ 1023 개 가능
                    bram_addr_pulse <= lfsr * 4;                // 11비트 0 ~ 2047 개 가능

                    // Pin 메모리에 1 값 쓰기.
                    bram_we_pin <= 1;
                    ena_pin <= 1;
                    
                    // Pulse 메모리에 1 부터 증가하는 값 쓰기
                    bram_we_pulse <= 0;             // 펄스 읽기
                    ena_pulse <= 1;                 // 활성화
                    mem_count <= 1;                 // 메모리 카운트 증가

                    mem_control_state <= 1;

                end else begin
                    if (mem_count > 50) begin
                        // 메모리 카운트가 50 이상이면 펄스 종료
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
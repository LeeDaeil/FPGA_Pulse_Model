`timescale 1ns / 1ps
`include "./Verilog_file/PulseGenSpeed/BRAM_Model.v"
`include "./Verilog_file/PulseGenSpeed/fp32_adder.v"

module PulseGenSpeedNut(
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
    reg [3:0]  mem_control_state = 0;

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

    reg [31:0] save_data [0:49];
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
        save_data[13] = 32'd0;
        save_data[14] = 32'd0;
        save_data[15] = 32'd0;
        save_data[16] = 32'd0;
        save_data[17] = 32'd0;
        save_data[18] = 32'd0;
        save_data[19] = 32'd0;
        save_data[20] = 32'd0;
        save_data[21] = 32'd0;
        save_data[22] = 32'd0;
        save_data[23] = 32'd0;
        save_data[24] = 32'd0;
        save_data[25] = 32'd0;
        save_data[26] = 32'd0;
        save_data[27] = 32'd0;
        save_data[28] = 32'd0;
        save_data[29] = 32'd0;
        save_data[30] = 32'd0;
        save_data[31] = 32'd0;
        save_data[32] = 32'd0;
        save_data[33] = 32'd0;
        save_data[34] = 32'd0;
        save_data[35] = 32'd0;
        save_data[36] = 32'd0;
        save_data[37] = 32'd0;
        save_data[38] = 32'd0;
        save_data[39] = 32'd0;
        save_data[40] = 32'd0;
        save_data[41] = 32'd0;
        save_data[42] = 32'd0;
        save_data[43] = 32'd0;
        save_data[44] = 32'd0;
        save_data[45] = 32'd0;
        save_data[46] = 32'd0;
        save_data[47] = 32'd0;
        save_data[48] = 32'd0;
        save_data[49] = 32'd0;
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
    wire [31:0] float_add_result_13;
    wire [31:0] float_add_result_14;
    wire [31:0] float_add_result_15;
    wire [31:0] float_add_result_16;
    wire [31:0] float_add_result_17;
    wire [31:0] float_add_result_18;
    wire [31:0] float_add_result_19;
    wire [31:0] float_add_result_20;
    wire [31:0] float_add_result_21;
    wire [31:0] float_add_result_22;
    wire [31:0] float_add_result_23;
    wire [31:0] float_add_result_24;
    wire [31:0] float_add_result_25;
    wire [31:0] float_add_result_26;
    wire [31:0] float_add_result_27;
    wire [31:0] float_add_result_28;
    wire [31:0] float_add_result_29;
    wire [31:0] float_add_result_30;
    wire [31:0] float_add_result_31;
    wire [31:0] float_add_result_32;
    wire [31:0] float_add_result_33;
    wire [31:0] float_add_result_34;
    wire [31:0] float_add_result_35;
    wire [31:0] float_add_result_36;
    wire [31:0] float_add_result_37;
    wire [31:0] float_add_result_38;
    wire [31:0] float_add_result_39;
    wire [31:0] float_add_result_40;
    wire [31:0] float_add_result_41;
    wire [31:0] float_add_result_42;
    wire [31:0] float_add_result_43;
    wire [31:0] float_add_result_44;
    wire [31:0] float_add_result_45;
    wire [31:0] float_add_result_46;
    wire [31:0] float_add_result_47;
    wire [31:0] float_add_result_48;
    wire [31:0] float_add_result_49;
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
    fp32_adder adder13 (
        .a(save_data[13]),
        .b(float_data[13]),
        .result(float_add_result_13)
    );
    fp32_adder adder14 (
        .a(save_data[14]),
        .b(float_data[14]),
        .result(float_add_result_14)
    );
    fp32_adder adder15 (
        .a(save_data[15]),
        .b(float_data[15]),
        .result(float_add_result_15)
    );
    fp32_adder adder16 (
        .a(save_data[16]),
        .b(float_data[16]),
        .result(float_add_result_16)
    );
    fp32_adder adder17 (
        .a(save_data[17]),
        .b(float_data[17]),
        .result(float_add_result_17)
    );
    fp32_adder adder18 (
        .a(save_data[18]),
        .b(float_data[18]),
        .result(float_add_result_18)
    );
    fp32_adder adder19 (
        .a(save_data[19]),
        .b(float_data[19]),
        .result(float_add_result_19)
    );
    fp32_adder adder20 (
        .a(save_data[20]),
        .b(float_data[20]),
        .result(float_add_result_20)
    );
    fp32_adder adder21 (
        .a(save_data[21]),
        .b(float_data[21]),
        .result(float_add_result_21)
    );
    fp32_adder adder22 (
        .a(save_data[22]),
        .b(float_data[22]),
        .result(float_add_result_22)
    );
    fp32_adder adder23 (
        .a(save_data[23]),
        .b(float_data[23]),
        .result(float_add_result_23)
    );
    fp32_adder adder24 (
        .a(save_data[24]),
        .b(float_data[24]),
        .result(float_add_result_24)
    );
    fp32_adder adder25 (
        .a(save_data[25]),
        .b(float_data[25]),
        .result(float_add_result_25)
    );
    fp32_adder adder26 (
        .a(save_data[26]),
        .b(float_data[26]),
        .result(float_add_result_26)
    );
    fp32_adder adder27 (
        .a(save_data[27]),
        .b(float_data[27]),
        .result(float_add_result_27)
    );
    fp32_adder adder28 (
        .a(save_data[28]),
        .b(float_data[28]),
        .result(float_add_result_28)
    );
    fp32_adder adder29 (
        .a(save_data[29]),
        .b(float_data[29]),
        .result(float_add_result_29)
    );
    fp32_adder adder30 (
        .a(save_data[30]),
        .b(float_data[30]),
        .result(float_add_result_30)
    );
    fp32_adder adder31 (
        .a(save_data[31]),
        .b(float_data[31]),
        .result(float_add_result_31)
    );
    fp32_adder adder32 (
        .a(save_data[32]),
        .b(float_data[32]),
        .result(float_add_result_32)
    );
    fp32_adder adder33 (
        .a(save_data[33]),
        .b(float_data[33]),
        .result(float_add_result_33)
    );
    fp32_adder adder34 (
        .a(save_data[34]),
        .b(float_data[34]),
        .result(float_add_result_34)
    );
    fp32_adder adder35 (
        .a(save_data[35]),
        .b(float_data[35]),
        .result(float_add_result_35)
    );
    fp32_adder adder36 (
        .a(save_data[36]),
        .b(float_data[36]),
        .result(float_add_result_36)
    );
    fp32_adder adder37 (
        .a(save_data[37]),
        .b(float_data[37]),
        .result(float_add_result_37)
    );
    fp32_adder adder38 (
        .a(save_data[38]),
        .b(float_data[38]),
        .result(float_add_result_38)
    );
    fp32_adder adder39 (
        .a(save_data[39]),
        .b(float_data[39]),
        .result(float_add_result_39)
    );
    fp32_adder adder40 (
        .a(save_data[40]),
        .b(float_data[40]),
        .result(float_add_result_40)
    );
    fp32_adder adder41 (
        .a(save_data[41]),
        .b(float_data[41]),
        .result(float_add_result_41)
    );
    fp32_adder adder42 (
        .a(save_data[42]),
        .b(float_data[42]),
        .result(float_add_result_42)
    );
    fp32_adder adder43 (
        .a(save_data[43]),
        .b(float_data[43]),
        .result(float_add_result_43)
    );
    fp32_adder adder44 (
        .a(save_data[44]),
        .b(float_data[44]),
        .result(float_add_result_44)
    );
    fp32_adder adder45 (
        .a(save_data[45]),
        .b(float_data[45]),
        .result(float_add_result_45)
    );
    fp32_adder adder46 (
        .a(save_data[46]),
        .b(float_data[46]),
        .result(float_add_result_46)
    );
    fp32_adder adder47 (
        .a(save_data[47]),
        .b(float_data[47]),
        .result(float_add_result_47)
    );
    fp32_adder adder48 (
        .a(save_data[48]),
        .b(float_data[48]),
        .result(float_add_result_48)
    );
    fp32_adder adder49 (
        .a(save_data[49]),
        .b(float_data[49]),
        .result(float_add_result_49)
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

                        if (mem_count < 50) begin
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
                        save_data[13] <= float_add_result_13;   
                        save_data[14] <= float_add_result_14;
                        save_data[15] <= float_add_result_15;
                        save_data[16] <= float_add_result_16;
                        save_data[17] <= float_add_result_17;
                        save_data[18] <= float_add_result_18;
                        save_data[19] <= float_add_result_19;
                        save_data[20] <= float_add_result_20;
                        save_data[21] <= float_add_result_21;
                        save_data[22] <= float_add_result_22;
                        save_data[23] <= float_add_result_23;
                        save_data[24] <= float_add_result_24;
                        save_data[25] <= float_add_result_25;
                        save_data[26] <= float_add_result_26;
                        save_data[27] <= float_add_result_27;
                        save_data[28] <= float_add_result_28;
                        save_data[29] <= float_add_result_29;
                        save_data[30] <= float_add_result_30;
                        save_data[31] <= float_add_result_31;
                        save_data[32] <= float_add_result_32;
                        save_data[33] <= float_add_result_33;
                        save_data[34] <= float_add_result_34;
                        save_data[35] <= float_add_result_35;
                        save_data[36] <= float_add_result_36;
                        save_data[37] <= float_add_result_37;
                        save_data[38] <= float_add_result_38;
                        save_data[39] <= float_add_result_39;
                        save_data[40] <= float_add_result_40;
                        save_data[41] <= float_add_result_41;
                        save_data[42] <= float_add_result_42;
                        save_data[43] <= float_add_result_43;
                        save_data[44] <= float_add_result_44;
                        save_data[45] <= float_add_result_45;
                        save_data[46] <= float_add_result_46;
                        save_data[47] <= float_add_result_47;
                        save_data[48] <= float_add_result_48;
                        save_data[49] <= float_add_result_49;
                        mem_control_state <= 3; // 다음 상태로 전환
                    end

                    3: begin
                        // 쓰기 상태: 계산된 데이터를 Bram에 쓰기
                        bram_addr <= mem_count * 4; // 주소 설정 [1]
                        bram_we <= 1;               // Bram 쓰기 활성화
                        bram_ena <= 1;              // Bram 활성화
                        // Module Local Variables
                        bram_data_in <= save_data[mem_count]; // 저장된 데이터 쓰기

                        if (mem_count < 50) begin
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

                        count <= count + 1;         // CPS 카운트 증가
                        mem_control_state <= 0;     // 상태 초기화
                    end
                endcase
            end
        end
    end
endmodule


module tb_PulseGenSpeedNut();

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
    PulseGenSpeedNut uut (
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
        $dumpfile("Verilog_file/PulseGenSpeed/PulseGenSpeedNut.vcd");
        $dumpvars(0, tb_PulseGenSpeedNut);
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
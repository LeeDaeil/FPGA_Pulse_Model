`timescale 1ns / 1ps
`include "./Verilog_file/BRAM_Model.v"

module BRAMDumpData (
    input wire clk,
    input wire [31:0] cps,
    output reg [31:0] bram_addr,
    output reg [31:0] bram_data_in,
    output reg bram_we,
    output reg ena_pin,
    input wire [31:0] bram_data_out
);

    reg [31:0] save_data [0:9];
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
    end

    reg [2:0] state;
    // localparam READ = 2'd0, CALC = 2'd1, WRITE = 2'd2, DONE = 2'd3;

    reg [3:0] index;

    reg [31:0] prev_cps = 0;
    reg [31:0] count = 0;

    reg [31:0] mem_val = 0;

    always @(posedge clk) begin
        if (cps == 0) begin
            prev_cps <= 0;          // cps가 0이면 이전 값을 초기화
            count <= 0;             // 카운트 초기화 (cps 요구사항 도달 용)

            ena_pin <= 0;           // Bram 비활성화
            bram_we <= 0;           // Bram 쓰기 비활성화
            state <= 0;             // 초기 상태
            index <= 0;             // save_data 인덱스 초기화
        end else begin
            // cps가 변경되면 상태 머신 작동
            if (cps != prev_cps) begin
                prev_cps <= cps;    // 이전 cps 값 저장
                count <= 0;         // 카운트 초기화 (cps 요구사항 도달 용)

                ena_pin <= 1;       // Bram 활성화
                bram_we <= 0;       // Bram 쓰기 비활성화
                state <= 0;         // 초기 상태

                bram_addr <= 0;     // Bram 0번 주소 읽기 요청
                index <= 0;         // 인덱스 초기화
            end else if (count < cps) begin
                case (state)
                    0: begin
                        // 읽기 상태: Bram에서 데이터 읽기
                        ena_pin <= 1;                   // Bram 활성화
                        bram_we <= 0;                   // Bram 쓰기 비활성화
                        bram_addr <= index * 4;   // 다음 주소 읽기 요청 (1번 주소)
                        index <= index + 1; // 다음 인덱스로 이동
                        state <= 1; // 다음 상태로 전환
                    end

                    1: begin
                        // 읽기 상태: Bram에서 데이터 읽기
                        ena_pin <= 1;                   // Bram 활성화
                        bram_we <= 0;                   // Bram 쓰기 비활성화
                        bram_addr <= index * 4;   // 다음 주소 읽기 요청 (1번 주소)

                        save_data[index] <= bram_data_out; // 데이터 저장 (0번 주소)
                        mem_val <= bram_data_out; // 읽은 데이터 저장

                        if (index < 10) begin
                            index <= index + 1; // 다음 인덱스로 이동
                        end else begin
                            state <= 2; // 다음 상태로 전환
                            index <= 0; // 인덱스 초기화
                        end
                    end

                    2: begin
                        // 계산 상태: 예시로 각 데이터를 증가시키는 연산 수행
                        save_data[0] <= save_data[0] + 1;
                        save_data[1] <= save_data[1] + 2;
                        save_data[2] <= save_data[2] + 3;
                        save_data[3] <= save_data[3] + 4;
                        save_data[4] <= save_data[4] + 5;
                        save_data[5] <= save_data[5] + 6;
                        save_data[6] <= save_data[6] + 7;
                        save_data[7] <= save_data[7] + 8;
                        save_data[8] <= save_data[8] + 9;
                        save_data[9] <= save_data[9] + 10;
                        state <= 3; // 다음 상태로 전환
                    end

                    3: begin
                        // 쓰기 상태: 계산된 데이터를 Bram에 쓰기
                        ena_pin <= 1;                   // Bram 활성화
                        bram_we <= 1;                   // Bram 쓰기 활성화
                        bram_addr <= index * 4;         // 현재 인덱스 주소로 쓰기 요청
                        bram_data_in <= save_data[index]; // 저장된 데이터 쓰기

                        if (index < 10) begin
                            index <= index + 1; // 다음 인덱스로 이동
                        end else begin
                            state <= 4; // 다음 상태로 전환
                            index <= 0; // 인덱스 초기화
                        end
                    end

                    4: begin
                        // 완료 상태: 모든 작업이 완료되었음을 나타냄
                        ena_pin <= 0;                   // Bram 비활성화
                        bram_we <= 0;                   // Bram 쓰기 비활성화
                        state <= 0;                     // 상태 초기화
                        count <= count + 1;             // 카운트 증가
                    end
                endcase
            end
        end
    end
endmodule



module BRAMDumpData_tb;

    // 클럭 및 제어 신호
    reg clk;
    reg [31:0] cps;
    wire [31:0] bram_addr;
    wire [31:0] bram_data_in;
    wire [31:0] bram_data_out;
    wire bram_we;
    wire ena_pin;

    // BRAM 인스턴스
    BRAMDumpData uut (
        .clk(clk),
        .cps(cps),
        .bram_addr(bram_addr),
        .bram_data_in(bram_data_in),
        .bram_we(bram_we),
        .ena_pin(ena_pin),
        .bram_data_out(bram_data_out)
    );
    // BRAM 모델 인스턴스
    bram pin_bram_inst (
        .clka(clk),
        .ena(ena_pin),
        .wea(bram_we),
        .addra(bram_addr),
        .dina(bram_data_in),
        .douta(bram_data_out)  // Read output not used in this test
    );

      // Clock generation: 10ns period
    always #5 clk = ~clk;

    // 시뮬레이션 초기화 및 종료
    initial begin
        $dumpfile("Verilog_file/BRAMDumpData.vcd");
        $dumpvars(0, BRAMDumpData_tb);

        // 초기화
        clk = 0;
        cps = 0;
        #10;
        // Test 2: cps = 10 → 10개의 pulse 발생
        cps = 1;
        #500;
        cps = 0;
        #10;
        // Test 2: cps = 10 → 10개의 pulse 발생
        cps = 1;
        #500;

        $finish;
    end

endmodule

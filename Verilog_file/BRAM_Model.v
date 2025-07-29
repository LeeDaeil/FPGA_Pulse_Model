module bram(
    input  wire            clka,
    input  wire            ena,
    input  wire            wea,
    input  wire  [31:0]    addra,
    input  wire  [31:0]    dina,
    output reg   [31:0]    douta
);

    reg [31:0] mem [0:7999];
    reg [31:0] mem1;
    reg [31:0] mem2;
    reg [31:0] mem3;
    reg [31:0] mem4;
    reg [31:0] mem5;
    reg [31:0] mem6;

    // 13비트 주소 인덱스 (0~8191까지 가능, 실제는 0~7999만 사용)
    wire [12:0] addr_index = addra[12:0];

    integer i;

    // 초기화 블록 (시뮬레이션용)
    initial begin
        for (i = 0; i <= 7999; i = i + 1) begin
            mem[i] = 32'd0;
        end
    end

    // 동기식 동작 (읽기/쓰기)
    always @(posedge clka) begin
        if (ena) begin
            if (wea != 1'b0) begin
                mem[addr_index] = dina;
            end
            douta <= mem[addr_index];

            // 디버깅용 특정 위치 레지스터 저장
            mem1 <= mem[0];
            mem2 <= mem[4];
            mem3 <= mem[8];
            mem4 <= mem[12];
            mem5 <= mem[16];
            mem6 <= mem[20];

            // 디버깅 출력
            // $display("[READ ] MEM[%0d] [0x%08X] => 0x%08X", addr_index, dina, mem[addr_index]);
        end
    end

endmodule
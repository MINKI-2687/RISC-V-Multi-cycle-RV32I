`timescale 1ns / 1ps

module tb_rv32i ();

    logic clk, rst;
    logic [ 7:0] gpi;
    wire  [ 7:0] gpo;
    wire  [15:0] gpio;  // 0~7: SW(In), 8~15: LED(Out)
    wire  [ 3:0] fnd_digit;
    wire  [ 7:0] fnd_data;
    logic        uart_rx;
    wire         uart_tx;

    // --- GPIO 스위치 입력을 위한 가짜 레지스터 ---
    logic [ 7:0] gpio_sw;
    // --- 상위 8비트(LED)는 비워두고(Z), 하위 8비트에만 스위치 값 전달 ---
    assign gpio = {8'bz, gpio_sw};

    rv32i_mcu dut (.*);

    always #5 clk = ~clk;

    initial begin
        // 1. 초기 상태 설정
        clk = 0;
        rst = 1;
        gpi = 8'h00;
        gpio_sw = 8'h00;
        uart_rx = 1;  // UART IDLE 상태 유지

        @(negedge clk);
        @(negedge clk);
        rst = 0;

        // 2. CPU 부팅 및 C 코드 초기화(sys_init) 대기
        // 메모리에서 명령어를 가져와 세팅하는 데 수천 클럭이 필요합니다.
        #4500;

        // ==========================================
        // [테스트 1] 스위치에 0x1234 입력
        // ==========================================
        $display("--- Test 1: Input 0x1234 ---");
        gpi     = 8'h12;  // 상위 바이트 (왼쪽 스위치)
        gpio_sw = 8'h34;  // 하위 바이트 (오른쪽 스위치)

        // 소프트웨어가 while(1) 루프를 돌며 연산하고 결과를 출력할 때까지 대기
        #100000;

        // // ==========================================
        // // [테스트 2] 스위치에 0xABCD 입력
        // // ==========================================
        // $display("--- Test 2: Input 0xABCD ---");
        // gpi = 8'hAB;
        // gpio_sw = 8'hCD;

        // FND가 4자리를 모두 스캐닝하는 것을 보려면 엄청난 시간이 필요합니다.
        #5000;

        $display("Simulation Finished.");
        $stop;
    end
endmodule

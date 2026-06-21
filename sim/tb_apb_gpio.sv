`timescale 1ns / 1ps

module tb_apb_gpio ();

    // 1. APB 인터페이스 신호 선언
    logic        pclk;
    logic        preset;
    logic [31:0] paddr;
    logic [31:0] pwdata;
    logic        pwrite;
    logic        penable;
    logic        psel;
    wire         pready;
    wire  [31:0] prdata;

    // 2. 물리적 양방향(INOUT) 핀 제어를 위한 와이어 및 가상 드라이버
    wire  [15:0] gpio;
    logic [15:0] gpio_tb_drive;

    // Testbench가 gpio 핀에 값을 강제로 밀어넣기 위한 Tri-state 버퍼 연결
    assign gpio = gpio_tb_drive;

    // 3. 검증 대상(DUT) 인스턴시에이션 (오직 GPIO 모듈만!)
    APB_GPIO dut (
        .pclk   (pclk),
        .preset (preset),
        .paddr  (paddr),
        .pwdata (pwdata),
        .pwrite (pwrite),
        .penable(penable),
        .psel   (psel),
        .prdata (prdata),
        .pready (pready),
        .gpio   (gpio)      // INOUT 포트 연결
    );

    // 4. 클럭 생성 (100MHz)
    always #5 pclk = ~pclk;

    // =================================================================
    // [가상 CPU 역할] APB Write / Read 트랜잭션 Task 정의
    // =================================================================
    task apb_write(input [11:0] addr, input [31:0] data);
        begin
            @(posedge pclk);
            psel    = 1;
            pwrite  = 1;
            paddr   = addr;
            pwdata  = data;
            penable = 0;
            @(posedge pclk);
            penable = 1;
            wait (pready);  // Slave가 준비될 때까지 대기
            @(posedge pclk);
            psel = 0;
            penable = 0;
        end
    endtask

    task apb_read(input [11:0] addr, output [31:0] data);
        begin
            @(posedge pclk);
            psel    = 1;
            pwrite  = 0;
            paddr   = addr;
            penable = 0;
            @(posedge pclk);
            penable = 1;
            wait (pready);
            data = prdata;  // 버스에서 데이터 읽기
            @(posedge pclk);
            psel = 0;
            penable = 0;
        end
    endtask

    // =================================================================
    // 5. 메인 테스트 시나리오 시작
    // =================================================================
    logic [31:0] read_val;

    initial begin
        // 초기화
        pclk          = 0;
        preset        = 1;
        psel          = 0;
        penable       = 0;
        pwrite        = 0;
        paddr         = 0;
        pwdata        = 0;
        // 중요: Testbench는 초기 상태에서 핀에 아무 전기적 간섭을 하지 않음 (High-Z)
        gpio_tb_drive = 16'hZZZZ;

        #20 preset = 0;  // 리셋 해제
        #20;

        // [시나리오 1] 방향 설정 (C코드의 GPIO_init 역할)
        $display("1. Set Direction: Upper(LED/Out), Lower(SW/In)");
        apb_write(12'h000, 32'h0000_FF00);  // CTRL_REG (0x000) 에 FF00 쓰기

        // [시나리오 2] 외부 스위치 조작
        $display("2. Testbench drives 0x34 to lower 8 pins (Switches)");
        // 상위 8비트는 Z로 두어 DUT가 출력하게 내버려두고, 하위 8비트만 34로 강제 구동
        gpio_tb_drive = {8'hZZ, 8'h34};
        #50;  // 하드웨어가 IDATA_REG에 캡처할 시간 부여

        // [시나리오 3] 스위치 값 읽어오기
        $display("3. APB Read from IDATA_REG");
        apb_read(12'h008, read_val);  // IDATA_REG (0x008) 읽기
        $display("   -> CPU Read Value: 0x%0h", read_val);

        // [시나리오 4] 읽은 값을 시프트 연산하여 LED로 쏘기
        $display("4. APB Write to ODATA_REG (Shifted << 8)");
        apb_write(12'h004,
                  (read_val & 32'h0000_00FF) << 8);  // ODATA_REG (0x004) 쓰기

        // [최종 확인]
        #50;
        $display("========================================");
        $display("Final Physical GPIO Pin State: %0h", gpio);
        if (gpio[15:8] == 8'h34)
            $display("[SUCCESS] Loopback Verification Passed!");
        else $display("[FAIL] Loopback Verification Failed.");
        $display("========================================");

        #100;
        $stop;
    end
endmodule

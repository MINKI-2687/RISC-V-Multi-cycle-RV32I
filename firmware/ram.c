#include<stdint.h>

#define SYS_ERR             (-1)
#define SYS_OK              (0)

#define APB_BRAM            (0x10000000)
#define APB_PERIPHERAL_BASE (0x20000000)
#define APB_GPO             (APB_PERIPHERAL_BASE + 0x0000U)
#define APB_GPI             (APB_PERIPHERAL_BASE + 0x1000U)
#define APB_GPIO            (APB_PERIPHERAL_BASE + 0x2000U)
#define APB_FND             (APB_PERIPHERAL_BASE + 0x3000U)
#define APB_UART            (APB_PERIPHERAL_BASE + 0x4000U)

#define APB_GPO_CTRL        (APB_GPO + 0x00U)
#define APB_GPO_ODATA       (APB_GPO + 0x04U)
#define APB_GPI_CTRL        (APB_GPI + 0x00U)
#define APB_GPI_IDATA       (APB_GPI + 0x04U)
#define APB_GPIO_CTRL       (APB_GPIO + 0x00U)
#define APB_GPIO_ODATA      (APB_GPIO + 0x04U)
#define APB_GPIO_IDATA      (APB_GPIO + 0x08U)
#define APB_FND_CTRL        (APB_FND + 0x00U)
#define APB_FND_ODATA       (APB_FND + 0x04U)
#define APB_UART_CTRL       (APB_UART + 0x00U)
#define APB_UART_BAUD       (APB_UART + 0x04U)
#define APB_UART_STATUS     (APB_UART + 0x08U)
#define APB_UART_TXDATA     (APB_UART + 0x0CU)
#define APB_UART_RXDATA     (APB_UART + 0x10U)

#define __IO    volatile 

typedef struct {
    __IO uint32_t CTRL;
    __IO uint32_t ODATA;
    __IO uint32_t IDATA;
} GPIO_TYPEDEF;

#define GPIOA   ((GPIO_TYPEDEF *) APB_GPIO)

/* 함수 선언부 */
int sys_init(void);
void delay_ms(int delay);
void GPIO_init(GPIO_TYPEDEF *GPIOx, unsigned int control);
void led_write(GPIO_TYPEDEF *GPIOx, unsigned int wdata);
unsigned int sw_read(GPIO_TYPEDEF *GPIOx);

// =================================================================
// ★ 개조된 main 함수: 오직 RAM 동작만 테스트!
// =================================================================
void main(void){
    int ret = SYS_ERR;
    
    // 컴파일러가 최적화로 날려버리지 못하게 volatile 포인터 선언
    volatile unsigned int *ram_ptr = (volatile unsigned int *)APB_BRAM;

    // 1. 시스템 초기화 (기존 페리페럴들 0으로 초기화)
    ret = sys_init();

    // 만약 sys_init 내부의 기본 RAM 테스트(0x1 쓰기)가 실패했다면 여기서 멈춤
    if (ret == SYS_ERR) {
        while(1); 
    }

    // 2. 본격적인 RAM 쓰기 테스트 (파형에서 알아보기 쉬운 넘버 사용)
    // ram_ptr[0]은 sys_init에서 썼으니 인덱스 1부터.
    ram_ptr[1] = 0xDEADBEEF; // 0x10000004
    ram_ptr[2] = 0x12345678; // 0x10000008
    ram_ptr[3] = 0x5555AAAA; // 0x1000000C
    ram_ptr[4] = 0xAAAA5555; // 0x10000010

    // 3. 제대로 써졌는지 RAM 읽기 테스트
    if (ram_ptr[1] == 0xDEADBEEF && 
        ram_ptr[2] == 0x12345678 && 
        ram_ptr[3] == 0x5555AAAA && 
        ram_ptr[4] == 0xAAAA5555) {
        
        // 테스트 성공! (파형에서 확인하기 위해 5번째 칸에 성공 마크 작성)
        ram_ptr[5] = 0x00000000; 
        ram_ptr[5] = 0x77777777; // 럭키 세븐!
    } else {
        //  테스트 실패!
        ram_ptr[5] = 0xBAD0BAD0; // "BAD BAD"
    }

    // 4. 테스트 종료 후 안전하게 무한 대기 (CPU 폭주 방지)
    while(1) {
        // NOP
    }
}

void GPIO_init(GPIO_TYPEDEF *GPIOx, unsigned int control) {
    GPIOx->CTRL = control;
}

void led_write(GPIO_TYPEDEF *GPIOx, unsigned int wdata) {
    GPIOx->ODATA = wdata;
    return;
}

unsigned int sw_read(GPIO_TYPEDEF *GPIOx){
    return GPIOx->IDATA;
}

int sys_init(void) {
    int i = 0;
    // RAM 
    *(unsigned int *) APB_BRAM      = 0x00000001;
    // RAM Read Test
    i = *(unsigned int *) APB_BRAM;
    if (i != 0x00000001){
        return SYS_ERR;
    }

    // GPO 
    *(unsigned int *) APB_GPO_CTRL      = 0x00000000;   // GPO control register 
    *(unsigned int *) APB_GPO_ODATA     = 0x00000000;   // GPO output register
    // GPI  
    *(unsigned int *) APB_GPI_CTRL      = 0x00000000;   // GPI control register 
    i = *(unsigned int *) APB_GPI_IDATA;                // GPI Input register
    // GPIO 
    *(unsigned int *) APB_GPIO_CTRL     = 0x00000000;   // GPIO control register 
    *(unsigned int *) APB_GPIO_ODATA    = 0x00000000;   // GPIO output register

    // FND 
    *(unsigned int *) APB_FND_CTRL      = 0x00000000;   // FND control register 
    *(unsigned int *) APB_FND_ODATA     = 0x00000000;   // FND output register
    // UART 
    *(unsigned int *) APB_UART_CTRL   = 0x00000000;   // UART control register 
    *(unsigned int *) APB_UART_BAUD   = 0x00000000;   // UART baudrate register 
    *(unsigned int *) APB_UART_TXDATA = 0x00000000;   // UART output register
    
    GPIO_init(GPIOA,0x0000ff00);     // GPIO [15:8] : LED output, GPIO[7:0] : SW input mode

    return SYS_OK;
}

void delay_ms(int delay) {
    int i = 0,j=0;
    volatile int k=0;
    for(i=0;i<delay;i++) {
        for (j=0;j<100000/3;j++) 
            k = k + 1;
    }
    return;
}
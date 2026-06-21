#include <stdint.h>

#define SYS_ERR             (-1)
#define SYS_OK              (0)

#define APB_BRAM            (0x10000000)
#define APB_PERIPHERAL_BASE (0x20000000)
#define APB_GPO             (APB_PERIPHERAL_BASE + 0x0000U)
#define APB_GPI             (APB_PERIPHERAL_BASE + 0x1000U)
#define APB_GPIO            (APB_PERIPHERAL_BASE + 0x2000U)
#define APB_FND             (APB_PERIPHERAL_BASE + 0x3000U)
#define APB_UART            (APB_PERIPHERAL_BASE + 0x4000U)

#define APB_GPO_CTRL         (APB_GPO + 0x00U)
#define APB_GPO_ODATA       (APB_GPO + 0x04U)
#define APB_GPI_CTRL         (APB_GPI + 0x00U)
#define APB_GPI_IDATA       (APB_GPI + 0x04U)
#define APB_GPIO_CTRL        (APB_GPIO + 0x00U)
#define APB_GPIO_ODATA      (APB_GPIO + 0x04U)
#define APB_GPIO_IDATA      (APB_GPIO + 0x08U)
#define APB_FND_CTRL         (APB_FND + 0x00U)
#define APB_FND_ODATA       (APB_FND + 0x04U)
#define APB_UART_CTRL        (APB_UART + 0x00U)
#define APB_UART_BAUD       (APB_UART + 0x04U)
#define APB_UART_STATUS     (APB_UART + 0x08U)
#define APB_UART_TXDATA     (APB_UART + 0x0CU)
#define APB_UART_RXDATA     (APB_UART + 0x10U)

#define __IO    volatile 

typedef struct {
    __IO uint32_t CTL;
    __IO uint32_t ODATA;
    __IO uint32_t IDATA;
} GPIO_TYPEDEF;

#define GPIOA   ((GPIO_TYPEDEF *) APB_GPIO)

/* 함수 프로토타입 유지 */
int sys_init(void);
void delay_ms(int delay);
void GPIO_init(GPIO_TYPEDEF *GPIOx, unsigned int control);
void led_write(GPIO_TYPEDEF *GPIOx, unsigned int wdata);
unsigned int sw_read(GPIO_TYPEDEF *GPIOx);

// =========================================================
// 수정한 MAIN 함수
// =========================================================
void main(void){
    int ret = SYS_ERR;
    unsigned int rx_val = 0;
    
    // 1. 기존 초기화 함수 실행
    ret = sys_init();
    if (ret == SYS_ERR) return;

    // FND 초기값 0000 설정
    *(volatile unsigned int *)APB_FND_ODATA = 0;

    while(1) {
        // 2. UART 수신 확인 (사용자 설계: STATUS_REG[15] 가 rx_done)
        // 0x8000은 Bit 15를 검사하기 위한 마스크입니다.
        if (*(volatile unsigned int *)APB_UART_STATUS & 0x80000000) {
            
            // 3. 수신 완료 시 데이터 읽기
            // (사용자 설계: RXDATA를 읽으면 STATUS[15]가 자동으로 0이 됨)
            rx_val = *(volatile unsigned int *)APB_UART_RXDATA;

            // 4. [TX 에코] PC로 다시 전송하기 위해 TX Busy 확인 (STATUS_REG[0] == 1이면 바쁨)
            while (*(volatile unsigned int *)APB_UART_STATUS & 0x01);
            
            // TX 데이터 레지스터에 값 전달
            *(volatile unsigned int *)APB_UART_TXDATA = rx_val;
            
            // tx_start (CTL_REG[0])에 1 펄스 인가하여 전송 시작
            *(volatile unsigned int *)APB_UART_CTRL = 0x01;

            // 5. [FND 출력] 수신한 값을 FND 화면에 표시
            *(volatile unsigned int *)APB_FND_ODATA = rx_val;
        }
    }
}

// =========================================================
// 아래는 그대로 유지된 기존 함수들
// =========================================================
void GPIO_init(GPIO_TYPEDEF *GPIOx, unsigned int control) {
    GPIOx->CTL = control;
}
void led_write(GPIO_TYPEDEF *GPIOx, unsigned int wdata) {
    GPIOx->ODATA = wdata;
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
    *(unsigned int *) APB_GPO_CTRL       = 0x00000000;   
    *(unsigned int *) APB_GPO_ODATA     = 0x00000000;   
    // GPI  
    *(unsigned int *) APB_GPI_CTRL       = 0x00000000;   
    i = *(unsigned int *) APB_GPI_IDATA;                
    // GPIO 
    *(unsigned int *) APB_GPIO_CTRL      = 0x00000000;   
    *(unsigned int *) APB_GPIO_ODATA    = 0x00000000;   

    // FND 초기화 (주석 해제)
    *(unsigned int *) APB_FND_CTRL      = 0x00000000;   
    *(unsigned int *) APB_FND_ODATA    = 0x00000000;   
    // UART 초기화 (주석 해제)
    *(unsigned int *) APB_UART_CTRL      = 0x00000000;   
    *(unsigned int *) APB_UART_BAUD     = 0x00000000;   
    *(unsigned int *) APB_UART_TXDATA    = 0x00000000;   

    GPIO_init(GPIOA,0x0000ff00);

    return SYS_OK;
}

void delay_ms(int delay) {
    int i = 0, j = 0, k = 0;
    for(i=0; i<delay; i++) {
        for (j=0; j<100000/3; j++) 
            k = k + 1;
    }
}
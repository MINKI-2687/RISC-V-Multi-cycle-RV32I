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


void main(void){
    int time = 0;
    unsigned int sw_val = 0;
    unsigned int blink_flag = 0;

    sys_init();
    // GPIO 비트 15:8은 LED 출력, 7:0은 SW 입력으로 설정
    GPIO_init(GPIOA, 0x0000FF00); 
    time = 100; 

    while(1) {
        if (time <= 0) {
            time = 100; // 다시 충전
            sw_val = sw_read(GPIOA); // 1. 스위치(7:0비트) 읽기
            
            // ★ 중요: 읽어온 값을 LED 위치(15:8비트)로 밀어줍니다.
            unsigned int shifted_sw_val = (sw_val << 8);

            if (blink_flag) {
                // 2. 스위치 켠 곳만 LED 켜기 (shifted 값 사용)
                led_write(GPIOA, shifted_sw_val); 
                blink_flag = 0;
            } else {
                // 3. 다 끄기
                led_write(GPIOA, 0); 
                blink_flag = 1;
            }
        }
        delay_ms(1); // 1ms 대기 (이 함수 내부 j 루프 횟수 줄이는 게 좋습니다)
        time--;
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
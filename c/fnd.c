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

/* 1. GPI 전용 구조체 정의 */
typedef struct {
    __IO uint32_t CTRL;
    __IO uint32_t IDATA; // GPI는 두 번째 방이 바로 IDATA!
} GPI_TYPEDEF;

/* 2. GPIA 포인터 선언 */
#define GPIA    ((GPI_TYPEDEF *) APB_GPI)

/* 함수 선언부 */
int sys_init(void);
void delay_ms(int delay);
void GPIO_init(GPIO_TYPEDEF *GPIOx, unsigned int control);
void led_write(GPIO_TYPEDEF *GPIOx, unsigned int wdata);
unsigned int sw_read(GPIO_TYPEDEF *GPIOx);
unsigned int gpi_read(GPI_TYPEDEF *GPIx);

void main(void) {
    unsigned int gpio_sw = 0;
    unsigned int gpi_sw = 0;
    unsigned int total_val = 0;
    sys_init();
    
    // GPI와 GPIO 모두 입력 허가 설정 필요
    *(volatile unsigned int *)APB_GPI_CTRL = 0x00FF;
    GPIO_init(GPIOA, 0x0000FF00);

    while(1) {
        gpio_sw = sw_read(GPIOA); // GPIO 8비트 (0~7번 스위치)
        gpi_sw  = gpi_read(GPIA); // GPI 8비트 (8~15번 스위치)

        // 두 값을 합쳐서 16비트 숫자로 만듦
        total_val = (gpi_sw << 8) | gpio_sw;

        // FND에 출력
        // 주의: 하드웨어 설계상 9999까지만 표현 가능합니다!
        // 만약 9999보다 큰 값이 들어가면 digit_1000 자리에 이상한 값이 찍힐 수 있습니다.
        if (total_val > 9999) total_val = 9999; 
        
        *(volatile unsigned int *)APB_FND_ODATA = total_val;
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

/* 3. GPI 전용 읽기 함수 (이름만 다르게) */
unsigned int gpi_read(GPI_TYPEDEF *GPIx) {
    return GPIx->IDATA;
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
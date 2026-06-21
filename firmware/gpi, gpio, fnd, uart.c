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

/* ========================================================= */
/* 구조체 및 포인터 선언부 (HAL 스타일로 깔끔하게 통일) */
/* ========================================================= */

// 1. GPIO (입출력 혼합 - 오른쪽 스위치/LED)
typedef struct {
    __IO uint32_t CTRL;
    __IO uint32_t ODATA;
    __IO uint32_t IDATA;
} GPIO_TYPEDEF;
#define GPIOA   ((GPIO_TYPEDEF *) APB_GPIO)

// 2. GPI (입력 전용 - 왼쪽 스위치)
typedef struct {
    __IO uint32_t CTRL;
    __IO uint32_t IDATA; 
} GPI_TYPEDEF;
#define GPIA    ((GPI_TYPEDEF *) APB_GPI)

// 3. (출력 전용 - 왼쪽 LED)
typedef struct {
    __IO uint32_t CTRL;
    __IO uint32_t ODATA; 
} GPO_TYPEDEF;
#define GPOA    ((GPO_TYPEDEF *) APB_GPO)

/* 함수 프로토타입 유지 및 추가 */
int sys_init(void);
void delay_ms(int delay);

void GPIO_init(GPIO_TYPEDEF *GPIOx, unsigned int control);
unsigned int sw_read(GPIO_TYPEDEF *GPIOx);
void led_write(GPIO_TYPEDEF *GPIOx, unsigned int wdata);

unsigned int gpi_read(GPI_TYPEDEF *GPIx);
void gpo_write(GPO_TYPEDEF *GPOx, unsigned int wdata);

// =========================================================
// 수정한 MAIN 함수 (구조체로 통일된 버전)
// =========================================================
void main(void){
    int ret = SYS_ERR;
    unsigned int rx_val = 0;
    unsigned int gpio_sw = 0;
    unsigned int gpi_sw = 0;
    unsigned int total_sw = 0;
    
    // 마지막으로 수신한 UART 값을 기억할 변수
    unsigned int last_uart_val = 0; 
    
    // 블링크를 위한 소프트웨어 카운터 변수
    unsigned int tick_count = 0;
    unsigned int blink_flag = 0;
    
    // 1. 초기화
    ret = sys_init();
    if (ret == SYS_ERR) return;

    *(volatile unsigned int *)APB_FND_CTRL = 0x00000001; 
    *(volatile unsigned int *)APB_GPI_CTRL = 0x000000FF; 
    *(volatile unsigned int *)APB_GPO_CTRL = 0x000000FF; 
    *(volatile unsigned int *)APB_UART_BAUD = 0x00000003; // 115200 bps

    while(1) {
        // ---------------------------------------------------------
        // [TASK 1] 스위치 읽어서 16비트 숫자로 합치기
        // ---------------------------------------------------------
        gpio_sw = sw_read(GPIOA); 
        gpi_sw  = gpi_read(GPIA); 
        total_sw = (gpi_sw << 8) | gpio_sw;

        // ---------------------------------------------------------
        // [TASK 2] UART 수신 및 에코백
        // ---------------------------------------------------------
        if (*(volatile unsigned int *)APB_UART_STATUS & 0x80000000) {
            rx_val = *(volatile unsigned int *)APB_UART_RXDATA;
            
            // 데이터가 오면 last_uart_val에 저장해둡니다.
            last_uart_val = rx_val; 

            while (*(volatile unsigned int *)APB_UART_STATUS & 0x01);
            *(volatile unsigned int *)APB_UART_TXDATA = rx_val;
            *(volatile unsigned int *)APB_UART_CTRL = 0x01;
        }

        // ---------------------------------------------------------
        // [TASK 3] FND 디스플레이 교통정리 (15번 스위치 활용)
        // ---------------------------------------------------------
        if (total_sw & 0x8000) { 
            // [모드 A] 15번 스위치 ON: 마지막으로 받은 UART 값을 표시
            *(volatile unsigned int *)APB_FND_ODATA = last_uart_val;
        } else {
            // [모드 B] 15번 스위치 OFF: 현재 스위치 값(0~14번)을 표시
            unsigned int display_sw = total_sw & 0x7FFF; 
            if (display_sw > 9999) display_sw = 9999; 
            *(volatile unsigned int *)APB_FND_ODATA = display_sw;
        }

        // ---------------------------------------------------------
        // [TASK 4] 논블로킹 Blink
        // ---------------------------------------------------------
        tick_count++;
        
        if (tick_count >= 50000) { 
            tick_count = 0;
            blink_flag = (blink_flag == 0) ? 1 : 0;
            
            if (blink_flag) {
                // 불 켜기
                led_write(GPIOA, (gpio_sw << 8)); // 오른쪽 LED ON
                gpo_write(GPOA, gpi_sw);          // 왼쪽 LED ON
            } else {
                // 불 끄기
                led_write(GPIOA, 0);              // 오른쪽 LED OFF
                gpo_write(GPOA, 0);               // 왼쪽 LED OFF
            }
        }
    }
}

// =========================================================
// 하드웨어 제어 함수 구현부
// =========================================================
void GPIO_init(GPIO_TYPEDEF *GPIOx, unsigned int control) {
    GPIOx->CTRL = control;
}

void led_write(GPIO_TYPEDEF *GPIOx, unsigned int wdata) {
    GPIOx->ODATA = wdata;
}

unsigned int sw_read(GPIO_TYPEDEF *GPIOx){
    return GPIOx->IDATA;
}

unsigned int gpi_read(GPI_TYPEDEF *GPIx) {
    return GPIx->IDATA;
}

// GPO 전용 쓰기 함수 구현
void gpo_write(GPO_TYPEDEF *GPOx, unsigned int wdata) {
    GPOx->ODATA = wdata;
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

    // FND 초기화 
    *(unsigned int *) APB_FND_CTRL      = 0x00000000;   
    *(unsigned int *) APB_FND_ODATA    = 0x00000000;   
    // UART 초기화 
    *(unsigned int *) APB_UART_CTRL      = 0x00000000;   
    *(unsigned int *) APB_UART_BAUD     = 0x00000000;   
    *(unsigned int *) APB_UART_TXDATA    = 0x00000000;   

    GPIO_init(GPIOA,0x0000ff00);

    return SYS_OK;
}
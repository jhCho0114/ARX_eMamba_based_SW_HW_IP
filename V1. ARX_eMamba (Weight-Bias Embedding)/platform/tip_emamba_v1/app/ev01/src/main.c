#include <stdint.h>

#include "ervp_printf.h"
// #include "txt.h"


#include "ervp_mmio_util.h"
#include "memorymap_info.h"


#define IP_WORD(word) (EMAMBA_IP_SLAVE_BASEADDR + ((word) << 2))

/** S_AXI.sv
* assign dIn[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 1];
*/
#define IP_INPUT(i)                 (IP_WORD(i + 1))

/** S_AXI.sv
* ram[100 + dOut_seqlength * 15 + 0]  <= #1 dOut[0 * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH];
*/
#define IP_OUTPUT(seqlength, class) (IP_WORD(100 + (seqlength*57 + class)))

#define IP_OUTPUT_SMALL_JUMP(seqlength, class) (IP_WORD(100 + (seqlength*15 + class)))


/** S_AXI.sv
* assign ps_start = ram[0][31];
* ram[0][15] <= #1 frameDout_ready;
*/
#define IP_STATUS                   (IP_WORD(0)) 



#include "quant_input_1.h"

// #define PRINT_LOG 1


int main()
{
#ifdef PRINT_LOG
    for (int i = 0; i < 320; i++) {
        printf("%d ", quant_input_1[i]);

        if ( i % 8 == 7) {
            printf("\n");
        }
        
        if ( i % 64 == 63) {
            printf("\n");
        }
    }
    printf("\n");
#endif

    uint32_t * pack_by_cast = (uint32_t *)quant_input_1;

    for (int packed_idx = 0; packed_idx < 80; packed_idx++) {
        mmio_write_data(IP_INPUT(packed_idx), pack_by_cast[packed_idx]);
    }

    mmio_write_data(IP_STATUS, 0);
    mmio_write_data(IP_STATUS, (uint32_t)(1 << 31)); // assign ps_start = ram[0][31];
#ifdef PRINT_LOG
    printf(" :: IP START ::\n");
#endif

    while ((mmio_read_data(IP_STATUS) & (uint32_t)(1 << 15)) == 0) // ram[0][15] <= #1 frameDout_ready;
    {
        ;  // polling for IP's finishing processing
    }

    for (int seqlength = 0; seqlength < 16; seqlength++)
    {
        int8_t output_data[57];

        for (int class = 0; class < 57/4 ; class++) // 0 ~ 13 : class 0 ~ 56
        { 
            uint32_t origin = mmio_read_data(IP_OUTPUT_SMALL_JUMP(seqlength, class));

            output_data[class*4 + 0] = (int8_t)(origin >> 0);
            output_data[class*4 + 1] = (int8_t)(origin >> 8);
            output_data[class*4 + 2] = (int8_t)(origin >> 16);
            output_data[class*4 + 3] = (int8_t)(origin >> 24);
        }
        uint32_t temp = mmio_read_data(IP_OUTPUT_SMALL_JUMP(seqlength, 57/4)); // 14 : frameDout_ready
        output_data[56] = (int8_t)(temp >> 0);

#ifdef PRINT_LOG
        for (int i = 0; i < 57; i++) {
            printf("%d ", output_data[i]);
        }
        printf("\n");
#endif
    }

    printf(" :: DONE\n");

    return 0;
}

/*
int main()
{
    printf(" Double IP test\n");
    CHECK_LOAD(load_int_value_txt("input_token.txt", input_token));

    for (int i = 0; i < NUM_CHANNELS; i++) {
        for (int j = 0; j < NUM_HEIGHT; j++) {
            for (int k = 0; k < NUM_WIDTH; k++) {
                printf("%d ", input_token[i][j][k]);
            }
            printf("\n");
        }
        printf("\n");
    }

    printf(" :: input_token write to IP_INPUT\n");
    for (int i = 0; i < 5; i++) {
        for (int j = 0; j < 8; j++) {
            uint32_t packed_data = 0;
            for (int k = 0; k < 8; k++) {
                if ((k % 4) == 0) {
                    packed_data = 0;
                }

                packed_data |= ((uint32_t)(uint8_t)input_token[i][j][k]) << ((k % 4) * 8);

                if ((k % 4) == 3) {
                    int widx = i*16 + j*2 + (k/4);   
                    mmio_write_data(IP_INPUT(widx), packed_data);
                }
            }
        }
    }

    mmio_write_data(IP_STATUS, 0);
    mmio_write_data(IP_STATUS, (uint32_t)(1 << 31)); // assign ps_start = ram[0][31];
    printf(" :: IP START ::\n");
    
    while ((mmio_read_data(IP_STATUS) & (uint32_t)(1 << 15)) == 0) // ram[0][15] <= #1 frameDout_ready;
    {
        ;  // polling for IP's finishing processing
    }

    for (int seqlength = 0; seqlength < 16; seqlength++)
    {
        int8_t output_data[57];

        for (int class = 0; class < 57/4 ; class++) // 0 ~ 13 : class 0 ~ 56
        { 
            uint32_t origin = mmio_read_data(IP_OUTPUT(seqlength, class));

            output_data[class*4 + 0] = (int8_t)(origin >> 24);
            output_data[class*4 + 1] = (int8_t)(origin >> 16);
            output_data[class*4 + 2] = (int8_t)(origin >>  8);
            output_data[class*4 + 3] = (int8_t)(origin >>  0);
        }
        uint32_t temp = mmio_read_data(IP_OUTPUT(seqlength, 57/4)); // 14 : frameDout_ready
        output_data[56] = (int8_t)(temp >> 24);

        for (int i = 0; i < 57; i++) {
            printf("%d ", output_data[i]);
        }
        printf("\n");
    }

    printf(" :: DONE\n");

    return 0;
}
*/
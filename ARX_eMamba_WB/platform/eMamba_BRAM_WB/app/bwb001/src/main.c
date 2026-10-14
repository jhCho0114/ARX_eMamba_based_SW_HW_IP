// #include <stdio.h>
// #include <stdlib.h>
// #include <string.h>
// #include <stdint.h>

// #include "platform_info.h"
// #include "memorymap_info.h"
// #include "ervp_mmio_util.h"
// #include "ervp_printf.h"

// #include "wb_raw.h"

// #define EMAMBA_BASEADDR  EMAMBA_IP_SLAVE_BASEADDR
// #define IN_BASE          INPUT_BRAM_SLAVE_BASEADDR
// #define OUT_BASE         OUTPUT_BRAM_SLAVE_BASEADDR
// #define WB_BASE          WB_BRAM_SLAVE_BASEADDR

// #define CTRL_START       (1u << 31)
// #define CTRL_WB_LOAD     (1u << 30)
// #define STAT_FRAME_DONE  (1u << 15)
// #define STAT_WB_DONE     (1u << 14)

// #define FRAME_BYTES      (sizeof(frame_single))
// #define NUM_SEQLEN       16
// #define NUM_CLASS        57
// #define OUT_ROW_STRIDE   64
// #define WB_IMAGE_BYTES   19440

// #define GOLDEN_TOL       1

// #ifndef STATUS_POLL_LIMIT
// #define STATUS_POLL_LIMIT 1000000U   // 약 1.5초 //#define STATUS_POLL_LIMIT 100000000U
// #endif

// static inline void mmio_write32(uint32_t base, uint32_t off, uint32_t v)
// {
//     mmio_write_data((mmio_addr_t)(base + off), v);
// }

// static inline uint32_t mmio_read32(uint32_t base, uint32_t off)
// {
//     return mmio_read_data((mmio_addr_t)(base + off));
// }

// #define mmio_write_ctrl(v)  mmio_write32(EMAMBA_BASEADDR, 0, (v))
// #define mmio_read_ctrl()    mmio_read32(EMAMBA_BASEADDR, 0)

// static inline void memory_barrier(void)
// {
//     __sync_synchronize();
// }

// // single input (quant_input_1, [ch][row][col]) = frame_data[0] of initial_input_new.h
// static const char frame_single[5][8][8] __attribute__((aligned(4))) = {
//     {
//         {1, 1, 1, 2, 2, 3, 3, 3},
//         {3, 3, 3, 4, 4, 4, 4, 4},
//         {4, 4, 4, 4, 4, 4, 4, 4},
//         {4, 4, 4, 4, 4, 4, 0, 0},
//         {0, 0, 0, 0, 0, 0, 0, 0},
//         {0, 0, 0, 0, 0, 0, 0, 0},
//         {0, 0, 0, 0, 0, 0, 0, 0},
//         {0, 0, 0, 0, 0, 0, 0, 0}
//     },
//     {
//         {14, 14, 15, 15, 15, 15, 16, 15},
//         {15, 16, 15, 16, 16, 16, 16, 16},
//         {16, 15, 15, 15, 15, 15, 15, 15},
//         {16, 16, 16, 15, 15, 15, 0, 0},
//         {0, 0, 0, 0, 0, 0, 0, 0},
//         {0, 0, 0, 0, 0, 0, 0, 0},
//         {0, 0, 0, 0, 0, 0, 0, 0},
//         {0, 0, 0, 0, 0, 0, 0, 0}
//     },
//     {
//         {-2, -3, 6, 5, 4, 5, 5, 1},
//         {5, 4, 3, 3, 3, 2, 3, 3},
//         {3, 1, 3, 2, 2, 3, 2, 3},
//         {2, 3, 2, 1, 2, 1, 0, 0},
//         {0, 0, 0, 0, 0, 0, 0, 0},
//         {0, 0, 0, 0, 0, 0, 0, 0},
//         {0, 0, 0, 0, 0, 0, 0, 0},
//         {0, 0, 0, 0, 0, 0, 0, 0}
//     },
//     {
//         {-3, -3, 6, 3, 3, 3, 3, 0},
//         {6, 3, -3, -3, -3, -6, 0, -3},
//         {-3, -6, 0, -3, -6, 0, -6, 0},
//         {-6, 0, -6, -3, 0, -3, 0, 0},
//         {0, 0, 0, 0, 0, 0, 0, 0},
//         {0, 0, 0, 0, 0, 0, 0, 0},
//         {0, 0, 0, 0, 0, 0, 0, 0},
//         {0, 0, 0, 0, 0, 0, 0, 0}
//     },
//     {
//         {-4, -5, -5, -2, 0, 1, -1, -5},
//         {-4, -3, 14, 16, 11, 0, -2, 3},
//         {-3, -3, 0, 8, 0, 3, 2, 4},
//         {3, 1, -3, -4, -3, 0, 0, 0},
//         {0, 0, 0, 0, 0, 0, 0, 0},
//         {0, 0, 0, 0, 0, 0, 0, 0},
//         {0, 0, 0, 0, 0, 0, 0, 0},
//         {0, 0, 0, 0, 0, 0, 0, 0}
//     }
// };

// _Static_assert(sizeof(frame_single) == 320, "Expected 5 x 8 x 8 input bytes");

// // golden (output_golden_legacy.txt, [seq][class])
// static const int8_t golden_out[NUM_SEQLEN][NUM_CLASS] = {
//     {2, 5, 10, 16, 21, 30, 20, 1, -19, -21, 17, 11, 16, 12, -1, -10, -24, -15, 11, 112, 108, 111, 99, 110, 117, 88, 104, 104, 97, 116, 103, 111, 98, 113, 98, 117, 117, 115, -7, 18, 26, 30, 27, 10, 11, 28, 18, 33, -15, -31, -60, -62, -6, -29, -53, -54, 35},
//     {2, 5, 6, 9, 18, 32, 28, -3, -10, -3, 12, 12, 16, 15, 0, 0, 1, 0, 5, 126, 124, 125, 123, 123, 127, 116, 121, 117, 110, 127, 121, 123, 115, 124, 118, 126, 122, 126, -8, 13, 30, 40, 24, 19, 41, 22, 5, 10, -13, -34, -57, -60, -10, -28, -53, -57, 28},
//     {0, 1, -1, 0, 11, 23, 36, -13, -21, -25, 4, 8, 17, 17, -5, -2, 0, -4, -3, 127, 127, 127, 127, 127, 127, 127, 127, 127, 124, 127, 127, 127, 127, 127, 127, 127, 127, 127, -7, 9, 28, 38, 24, 19, 22, 21, 11, -1, -10, -33, -54, -59, -10, -29, -51, -56, 23},
//     {10, 7, 7, 7, 22, 37, 45, -5, -8, -7, 15, 16, 17, 19, 4, 3, 3, 0, 7, 126, 127, 127, 127, 127, 127, 127, 126, 127, 122, 123, 125, 127, 121, 124, 126, 127, 121, 127, -10, 11, 33, 44, 24, 26, 34, 23, 10, 2, -8, -33, -55, -59, -9, -32, -55, -60, 26},
//     {18, 14, 13, 10, 24, 24, 28, -1, 6, 12, 16, 16, 16, 14, 9, 12, 13, 13, 11, 121, 126, 127, 127, 127, 126, 126, 126, 127, 127, 117, 127, 127, 123, 117, 127, 124, 116, 126, -7, 13, 37, 47, 29, 15, -12, 26, 6, -30, -1, -33, -51, -59, -4, -40, -59, -63, 28},
//     {14, 12, 11, 13, 25, 38, 48, -6, 4, -7, 13, 16, 11, 14, 6, -1, -1, 3, 16, 118, 122, 125, 127, 119, 125, 127, 127, 127, 126, 115, 121, 125, 110, 115, 127, 117, 115, 127, -5, 18, 38, 55, 24, 24, 0, 26, 8, -16, 2, -29, -57, -56, -2, -32, -57, -63, 30},
//     {4, 4, 8, 8, 16, 24, 35, -7, -5, -1, 14, 12, 15, 16, 2, 5, -4, 1, 6, 118, 121, 124, 123, 125, 127, 121, 114, 118, 118, 113, 115, 120, 110, 110, 118, 127, 119, 123, -4, 14, 27, 33, 27, 17, 6, 25, 3, -26, -9, -31, -49, -53, -9, -33, -52, -55, 25},
//     {15, 12, 12, 15, 27, 40, 54, 0, -4, -14, 17, 21, 22, 23, 7, 5, 0, 1, 15, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, -15, 6, 27, 37, 16, 17, 5, 18, 8, -8, -14, -34, -62, -64, -15, -36, -58, -64, 21},
//     {9, 9, 10, 10, 23, 37, 48, -2, -9, -17, 15, 15, 15, 16, 4, -2, -7, -9, 9, 127, 127, 126, 127, 125, 127, 125, 124, 123, 119, 124, 123, 127, 121, 124, 122, 127, 121, 126, -12, 7, 27, 36, 20, 16, 16, 19, 7, -3, -13, -35, -57, -60, -13, -29, -50, -54, 22},
//     {9, 8, 10, 9, 21, 32, 44, -5, -9, -15, 14, 14, 15, 16, 4, -1, -4, -5, 7, 125, 125, 124, 123, 124, 124, 122, 120, 121, 117, 120, 120, 123, 116, 121, 121, 127, 120, 123, -12, 6, 24, 35, 20, 15, 12, 18, 4, -7, -12, -35, -55, -60, -12, -33, -54, -56, 19},
//     {9, 8, 9, 9, 22, 34, 44, -3, -9, -15, 15, 16, 18, 19, 3, -2, -6, -7, 9, 126, 126, 126, 126, 125, 127, 123, 123, 124, 118, 124, 123, 126, 119, 124, 123, 127, 123, 126, -12, 8, 28, 37, 21, 16, 15, 20, 7, -4, -12, -34, -57, -60, -12, -31, -53, -57, 24},
//     {8, 7, 10, 10, 21, 32, 40, -3, -9, -17, 15, 14, 17, 18, 4, -1, -5, -6, 7, 125, 125, 124, 123, 123, 124, 121, 121, 121, 117, 123, 121, 123, 116, 123, 120, 126, 119, 124, -10, 9, 26, 36, 21, 14, 10, 20, 5, -2, -12, -32, -54, -58, -11, -30, -52, -55, 23},
//     {9, 11, 11, 11, 22, 32, 41, -1, -8, -16, 14, 16, 17, 17, 4, 0, -5, -6, 11, 127, 127, 127, 127, 127, 127, 124, 126, 127, 122, 125, 126, 127, 123, 125, 126, 127, 124, 127, -10, 10, 28, 37, 22, 12, 5, 20, 8, -6, -12, -34, -57, -60, -11, -30, -51, -56, 23},
//     {9, 8, 9, 9, 20, 29, 38, -4, -9, -13, 14, 14, 16, 16, 4, 1, -1, -3, 6, 126, 126, 125, 124, 125, 126, 122, 121, 122, 118, 123, 123, 124, 118, 123, 122, 127, 120, 124, -10, 8, 26, 36, 22, 13, 7, 19, 4, -10, -10, -33, -53, -59, -10, -31, -52, -55, 22},
//     {10, 11, 11, 12, 23, 33, 40, -1, -6, -11, 14, 16, 18, 18, 5, 1, -1, -2, 10, 127, 126, 127, 127, 126, 127, 126, 126, 127, 121, 126, 126, 127, 122, 123, 125, 127, 123, 127, -12, 7, 27, 37, 19, 11, 6, 18, 4, -10, -13, -34, -56, -60, -13, -32, -52, -57, 22},
//     {10, 11, 11, 12, 23, 33, 40, -1, -6, -11, 14, 16, 18, 18, 5, 1, -1, -2, 10, 127, 126, 127, 127, 126, 127, 126, 126, 127, 121, 126, 126, 127, 122, 123, 125, 127, 123, 127, -12, 7, 27, 37, 19, 11, 6, 18, 4, -10, -13, -34, -56, -60, -13, -32, -52, -57, 22}
// };

// typedef struct {
//     const int8_t *data;
//     uint32_t      bytes;
//     uint32_t      off;
//     const char   *name;
// } wb_entry_t;

// #define WB(arr, wb_byte)  { arr, sizeof(arr), (wb_byte), #arr }

// static const wb_entry_t wb_map[] = {
//     WB(PatchEmbedding_quant_w,                   0),
//     WB(PatchEmbedding_quant_b,                 400),
//     WB(MambaBlock_0_LightNorm_w_quant,         420),
//     WB(MambaBlock_0_LightNorm_b_quant,         440),
//     WB(MambaBlock_0_proj_w_quant,              460),
//     WB(MambaBlock_0_proj_b_quant,             1260),
//     WB(MambaBlock_0_proj_res_w_quant,         1300),
//     WB(MambaBlock_0_proj_res_b_quant,         2100),
//     WB(MambaBlock_0_conv1d_w_quant,           3772),
//     WB(MambaBlock_0_conv1d_b_quant,           5372),
//     WB(MambaBlock_0_SSM_pre_A_quant,          5412),
//     WB(MambaBlock_0_SSM_pre_D_quant,          5732),
//     WB(MambaBlock_0_SSM_pre_deltaBC_w_quant,  5772),
//     WB(MambaBlock_0_SSM_pre_dt_proj_w_quant,  7868),
//     WB(MambaBlock_0_SSM_pre_dt_proj_b_quant,  9148),
//     WB(MambaBlock_0_proj_rev_w,               9188),
//     WB(MambaBlock_0_proj_rev_b,               9988),
//     WB(MambaBlock_1_LightNorm_w_quant,       10008),
//     WB(MambaBlock_1_LightNorm_b_quant,       10028),
//     WB(MambaBlock_1_proj_w_quant,            10048),
//     WB(MambaBlock_1_proj_b_quant,            10848),
//     WB(MambaBlock_1_proj_res_w_quant,        10888),
//     WB(MambaBlock_1_proj_res_b_quant,        11688),
//     WB(MambaBlock_1_conv1d_w_quant,          11964),
//     WB(MambaBlock_1_conv1d_b_quant,          13564),
//     WB(MambaBlock_1_SSM_pre_A_quant,         13604),
//     WB(MambaBlock_1_SSM_pre_D_quant,         13924),
//     WB(MambaBlock_1_SSM_pre_deltaBC_w_quant, 13964),
//     WB(MambaBlock_1_SSM_pre_dt_proj_w_quant, 16060),
//     WB(MambaBlock_1_SSM_pre_dt_proj_b_quant, 17340),
//     WB(MambaBlock_1_proj_rev_w,              17380),
//     WB(MambaBlock_1_proj_rev_b,              18180),
//     WB(outputhead_LightNorm_w_quant,         18200),
//     WB(outputhead_LightNorm_b_quant,         18220),
//     WB(outputhead_linear_w,                  18240),
//     WB(outputhead_linear_b,                  19380),
// };

// #define WB_MAP_N  (sizeof(wb_map) / sizeof(wb_map[0]))

// static uint8_t wb_image[WB_IMAGE_BYTES] __attribute__((aligned(4)));

// static int build_wb_image(void)
// {
//     memset(wb_image, 0, sizeof(wb_image));
//     for (uint32_t i = 0; i < WB_MAP_N; i++) {
//         const wb_entry_t *e = &wb_map[i];
//         if (e->off + e->bytes > WB_IMAGE_BYTES) {
//             printf("wb_map[%lu] %s: off %lu + %lu > %d\n",
//                    (unsigned long)i, e->name,
//                    (unsigned long)e->off, (unsigned long)e->bytes, WB_IMAGE_BYTES);
//             return -1;
//         }
//         if (i > 0 && e->off < wb_map[i - 1].off + wb_map[i - 1].bytes) {
//             printf("wb_map[%lu] %s overlaps previous entry\n", (unsigned long)i, e->name);
//             return -1;
//         }
//         memcpy(&wb_image[e->off], e->data, e->bytes);
//     }
//     return 0;
// }

// static int write_wb_bram(void)
// {
//     const uint32_t *src = (const uint32_t *)wb_image;

//     for (uint32_t w = 0; w < WB_IMAGE_BYTES / 4; w++)
//         mmio_write32(WB_BASE, 4 * w, src[w]);

//     for (uint32_t w = 0; w < WB_IMAGE_BYTES / 4; w++) {
//         uint32_t rb = mmio_read32(WB_BASE, 4 * w);
//         if (rb != src[w]) {
//             printf("WB verify fail @byte %lu: wrote %08lX read %08lX\n",
//                    (unsigned long)(4 * w), (unsigned long)src[w], (unsigned long)rb);
//             return -1;
//         }
//     }
//     return 0;
// }

// static int load_frame(void)
// {
//     const uint32_t *src = (const uint32_t *)frame_single;

//     for (uint32_t w = 0; w < FRAME_BYTES / 4; w++)
//         mmio_write32(IN_BASE, 4 * w, src[w]);

//     for (uint32_t w = 0; w < FRAME_BYTES / 4; w++) {
//         uint32_t rb = mmio_read32(IN_BASE, 4 * w);
//         if (rb != src[w]) {
//             printf("IN verify fail @byte %lu: wrote %08lX read %08lX\n",
//                    (unsigned long)(4 * w), (unsigned long)src[w], (unsigned long)rb);
//             return -1;
//         }
//     }
//     return 0;
// }

// // the Xilinx version spins forever here; a timeout keeps the UART log useful when the IP hangs
// static int wait_status(uint32_t mask, uint32_t expected, uint32_t *ctrl)
// {
//     for (uint32_t poll = 0; poll < STATUS_POLL_LIMIT; poll++) {
//         *ctrl = mmio_read_ctrl();
//         if ((*ctrl & mask) == expected)
//             return 0;
//     }
//     printf("Status timeout: mask=%08lX expected=%08lX ctrl=%08lX\n",
//            (unsigned long)mask, (unsigned long)expected, (unsigned long)*ctrl);
//     return -1;
// }

// static void read_output(uint8_t buf[NUM_SEQLEN][OUT_ROW_STRIDE])
// {
//     for (int s = 0; s < NUM_SEQLEN; s++) {
//         for (int w = 0; w < OUT_ROW_STRIDE / 4; w++) {
//             uint32_t v = mmio_read32(OUT_BASE, (uint32_t)(s * OUT_ROW_STRIDE + 4 * w));
//             buf[s][4 * w + 0] = (uint8_t)(v);
//             buf[s][4 * w + 1] = (uint8_t)(v >> 8);
//             buf[s][4 * w + 2] = (uint8_t)(v >> 16);
//             buf[s][4 * w + 3] = (uint8_t)(v >> 24);
//         }
//     }
// }

// static int compare_golden(uint8_t buf[NUM_SEQLEN][OUT_ROW_STRIDE])
// {
//     int max_err = 0, mismatch = 0, worst_s = -1, worst_c = -1;

//     for (int s = 0; s < NUM_SEQLEN; s++) {
//         int row_max = 0;
//         for (int c = 0; c < NUM_CLASS; c++) {
//             int e = (int)(int8_t)buf[s][c] - (int)golden_out[s][c];
//             if (e < 0) e = -e;
//             if (e > row_max) row_max = e;
//             if (e > GOLDEN_TOL) mismatch++;
//             if (e > max_err) { max_err = e; worst_s = s; worst_c = c; }
//         }
//         printf("  seq %2d: tag %02X  max|err| = %d\n", s, buf[s][NUM_CLASS], row_max);
//     }

//     printf("golden compare: max|err| = %d", max_err);
//     if (worst_s >= 0)
//         printf(" @ seq %d class %d (hw %d, golden %d)", worst_s, worst_c,
//                (int)(int8_t)buf[worst_s][worst_c], (int)golden_out[worst_s][worst_c]);
//     printf(", %d entries over tol %d\n", mismatch, GOLDEN_TOL);
//     return mismatch;
// }

// int main(void)
// {
//     static uint8_t out_buf[NUM_SEQLEN][OUT_ROW_STRIDE];
//     uint32_t ctrl = 0;

//     printf("\n=== eMamba single-frame test (quant_input_1) ===\n");
//     printf("ctrl @%08lX  in @%08lX  out @%08lX  wb @%08lX\n",
//            (unsigned long)EMAMBA_BASEADDR, (unsigned long)IN_BASE,
//            (unsigned long)OUT_BASE, (unsigned long)WB_BASE);
//     printf("ctrl before = %08lX\n", (unsigned long)mmio_read_ctrl());

//     if (build_wb_image() || write_wb_bram()) {
//         printf("WB build or write failed\n");
//         return -1;
//     }
//     printf("WB image written: %d B, %lu arrays\n", WB_IMAGE_BYTES, (unsigned long)WB_MAP_N);

//     mmio_write_ctrl(CTRL_WB_LOAD);
//     memory_barrier();
//     if (wait_status(STAT_WB_DONE, STAT_WB_DONE, &ctrl)) {
//         printf("WB load failed\n");
//         return -1;
//     }
//     printf("WB loaded (ctrl = %08lX)\n", (unsigned long)ctrl);

//     if (load_frame()) {
//         printf("Frame load failed\n");
//         return -1;
//     }
//     printf("frame written: %lu B\n", (unsigned long)FRAME_BYTES);

//     // start only: writing CTRL_WB_LOAD together lets the loader overwrite weights mid-run
//     memory_barrier();
//     mmio_write_ctrl(CTRL_START);
//     memory_barrier();
//     if (wait_status(STAT_FRAME_DONE, STAT_FRAME_DONE, &ctrl)) {
//         printf("Frame incomplete\n");
//         return -1;
//     }
//     printf("frame done (ctrl = %08lX)\n", (unsigned long)ctrl);

//     memory_barrier();
//     read_output(out_buf);

//     printf("Frame 0:\n");
//     for (int s = 0; s < NUM_SEQLEN; s++) {
//         for (int c = 0; c < NUM_CLASS; c++)
//             printf("%d%s", (int)(int8_t)out_buf[s][c], c < NUM_CLASS - 1 ? ", " : "\n");
//     }

//     printf("\nGolden:\n");
//     for (int s = 0; s < NUM_SEQLEN; s++) {
//         for (int c = 0; c < NUM_CLASS; c++)
//             printf("%d%s", (int)golden_out[s][c], c < NUM_CLASS - 1 ? ", " : "\n");
//     }

//     printf("\n");
//     int mismatch = compare_golden(out_buf);
//     printf("\n%s\n", mismatch ? "*** MISMATCH ***" : "PASS (within tol)");

//     printf("\nFinish test.\n");
//     return mismatch ? -1 : 0;
// }

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#include "platform_info.h"
#include "memorymap_info.h"
#include "ervp_mmio_util.h"
#include "ervp_printf.h"

#include "wb_raw.h"

#define EMAMBA_BASEADDR  EMAMBA_IP_SLAVE_BASEADDR
#define IN_BASE          INPUT_BRAM_SLAVE_BASEADDR
#define OUT_BASE         OUTPUT_BRAM_SLAVE_BASEADDR
#define WB_BASE          WB_BRAM_SLAVE_BASEADDR

#define CTRL_START       (1u << 31)
#define CTRL_WB_LOAD     (1u << 30)
#define STAT_FRAME_DONE  (1u << 15)
#define STAT_WB_DONE     (1u << 14)

#define FRAME_BYTES      (sizeof(frame_single))
#define NUM_SEQLEN       16
#define NUM_CLASS        57
#define OUT_ROW_STRIDE   64
#define WB_IMAGE_BYTES   19440

#define GOLDEN_TOL       1

#ifndef STATUS_POLL_LIMIT
#define STATUS_POLL_LIMIT 1000000U   // 약 1.5초 //#define STATUS_POLL_LIMIT 100000000U
#endif

static inline void mmio_write32(uint32_t base, uint32_t off, uint32_t v)
{
    mmio_write_data((mmio_addr_t)(base + off), v);
}

static inline uint32_t mmio_read32(uint32_t base, uint32_t off)
{
    return mmio_read_data((mmio_addr_t)(base + off));
}

#define mmio_write_ctrl(v)  mmio_write32(EMAMBA_BASEADDR, 0, (v))
#define mmio_read_ctrl()    mmio_read32(EMAMBA_BASEADDR, 0)

static inline void memory_barrier(void)
{
    __sync_synchronize();
}

// single input (quant_input_1, [ch][row][col]) = frame_data[0] of initial_input_new.h
static const char frame_single[5][8][8] __attribute__((aligned(4))) = {
    {
        {1, 1, 1, 2, 2, 3, 3, 3},
        {3, 3, 3, 4, 4, 4, 4, 4},
        {4, 4, 4, 4, 4, 4, 4, 4},
        {4, 4, 4, 4, 4, 4, 0, 0},
        {0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0, 0, 0, 0}
    },
    {
        {14, 14, 15, 15, 15, 15, 16, 15},
        {15, 16, 15, 16, 16, 16, 16, 16},
        {16, 15, 15, 15, 15, 15, 15, 15},
        {16, 16, 16, 15, 15, 15, 0, 0},
        {0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0, 0, 0, 0}
    },
    {
        {-2, -3, 6, 5, 4, 5, 5, 1},
        {5, 4, 3, 3, 3, 2, 3, 3},
        {3, 1, 3, 2, 2, 3, 2, 3},
        {2, 3, 2, 1, 2, 1, 0, 0},
        {0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0, 0, 0, 0}
    },
    {
        {-3, -3, 6, 3, 3, 3, 3, 0},
        {6, 3, -3, -3, -3, -6, 0, -3},
        {-3, -6, 0, -3, -6, 0, -6, 0},
        {-6, 0, -6, -3, 0, -3, 0, 0},
        {0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0, 0, 0, 0}
    },
    {
        {-4, -5, -5, -2, 0, 1, -1, -5},
        {-4, -3, 14, 16, 11, 0, -2, 3},
        {-3, -3, 0, 8, 0, 3, 2, 4},
        {3, 1, -3, -4, -3, 0, 0, 0},
        {0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0, 0, 0, 0}
    }
};

_Static_assert(sizeof(frame_single) == 320, "Expected 5 x 8 x 8 input bytes");

// golden (output_golden_legacy.txt, [seq][class])
static const int8_t golden_out[NUM_SEQLEN][NUM_CLASS] = {
    {2, 5, 10, 16, 21, 30, 20, 1, -19, -21, 17, 11, 16, 12, -1, -10, -24, -15, 11, 112, 108, 111, 99, 110, 117, 88, 104, 104, 97, 116, 103, 111, 98, 113, 98, 117, 117, 115, -7, 18, 26, 30, 27, 10, 11, 28, 18, 33, -15, -31, -60, -62, -6, -29, -53, -54, 35},
    {2, 5, 6, 9, 18, 32, 28, -3, -10, -3, 12, 12, 16, 15, 0, 0, 1, 0, 5, 126, 124, 125, 123, 123, 127, 116, 121, 117, 110, 127, 121, 123, 115, 124, 118, 126, 122, 126, -8, 13, 30, 40, 24, 19, 41, 22, 5, 10, -13, -34, -57, -60, -10, -28, -53, -57, 28},
    {0, 1, -1, 0, 11, 23, 36, -13, -21, -25, 4, 8, 17, 17, -5, -2, 0, -4, -3, 127, 127, 127, 127, 127, 127, 127, 127, 127, 124, 127, 127, 127, 127, 127, 127, 127, 127, 127, -7, 9, 28, 38, 24, 19, 22, 21, 11, -1, -10, -33, -54, -59, -10, -29, -51, -56, 23},
    {10, 7, 7, 7, 22, 37, 45, -5, -8, -7, 15, 16, 17, 19, 4, 3, 3, 0, 7, 126, 127, 127, 127, 127, 127, 127, 126, 127, 122, 123, 125, 127, 121, 124, 126, 127, 121, 127, -10, 11, 33, 44, 24, 26, 34, 23, 10, 2, -8, -33, -55, -59, -9, -32, -55, -60, 26},
    {18, 14, 13, 10, 24, 24, 28, -1, 6, 12, 16, 16, 16, 14, 9, 12, 13, 13, 11, 121, 126, 127, 127, 127, 126, 126, 126, 127, 127, 117, 127, 127, 123, 117, 127, 124, 116, 126, -7, 13, 37, 47, 29, 15, -12, 26, 6, -30, -1, -33, -51, -59, -4, -40, -59, -63, 28},
    {14, 12, 11, 13, 25, 38, 48, -6, 4, -7, 13, 16, 11, 14, 6, -1, -1, 3, 16, 118, 122, 125, 127, 119, 125, 127, 127, 127, 126, 115, 121, 125, 110, 115, 127, 117, 115, 127, -5, 18, 38, 55, 24, 24, 0, 26, 8, -16, 2, -29, -57, -56, -2, -32, -57, -63, 30},
    {4, 4, 8, 8, 16, 24, 35, -7, -5, -1, 14, 12, 15, 16, 2, 5, -4, 1, 6, 118, 121, 124, 123, 125, 127, 121, 114, 118, 118, 113, 115, 120, 110, 110, 118, 127, 119, 123, -4, 14, 27, 33, 27, 17, 6, 25, 3, -26, -9, -31, -49, -53, -9, -33, -52, -55, 25},
    {15, 12, 12, 15, 27, 40, 54, 0, -4, -14, 17, 21, 22, 23, 7, 5, 0, 1, 15, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, -15, 6, 27, 37, 16, 17, 5, 18, 8, -8, -14, -34, -62, -64, -15, -36, -58, -64, 21},
    {9, 9, 10, 10, 23, 37, 48, -2, -9, -17, 15, 15, 15, 16, 4, -2, -7, -9, 9, 127, 127, 126, 127, 125, 127, 125, 124, 123, 119, 124, 123, 127, 121, 124, 122, 127, 121, 126, -12, 7, 27, 36, 20, 16, 16, 19, 7, -3, -13, -35, -57, -60, -13, -29, -50, -54, 22},
    {9, 8, 10, 9, 21, 32, 44, -5, -9, -15, 14, 14, 15, 16, 4, -1, -4, -5, 7, 125, 125, 124, 123, 124, 124, 122, 120, 121, 117, 120, 120, 123, 116, 121, 121, 127, 120, 123, -12, 6, 24, 35, 20, 15, 12, 18, 4, -7, -12, -35, -55, -60, -12, -33, -54, -56, 19},
    {9, 8, 9, 9, 22, 34, 44, -3, -9, -15, 15, 16, 18, 19, 3, -2, -6, -7, 9, 126, 126, 126, 126, 125, 127, 123, 123, 124, 118, 124, 123, 126, 119, 124, 123, 127, 123, 126, -12, 8, 28, 37, 21, 16, 15, 20, 7, -4, -12, -34, -57, -60, -12, -31, -53, -57, 24},
    {8, 7, 10, 10, 21, 32, 40, -3, -9, -17, 15, 14, 17, 18, 4, -1, -5, -6, 7, 125, 125, 124, 123, 123, 124, 121, 121, 121, 117, 123, 121, 123, 116, 123, 120, 126, 119, 124, -10, 9, 26, 36, 21, 14, 10, 20, 5, -2, -12, -32, -54, -58, -11, -30, -52, -55, 23},
    {9, 11, 11, 11, 22, 32, 41, -1, -8, -16, 14, 16, 17, 17, 4, 0, -5, -6, 11, 127, 127, 127, 127, 127, 127, 124, 126, 127, 122, 125, 126, 127, 123, 125, 126, 127, 124, 127, -10, 10, 28, 37, 22, 12, 5, 20, 8, -6, -12, -34, -57, -60, -11, -30, -51, -56, 23},
    {9, 8, 9, 9, 20, 29, 38, -4, -9, -13, 14, 14, 16, 16, 4, 1, -1, -3, 6, 126, 126, 125, 124, 125, 126, 122, 121, 122, 118, 123, 123, 124, 118, 123, 122, 127, 120, 124, -10, 8, 26, 36, 22, 13, 7, 19, 4, -10, -10, -33, -53, -59, -10, -31, -52, -55, 22},
    {10, 11, 11, 12, 23, 33, 40, -1, -6, -11, 14, 16, 18, 18, 5, 1, -1, -2, 10, 127, 126, 127, 127, 126, 127, 126, 126, 127, 121, 126, 126, 127, 122, 123, 125, 127, 123, 127, -12, 7, 27, 37, 19, 11, 6, 18, 4, -10, -13, -34, -56, -60, -13, -32, -52, -57, 22},
    {10, 11, 11, 12, 23, 33, 40, -1, -6, -11, 14, 16, 18, 18, 5, 1, -1, -2, 10, 127, 126, 127, 127, 126, 127, 126, 126, 127, 121, 126, 126, 127, 122, 123, 125, 127, 123, 127, -12, 7, 27, 37, 19, 11, 6, 18, 4, -10, -13, -34, -56, -60, -13, -32, -52, -57, 22}
};

typedef struct {
    const int8_t *data;
    uint32_t      bytes;
    uint32_t      off;
    const char   *name;
} wb_entry_t;

#define WB(arr, wb_byte)  { arr, sizeof(arr), (wb_byte), #arr }

static const wb_entry_t wb_map[] = {
    WB(PatchEmbedding_quant_w,                   0),
    WB(PatchEmbedding_quant_b,                 400),
    WB(MambaBlock_0_LightNorm_w_quant,         420),
    WB(MambaBlock_0_LightNorm_b_quant,         440),
    WB(MambaBlock_0_proj_w_quant,              460),
    WB(MambaBlock_0_proj_b_quant,             1260),
    WB(MambaBlock_0_proj_res_w_quant,         1300),
    WB(MambaBlock_0_proj_res_b_quant,         2100),
    WB(MambaBlock_0_conv1d_w_quant,           3772),
    WB(MambaBlock_0_conv1d_b_quant,           5372),
    WB(MambaBlock_0_SSM_pre_A_quant,          5412),
    WB(MambaBlock_0_SSM_pre_D_quant,          5732),
    WB(MambaBlock_0_SSM_pre_deltaBC_w_quant,  5772),
    WB(MambaBlock_0_SSM_pre_dt_proj_w_quant,  7868),
    WB(MambaBlock_0_SSM_pre_dt_proj_b_quant,  9148),
    WB(MambaBlock_0_proj_rev_w,               9188),
    WB(MambaBlock_0_proj_rev_b,               9988),
    WB(MambaBlock_1_LightNorm_w_quant,       10008),
    WB(MambaBlock_1_LightNorm_b_quant,       10028),
    WB(MambaBlock_1_proj_w_quant,            10048),
    WB(MambaBlock_1_proj_b_quant,            10848),
    WB(MambaBlock_1_proj_res_w_quant,        10888),
    WB(MambaBlock_1_proj_res_b_quant,        11688),
    WB(MambaBlock_1_conv1d_w_quant,          11964),
    WB(MambaBlock_1_conv1d_b_quant,          13564),
    WB(MambaBlock_1_SSM_pre_A_quant,         13604),
    WB(MambaBlock_1_SSM_pre_D_quant,         13924),
    WB(MambaBlock_1_SSM_pre_deltaBC_w_quant, 13964),
    WB(MambaBlock_1_SSM_pre_dt_proj_w_quant, 16060),
    WB(MambaBlock_1_SSM_pre_dt_proj_b_quant, 17340),
    WB(MambaBlock_1_proj_rev_w,              17380),
    WB(MambaBlock_1_proj_rev_b,              18180),
    WB(outputhead_LightNorm_w_quant,         18200),
    WB(outputhead_LightNorm_b_quant,         18220),
    WB(outputhead_linear_w,                  18240),
    WB(outputhead_linear_b,                  19380),
};

#define WB_MAP_N  (sizeof(wb_map) / sizeof(wb_map[0]))

static uint8_t wb_image[WB_IMAGE_BYTES] __attribute__((aligned(4)));

static int build_wb_image(void)
{
    memset(wb_image, 0, sizeof(wb_image));
    for (uint32_t i = 0; i < WB_MAP_N; i++) {
        const wb_entry_t *e = &wb_map[i];
        if (e->off + e->bytes > WB_IMAGE_BYTES) {
            printf("wb_map[%lu] %s: off %lu + %lu > %d\n",
                   (unsigned long)i, e->name,
                   (unsigned long)e->off, (unsigned long)e->bytes, WB_IMAGE_BYTES);
            return -1;
        }
        if (i > 0 && e->off < wb_map[i - 1].off + wb_map[i - 1].bytes) {
            printf("wb_map[%lu] %s overlaps previous entry\n", (unsigned long)i, e->name);
            return -1;
        }
        memcpy(&wb_image[e->off], e->data, e->bytes);
    }
    return 0;
}

static int write_wb_bram(void)
{
    const uint32_t *src = (const uint32_t *)wb_image;

    for (uint32_t w = 0; w < WB_IMAGE_BYTES / 4; w++)
        mmio_write32(WB_BASE, 4 * w, src[w]);

    for (uint32_t w = 0; w < WB_IMAGE_BYTES / 4; w++) {
        uint32_t rb = mmio_read32(WB_BASE, 4 * w);
        if (rb != src[w]) {
            printf("WB verify fail @byte %lu: wrote %08lX read %08lX\n",
                   (unsigned long)(4 * w), (unsigned long)src[w], (unsigned long)rb);
            return -1;
        }
    }
    return 0;
}

static int load_frame(void)
{
    const uint32_t *src = (const uint32_t *)frame_single;

    for (uint32_t w = 0; w < FRAME_BYTES / 4; w++)
        mmio_write32(IN_BASE, 4 * w, src[w]);

    for (uint32_t w = 0; w < FRAME_BYTES / 4; w++) {
        uint32_t rb = mmio_read32(IN_BASE, 4 * w);
        if (rb != src[w]) {
            printf("IN verify fail @byte %lu: wrote %08lX read %08lX\n",
                   (unsigned long)(4 * w), (unsigned long)src[w], (unsigned long)rb);
            return -1;
        }
    }
    return 0;
}

// the Xilinx version spins forever here; a timeout keeps the UART log useful when the IP hangs
static int wait_status(uint32_t mask, uint32_t expected, uint32_t *ctrl)
{
    for (uint32_t poll = 0; poll < STATUS_POLL_LIMIT; poll++) {
        *ctrl = mmio_read_ctrl();
        if ((*ctrl & mask) == expected)
            return 0;
    }
    printf("Status timeout: mask=%08lX expected=%08lX ctrl=%08lX\n",
           (unsigned long)mask, (unsigned long)expected, (unsigned long)*ctrl);
    return -1;
}

static void read_output(uint8_t buf[NUM_SEQLEN][OUT_ROW_STRIDE])
{
    for (int s = 0; s < NUM_SEQLEN; s++) {
        for (int w = 0; w < OUT_ROW_STRIDE / 4; w++) {
            uint32_t v = mmio_read32(OUT_BASE, (uint32_t)(s * OUT_ROW_STRIDE + 4 * w));
            buf[s][4 * w + 0] = (uint8_t)(v);
            buf[s][4 * w + 1] = (uint8_t)(v >> 8);
            buf[s][4 * w + 2] = (uint8_t)(v >> 16);
            buf[s][4 * w + 3] = (uint8_t)(v >> 24);
        }
    }
}

static int compare_golden(uint8_t buf[NUM_SEQLEN][OUT_ROW_STRIDE])
{
    int max_err = 0, mismatch = 0, worst_s = -1, worst_c = -1;

    for (int s = 0; s < NUM_SEQLEN; s++) {
        int row_max = 0;
        for (int c = 0; c < NUM_CLASS; c++) {
            int e = (int)(int8_t)buf[s][c] - (int)golden_out[s][c];
            if (e < 0) e = -e;
            if (e > row_max) row_max = e;
            if (e > GOLDEN_TOL) mismatch++;
            if (e > max_err) { max_err = e; worst_s = s; worst_c = c; }
        }
        printf("  seq %2d: tag %02X  max|err| = %d\n", s, buf[s][NUM_CLASS], row_max);
    }

    printf("golden compare: max|err| = %d", max_err);
    if (worst_s >= 0)
        printf(" @ seq %d class %d (hw %d, golden %d)", worst_s, worst_c,
               (int)(int8_t)buf[worst_s][worst_c], (int)golden_out[worst_s][worst_c]);
    printf(", %d entries over tol %d\n", mismatch, GOLDEN_TOL);
    return mismatch;
}

int main(void)
{
    static uint8_t out_buf[NUM_SEQLEN][OUT_ROW_STRIDE];
    uint32_t ctrl = 0;

    printf("\n=== eMamba single-frame test (quant_input_1) ===\n");
    printf("ctrl @%08lX  in @%08lX  out @%08lX  wb @%08lX\n",
           (unsigned long)EMAMBA_BASEADDR, (unsigned long)IN_BASE,
           (unsigned long)OUT_BASE, (unsigned long)WB_BASE);
    printf("ctrl before = %08lX\n", (unsigned long)mmio_read_ctrl());

    if (build_wb_image() || write_wb_bram()) {
        printf("WB build or write failed\n");
        return -1;
    }
    printf("WB image written: %d B, %lu arrays\n", WB_IMAGE_BYTES, (unsigned long)WB_MAP_N);

    mmio_write_ctrl(CTRL_WB_LOAD);
    memory_barrier();
    if (wait_status(STAT_WB_DONE, STAT_WB_DONE, &ctrl)) {
        printf("WB load failed\n");
        return -1;
    }
    printf("WB loaded (ctrl = %08lX)\n", (unsigned long)ctrl);

    if (load_frame()) {
        printf("Frame load failed\n");
        return -1;
    }
    printf("frame written: %lu B\n", (unsigned long)FRAME_BYTES);

    // start only: writing CTRL_WB_LOAD together lets the loader overwrite weights mid-run
    memory_barrier();
    mmio_write_ctrl(CTRL_START);
    memory_barrier();
    if (wait_status(STAT_FRAME_DONE, STAT_FRAME_DONE, &ctrl)) {
        printf("Frame incomplete\n");
        return -1;
    }
    printf("frame done (ctrl = %08lX)\n", (unsigned long)ctrl);

    memory_barrier();
    read_output(out_buf);

    // 12 values per line keeps every line under 80 columns so minicom does not clip it
    printf("Frame 0 (hw):\n");
    for (int s = 0; s < NUM_SEQLEN; s++) {
        for (int c = 0; c < NUM_CLASS; c++) {
            if (c % 12 == 0)
                printf("hw[%2d][%2d]:", s, c);
            printf("%4d", (int)(int8_t)out_buf[s][c]);
            if (c % 12 == 11 || c == NUM_CLASS - 1)
                printf("\n");
        }
    }

    printf("\nDiff (hw - golden):\n");
    for (int s = 0; s < NUM_SEQLEN; s++) {
        for (int c = 0; c < NUM_CLASS; c++) {
            if (c % 12 == 0)
                printf("df[%2d][%2d]:", s, c);
            printf("%4d", (int)(int8_t)out_buf[s][c] - (int)golden_out[s][c]);
            if (c % 12 == 11 || c == NUM_CLASS - 1)
                printf("\n");
        }
    }

    printf("\n");
    int mismatch = compare_golden(out_buf);
    printf("\n%s\n", mismatch ? "*** MISMATCH ***" : "PASS (within tol)");

    printf("\nFinish test.\n");
    return mismatch ? -1 : 0;
}
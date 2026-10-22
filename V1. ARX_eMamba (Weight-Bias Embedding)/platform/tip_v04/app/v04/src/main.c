/* RVX: stdio unavailable -> ervp_printf; string.h avoided via local copy helper. */
#include <stdint.h>

#include "ervp_printf.h"
#include "core.h"
#include "json.h"

/* Weights/biases embedded as compile-time const int8_t arrays, passed straight
 * into the kernels (scaled on the fly). All activation buffers are int8_t. */
#include "PatchEmbedding_int8_arrays.h"
#include "MambaBlock_0_int8_arrays.h"
#include "MambaBlock_1_int8_arrays.h"
#include "outputhead_int8_arrays.h"

/* memcpy replacement for [NUM_SEQLEN][NUM_DIM] int8 activation blocks */
static void copy_dim(int8_t dst[NUM_SEQLEN][NUM_DIM],
                     const int8_t src[NUM_SEQLEN][NUM_DIM])
{
    for (int i = 0; i < NUM_SEQLEN; i++)
        for (int j = 0; j < NUM_DIM; j++)
            dst[i][j] = src[i][j];
}

#define CHECK_LOAD(call) do {                 \
    int rc = (call);                          \
    if (rc != 0) {                            \
        printf("LOAD FAIL: %s -> rc=%d\n",   \
               #call, rc);                   \
        return 1;                             \
    }                                         \
} while (0)

#define STATIC 1

/* ---- Activation buffers (int8_t): every value handed back to main is
 *      cap_int8/clamped, so int8 storage is exact. ---- */
#ifdef STATIC
    static int8_t input_token[NUM_CHANNELS][NUM_HEIGHT][NUM_WIDTH];

    /* PatchEmbedding */
    static int8_t dOut_Patch_Rearrange[NUM_SEQLEN][NUM_DIM];
    static int8_t Patch_Linear_dOut[NUM_SEQLEN][NUM_DIM];

    /* MambaBlock */
    static int8_t skip[NUM_SEQLEN][NUM_DIM];
    static int8_t x[NUM_SEQLEN][NUM_DIM];
    static int8_t x1[NUM_SEQLEN][NUM_ED];
    static int8_t z1[NUM_SEQLEN][NUM_ED];
    // static int8_t z1_silu[NUM_SEQLEN][NUM_ED]; // in-place update z1_silu to z1 to compress memory
    static int8_t xx[NUM_ED][NUM_SEQLEN];
    static int8_t xxx[NUM_ED][NUM_SEQLEN];
    // static int8_t xxxx[NUM_SEQLEN][NUM_ED];    // xxxx to x1 to compress memory
    static int8_t delta[NUM_SEQLEN][NUM_DELTA];   // [16][32]
    static int8_t B[NUM_SEQLEN][NUM_N];           // [16][8]
    static int8_t C[NUM_SEQLEN][NUM_N];           // [16][8]
    static int8_t delta_dOut[NUM_SEQLEN][NUM_ED];
    // static int8_t delta_relu[NUM_SEQLEN][NUM_ED]; // in-place update delta_relu to delta_dOut to compress memory
    static int8_t deltaA[NUM_SEQLEN][NUM_ED][NUM_N];
    static int8_t deltaB[NUM_SEQLEN][NUM_ED][NUM_N];
    static int8_t ssm_dOut[NUM_SEQLEN][NUM_ED];
    // static int8_t elem_dOut[NUM_SEQLEN][NUM_ED]; // elem_dOut to x1 to compress memory
    // static int8_t Linear_contract_dOut[NUM_SEQLEN][NUM_DIM]; // Linear_contract_dOut to x to compress memory
    static int8_t final_add[NUM_SEQLEN][NUM_DIM];
    // static int8_t blk1_backup[NUM_SEQLEN][NUM_DIM];    // blk1_backup to skip to compress memory

    /* OutputHead */
    static int8_t OutputHead_Linear_dOut[NUM_SEQLEN][NUM_CLASS];

    /* FPGA reference result (loaded from JSON for the final compare). */
    static int8_t FPGA_outputhead_linear_dOut[NUM_SEQLEN][NUM_CLASS];
#endif

int main()
{

#ifndef STATIC
    int8_t input_token[NUM_CHANNELS][NUM_HEIGHT][NUM_WIDTH];

    int8_t dOut_Patch_Rearrange[NUM_SEQLEN][NUM_DIM];
    int8_t Patch_Linear_dOut[NUM_SEQLEN][NUM_DIM];

    int8_t skip[NUM_SEQLEN][NUM_DIM];
    int8_t x[NUM_SEQLEN][NUM_DIM];
    int8_t x1[NUM_SEQLEN][NUM_ED];
    int8_t z1[NUM_SEQLEN][NUM_ED];
    // int8_t z1_silu[NUM_SEQLEN][NUM_ED]; // in-place update z1_silu to z1 to compress memory
    int8_t xx[NUM_ED][NUM_SEQLEN];
    int8_t xxx[NUM_ED][NUM_SEQLEN];
    // int8_t xxxx[NUM_SEQLEN][NUM_ED];    // xxxx to x1 to compress memory
    int8_t delta[NUM_SEQLEN][NUM_DELTA];
    int8_t B[NUM_SEQLEN][NUM_N];
    int8_t C[NUM_SEQLEN][NUM_N];
    int8_t delta_dOut[NUM_SEQLEN][NUM_ED];
    // int8_t delta_relu[NUM_SEQLEN][NUM_ED]; // in-place update delta_relu to delta_dOut to compress memory
    int8_t deltaA[NUM_SEQLEN][NUM_ED][NUM_N];
    int8_t deltaB[NUM_SEQLEN][NUM_ED][NUM_N];
    int8_t ssm_dOut[NUM_SEQLEN][NUM_ED];
    // int8_t elem_dOut[NUM_SEQLEN][NUM_ED]; // elem_dOut to x1 to compress memory
    //int8_t Linear_contract_dOut[NUM_SEQLEN][NUM_DIM]; // Linear_contract_dOut to x to compress memory
    int8_t final_add[NUM_SEQLEN][NUM_DIM];
    // int8_t blk1_backup[NUM_SEQLEN][NUM_DIM];    // blk1_backup to skip to compress memory

    int8_t OutputHead_Linear_dOut[NUM_SEQLEN][NUM_CLASS];
    int8_t FPGA_outputhead_linear_dOut[NUM_SEQLEN][NUM_CLASS];
#endif

    //---------------------------------- PatchEmbedding ----------------------------------
    /* FIRST JSON read: quantized input. */

    printf(" -=-=-=-=-=-= here we go =-=-=-=-=-=-=\n");
    CHECK_LOAD(load_int_value_json("quant_input_1.json", input_token));

    printf(" -=-=-=-=-=-= input_token loaded =-=-=-=-=-=-=\n");
    Patch_Rearrange(input_token, dOut_Patch_Rearrange);

    Patch_Linear(
        NUM_SEQLEN,
        NUM_DIM,
        NUM_DIM,
        dOut_Patch_Rearrange,
        PatchEmbedding_quant_w,      // const int8_t [20][20]
        PatchEmbedding_quant_b,      // const int8_t [20]
        Patch_Linear_dOut,
        3,
        7,
        8,
        5
    );

    //===============================================================================================
    // Start of MambaBlock_0
    //===============================================================================================

    //---------------------------------- skip ----------------------------------
    copy_dim(skip, Patch_Linear_dOut);

    //---------------------------------- LightNorm ----------------------------------
    int exp_dIn = 5;
    int exp_bias = 3;
    int exp_dOut = -(10-6);
    int exp_weight = 0;
    LightNorm(
        NUM_SEQLEN,
        NUM_DIM,
        NUM_DIM,
        Patch_Linear_dOut,
        MambaBlock_0_LightNorm_w_quant,   // const int8_t [20]
        MambaBlock_0_LightNorm_b_quant,   // const int8_t [20]
        x, // LightNorm_dOut
        exp_dIn,
        exp_weight,
        exp_bias,
        exp_dOut
    );

    //---------------------------------- Linear_expand x1 ----------------------------------
    exp_dIn = 0;
    exp_bias = 6;
    exp_dOut = -8;
    exp_weight = 0;
    Linear_expand(
        NUM_SEQLEN,
        NUM_DIM,
        NUM_ED,
        x,
        MambaBlock_0_proj_w_quant,        // const int8_t [40][20]
        MambaBlock_0_proj_b_quant,        // const int8_t [40]
        x1,
        exp_dIn,
        exp_weight,
        exp_bias,
        exp_dOut
    );

    //---------------------------------- Linear_expand_res z1 ----------------------------------
    exp_dIn = 0;
    exp_bias = 6;
    exp_dOut = -(6+8-5);
    exp_weight = 0;
    Linear_expand(
        NUM_SEQLEN,
        NUM_DIM,
        NUM_ED,
        x,
        MambaBlock_0_proj_res_w_quant,    // const int8_t [40][20]
        MambaBlock_0_proj_res_b_quant,    // const int8_t [40]
        z1,
        exp_dIn,
        exp_weight,
        exp_bias,
        exp_dOut
    );

    //---------------------------------- SiLU_piecewise z1_silu ----------------------------------
    int scale_dIn = 5;
    exp_dIn = 0;
    exp_dOut = -(5*2-5);
    SiLU_piecewise(
        NUM_SEQLEN,
        NUM_ED,
        z1,
        z1, // in-place update z1_silu to z1 to compress memory
        exp_dIn,
        exp_dOut,
        scale_dIn
    );

    //---------------------------------- Rearrange ----------------------------------
    Rearrange(
        NUM_SEQLEN,
        NUM_ED,
        x1,
        xx
    );
    printf("Rearrange xx: \n");

    //---------------------------------- Conv1D ----------------------------------
    exp_dIn = 0;
    exp_bias = 5;
    exp_dOut = -9;
    exp_weight = 0;
    Conv1D(
        NUM_ED,          // OUT_CH = 40
        NUM_ED,          // IN_CH  = 40
        NUM_SEQLEN,      // SEQ_LEN = 16
        xx,
        MambaBlock_0_conv1d_w_quant,      // const int8_t [40][40][1]
        MambaBlock_0_conv1d_b_quant,      // const int8_t [40]
        xxx,
        exp_dIn,
        exp_weight,
        exp_bias,
        exp_dOut
    );

    //---------------------------------- Rearrange ----------------------------------
    Rearrange(
        NUM_ED,
        NUM_SEQLEN,
        xxx,
        x1
    );

    //---------------------------------- SSM_pre_Linear_dBC ---------------------------------
    exp_dIn = 0;
    exp_weight = 0;
    exp_dOut = 0;
    int exp_delta=-(5+8-5);
    int exp_B=-(5+8-5);
    int exp_C=-(5+8-5);
    SSM_pre_Linear_dBC(
        x1,  // [16][40]
        MambaBlock_0_SSM_pre_deltaBC_w_quant,   // const int8_t [48][40]
        delta,           // [16][32]
        B,               // [16][8]
        C,               // [16][8]
        exp_dIn,
        exp_weight,
        exp_dOut,
        exp_delta,
        exp_B,
        exp_C
    );

    //---------------------------------- SSM_pre_Linear_delta ---------------------------------
    exp_dIn = 0;
    exp_weight = 0;
    exp_bias=(5+8-8);
    exp_dOut=-(5+8-4);
    SSM_pre_Linear_delta(
        delta,
        MambaBlock_0_SSM_pre_dt_proj_w_quant,   // const int8_t [40][32]
        MambaBlock_0_SSM_pre_dt_proj_b_quant,   // const int8_t [40]
        delta_dOut,
        exp_dIn,
        exp_weight,
        exp_bias,
        exp_dOut
    );

    SSM_pre_ReLU(
        NUM_SEQLEN,
        NUM_ED,
        delta_dOut,
        delta_dOut // in-place update delta_relu to delta_dOut to compress memory
    );
    printf("SSM_pre_ReLU delta_dOut: \n");

    //---------------------------------- SSM_pre_deltaA ---------------------------------
    exp_dIn = 0;
    int exp_A=0;
    exp_dOut=-((4+3)*2 - 7);
    int scale_delta=4;
    int scale_A=3;
    SSM_pre_deltaA(
        delta_dOut, // in-place update delta_relu to delta_dOut to compress memory
        MambaBlock_0_SSM_pre_A_quant,           // const int8_t [40][8]
        deltaA,
        exp_dIn,
        exp_A,
        exp_dOut,
        scale_delta,
        scale_A
    );

    //---------------------------------- SSM_pre_deltaB ---------------------------------
    int exp_deltaB_dOut = -(4+5-3);
    SSM_pre_deltaB(
        delta_dOut, // in-place update delta_relu to delta_dOut to compress memory
        B,              // [16][8]
        deltaB,         // [16][40][8]
        exp_deltaB_dOut
    );

    //---------------------------------- SSM_computation ---------------------------------
    scale_dIn = 5;
    int scale_deltaA = 7;
    int scale_deltaB = 3;
    int scale_C = 5;
    int scale_D = 6;     // D_quant.json scale = 2^-6
    int scale_dOut = 1;
    SSM_computation(
        x1,   // [16][40]
        deltaA,      // [16][40][8]
        deltaB,      // [16][40][8]
        C,           // [16][8]
        MambaBlock_0_SSM_pre_D_quant,           // const int8_t [40]
        ssm_dOut,    // [16][40]
        scale_dIn,
        scale_deltaA,
        scale_deltaB,
        scale_C,
        scale_D,
        scale_dOut
    );

    //---------------------------------- Elementwise_Product ---------------------------------
    int exp_dIn1 = 0;
    int exp_dIn2 = 0;
    exp_dOut = -(1+5-2);
    Elementwise_Product(
        NUM_SEQLEN,
        NUM_ED,
        ssm_dOut,     // [16][40]
        z1, // in-place update z1_silu to z1 to compress memory
        x1,  // elem_dOut to x1 to compress memory
        exp_dIn1,
        exp_dIn2,
        exp_dOut
    );

    //---------------------------------- Linear_contract / proj_rev ----------------------------------
    int exp_dIn_contract = 0;
    int exp_weight_contract = 0;
    int exp_bias_contract = (2+8-9);
    int exp_dOut_contract = -(2+8-3);
    Linear_contract(
        NUM_SEQLEN,              // N = 16
        NUM_ED,                  // K = 40
        NUM_DIM,                 // M = 20
        x1,                      // elem_dOut to x1 to compress memory
        MambaBlock_0_proj_rev_w, // const int8_t [20][40]
        MambaBlock_0_proj_rev_b, // const int8_t [20]
        x,    // Linear_contract_dOut to x to compress memory
        exp_dIn_contract,
        exp_weight_contract,
        exp_bias_contract,
        exp_dOut_contract
    );

    //---------------------------------- Elemetwise_Add ---------------------------------
    int exp_dIn1_add = 2;
    int exp_dIn2_add = 0;
    int exp_dOut_add = -(5-3);
    Elementwise_Add(
        NUM_SEQLEN,
        NUM_DIM,
        x,  // Linear_contract_dOut to x to compress memory
        skip,
        final_add,
        exp_dIn1_add,
        exp_dIn2_add,
        exp_dOut_add
    );
    printf("Block 0 final_add: \n");

    //===============================================================================================
    // End of MambaBlock_0   ||   START OF MambaBlock_1
    //===============================================================================================

    copy_dim(skip, final_add); // blk1_backup to final_add to compress memory
    copy_dim(x, final_add);

    //---------------------------------- LightNorm ----------------------------------
    exp_dIn = 5;
    exp_bias = 3;
    exp_dOut = -(10-6);
    exp_weight = 0;
    LightNorm(
        NUM_SEQLEN,
        NUM_DIM,
        NUM_DIM,
        x,
        MambaBlock_1_LightNorm_w_quant,
        MambaBlock_1_LightNorm_b_quant,
        x, // LightNorm_dOut
        exp_dIn,
        exp_weight,
        exp_bias,
        exp_dOut
    );

    //---------------------------------- Linear_expand x1 ----------------------------------
    exp_dIn = 0;
    exp_bias = 6;
    exp_dOut = -8;
    exp_weight = 0;
    Linear_expand(
        NUM_SEQLEN,
        NUM_DIM,
        NUM_ED,
        x,
        MambaBlock_1_proj_w_quant,
        MambaBlock_1_proj_b_quant,
        x1,
        exp_dIn,
        exp_weight,
        exp_bias,
        exp_dOut
    );

    //---------------------------------- Linear_expand_res z1 ----------------------------------
    exp_dIn = 0;
    exp_bias = (6+7-8);
    exp_dOut = -(6+7-5);
    exp_weight = 0;
    Linear_expand(
        NUM_SEQLEN,
        NUM_DIM,
        NUM_ED,
        x,
        MambaBlock_1_proj_res_w_quant,
        MambaBlock_1_proj_res_b_quant,
        z1,
        exp_dIn,
        exp_weight,
        exp_bias,
        exp_dOut
    );

    //---------------------------------- SiLU_piecewise z1_silu ----------------------------------
    scale_dIn = 5;
    exp_dIn = 0;
    exp_dOut = -(5*2-5);
    SiLU_piecewise(
        NUM_SEQLEN,
        NUM_ED,
        z1,
        z1, // in-place update z1_silu to z1 to compress memory
        exp_dIn,
        exp_dOut,
        scale_dIn
    );

    //---------------------------------- Rearrange ----------------------------------
    Rearrange(
        NUM_SEQLEN,
        NUM_ED,
        x1,
        xx
    );

    //---------------------------------- Conv1D ----------------------------------
    exp_dIn = 0;
    exp_bias = (6+7-8);
    exp_dOut = -(6+7-5);
    exp_weight = 0;
    Conv1D(
        NUM_ED,          // OUT_CH = 40
        NUM_ED,          // IN_CH  = 40
        NUM_SEQLEN,      // SEQ_LEN = 16
        xx,
        MambaBlock_1_conv1d_w_quant,
        MambaBlock_1_conv1d_b_quant,
        xxx,
        exp_dIn,
        exp_weight,
        exp_bias,
        exp_dOut
    );

    //---------------------------------- Rearrange ----------------------------------
    Rearrange(
        NUM_ED,
        NUM_SEQLEN,
        xxx,
        x1
    );

    //---------------------------------- SSM_pre_Linear_dBC ---------------------------------
    exp_dIn = 0;
    exp_weight = 0;
    exp_dOut = 0;
    exp_delta=-(5+7-5);
    exp_B=-(5+7-3);
    exp_C=-(5+7-3);
    SSM_pre_Linear_dBC(
        x1,  // [16][40]
        MambaBlock_1_SSM_pre_deltaBC_w_quant,
        delta,           // [16][32]
        B,               // [16][8]
        C,               // [16][8]
        exp_dIn,
        exp_weight,
        exp_dOut,
        exp_delta,
        exp_B,
        exp_C
    );

    //---------------------------------- SSM_pre_Linear_delta ---------------------------------
    exp_dIn = 0;
    exp_weight = 0;
    exp_bias=(5+8-8);
    exp_dOut=-(5+8-4);
    SSM_pre_Linear_delta(
        delta,
        MambaBlock_1_SSM_pre_dt_proj_w_quant,
        MambaBlock_1_SSM_pre_dt_proj_b_quant,
        delta_dOut,
        exp_dIn,
        exp_weight,
        exp_bias,
        exp_dOut
    );

    SSM_pre_ReLU(
        NUM_SEQLEN,
        NUM_ED,
        delta_dOut,
        delta_dOut // in-place update delta_relu to delta_dOut to compress memory
    );

    //---------------------------------- SSM_pre_deltaA ---------------------------------
    exp_dIn = 0;
    exp_A=0;
    exp_dOut=-((4+2)*2 - 7);
    scale_delta=4;
    scale_A=2;
    SSM_pre_deltaA(
        delta_dOut, // in-place update delta_relu to delta_dOut to compress memory
        MambaBlock_1_SSM_pre_A_quant,
        deltaA,            // [16][40][8]
        exp_dIn,
        exp_A,
        exp_dOut,
        scale_delta,
        scale_A
    );

    //---------------------------------- SSM_pre_deltaB ---------------------------------
    exp_deltaB_dOut = -(4+3-1);
    SSM_pre_deltaB(
        delta_dOut, // in-place update delta_relu to delta_dOut to compress memory
        B,              // [16][8]
        deltaB,         // [16][40][8]
        exp_deltaB_dOut
    );

    //---------------------------------- SSM_computation ---------------------------------
    scale_dIn = 5;
    scale_deltaA = 7;
    scale_deltaB = 1;
    scale_C = 3;
    scale_D = 6;     // D_quant.json scale = 2^-6
    scale_dOut = -3;
    SSM_computation(
        x1,   // [16][40]
        deltaA,      // [16][40][8]
        deltaB,      // [16][40][8]
        C,           // [16][8]
        MambaBlock_1_SSM_pre_D_quant,
        ssm_dOut,    // [16][40]
        scale_dIn,
        scale_deltaA,
        scale_deltaB,
        scale_C,
        scale_D,
        scale_dOut
    );

    //---------------------------------- Elementwise_Product ---------------------------------
    exp_dIn1 = 0;
    exp_dIn2 = 0;
    exp_dOut = -(-3+5 - (-4));
    Elementwise_Product(
        NUM_SEQLEN,
        NUM_ED,
        ssm_dOut,     // [16][40]
        z1, // in-place update z1_silu to z1 to compress memory
        x1,  // elem_dOut to x1 to compress memory
        exp_dIn1,
        exp_dIn2,
        exp_dOut
    );

    //---------------------------------- Linear_contract / proj_rev ----------------------------------
    exp_dIn_contract = 6;
    exp_weight_contract = 0;
    exp_bias_contract = 0;
    exp_dOut_contract = -(9-(-3));
    Linear_contract(
        NUM_SEQLEN,              // N = 16
        NUM_ED,                  // K = 40
        NUM_DIM,                 // M = 20
        x1,                      // elem_dOut to x1 to compress memory
        MambaBlock_1_proj_rev_w,
        MambaBlock_1_proj_rev_b,
        x,  // Linear_contract_dOut to x to compress memory
        exp_dIn_contract,
        exp_weight_contract,
        exp_bias_contract,
        exp_dOut_contract
    );

    //---------------------------------- Elemetwise_Add ---------------------------------
    exp_dIn1_add = 6;
    exp_dIn2_add = 0;
    exp_dOut_add = -6;
    Elementwise_Add(
        NUM_SEQLEN,
        NUM_DIM,
        x,  // Linear_contract_dOut to x to compress memory
        skip, // blk1_backup to skip to compress memory
        final_add,
        exp_dIn1_add,
        exp_dIn2_add,
        exp_dOut_add
    );

    //===============================================================================================
    // End of MambaBlock_1   ||   START OF OutputHead
    //===============================================================================================

    //---------------------------------- OutputHead LightNorm ----------------------------------
    exp_dIn = 5;
    exp_weight = 0;            // Python default
    exp_bias = 3;
    exp_dOut = -(10 - 6);      // -4
    LightNorm(
        NUM_SEQLEN,
        NUM_DIM,
        NUM_DIM,
        final_add,             // [16][20]
        outputhead_LightNorm_w_quant,  // const int8_t [20]
        outputhead_LightNorm_b_quant,  // const int8_t [20]
        x,                     // [16][20], OutputHead LightNorm result
        exp_dIn,
        exp_weight,
        exp_bias,
        exp_dOut
    );

    //---------------------------------- OutputHead Linear ----------------------------------
    exp_dIn = 0;
    exp_weight = 0;
    exp_bias = 6;
    exp_dOut = -8;
    Linear_expand(
        NUM_SEQLEN,
        NUM_DIM,
        NUM_CLASS,
        x,
        outputhead_linear_w,           // const int8_t [57][20]
        outputhead_linear_b,           // const int8_t [57]
        OutputHead_Linear_dOut,
        exp_dIn,
        exp_weight,
        exp_bias,
        exp_dOut
    );

    // for (int i = 0; i < NUM_SEQLEN; i++) {
    //     for (int j = 0; j < NUM_CLASS; j++) {
    //         printf( "%d ", OutputHead_Linear_dOut[i][j]);
    //     }
    //     printf( "\n");
    // }

    //===============================================================================================
    //---------------------------------- Compare OutputHead Linear ----------------------------------
    /* LAST JSON read: FPGA reference result. */
    CHECK_LOAD(load_int_value_json_3D_batch1_to_2D(
        "FPGA_result_1029_3.json",
        NUM_SEQLEN,
        NUM_CLASS,
        FPGA_outputhead_linear_dOut
    ));

    compare_int_2D(
        "FPGA OutputHead Linear Compare V.S. Verilog Result [FPGA_result_1029_3.json]",
        NUM_SEQLEN,
        NUM_CLASS,
        FPGA_outputhead_linear_dOut,
        OutputHead_Linear_dOut
    );

    return 0;
}

/*
#include "rvx_compat.h"
#include "json.h"

#define ROWS 16
#define COLS 57

#define CHECK_LOAD(call) do {                 \
int rc = (call);                          \
if (rc != 0) {                            \
printf("LOAD FAIL: %s -> rc=%d\n",   \
#call, rc);                   \
return 1;                             \
}                                         \
} while (0)

static int8_t quant_w[ROWS][COLS];

int main()
{
    printf("=-=-=-=- quant_w.json read test start -=-=-=-=-\n");
    
    CHECK_LOAD(load_int_value_json_3D_batch1_to_2D(
        "FPGA_result_1029_3.json",
        ROWS,
        COLS,
        quant_w
    ));
    
    CHECK_LOAD(load_int_value_json("quant_input_1.json", input_token));
    
    printf("quant_w loaded successfully\n\n");
    
    for (int i = 0; i < ROWS; i++) {
        for (int j = 0; j < COLS; j++) {
            printf("%d ", quant_w[i][j]);
        }
        printf("\n");
    }
    
    printf("\n=-=-=-=- quant_w.json read test end -=-=-=-=-\n");
    
    return 0;
}
*/
/*
#include "rvx_compat.h"
#include "json.h"


#define CHECK_LOAD(call) do {                 \
int rc = (call);                          \
if (rc != 0) {                            \
printf("LOAD FAIL: %s -> rc=%d\n",   \
#call, rc);                   \
return 1;                             \
}                                         \
} while (0)

static int8_t input_token[5][8][8];

int main()
{
    printf("=-=-=-=-  read test start -=-=-=-=-\n");
    
    CHECK_LOAD(load_int_value_json("quant_input_1.json", input_token));
    
    printf("quant_w loaded successfully\n\n");
    
    for (int c = 0; c < 5; c++) {   
        for (int h = 0; h < 8; h++) {
            for (int w = 0; w < 8; w++) {
                printf("%d ", input_token[c][h][w]);
            }
            printf("\n");
        }
        printf("\n");
    }
    
    printf("\n=-=-=-=- read test end -=-=-=-=-\n");
    
    return 0;
}
*/
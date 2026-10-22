/* 순서표 (vectors/program/program.mem · program.lst) — 시퀀서가 실행하는 256 bit 명령 681 줄
 * 부팅 스트림의 앞 32,768 B = 이 표 1,024 줄 × 32 B (뒤 343 줄은 0). 명령 형식은 ENGINE_SPEC §5 (op · 출처/목적 버퍼 · 주소 · 채널 · 시프트 · 플래그 · prm).
 * 줄 하나 = uint32 8 개 (워드 w = 명령의 bit [32w+31 : 32w], 스트림 바이트 4w 부터 리틀 엔디언). 비트 필드라 16 진수로 둔다.
 * 각 줄 앞의 주석 = program.lst 의 같은 줄 (pc, 명령, step, 입력 → 출력, 행 범위, 채널, 시프트, 플래그, prm 라인).
 * 값을 바꾸면 안 되는 표다 — gen_program.py 가 이미지의 영역 주소 (prm) 를 넣어 만들므로 이미지와 짝이다.
 * (tools/gen_board_headers.py 가 만든 파일 — 값을 고치면 같은 자리의 값만 바꿀 것, 배열 크기는 그대로)
 */
#ifndef EMY_PROGRAM_H_
#define EMY_PROGRAM_H_
#include <stdint.h>

#define EMY_PROGRAM_LINES 681u      /* 실제 명령 줄 수 */
#define EMY_PROGRAM_SLOTS 1024u     /* 부팅 스트림의 순서표 영역 줄 수 (32 KB) */
#define EMY_PROGRAM_BYTES 32768u

static const uint32_t emy_program[681][8] = {
    /* 0  LOOP TILE n=40 body=4 */
    { 0x00000001, 0x00280000, 0x00000004, 0x00000140, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 1  WAIT_IN wait rows>=17+(r0<<1) */
    { 0x00000002, 0x00110000, 0x00000000, 0x00000280, 0x00000000, 0x00000000, 0x00000000, 0x00110000 },
    /* 2  GEMM         L00_SimpleStem_01_conv0_Conv2d             L00 conv0: ring -> X               in: IN.ring@IN+0                                                 out: L00.conv0@X+0                    rows[0,8)    C 3->16 640x640  sh 0,0,0,0  flags 30 misc 0002  prm 0+36 L00_SimpleStem_01_conv0_Conv2d */
    { 0x00003020, 0x00030000, 0x02800010, 0x08000280, 0x00700000, 0x00000000, 0x00000020, 0x00020024 },
    /* 3  VEC_SILU     L00_SimpleStem_02_SiLU                     L00 SiLU: X -> ACC                 in: L00.conv0@X+0                                                out: L00.silu0@ACC+0                  rows[0,8)    C 16->16 320x320  sh 0,0,0,0  flags 30 misc 0000  prm 39+0 */
    { 0x00003011, 0x00100000, 0x01400010, 0x08000140, 0x00200000, 0x00000000, 0x00002750, 0x00000000 },
    /* 4  WAIT_IN release 15+(r0<<1) */
    { 0x00000002, 0x00000000, 0x0000000f, 0x00000280, 0x00000000, 0x00000000, 0x00000000, 0x00010000 },
    /* 5  LOOP TILE n=20 body=2 */
    { 0x00000001, 0x00140000, 0x00000002, 0x000000a0, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 6  GEMM         L00_SimpleStem_03_conv3_Conv2d             L00 conv3: ACC -> B                in: L00.silu0@ACC+0                                              out: L00.conv3@B+0                    rows[0,8)    C 16->32 320x320  sh 0,0,0,0  flags 30 misc 0002  prm 47+144 L00_SimpleStem_03_conv3_Conv2d */
    { 0x00003020, 0x00100000, 0x01400020, 0x08000140, 0x00500000, 0x00000000, 0x00002f10, 0x00020090 },
    /* 7  VEC_SILU     L00_SimpleStem_04_SiLU                     L00 SiLU -> A                      in: L00.conv3@B+0                                                out: L00.out@A+0                      rows[0,8)    C 32->32 160x160  sh 0,0,0,0  flags 30 misc 0000  prm 196+0 */
    { 0x00003011, 0x00200000, 0x00a00020, 0x080000a0, 0x00100000, 0x00000000, 0x0000c400, 0x00000000 },
    /* 8  LOOP TILE n=0 body=0 */
    { 0x00000001, 0x00000000, 0x0000000c, 0x000000a0, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 9  GEMM         L01_VSSBlock_01_proj_Conv2d                01 proj                            in: L00.out@A+0                                                  out: t01@WORK+0(rel)                  rows[-2,10)  C 32->32 160x160  sh 0,0,0,0  flags 30 misc 8000  prm 204+32 L01_VSSBlock_01_proj_Conv2d */
    { 0x00003020, 0x00200000, 0x00a00020, 0x0afe00a0, 0x00000000, 0x00000000, 0x0000cc40, 0x80000020 },
    /* 10  VEC_SILU     L01_VSSBlock_02_proj_SiLU                  02 SiLU                            in: t01@WORK+0(rel)                                              out: t02@WORK+7680(rel)               rows[-2,10)  C 32->32 160x160  sh 0,0,0,0  flags 30 misc a000  prm 241+0 */
    { 0x00003011, 0x00200000, 0x00a00020, 0x0afe00a0, 0x00400000, 0x1e000000, 0x0000f140, 0xa0000000 },
    /* 11  DW           L01_VSSBlock_03_ls_fc1_DWConv2d            03 DW                              in: t02@WORK+7680(rel)                                           out: t03@WORK+0(rel)                  rows[-2,10)  C 32->32 160x160  sh 0,0,0,0  flags 30 misc a000  prm 249+0 L01_VSSBlock_03_ls_fc1_DWConv2d */
    { 0x00003030, 0x00200000, 0x00a00020, 0x0afe00a0, 0x00401e00, 0x00000000, 0x0000f940, 0xa0000000 },
    /* 12  GEMM         L01_VSSBlock_04_ls_fc2_Conv2d              04                                 in: t03@WORK+0(rel)                                              out: t04@WORK+15360(rel)              rows[-1,9)   C 32->32 160x160  sh 0,0,0,0  flags 30 misc a000  prm 265+32 L01_VSSBlock_04_ls_fc2_Conv2d */
    { 0x00003020, 0x00200000, 0x00a00020, 0x09ff00a0, 0x00400000, 0x3c000000, 0x00010940, 0xa0000020 },
    /* 13  VEC_SILU     L01_VSSBlock_05_ls_SiLU                    05 SiLU                            in: t04@WORK+15360(rel)                                          out: t05@WORK+0(rel)                  rows[-1,9)   C 32->32 160x160  sh 0,0,0,0  flags 30 misc a000  prm 39+0 */
    { 0x00003011, 0x00200000, 0x00a00020, 0x09ff00a0, 0x00403c00, 0x00000000, 0x00002740, 0xa0000000 },
    /* 14  GEMM         L01_VSSBlock_06_ls_fc3_Conv2d              06 (scratch)                       in: t05@WORK+0(rel)                                              out: s06@B+0(rel)                     rows[-1,9)   C 32->32 160x160  sh 0,0,0,0  flags 30 misc a000  prm 302+32 L01_VSSBlock_06_ls_fc3_Conv2d */
    { 0x00003020, 0x00200000, 0x00a00020, 0x09ff00a0, 0x00400000, 0x00000000, 0x00012e10, 0xa0000020 },
    /* 15  VEC_ADD      L01_VSSBlock_07_ls_Add                     07 Add -> requant to 08            in: t02@WORK+7680(rel), s06@B+0(rel)                             out: t07@WORK+0(rel)                  rows[-1,9)   C 32->32 160x160  sh -1,0,1,0  flags 70 misc e000  prm 0+0 */
    { 0x00ff7012, 0x00200001, 0x00a00020, 0x09ff00a0, 0x00401e00, 0x00001000, 0x00000040, 0xe0000000 },
    /* 16  VEC_LN       L01_VSSBlock_08_norm_LightNorm             08 LightNorm                       in: t07@WORK+0(rel)                                              out: t08@WORK+7680(rel)               rows[-1,9)   C 32->32 160x160  sh 0,0,21,19  flags 30 misc a000  prm 339+0 */
    { 0x00003014, 0x00201315, 0x00a00020, 0x09ff00a0, 0x00400000, 0x1e000000, 0x00015340, 0xa0000000 },
    /* 17  GEMM         L01_VSSBlock_09_ss2d_in_proj_Conv2d        09 in_proj x half                  in: t08@WORK+7680(rel)                                           out: t09x@WORK+15360(rel)             rows[-1,9)   C 32->64 160x160  sh 0,0,0,0  flags 30 misc a000  prm 373+64 L01_VSSBlock_09_ss2d_in_proj_Conv2d:x */
    { 0x00003020, 0x00200000, 0x00a00040, 0x09ff00a0, 0x00401e00, 0x3c000000, 0x00017540, 0xa0000040 },
    /* 18  VEC_RQ       L01_VSSBlock_11_ss2d_DWConv2d              11 DW input requant (DW has none)  in: t09x@WORK+15360(rel)                                         out: rq11@WORK+30720(rel)             rows[-1,9)   C 64->64 160x160  sh 1,0,0,0  flags 30 misc a000  prm 0+0 */
    { 0x00013010, 0x00400000, 0x00a00040, 0x09ff00a0, 0x00403c00, 0x78000000, 0x00000040, 0xa0000000 },
    /* 19  DW           L01_VSSBlock_11_ss2d_DWConv2d              11 DW                              in: rq11@WORK+30720(rel)                                         out: t11@WORK+0(rel)                  rows[-1,9)   C 64->64 160x160  sh 0,0,0,0  flags 30 misc a000  prm 529+0 L01_VSSBlock_11_ss2d_DWConv2d */
    { 0x00003030, 0x00400000, 0x00a00040, 0x09ff00a0, 0x00407800, 0x00000000, 0x00021140, 0xa0000000 },
    /* 20  VEC_SILU     L01_VSSBlock_12_ss2d_SiLU_x                12 SiLU -> X                       in: t11@WORK+0(rel)                                              out: X@X+0                            rows[0,8)    C 64->64 160x160  sh 0,0,0,0  flags 30 misc 2000  prm 521+0 */
    { 0x00003011, 0x00400000, 0x00a00040, 0x080000a0, 0x00400000, 0x00000000, 0x00020920, 0x20000000 },
    /* 21  SETK 0 */
    { 0x00000003, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 22  LOOP GROUP n=3200 body=4 */
    { 0x00000001, 0x0c800000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 23  GEMM         L01_VSSBlock_14_ss2d_XProj                 14 XProj dir0                      in: X@X+0                                                        out: g_xp@WORK+64                     frame        C 64->34 160x160  sh 0,0,0,0  flags 30 misc 0090  prm 561+72 L01_VSSBlock_14_ss2d_XProj:dir0 */
    { 0x00003020, 0x00400000, 0x00a00022, 0x000000a0, 0x00200000, 0x00400000, 0x00023140, 0x00900048 },
    /* 24  GEMM         L01_VSSBlock_15_ss2d_DtProj                15 DtProj dir0 (+ReLU)             in: g_xp@WORK+64                                                 out: g_delta@WORK+0                   frame        C 2->64 160x160  sh 0,0,0,5  flags 31 misc 0088  prm 877+16 L01_VSSBlock_15_ss2d_DtProj:dir0 */
    { 0x00003120, 0x00020500, 0x00a00040, 0x000000a0, 0x00400040, 0x00000000, 0x00036d40, 0x00880010 },
    /* 25  SCAN         L01_VSSBlock_16_ss2d_SelectiveScan         16 scan dir0                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+104                     frame        C 64->64 160x160  sh 0,0,0,0  flags 44 misc 00b0  prm 981+2 L01_VSSBlock_16_ss2d_SelectiveScan:dir0 */
    { 0x00004440, 0x00400000, 0x00a00040, 0x000000a0, 0x00200000, 0x00684000, 0x0003d540, 0x00b00002 },
    /* 26  VEC_ADD      L01_VSSBlock_17_ss2d_CrossMerge            17 accumulate dir0                 in: g_y@WORK+104, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 64->64 160x160  sh 0,0,0,0  flags 7a misc 0548  prm 0+0 */
    { 0x00007a12, 0x00400000, 0x00a00040, 0x000000a0, 0x00400068, 0x00005000, 0x00000050, 0x05480000 },
    /* 27  SETK 1 */
    { 0x00000003, 0x00010000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 28  LOOP GROUP n=3200 body=4 */
    { 0x00000001, 0x0c800000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 29  GEMM         L01_VSSBlock_14_ss2d_XProj                 14 XProj dir1                      in: X@X+0                                                        out: g_xp@WORK+64                     frame        C 64->34 160x160  sh 0,0,0,0  flags 30 misc 0090  prm 640+72 L01_VSSBlock_14_ss2d_XProj:dir1 */
    { 0x00003020, 0x00400000, 0x00a00022, 0x000000a0, 0x00200000, 0x00400000, 0x00028040, 0x00900048 },
    /* 30  GEMM         L01_VSSBlock_15_ss2d_DtProj                15 DtProj dir1 (+ReLU)             in: g_xp@WORK+64                                                 out: g_delta@WORK+0                   frame        C 2->64 160x160  sh 0,0,0,5  flags 31 misc 0088  prm 903+16 L01_VSSBlock_15_ss2d_DtProj:dir1 */
    { 0x00003120, 0x00020500, 0x00a00040, 0x000000a0, 0x00400040, 0x00000000, 0x00038740, 0x00880010 },
    /* 31  SCAN         L01_VSSBlock_16_ss2d_SelectiveScan         16 scan dir1                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+104                     frame        C 64->64 160x160  sh 0,0,0,0  flags 44 misc 00b0  prm 1016+2 L01_VSSBlock_16_ss2d_SelectiveScan:dir1 */
    { 0x00004440, 0x00400000, 0x00a00040, 0x000000a0, 0x00200000, 0x00684000, 0x0003f840, 0x00b00002 },
    /* 32  VEC_ADD      L01_VSSBlock_17_ss2d_CrossMerge            17 accumulate dir1                 in: g_y@WORK+104, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 64->64 160x160  sh 0,0,0,0  flags 72 misc 0548  prm 0+0 */
    { 0x00007212, 0x00400000, 0x00a00040, 0x000000a0, 0x00400068, 0x00005000, 0x00000050, 0x05480000 },
    /* 33  SETK 2 */
    { 0x00000003, 0x00020000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 34  LOOP GROUP n=3200 body=4 */
    { 0x00000001, 0x0c800000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 35  GEMM         L01_VSSBlock_14_ss2d_XProj                 14 XProj dir2                      in: X@X+0                                                        out: g_xp@WORK+64                     frame        C 64->34 160x160  sh 0,0,0,0  flags 30 misc 0090  prm 719+72 L01_VSSBlock_14_ss2d_XProj:dir2 */
    { 0x00003020, 0x00400000, 0x00a00022, 0x000000a0, 0x00200000, 0x00400000, 0x0002cf40, 0x00900048 },
    /* 36  GEMM         L01_VSSBlock_15_ss2d_DtProj                15 DtProj dir2 (+ReLU)             in: g_xp@WORK+64                                                 out: g_delta@WORK+0                   frame        C 2->64 160x160  sh 0,0,0,5  flags 31 misc 0088  prm 929+16 L01_VSSBlock_15_ss2d_DtProj:dir2 */
    { 0x00003120, 0x00020500, 0x00a00040, 0x000000a0, 0x00400040, 0x00000000, 0x0003a140, 0x00880010 },
    /* 37  SCAN         L01_VSSBlock_16_ss2d_SelectiveScan         16 scan dir2                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+104                     frame        C 64->64 160x160  sh 0,0,0,0  flags 44 misc 00b0  prm 1051+2 L01_VSSBlock_16_ss2d_SelectiveScan:dir2 */
    { 0x00004440, 0x00400000, 0x00a00040, 0x000000a0, 0x00200000, 0x00684000, 0x00041b40, 0x00b00002 },
    /* 38  VEC_ADD      L01_VSSBlock_17_ss2d_CrossMerge            17 accumulate dir2                 in: g_y@WORK+104, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 64->64 160x160  sh 0,0,0,0  flags 72 misc 0548  prm 0+0 */
    { 0x00007212, 0x00400000, 0x00a00040, 0x000000a0, 0x00400068, 0x00005000, 0x00000050, 0x05480000 },
    /* 39  SETK 3 */
    { 0x00000003, 0x00030000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 40  LOOP GROUP n=3200 body=4 */
    { 0x00000001, 0x0c800000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 41  GEMM         L01_VSSBlock_14_ss2d_XProj                 14 XProj dir3                      in: X@X+0                                                        out: g_xp@WORK+64                     frame        C 64->34 160x160  sh 0,0,0,0  flags 30 misc 0090  prm 798+72 L01_VSSBlock_14_ss2d_XProj:dir3 */
    { 0x00003020, 0x00400000, 0x00a00022, 0x000000a0, 0x00200000, 0x00400000, 0x00031e40, 0x00900048 },
    /* 42  GEMM         L01_VSSBlock_15_ss2d_DtProj                15 DtProj dir3 (+ReLU)             in: g_xp@WORK+64                                                 out: g_delta@WORK+0                   frame        C 2->64 160x160  sh 0,0,0,5  flags 31 misc 0088  prm 955+16 L01_VSSBlock_15_ss2d_DtProj:dir3 */
    { 0x00003120, 0x00020500, 0x00a00040, 0x000000a0, 0x00400040, 0x00000000, 0x0003bb40, 0x00880010 },
    /* 43  SCAN         L01_VSSBlock_16_ss2d_SelectiveScan         16 scan dir3                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+104                     frame        C 64->64 160x160  sh 0,0,0,0  flags 44 misc 00b0  prm 1086+2 L01_VSSBlock_16_ss2d_SelectiveScan:dir3 */
    { 0x00004440, 0x00400000, 0x00a00040, 0x000000a0, 0x00200000, 0x00684000, 0x00043e40, 0x00b00002 },
    /* 44  VEC_ADD      L01_VSSBlock_17_ss2d_CrossMerge            17 accumulate dir3                 in: g_y@WORK+104, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 64->64 160x160  sh 0,0,0,0  flags 72 misc 0548  prm 0+0 */
    { 0x00007212, 0x00400000, 0x00a00040, 0x000000a0, 0x00400068, 0x00005000, 0x00000050, 0x05480000 },
    /* 45  LOOP TILE n=0 body=0 */
    { 0x00000001, 0x00000000, 0x00000017, 0x000000a0, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 46  VEC_RQ       L01_VSSBlock_17_ss2d_CrossMerge            17' ACC -> int8                    in: ACC@ACC+0(w)                                                 out: t17@WORK+0(rel)                  rows[-1,9)   C 64->64 160x160  sh 1,0,0,0  flags 30 misc 8200  prm 0+0 */
    { 0x00013010, 0x00400000, 0x00a00040, 0x09ff00a0, 0x00500000, 0x00000000, 0x00000040, 0x82000000 },
    /* 47  VEC_LN       L01_VSSBlock_18_ss2d_out_norm_LightNorm    18 out_norm                        in: t17@WORK+0(rel)                                              out: t18@WORK+15360(rel)              rows[-1,9)   C 64->64 160x160  sh 0,0,21,17  flags 30 misc a000  prm 1121+0 */
    { 0x00003014, 0x00401115, 0x00a00040, 0x09ff00a0, 0x00400000, 0x3c000000, 0x00046140, 0xa0000000 },
    /* 48  GEMM         L01_VSSBlock_01_proj_Conv2d                01 (recompute)                     in: L00.out@A+0                                                  out: r01@WORK+0(rel)                  rows[-2,10)  C 32->32 160x160  sh 0,0,0,0  flags 30 misc 8000  prm 204+32 L01_VSSBlock_01_proj_Conv2d */
    { 0x00003020, 0x00200000, 0x00a00020, 0x0afe00a0, 0x00000000, 0x00000000, 0x0000cc40, 0x80000020 },
    /* 49  VEC_SILU     L01_VSSBlock_02_proj_SiLU                  02 = r (recompute)                 in: r01@WORK+0(rel)                                              out: r02@WORK+7680(rel)               rows[-2,10)  C 32->32 160x160  sh 0,0,0,0  flags 30 misc a000  prm 241+0 */
    { 0x00003011, 0x00200000, 0x00a00020, 0x0afe00a0, 0x00400000, 0x1e000000, 0x0000f140, 0xa0000000 },
    /* 50  DW           L01_VSSBlock_03_ls_fc1_DWConv2d            03 (recompute)                     in: r02@WORK+7680(rel)                                           out: r03@WORK+0(rel)                  rows[-2,10)  C 32->32 160x160  sh 0,0,0,0  flags 30 misc a000  prm 249+0 L01_VSSBlock_03_ls_fc1_DWConv2d */
    { 0x00003030, 0x00200000, 0x00a00020, 0x0afe00a0, 0x00401e00, 0x00000000, 0x0000f940, 0xa0000000 },
    /* 51  GEMM         L01_VSSBlock_04_ls_fc2_Conv2d              04 (recompute)                     in: r03@WORK+0(rel)                                              out: r04@WORK+30720(rel)              rows[-1,9)   C 32->32 160x160  sh 0,0,0,0  flags 30 misc a000  prm 265+32 L01_VSSBlock_04_ls_fc2_Conv2d */
    { 0x00003020, 0x00200000, 0x00a00020, 0x09ff00a0, 0x00400000, 0x78000000, 0x00010940, 0xa0000020 },
    /* 52  VEC_SILU     L01_VSSBlock_05_ls_SiLU                    05 (recompute)                     in: r04@WORK+30720(rel)                                          out: r05@WORK+0(rel)                  rows[-1,9)   C 32->32 160x160  sh 0,0,0,0  flags 30 misc a000  prm 39+0 */
    { 0x00003011, 0x00200000, 0x00a00020, 0x09ff00a0, 0x00407800, 0x00000000, 0x00002740, 0xa0000000 },
    /* 53  GEMM         L01_VSSBlock_06_ls_fc3_Conv2d              06 (recompute, X scratch)          in: r05@WORK+0(rel)                                              out: s06@X+0(rel)                     rows[-1,9)   C 32->32 160x160  sh 0,0,0,0  flags 30 misc a000  prm 302+32 L01_VSSBlock_06_ls_fc3_Conv2d */
    { 0x00003020, 0x00200000, 0x00a00020, 0x09ff00a0, 0x00400000, 0x00000000, 0x00012e20, 0xa0000020 },
    /* 54  VEC_ADD      L01_VSSBlock_07_ls_Add                     07 (recompute)                     in: r02@WORK+7680(rel), s06@X+0(rel)                             out: r07@WORK+0(rel)                  rows[-1,9)   C 32->32 160x160  sh -1,0,1,0  flags 70 misc e000  prm 0+0 */
    { 0x00ff7012, 0x00200001, 0x00a00020, 0x09ff00a0, 0x00401e00, 0x00002000, 0x00000040, 0xe0000000 },
    /* 55  VEC_LN       L01_VSSBlock_08_norm_LightNorm             08 (recompute)                     in: r07@WORK+0(rel)                                              out: r08@WORK+30720(rel)              rows[-1,9)   C 32->32 160x160  sh 0,0,21,19  flags 30 misc a000  prm 339+0 */
    { 0x00003014, 0x00201315, 0x00a00020, 0x09ff00a0, 0x00400000, 0x78000000, 0x00015340, 0xa0000000 },
    /* 56  GEMM         L01_VSSBlock_09_ss2d_in_proj_Conv2d        09 in_proj z half (recompute)      in: r08@WORK+30720(rel)                                          out: r09z@WORK+38400(rel)             rows[-1,9)   C 32->64 160x160  sh 0,0,0,0  flags 30 misc a000  prm 447+64 L01_VSSBlock_09_ss2d_in_proj_Conv2d:z */
    { 0x00003020, 0x00200000, 0x00a00040, 0x09ff00a0, 0x00407800, 0x96000000, 0x0001bf40, 0xa0000040 },
    /* 57  VEC_SILU     L01_VSSBlock_10_ss2d_SiLU_z                10 = z (X scratch)                 in: r09z@WORK+38400(rel)                                         out: s10z@X+0(rel)                    rows[-1,9)   C 64->64 160x160  sh 0,0,0,0  flags 30 misc a000  prm 521+0 */
    { 0x00003011, 0x00400000, 0x00a00040, 0x09ff00a0, 0x00409600, 0x00000000, 0x00020920, 0xa0000000 },
    /* 58  VEC_MUL      L01_VSSBlock_19_ss2d_Mul                   19 gate -> requant to 20           in: t18@WORK+15360(rel), s10z@X+0(rel)                           out: t19@WORK+30720(rel)              rows[-1,9)   C 64->64 160x160  sh 0,0,3,0  flags 70 misc e000  prm 0+0 */
    { 0x00007013, 0x00400003, 0x00a00040, 0x09ff00a0, 0x00403c00, 0x78002000, 0x00000040, 0xe0000000 },
    /* 59  GEMM         L01_VSSBlock_20_ss2d_out_proj_Conv2d       20 out_proj (X scratch)            in: t19@WORK+30720(rel)                                          out: s20@X+0(rel)                     rows[-1,9)   C 64->32 160x160  sh 0,0,0,0  flags 30 misc a000  prm 1157+64 L01_VSSBlock_20_ss2d_out_proj_Conv2d */
    { 0x00003020, 0x00400000, 0x00a00020, 0x09ff00a0, 0x00407800, 0x00000000, 0x00048520, 0xa0000040 },
    /* 60  VEC_ADD      L01_VSSBlock_21_Add                        21 Add (wide, kept)                in: r02@WORK+7680(rel), s20@X+0(rel)                             out: t21@WORK+15360(rel)(w)           rows[-1,9)   C 32->32 160x160  sh -1,0,0,0  flags 72 misc e000  prm 0+0 */
    { 0x00ff7212, 0x00200000, 0x00a00020, 0x09ff00a0, 0x00401e00, 0x3c002000, 0x00000040, 0xe0000000 },
    /* 61  VEC_LN       L01_VSSBlock_22_norm2_LightNorm            22 norm2                           in: t21@WORK+15360(rel)(w)                                       out: t22@WORK+0(rel)                  rows[-1,9)   C 32->32 160x160  sh 1,0,21,19  flags 30 misc a200  prm 1226+0 */
    { 0x00013014, 0x00201315, 0x00a00020, 0x09ff00a0, 0x00403c00, 0x00000000, 0x0004ca40, 0xa2000000 },
    /* 62  GEMM         L01_VSSBlock_23_mlp_fc1_Conv2d             23 fc1 x half (X scratch)          in: t22@WORK+0(rel)                                              out: s23x@X+0(rel)                    rows[-1,9)   C 32->85 160x160  sh 0,0,0,0  flags 30 misc a000  prm 1260+88 L01_VSSBlock_23_mlp_fc1_Conv2d:x */
    { 0x00003020, 0x00200000, 0x00a00055, 0x09ff00a0, 0x00400000, 0x00000000, 0x0004ec20, 0xa0000058 },
    /* 63  GEMM         L01_VSSBlock_23_mlp_fc1_Conv2d             23 fc1 v half (X scratch)          in: t22@WORK+0(rel)                                              out: s23v@X+21120(rel)                rows[-1,9)   C 32->85 160x160  sh 0,0,0,0  flags 30 misc a000  prm 1362+88 L01_VSSBlock_23_mlp_fc1_Conv2d:v */
    { 0x00003020, 0x00200000, 0x00a00055, 0x09ff00a0, 0x00400000, 0x52800000, 0x00055220, 0xa0000058 },
    /* 64  DW           L01_VSSBlock_24_mlp_DWConv2d               24 DW                              in: s23x@X+0(rel)                                                out: t24@WORK+30720(rel)              rows[-1,9)   C 85->85 160x160  sh 0,0,0,0  flags 30 misc a000  prm 1464+0 L01_VSSBlock_24_mlp_DWConv2d */
    { 0x00003030, 0x00550000, 0x00a00055, 0x09ff00a0, 0x00200000, 0x78000000, 0x0005b840, 0xa0000000 },
    /* 65  VEC_ADD      L01_VSSBlock_26_mlp_SiLU                   25 Add -> 26 SiLU (fused)          in: t24@WORK+30720(rel), s23x@X+0(rel)                           out: t26@WORK+51840(rel)              rows[0,8)    C 85->85 160x160  sh 0,0,0,0  flags f0 misc e000  prm 1508+0 */
    { 0x0000f012, 0x00550000, 0x00a00055, 0x080000a0, 0x00407800, 0xca802000, 0x0005e440, 0xe0000000 },
    /* 66  VEC_MUL      L01_VSSBlock_27_mlp_Mul                    27 Mul -> requant to 28            in: t26@WORK+51840(rel), s23v@X+21120(rel)                       out: t27@WORK+30720(rel)              rows[0,8)    C 85->85 160x160  sh 0,0,3,0  flags 70 misc e000  prm 0+0 */
    { 0x00007013, 0x00550003, 0x00a00055, 0x080000a0, 0x8040ca80, 0x78002052, 0x00000040, 0xe0000000 },
    /* 67  GEMM         L01_VSSBlock_28_mlp_fc2_Conv2d             28 fc2 (X scratch)                 in: t27@WORK+30720(rel)                                          out: s28@X+0(rel)                     rows[0,8)    C 85->32 160x160  sh 0,0,0,0  flags 30 misc a000  prm 1516+88 L01_VSSBlock_28_mlp_fc2_Conv2d */
    { 0x00003020, 0x00550000, 0x00a00020, 0x080000a0, 0x00407800, 0x00000000, 0x0005ec20, 0xa0000058 },
    /* 68  VEC_ADD      L01_VSSBlock_29_Add                        29 Add -> block output             in: t21@WORK+15360(rel)(w), s28@X+0(rel)                         out: L01_VSSBlock.out@B+0             rows[0,8)    C 32->32 160x160  sh 0,0,1,0  flags 70 misc 6200  prm 0+0 */
    { 0x00007012, 0x00200001, 0x00a00020, 0x080000a0, 0x00403c00, 0x00002000, 0x00000010, 0x62000000 },
    /* 69  GEMM         L02_VisionClueMerge_02_pw_linear_Conv2d    VCM: S2D gather + 1x1              in: L01_VSSBlock.out@B+0                                         out: vcm_pw@WORK+0                    frame        C 32->64 160x160  sh 0,0,0,0  flags 30 misc 0003  prm 1609+256 L02_VisionClueMerge_02_pw_linear_Conv2d */
    { 0x00003020, 0x00200000, 0x00a00040, 0x000000a0, 0x00100000, 0x00000000, 0x00064940, 0x00030100 },
    /* 70  VEC_SILU     L02_VisionClueMerge_03_SiLU                VCM SiLU -> layer out              in: vcm_pw@WORK+0                                                out: L02.out@A+0                      frame        C 64->64 80x80  sh 0,0,0,0  flags 30 misc 0000  prm 521+0 */
    { 0x00003011, 0x00400000, 0x00500040, 0x00000050, 0x00400000, 0x00000000, 0x00020900, 0x00000000 },
    /* 71  LOOP TILE n=0 body=0 */
    { 0x00000001, 0x00000000, 0x0000000b, 0x00000050, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 72  GEMM         L03_VSSBlock_01_proj_Conv2d                01 proj                            in: L02.out@A+0                                                  out: t01@WORK+0(rel)                  rows[-2,10)  C 64->64 80x80  sh 0,0,0,0  flags 30 misc 8000  prm 1875+128 L03_VSSBlock_01_proj_Conv2d */
    { 0x00003020, 0x00400000, 0x00500040, 0x0afe0050, 0x00000000, 0x00000000, 0x00075340, 0x80000080 },
    /* 73  VEC_SILU     L03_VSSBlock_02_proj_SiLU                  02 SiLU                            in: t01@WORK+0(rel)                                              out: t02@WORK+7680(rel)               rows[-2,10)  C 64->64 80x80  sh 0,0,0,0  flags 30 misc a000  prm 2013+0 */
    { 0x00003011, 0x00400000, 0x00500040, 0x0afe0050, 0x00400000, 0x1e000000, 0x0007dd40, 0xa0000000 },
    /* 74  DW           L03_VSSBlock_03_ls_fc1_DWConv2d            03 DW                              in: t02@WORK+7680(rel)                                           out: t03@WORK+0(rel)                  rows[-2,10)  C 64->64 80x80  sh 0,0,0,0  flags 30 misc a000  prm 2021+0 L03_VSSBlock_03_ls_fc1_DWConv2d */
    { 0x00003030, 0x00400000, 0x00500040, 0x0afe0050, 0x00401e00, 0x00000000, 0x0007e540, 0xa0000000 },
    /* 75  GEMM         L03_VSSBlock_04_ls_fc2_Conv2d              04                                 in: t03@WORK+0(rel)                                              out: t04@WORK+15360(rel)              rows[-1,9)   C 64->64 80x80  sh 0,0,0,0  flags 30 misc a000  prm 2053+128 L03_VSSBlock_04_ls_fc2_Conv2d */
    { 0x00003020, 0x00400000, 0x00500040, 0x09ff0050, 0x00400000, 0x3c000000, 0x00080540, 0xa0000080 },
    /* 76  VEC_SILU     L03_VSSBlock_05_ls_SiLU                    05 SiLU                            in: t04@WORK+15360(rel)                                          out: t05@WORK+0(rel)                  rows[-1,9)   C 64->64 80x80  sh 0,0,0,0  flags 30 misc a000  prm 521+0 */
    { 0x00003011, 0x00400000, 0x00500040, 0x09ff0050, 0x00403c00, 0x00000000, 0x00020940, 0xa0000000 },
    /* 77  GEMM         L03_VSSBlock_06_ls_fc3_Conv2d              06 (scratch)                       in: t05@WORK+0(rel)                                              out: s06@B+0(rel)                     rows[-1,9)   C 64->64 80x80  sh 0,0,0,0  flags 30 misc a000  prm 2191+128 L03_VSSBlock_06_ls_fc3_Conv2d */
    { 0x00003020, 0x00400000, 0x00500040, 0x09ff0050, 0x00400000, 0x00000000, 0x00088f10, 0xa0000080 },
    /* 78  VEC_ADD      L03_VSSBlock_07_ls_Add                     07 Add -> requant to 08            in: t02@WORK+7680(rel), s06@B+0(rel)                             out: t07@WORK+0(rel)                  rows[-1,9)   C 64->64 80x80  sh -1,0,1,0  flags 70 misc e000  prm 0+0 */
    { 0x00ff7012, 0x00400001, 0x00500040, 0x09ff0050, 0x00401e00, 0x00001000, 0x00000040, 0xe0000000 },
    /* 79  VEC_LN       L03_VSSBlock_08_norm_LightNorm             08 LightNorm                       in: t07@WORK+0(rel)                                              out: t08@WORK+7680(rel)               rows[-1,9)   C 64->64 80x80  sh 0,0,21,20  flags 30 misc a000  prm 2329+0 */
    { 0x00003014, 0x00401415, 0x00500040, 0x09ff0050, 0x00400000, 0x1e000000, 0x00091940, 0xa0000000 },
    /* 80  GEMM         L03_VSSBlock_09_ss2d_in_proj_Conv2d        09 in_proj x half                  in: t08@WORK+7680(rel)                                           out: t09x@WORK+15360(rel)             rows[-1,9)   C 64->128 80x80  sh 0,0,0,0  flags 30 misc a000  prm 2365+256 L03_VSSBlock_09_ss2d_in_proj_Conv2d:x */
    { 0x00003020, 0x00400000, 0x00500080, 0x09ff0050, 0x00401e00, 0x3c000000, 0x00093d40, 0xa0000100 },
    /* 81  DW           L03_VSSBlock_11_ss2d_DWConv2d              11 DW                              in: t09x@WORK+15360(rel)                                         out: t11@WORK+0(rel)                  rows[-1,9)   C 128->128 80x80  sh 0,0,0,0  flags 30 misc a000  prm 2917+0 L03_VSSBlock_11_ss2d_DWConv2d */
    { 0x00003030, 0x00800000, 0x00500080, 0x09ff0050, 0x00403c00, 0x00000000, 0x000b6540, 0xa0000000 },
    /* 82  VEC_SILU     L03_VSSBlock_12_ss2d_SiLU_x                12 SiLU -> X                       in: t11@WORK+0(rel)                                              out: X@X+0                            rows[0,8)    C 128->128 80x80  sh 0,0,0,0  flags 30 misc 2000  prm 2013+0 */
    { 0x00003011, 0x00800000, 0x00500080, 0x08000050, 0x00400000, 0x00000000, 0x0007dd20, 0x20000000 },
    /* 83  SETK 0 */
    { 0x00000003, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 84  LOOP GROUP n=800 body=4 */
    { 0x00000001, 0x03200000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 85  GEMM         L03_VSSBlock_14_ss2d_XProj                 14 XProj dir0                      in: X@X+0                                                        out: g_xp@WORK+128                    frame        C 128->36 80x80  sh 0,0,0,0  flags 30 misc 0090  prm 2981+144 L03_VSSBlock_14_ss2d_XProj:dir0 */
    { 0x00003020, 0x00800000, 0x00500024, 0x00000050, 0x00200000, 0x00800000, 0x000ba540, 0x00900090 },
    /* 86  GEMM         L03_VSSBlock_15_ss2d_DtProj                15 DtProj dir0 (+ReLU)             in: g_xp@WORK+128                                                out: g_delta@WORK+0                   frame        C 4->128 80x80  sh 0,0,0,5  flags 31 misc 0088  prm 3585+32 L03_VSSBlock_15_ss2d_DtProj:dir0 */
    { 0x00003120, 0x00040500, 0x00500080, 0x00000050, 0x00400080, 0x00000000, 0x000e0140, 0x00880020 },
    /* 87  SCAN         L03_VSSBlock_16_ss2d_SelectiveScan         16 scan dir0                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+168                     frame        C 128->128 80x80  sh 0,0,0,0  flags 44 misc 00b0  prm 3793+4 L03_VSSBlock_16_ss2d_SelectiveScan:dir0 */
    { 0x00004440, 0x00800000, 0x00500080, 0x00000050, 0x00200000, 0x00a84000, 0x000ed140, 0x00b00004 },
    /* 88  VEC_ADD      L03_VSSBlock_17_ss2d_CrossMerge            17 accumulate dir0                 in: g_y@WORK+168, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 128->128 80x80  sh -1,0,0,0  flags 7a misc 0548  prm 0+0 */
    { 0x00ff7a12, 0x00800000, 0x00500080, 0x00000050, 0x004000a8, 0x00005000, 0x00000050, 0x05480000 },
    /* 89  SETK 1 */
    { 0x00000003, 0x00010000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 90  LOOP GROUP n=800 body=4 */
    { 0x00000001, 0x03200000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 91  GEMM         L03_VSSBlock_14_ss2d_XProj                 14 XProj dir1                      in: X@X+0                                                        out: g_xp@WORK+128                    frame        C 128->36 80x80  sh 0,0,0,0  flags 30 misc 0090  prm 3132+144 L03_VSSBlock_14_ss2d_XProj:dir1 */
    { 0x00003020, 0x00800000, 0x00500024, 0x00000050, 0x00200000, 0x00800000, 0x000c3c40, 0x00900090 },
    /* 92  GEMM         L03_VSSBlock_15_ss2d_DtProj                15 DtProj dir1 (+ReLU)             in: g_xp@WORK+128                                                out: g_delta@WORK+0                   frame        C 4->128 80x80  sh 0,0,0,5  flags 31 misc 0088  prm 3637+32 L03_VSSBlock_15_ss2d_DtProj:dir1 */
    { 0x00003120, 0x00040500, 0x00500080, 0x00000050, 0x00400080, 0x00000000, 0x000e3540, 0x00880020 },
    /* 93  SCAN         L03_VSSBlock_16_ss2d_SelectiveScan         16 scan dir1                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+168                     frame        C 128->128 80x80  sh 0,0,0,0  flags 44 misc 00b0  prm 3862+4 L03_VSSBlock_16_ss2d_SelectiveScan:dir1 */
    { 0x00004440, 0x00800000, 0x00500080, 0x00000050, 0x00200000, 0x00a84000, 0x000f1640, 0x00b00004 },
    /* 94  VEC_ADD      L03_VSSBlock_17_ss2d_CrossMerge            17 accumulate dir1                 in: g_y@WORK+168, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 128->128 80x80  sh -1,0,0,0  flags 72 misc 0548  prm 0+0 */
    { 0x00ff7212, 0x00800000, 0x00500080, 0x00000050, 0x004000a8, 0x00005000, 0x00000050, 0x05480000 },
    /* 95  SETK 2 */
    { 0x00000003, 0x00020000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 96  LOOP GROUP n=800 body=4 */
    { 0x00000001, 0x03200000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 97  GEMM         L03_VSSBlock_14_ss2d_XProj                 14 XProj dir2                      in: X@X+0                                                        out: g_xp@WORK+128                    frame        C 128->36 80x80  sh 0,0,0,0  flags 30 misc 0090  prm 3283+144 L03_VSSBlock_14_ss2d_XProj:dir2 */
    { 0x00003020, 0x00800000, 0x00500024, 0x00000050, 0x00200000, 0x00800000, 0x000cd340, 0x00900090 },
    /* 98  GEMM         L03_VSSBlock_15_ss2d_DtProj                15 DtProj dir2 (+ReLU)             in: g_xp@WORK+128                                                out: g_delta@WORK+0                   frame        C 4->128 80x80  sh 0,0,0,5  flags 31 misc 0088  prm 3689+32 L03_VSSBlock_15_ss2d_DtProj:dir2 */
    { 0x00003120, 0x00040500, 0x00500080, 0x00000050, 0x00400080, 0x00000000, 0x000e6940, 0x00880020 },
    /* 99  SCAN         L03_VSSBlock_16_ss2d_SelectiveScan         16 scan dir2                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+168                     frame        C 128->128 80x80  sh 0,0,0,0  flags 44 misc 00b0  prm 3931+4 L03_VSSBlock_16_ss2d_SelectiveScan:dir2 */
    { 0x00004440, 0x00800000, 0x00500080, 0x00000050, 0x00200000, 0x00a84000, 0x000f5b40, 0x00b00004 },
    /* 100  VEC_ADD      L03_VSSBlock_17_ss2d_CrossMerge            17 accumulate dir2                 in: g_y@WORK+168, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 128->128 80x80  sh 0,0,0,0  flags 72 misc 0548  prm 0+0 */
    { 0x00007212, 0x00800000, 0x00500080, 0x00000050, 0x004000a8, 0x00005000, 0x00000050, 0x05480000 },
    /* 101  SETK 3 */
    { 0x00000003, 0x00030000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 102  LOOP GROUP n=800 body=4 */
    { 0x00000001, 0x03200000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 103  GEMM         L03_VSSBlock_14_ss2d_XProj                 14 XProj dir3                      in: X@X+0                                                        out: g_xp@WORK+128                    frame        C 128->36 80x80  sh 0,0,0,0  flags 30 misc 0090  prm 3434+144 L03_VSSBlock_14_ss2d_XProj:dir3 */
    { 0x00003020, 0x00800000, 0x00500024, 0x00000050, 0x00200000, 0x00800000, 0x000d6a40, 0x00900090 },
    /* 104  GEMM         L03_VSSBlock_15_ss2d_DtProj                15 DtProj dir3 (+ReLU)             in: g_xp@WORK+128                                                out: g_delta@WORK+0                   frame        C 4->128 80x80  sh 0,0,0,5  flags 31 misc 0088  prm 3741+32 L03_VSSBlock_15_ss2d_DtProj:dir3 */
    { 0x00003120, 0x00040500, 0x00500080, 0x00000050, 0x00400080, 0x00000000, 0x000e9d40, 0x00880020 },
    /* 105  SCAN         L03_VSSBlock_16_ss2d_SelectiveScan         16 scan dir3                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+168                     frame        C 128->128 80x80  sh 0,0,0,0  flags 44 misc 00b0  prm 4000+4 L03_VSSBlock_16_ss2d_SelectiveScan:dir3 */
    { 0x00004440, 0x00800000, 0x00500080, 0x00000050, 0x00200000, 0x00a84000, 0x000fa040, 0x00b00004 },
    /* 106  VEC_ADD      L03_VSSBlock_17_ss2d_CrossMerge            17 accumulate dir3                 in: g_y@WORK+168, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 128->128 80x80  sh -2,0,0,0  flags 72 misc 0548  prm 0+0 */
    { 0x00fe7212, 0x00800000, 0x00500080, 0x00000050, 0x004000a8, 0x00005000, 0x00000050, 0x05480000 },
    /* 107  LOOP TILE n=0 body=0 */
    { 0x00000001, 0x00000000, 0x00000017, 0x00000050, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 108  VEC_RQ       L03_VSSBlock_17_ss2d_CrossMerge            17' ACC -> int8                    in: ACC@ACC+0(w)                                                 out: t17@WORK+0(rel)                  rows[-1,9)   C 128->128 80x80  sh 3,0,0,0  flags 30 misc 8200  prm 0+0 */
    { 0x00033010, 0x00800000, 0x00500080, 0x09ff0050, 0x00500000, 0x00000000, 0x00000040, 0x82000000 },
    /* 109  VEC_LN       L03_VSSBlock_18_ss2d_out_norm_LightNorm    18 out_norm                        in: t17@WORK+0(rel)                                              out: t18@WORK+15360(rel)              rows[-1,9)   C 128->128 80x80  sh 0,0,20,17  flags 30 misc a000  prm 4069+0 */
    { 0x00003014, 0x00801114, 0x00500080, 0x09ff0050, 0x00400000, 0x3c000000, 0x000fe540, 0xa0000000 },
    /* 110  GEMM         L03_VSSBlock_01_proj_Conv2d                01 (recompute)                     in: L02.out@A+0                                                  out: r01@WORK+0(rel)                  rows[-2,10)  C 64->64 80x80  sh 0,0,0,0  flags 30 misc 8000  prm 1875+128 L03_VSSBlock_01_proj_Conv2d */
    { 0x00003020, 0x00400000, 0x00500040, 0x0afe0050, 0x00000000, 0x00000000, 0x00075340, 0x80000080 },
    /* 111  VEC_SILU     L03_VSSBlock_02_proj_SiLU                  02 = r (recompute)                 in: r01@WORK+0(rel)                                              out: r02@WORK+7680(rel)               rows[-2,10)  C 64->64 80x80  sh 0,0,0,0  flags 30 misc a000  prm 2013+0 */
    { 0x00003011, 0x00400000, 0x00500040, 0x0afe0050, 0x00400000, 0x1e000000, 0x0007dd40, 0xa0000000 },
    /* 112  DW           L03_VSSBlock_03_ls_fc1_DWConv2d            03 (recompute)                     in: r02@WORK+7680(rel)                                           out: r03@WORK+0(rel)                  rows[-2,10)  C 64->64 80x80  sh 0,0,0,0  flags 30 misc a000  prm 2021+0 L03_VSSBlock_03_ls_fc1_DWConv2d */
    { 0x00003030, 0x00400000, 0x00500040, 0x0afe0050, 0x00401e00, 0x00000000, 0x0007e540, 0xa0000000 },
    /* 113  GEMM         L03_VSSBlock_04_ls_fc2_Conv2d              04 (recompute)                     in: r03@WORK+0(rel)                                              out: r04@WORK+30720(rel)              rows[-1,9)   C 64->64 80x80  sh 0,0,0,0  flags 30 misc a000  prm 2053+128 L03_VSSBlock_04_ls_fc2_Conv2d */
    { 0x00003020, 0x00400000, 0x00500040, 0x09ff0050, 0x00400000, 0x78000000, 0x00080540, 0xa0000080 },
    /* 114  VEC_SILU     L03_VSSBlock_05_ls_SiLU                    05 (recompute)                     in: r04@WORK+30720(rel)                                          out: r05@WORK+0(rel)                  rows[-1,9)   C 64->64 80x80  sh 0,0,0,0  flags 30 misc a000  prm 521+0 */
    { 0x00003011, 0x00400000, 0x00500040, 0x09ff0050, 0x00407800, 0x00000000, 0x00020940, 0xa0000000 },
    /* 115  GEMM         L03_VSSBlock_06_ls_fc3_Conv2d              06 (recompute, X scratch)          in: r05@WORK+0(rel)                                              out: s06@X+0(rel)                     rows[-1,9)   C 64->64 80x80  sh 0,0,0,0  flags 30 misc a000  prm 2191+128 L03_VSSBlock_06_ls_fc3_Conv2d */
    { 0x00003020, 0x00400000, 0x00500040, 0x09ff0050, 0x00400000, 0x00000000, 0x00088f20, 0xa0000080 },
    /* 116  VEC_ADD      L03_VSSBlock_07_ls_Add                     07 (recompute)                     in: r02@WORK+7680(rel), s06@X+0(rel)                             out: r07@WORK+0(rel)                  rows[-1,9)   C 64->64 80x80  sh -1,0,1,0  flags 70 misc e000  prm 0+0 */
    { 0x00ff7012, 0x00400001, 0x00500040, 0x09ff0050, 0x00401e00, 0x00002000, 0x00000040, 0xe0000000 },
    /* 117  VEC_LN       L03_VSSBlock_08_norm_LightNorm             08 (recompute)                     in: r07@WORK+0(rel)                                              out: r08@WORK+30720(rel)              rows[-1,9)   C 64->64 80x80  sh 0,0,21,20  flags 30 misc a000  prm 2329+0 */
    { 0x00003014, 0x00401415, 0x00500040, 0x09ff0050, 0x00400000, 0x78000000, 0x00091940, 0xa0000000 },
    /* 118  GEMM         L03_VSSBlock_09_ss2d_in_proj_Conv2d        09 in_proj z half (recompute)      in: r08@WORK+30720(rel)                                          out: r09z@WORK+38400(rel)             rows[-1,9)   C 64->128 80x80  sh 0,0,0,0  flags 30 misc a000  prm 2641+256 L03_VSSBlock_09_ss2d_in_proj_Conv2d:z */
    { 0x00003020, 0x00400000, 0x00500080, 0x09ff0050, 0x00407800, 0x96000000, 0x000a5140, 0xa0000100 },
    /* 119  VEC_SILU     L03_VSSBlock_10_ss2d_SiLU_z                10 = z (X scratch)                 in: r09z@WORK+38400(rel)                                         out: s10z@X+0(rel)                    rows[-1,9)   C 128->128 80x80  sh 0,0,0,0  flags 30 misc a000  prm 2013+0 */
    { 0x00003011, 0x00800000, 0x00500080, 0x09ff0050, 0x00409600, 0x00000000, 0x0007dd20, 0xa0000000 },
    /* 120  VEC_MUL      L03_VSSBlock_19_ss2d_Mul                   19 gate -> requant to 20           in: t18@WORK+15360(rel), s10z@X+0(rel)                           out: t19@WORK+30720(rel)              rows[-1,9)   C 128->128 80x80  sh 0,0,4,0  flags 70 misc e000  prm 0+0 */
    { 0x00007013, 0x00800004, 0x00500080, 0x09ff0050, 0x00403c00, 0x78002000, 0x00000040, 0xe0000000 },
    /* 121  GEMM         L03_VSSBlock_20_ss2d_out_proj_Conv2d       20 out_proj (X scratch)            in: t19@WORK+30720(rel)                                          out: s20@X+0(rel)                     rows[-1,9)   C 128->64 80x80  sh 0,0,0,0  flags 30 misc a000  prm 4109+256 L03_VSSBlock_20_ss2d_out_proj_Conv2d */
    { 0x00003020, 0x00800000, 0x00500040, 0x09ff0050, 0x00407800, 0x00000000, 0x00100d20, 0xa0000100 },
    /* 122  VEC_ADD      L03_VSSBlock_21_Add                        21 Add (wide, kept)                in: r02@WORK+7680(rel), s20@X+0(rel)                             out: t21@WORK+15360(rel)(w)           rows[-1,9)   C 64->64 80x80  sh -1,0,0,0  flags 72 misc e000  prm 0+0 */
    { 0x00ff7212, 0x00400000, 0x00500040, 0x09ff0050, 0x00401e00, 0x3c002000, 0x00000040, 0xe0000000 },
    /* 123  VEC_LN       L03_VSSBlock_22_norm2_LightNorm            22 norm2                           in: t21@WORK+15360(rel)(w)                                       out: t22@WORK+0(rel)                  rows[-1,9)   C 64->64 80x80  sh 1,0,21,20  flags 30 misc a200  prm 4375+0 */
    { 0x00013014, 0x00401415, 0x00500040, 0x09ff0050, 0x00403c00, 0x00000000, 0x00111740, 0xa2000000 },
    /* 124  GEMM         L03_VSSBlock_23_mlp_fc1_Conv2d             23 fc1 x half (X scratch)          in: t22@WORK+0(rel)                                              out: s23x@X+0(rel)                    rows[-1,9)   C 64->170 80x80  sh 0,0,0,0  flags 30 misc a000  prm 4411+344 L03_VSSBlock_23_mlp_fc1_Conv2d:x */
    { 0x00003020, 0x00400000, 0x005000aa, 0x09ff0050, 0x00400000, 0x00000000, 0x00113b20, 0xa0000158 },
    /* 125  GEMM         L03_VSSBlock_23_mlp_fc1_Conv2d             23 fc1 v half (X scratch)          in: t22@WORK+0(rel)                                              out: s23v@X+21120(rel)                rows[-1,9)   C 64->170 80x80  sh 0,0,0,0  flags 30 misc a000  prm 4783+344 L03_VSSBlock_23_mlp_fc1_Conv2d:v */
    { 0x00003020, 0x00400000, 0x005000aa, 0x09ff0050, 0x00400000, 0x52800000, 0x0012af20, 0xa0000158 },
    /* 126  DW           L03_VSSBlock_24_mlp_DWConv2d               24 DW                              in: s23x@X+0(rel)                                                out: t24@WORK+30720(rel)              rows[-1,9)   C 170->170 80x80  sh 0,0,0,0  flags 30 misc a000  prm 5155+0 L03_VSSBlock_24_mlp_DWConv2d */
    { 0x00003030, 0x00aa0000, 0x005000aa, 0x09ff0050, 0x00200000, 0x78000000, 0x00142340, 0xa0000000 },
    /* 127  VEC_ADD      L03_VSSBlock_26_mlp_SiLU                   25 Add -> 26 SiLU (fused)          in: t24@WORK+30720(rel), s23x@X+0(rel)                           out: t26@WORK+51840(rel)              rows[0,8)    C 170->170 80x80  sh 0,-1,1,0  flags f0 misc e000  prm 2013+0 */
    { 0xff00f012, 0x00aa0001, 0x005000aa, 0x08000050, 0x00407800, 0xca802000, 0x0007dd40, 0xe0000000 },
    /* 128  VEC_MUL      L03_VSSBlock_27_mlp_Mul                    27 Mul -> requant to 28            in: t26@WORK+51840(rel), s23v@X+21120(rel)                       out: t27@WORK+30720(rel)              rows[0,8)    C 170->170 80x80  sh 0,0,5,0  flags 70 misc e000  prm 0+0 */
    { 0x00007013, 0x00aa0005, 0x005000aa, 0x08000050, 0x8040ca80, 0x78002052, 0x00000040, 0xe0000000 },
    /* 129  GEMM         L03_VSSBlock_28_mlp_fc2_Conv2d             28 fc2 (X scratch)                 in: t27@WORK+30720(rel)                                          out: s28@X+0(rel)                     rows[0,8)    C 170->64 80x80  sh 0,0,0,0  flags 30 misc a000  prm 5243+352 L03_VSSBlock_28_mlp_fc2_Conv2d */
    { 0x00003020, 0x00aa0000, 0x00500040, 0x08000050, 0x00407800, 0x00000000, 0x00147b20, 0xa0000160 },
    /* 130  VEC_ADD      L03_VSSBlock_29_Add                        29 Add -> block output             in: t21@WORK+15360(rel)(w), s28@X+0(rel)                         out: L03_VSSBlock.out@B+0             rows[0,8)    C 64->64 80x80  sh 0,0,1,0  flags 70 misc 6200  prm 0+0 */
    { 0x00007012, 0x00400001, 0x00500040, 0x08000050, 0x00403c00, 0x00002000, 0x00000010, 0x62000000 },
    /* 131  VEC_RQ       L03_VSSBlock_29_Add                        keep block output in SKIP (S3)     in: L03_VSSBlock.out@B+0                                         out: S3@SKIP+0                        frame        C 64->64 80x80  sh 0,0,0,0  flags 30 misc 0000  prm 0+0 */
    { 0x00003010, 0x00400000, 0x00500040, 0x00000050, 0x00100000, 0x00000000, 0x00000030, 0x00000000 },
    /* 132  GEMM         L04_VisionClueMerge_02_pw_linear_Conv2d    VCM: S2D gather + 1x1              in: L03_VSSBlock.out@B+0                                         out: vcm_pw@WORK+0                    frame        C 64->128 80x80  sh 0,0,0,0  flags 30 misc 0003  prm 5605+1024 L04_VisionClueMerge_02_pw_linear_Conv2d */
    { 0x00003020, 0x00400000, 0x00500080, 0x00000050, 0x00100000, 0x00000000, 0x0015e540, 0x00030400 },
    /* 133  VEC_SILU     L04_VisionClueMerge_03_SiLU                VCM SiLU -> layer out              in: vcm_pw@WORK+0                                                out: L04.out@A+0                      frame        C 128->128 40x40  sh 0,0,0,0  flags 30 misc 0000  prm 521+0 */
    { 0x00003011, 0x00800000, 0x00280080, 0x00000028, 0x00400000, 0x00000000, 0x00020900, 0x00000000 },
    /* 134  LOOP TILE n=0 body=0 */
    { 0x00000001, 0x00000000, 0x0000000b, 0x00000028, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 135  GEMM         L05_VSSBlock0_01_proj_Conv2d               01 proj                            in: L04.out@A+0                                                  out: t01@WORK+0(rel)                  rows[-2,10)  C 128->128 40x40  sh 0,0,0,0  flags 30 misc 8000  prm 6649+512 L05_VSSBlock0_01_proj_Conv2d */
    { 0x00003020, 0x00800000, 0x00280080, 0x0afe0028, 0x00000000, 0x00000000, 0x0019f940, 0x80000200 },
    /* 136  VEC_SILU     L05_VSSBlock0_02_proj_SiLU                 02 SiLU                            in: t01@WORK+0(rel)                                              out: t02@WORK+7680(rel)               rows[-2,10)  C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 7181+0 */
    { 0x00003011, 0x00800000, 0x00280080, 0x0afe0028, 0x00400000, 0x1e000000, 0x001c0d40, 0xa0000000 },
    /* 137  DW           L05_VSSBlock0_03_ls_fc1_DWConv2d           03 DW                              in: t02@WORK+7680(rel)                                           out: t03@WORK+0(rel)                  rows[-2,10)  C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 7189+0 L05_VSSBlock0_03_ls_fc1_DWConv2d */
    { 0x00003030, 0x00800000, 0x00280080, 0x0afe0028, 0x00401e00, 0x00000000, 0x001c1540, 0xa0000000 },
    /* 138  GEMM         L05_VSSBlock0_04_ls_fc2_Conv2d             04                                 in: t03@WORK+0(rel)                                              out: t04@WORK+15360(rel)              rows[-1,9)   C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 7253+512 L05_VSSBlock0_04_ls_fc2_Conv2d */
    { 0x00003020, 0x00800000, 0x00280080, 0x09ff0028, 0x00400000, 0x3c000000, 0x001c5540, 0xa0000200 },
    /* 139  VEC_SILU     L05_VSSBlock0_05_ls_SiLU                   05 SiLU                            in: t04@WORK+15360(rel)                                          out: t05@WORK+0(rel)                  rows[-1,9)   C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 521+0 */
    { 0x00003011, 0x00800000, 0x00280080, 0x09ff0028, 0x00403c00, 0x00000000, 0x00020940, 0xa0000000 },
    /* 140  GEMM         L05_VSSBlock0_06_ls_fc3_Conv2d             06 (scratch)                       in: t05@WORK+0(rel)                                              out: s06@B+0(rel)                     rows[-1,9)   C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 7785+512 L05_VSSBlock0_06_ls_fc3_Conv2d */
    { 0x00003020, 0x00800000, 0x00280080, 0x09ff0028, 0x00400000, 0x00000000, 0x001e6910, 0xa0000200 },
    /* 141  VEC_ADD      L05_VSSBlock0_07_ls_Add                    07 Add -> requant to 08            in: t02@WORK+7680(rel), s06@B+0(rel)                             out: t07@WORK+0(rel)                  rows[-1,9)   C 128->128 40x40  sh 0,0,0,0  flags 70 misc e000  prm 0+0 */
    { 0x00007012, 0x00800000, 0x00280080, 0x09ff0028, 0x00401e00, 0x00001000, 0x00000040, 0xe0000000 },
    /* 142  VEC_LN       L05_VSSBlock0_08_norm_LightNorm            08 LightNorm                       in: t07@WORK+0(rel)                                              out: t08@WORK+7680(rel)               rows[-1,9)   C 128->128 40x40  sh 0,0,21,19  flags 30 misc a000  prm 8317+0 */
    { 0x00003014, 0x00801315, 0x00280080, 0x09ff0028, 0x00400000, 0x1e000000, 0x00207d40, 0xa0000000 },
    /* 143  GEMM         L05_VSSBlock0_09_ss2d_in_proj_Conv2d       09 in_proj x half                  in: t08@WORK+7680(rel)                                           out: t09x@WORK+15360(rel)             rows[-1,9)   C 128->256 40x40  sh 0,0,0,0  flags 30 misc a000  prm 8357+1024 L05_VSSBlock0_09_ss2d_in_proj_Conv2d:x */
    { 0x00003020, 0x00800000, 0x00280100, 0x09ff0028, 0x00401e00, 0x3c000000, 0x0020a540, 0xa0000400 },
    /* 144  DW           L05_VSSBlock0_11_ss2d_DWConv2d             11 DW                              in: t09x@WORK+15360(rel)                                         out: t11@WORK+0(rel)                  rows[-1,9)   C 256->256 40x40  sh 0,0,0,0  flags 30 misc a000  prm 10485+0 L05_VSSBlock0_11_ss2d_DWConv2d */
    { 0x00003030, 0x01000000, 0x00280100, 0x09ff0028, 0x00403c00, 0x00000000, 0x0028f540, 0xa0000000 },
    /* 145  VEC_SILU     L05_VSSBlock0_12_ss2d_SiLU_x               12 SiLU -> X                       in: t11@WORK+0(rel)                                              out: X@X+0                            rows[0,8)    C 256->256 40x40  sh 0,0,0,0  flags 30 misc 2000  prm 521+0 */
    { 0x00003011, 0x01000000, 0x00280100, 0x08000028, 0x00400000, 0x00000000, 0x00020920, 0x20000000 },
    /* 146  SETK 0 */
    { 0x00000003, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 147  LOOP GROUP n=200 body=4 */
    { 0x00000001, 0x00c80000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 148  GEMM         L05_VSSBlock0_14_ss2d_XProj                14 XProj dir0                      in: X@X+0                                                        out: g_xp@WORK+256                    frame        C 256->40 40x40  sh 0,0,0,0  flags 30 misc 0090  prm 10613+320 L05_VSSBlock0_14_ss2d_XProj:dir0 */
    { 0x00003020, 0x01000000, 0x00280028, 0x00000028, 0x00200000, 0x01000000, 0x00297540, 0x00900140 },
    /* 149  GEMM         L05_VSSBlock0_15_ss2d_DtProj               15 DtProj dir0 (+ReLU)             in: g_xp@WORK+256                                                out: g_delta@WORK+0                   frame        C 8->256 40x40  sh 0,0,0,5  flags 31 misc 0088  prm 11921+64 L05_VSSBlock0_15_ss2d_DtProj:dir0 */
    { 0x00003120, 0x00080500, 0x00280100, 0x00000028, 0x00400100, 0x00000000, 0x002e9140, 0x00880040 },
    /* 150  SCAN         L05_VSSBlock0_16_ss2d_SelectiveScan        16 scan dir0                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+296                     frame        C 256->256 40x40  sh 0,0,0,0  flags 44 misc 00b0  prm 12337+8 L05_VSSBlock0_16_ss2d_SelectiveScan:dir0 */
    { 0x00004440, 0x01000000, 0x00280100, 0x00000028, 0x00200000, 0x01284000, 0x00303140, 0x00b00008 },
    /* 151  VEC_ADD      L05_VSSBlock0_17_ss2d_CrossMerge           17 accumulate dir0                 in: g_y@WORK+296, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 256->256 40x40  sh -1,0,0,0  flags 7a misc 0548  prm 0+0 */
    { 0x00ff7a12, 0x01000000, 0x00280100, 0x00000028, 0x00400128, 0x00005000, 0x00000050, 0x05480000 },
    /* 152  SETK 1 */
    { 0x00000003, 0x00010000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 153  LOOP GROUP n=200 body=4 */
    { 0x00000001, 0x00c80000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 154  GEMM         L05_VSSBlock0_14_ss2d_XProj                14 XProj dir1                      in: X@X+0                                                        out: g_xp@WORK+256                    frame        C 256->40 40x40  sh 0,0,0,0  flags 30 misc 0090  prm 10940+320 L05_VSSBlock0_14_ss2d_XProj:dir1 */
    { 0x00003020, 0x01000000, 0x00280028, 0x00000028, 0x00200000, 0x01000000, 0x002abc40, 0x00900140 },
    /* 155  GEMM         L05_VSSBlock0_15_ss2d_DtProj               15 DtProj dir1 (+ReLU)             in: g_xp@WORK+256                                                out: g_delta@WORK+0                   frame        C 8->256 40x40  sh 0,0,0,5  flags 31 misc 0088  prm 12025+64 L05_VSSBlock0_15_ss2d_DtProj:dir1 */
    { 0x00003120, 0x00080500, 0x00280100, 0x00000028, 0x00400100, 0x00000000, 0x002ef940, 0x00880040 },
    /* 156  SCAN         L05_VSSBlock0_16_ss2d_SelectiveScan        16 scan dir1                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+296                     frame        C 256->256 40x40  sh 0,0,0,0  flags 44 misc 00b0  prm 12474+8 L05_VSSBlock0_16_ss2d_SelectiveScan:dir1 */
    { 0x00004440, 0x01000000, 0x00280100, 0x00000028, 0x00200000, 0x01284000, 0x0030ba40, 0x00b00008 },
    /* 157  VEC_ADD      L05_VSSBlock0_17_ss2d_CrossMerge           17 accumulate dir1                 in: g_y@WORK+296, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 256->256 40x40  sh -2,0,0,0  flags 72 misc 0548  prm 0+0 */
    { 0x00fe7212, 0x01000000, 0x00280100, 0x00000028, 0x00400128, 0x00005000, 0x00000050, 0x05480000 },
    /* 158  SETK 2 */
    { 0x00000003, 0x00020000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 159  LOOP GROUP n=200 body=4 */
    { 0x00000001, 0x00c80000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 160  GEMM         L05_VSSBlock0_14_ss2d_XProj                14 XProj dir2                      in: X@X+0                                                        out: g_xp@WORK+256                    frame        C 256->40 40x40  sh 0,0,0,0  flags 30 misc 0090  prm 11267+320 L05_VSSBlock0_14_ss2d_XProj:dir2 */
    { 0x00003020, 0x01000000, 0x00280028, 0x00000028, 0x00200000, 0x01000000, 0x002c0340, 0x00900140 },
    /* 161  GEMM         L05_VSSBlock0_15_ss2d_DtProj               15 DtProj dir2 (+ReLU)             in: g_xp@WORK+256                                                out: g_delta@WORK+0                   frame        C 8->256 40x40  sh 0,0,0,5  flags 31 misc 0088  prm 12129+64 L05_VSSBlock0_15_ss2d_DtProj:dir2 */
    { 0x00003120, 0x00080500, 0x00280100, 0x00000028, 0x00400100, 0x00000000, 0x002f6140, 0x00880040 },
    /* 162  SCAN         L05_VSSBlock0_16_ss2d_SelectiveScan        16 scan dir2                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+296                     frame        C 256->256 40x40  sh 0,0,0,0  flags 44 misc 00b0  prm 12611+8 L05_VSSBlock0_16_ss2d_SelectiveScan:dir2 */
    { 0x00004440, 0x01000000, 0x00280100, 0x00000028, 0x00200000, 0x01284000, 0x00314340, 0x00b00008 },
    /* 163  VEC_ADD      L05_VSSBlock0_17_ss2d_CrossMerge           17 accumulate dir2                 in: g_y@WORK+296, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 256->256 40x40  sh -1,0,0,0  flags 72 misc 0548  prm 0+0 */
    { 0x00ff7212, 0x01000000, 0x00280100, 0x00000028, 0x00400128, 0x00005000, 0x00000050, 0x05480000 },
    /* 164  SETK 3 */
    { 0x00000003, 0x00030000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 165  LOOP GROUP n=200 body=4 */
    { 0x00000001, 0x00c80000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 166  GEMM         L05_VSSBlock0_14_ss2d_XProj                14 XProj dir3                      in: X@X+0                                                        out: g_xp@WORK+256                    frame        C 256->40 40x40  sh 0,0,0,0  flags 30 misc 0090  prm 11594+320 L05_VSSBlock0_14_ss2d_XProj:dir3 */
    { 0x00003020, 0x01000000, 0x00280028, 0x00000028, 0x00200000, 0x01000000, 0x002d4a40, 0x00900140 },
    /* 167  GEMM         L05_VSSBlock0_15_ss2d_DtProj               15 DtProj dir3 (+ReLU)             in: g_xp@WORK+256                                                out: g_delta@WORK+0                   frame        C 8->256 40x40  sh 0,0,0,5  flags 31 misc 0088  prm 12233+64 L05_VSSBlock0_15_ss2d_DtProj:dir3 */
    { 0x00003120, 0x00080500, 0x00280100, 0x00000028, 0x00400100, 0x00000000, 0x002fc940, 0x00880040 },
    /* 168  SCAN         L05_VSSBlock0_16_ss2d_SelectiveScan        16 scan dir3                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+296                     frame        C 256->256 40x40  sh 0,0,0,0  flags 44 misc 00b0  prm 12748+8 L05_VSSBlock0_16_ss2d_SelectiveScan:dir3 */
    { 0x00004440, 0x01000000, 0x00280100, 0x00000028, 0x00200000, 0x01284000, 0x0031cc40, 0x00b00008 },
    /* 169  VEC_ADD      L05_VSSBlock0_17_ss2d_CrossMerge           17 accumulate dir3                 in: g_y@WORK+296, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 256->256 40x40  sh 0,0,0,0  flags 72 misc 0548  prm 0+0 */
    { 0x00007212, 0x01000000, 0x00280100, 0x00000028, 0x00400128, 0x00005000, 0x00000050, 0x05480000 },
    /* 170  LOOP TILE n=0 body=0 */
    { 0x00000001, 0x00000000, 0x00000017, 0x00000028, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 171  VEC_RQ       L05_VSSBlock0_17_ss2d_CrossMerge           17' ACC -> int8                    in: ACC@ACC+0(w)                                                 out: t17@WORK+0(rel)                  rows[-1,9)   C 256->256 40x40  sh 2,0,0,0  flags 30 misc 8200  prm 0+0 */
    { 0x00023010, 0x01000000, 0x00280100, 0x09ff0028, 0x00500000, 0x00000000, 0x00000040, 0x82000000 },
    /* 172  VEC_LN       L05_VSSBlock0_18_ss2d_out_norm_LightNorm   18 out_norm                        in: t17@WORK+0(rel)                                              out: t18@WORK+15360(rel)              rows[-1,9)   C 256->256 40x40  sh 0,0,20,18  flags 30 misc a000  prm 12885+0 */
    { 0x00003014, 0x01001214, 0x00280100, 0x09ff0028, 0x00400000, 0x3c000000, 0x00325540, 0xa0000000 },
    /* 173  GEMM         L05_VSSBlock0_01_proj_Conv2d               01 (recompute)                     in: L04.out@A+0                                                  out: r01@WORK+0(rel)                  rows[-2,10)  C 128->128 40x40  sh 0,0,0,0  flags 30 misc 8000  prm 6649+512 L05_VSSBlock0_01_proj_Conv2d */
    { 0x00003020, 0x00800000, 0x00280080, 0x0afe0028, 0x00000000, 0x00000000, 0x0019f940, 0x80000200 },
    /* 174  VEC_SILU     L05_VSSBlock0_02_proj_SiLU                 02 = r (recompute)                 in: r01@WORK+0(rel)                                              out: r02@WORK+7680(rel)               rows[-2,10)  C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 7181+0 */
    { 0x00003011, 0x00800000, 0x00280080, 0x0afe0028, 0x00400000, 0x1e000000, 0x001c0d40, 0xa0000000 },
    /* 175  DW           L05_VSSBlock0_03_ls_fc1_DWConv2d           03 (recompute)                     in: r02@WORK+7680(rel)                                           out: r03@WORK+0(rel)                  rows[-2,10)  C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 7189+0 L05_VSSBlock0_03_ls_fc1_DWConv2d */
    { 0x00003030, 0x00800000, 0x00280080, 0x0afe0028, 0x00401e00, 0x00000000, 0x001c1540, 0xa0000000 },
    /* 176  GEMM         L05_VSSBlock0_04_ls_fc2_Conv2d             04 (recompute)                     in: r03@WORK+0(rel)                                              out: r04@WORK+30720(rel)              rows[-1,9)   C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 7253+512 L05_VSSBlock0_04_ls_fc2_Conv2d */
    { 0x00003020, 0x00800000, 0x00280080, 0x09ff0028, 0x00400000, 0x78000000, 0x001c5540, 0xa0000200 },
    /* 177  VEC_SILU     L05_VSSBlock0_05_ls_SiLU                   05 (recompute)                     in: r04@WORK+30720(rel)                                          out: r05@WORK+0(rel)                  rows[-1,9)   C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 521+0 */
    { 0x00003011, 0x00800000, 0x00280080, 0x09ff0028, 0x00407800, 0x00000000, 0x00020940, 0xa0000000 },
    /* 178  GEMM         L05_VSSBlock0_06_ls_fc3_Conv2d             06 (recompute, X scratch)          in: r05@WORK+0(rel)                                              out: s06@X+0(rel)                     rows[-1,9)   C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 7785+512 L05_VSSBlock0_06_ls_fc3_Conv2d */
    { 0x00003020, 0x00800000, 0x00280080, 0x09ff0028, 0x00400000, 0x00000000, 0x001e6920, 0xa0000200 },
    /* 179  VEC_ADD      L05_VSSBlock0_07_ls_Add                    07 (recompute)                     in: r02@WORK+7680(rel), s06@X+0(rel)                             out: r07@WORK+0(rel)                  rows[-1,9)   C 128->128 40x40  sh 0,0,0,0  flags 70 misc e000  prm 0+0 */
    { 0x00007012, 0x00800000, 0x00280080, 0x09ff0028, 0x00401e00, 0x00002000, 0x00000040, 0xe0000000 },
    /* 180  VEC_LN       L05_VSSBlock0_08_norm_LightNorm            08 (recompute)                     in: r07@WORK+0(rel)                                              out: r08@WORK+30720(rel)              rows[-1,9)   C 128->128 40x40  sh 0,0,21,19  flags 30 misc a000  prm 8317+0 */
    { 0x00003014, 0x00801315, 0x00280080, 0x09ff0028, 0x00400000, 0x78000000, 0x00207d40, 0xa0000000 },
    /* 181  GEMM         L05_VSSBlock0_09_ss2d_in_proj_Conv2d       09 in_proj z half (recompute)      in: r08@WORK+30720(rel)                                          out: r09z@WORK+38400(rel)             rows[-1,9)   C 128->256 40x40  sh 0,0,0,0  flags 30 misc a000  prm 9421+1024 L05_VSSBlock0_09_ss2d_in_proj_Conv2d:z */
    { 0x00003020, 0x00800000, 0x00280100, 0x09ff0028, 0x00407800, 0x96000000, 0x0024cd40, 0xa0000400 },
    /* 182  VEC_SILU     L05_VSSBlock0_10_ss2d_SiLU_z               10 = z (X scratch)                 in: r09z@WORK+38400(rel)                                         out: s10z@X+0(rel)                    rows[-1,9)   C 256->256 40x40  sh 0,0,0,0  flags 30 misc a000  prm 521+0 */
    { 0x00003011, 0x01000000, 0x00280100, 0x09ff0028, 0x00409600, 0x00000000, 0x00020920, 0xa0000000 },
    /* 183  VEC_MUL      L05_VSSBlock0_19_ss2d_Mul                  19 gate -> requant to 20           in: t18@WORK+15360(rel), s10z@X+0(rel)                           out: t19@WORK+30720(rel)              rows[-1,9)   C 256->256 40x40  sh 0,0,4,0  flags 70 misc e000  prm 0+0 */
    { 0x00007013, 0x01000004, 0x00280100, 0x09ff0028, 0x00403c00, 0x78002000, 0x00000040, 0xe0000000 },
    /* 184  GEMM         L05_VSSBlock0_20_ss2d_out_proj_Conv2d      20 out_proj (X scratch)            in: t19@WORK+30720(rel)                                          out: s20@X+0(rel)                     rows[-1,9)   C 256->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 12933+1024 L05_VSSBlock0_20_ss2d_out_proj_Conv2d */
    { 0x00003020, 0x01000000, 0x00280080, 0x09ff0028, 0x00407800, 0x00000000, 0x00328520, 0xa0000400 },
    /* 185  VEC_ADD      L05_VSSBlock0_21_Add                       21 Add (wide, kept)                in: r02@WORK+7680(rel), s20@X+0(rel)                             out: t21@WORK+15360(rel)(w)           rows[-1,9)   C 128->128 40x40  sh -1,0,0,0  flags 72 misc e000  prm 0+0 */
    { 0x00ff7212, 0x00800000, 0x00280080, 0x09ff0028, 0x00401e00, 0x3c002000, 0x00000040, 0xe0000000 },
    /* 186  VEC_LN       L05_VSSBlock0_22_norm2_LightNorm           22 norm2                           in: t21@WORK+15360(rel)(w)                                       out: t22@WORK+0(rel)                  rows[-1,9)   C 128->128 40x40  sh 1,0,22,20  flags 30 misc a200  prm 13977+0 */
    { 0x00013014, 0x00801416, 0x00280080, 0x09ff0028, 0x00403c00, 0x00000000, 0x00369940, 0xa2000000 },
    /* 187  GEMM         L05_VSSBlock0_23_mlp_fc1_Conv2d            23 fc1 x half (X scratch)          in: t22@WORK+0(rel)                                              out: s23x@X+0(rel)                    rows[-1,9)   C 128->341 40x40  sh 0,0,0,0  flags 30 misc a000  prm 14017+1376 L05_VSSBlock0_23_mlp_fc1_Conv2d:x */
    { 0x00003020, 0x00800000, 0x00280155, 0x09ff0028, 0x00400000, 0x00000000, 0x0036c120, 0xa0000560 },
    /* 188  GEMM         L05_VSSBlock0_23_mlp_fc1_Conv2d            23 fc1 v half (X scratch)          in: t22@WORK+0(rel)                                              out: s23v@X+20640(rel)                rows[-1,9)   C 128->341 40x40  sh 0,0,0,0  flags 30 misc a000  prm 15447+1376 L05_VSSBlock0_23_mlp_fc1_Conv2d:v */
    { 0x00003020, 0x00800000, 0x00280155, 0x09ff0028, 0x00400000, 0x50a00000, 0x003c5720, 0xa0000560 },
    /* 189  DW           L05_VSSBlock0_24_mlp_DWConv2d              24 DW                              in: s23x@X+0(rel)                                                out: t24@WORK+30720(rel)              rows[-1,9)   C 341->341 40x40  sh 0,0,0,0  flags 30 misc a000  prm 16877+0 L05_VSSBlock0_24_mlp_DWConv2d */
    { 0x00003030, 0x01550000, 0x00280155, 0x09ff0028, 0x00200000, 0x78000000, 0x0041ed40, 0xa0000000 },
    /* 190  VEC_ADD      L05_VSSBlock0_26_mlp_SiLU                  25 Add -> 26 SiLU (fused)          in: t24@WORK+30720(rel), s23x@X+0(rel)                           out: t26@WORK+51360(rel)              rows[0,8)    C 341->341 40x40  sh 0,0,1,0  flags f0 misc e000  prm 521+0 */
    { 0x0000f012, 0x01550001, 0x00280155, 0x08000028, 0x00407800, 0xc8a02000, 0x00020940, 0xe0000000 },
    /* 191  VEC_MUL      L05_VSSBlock0_27_mlp_Mul                   27 Mul -> requant to 28            in: t26@WORK+51360(rel), s23v@X+20640(rel)                       out: t27@WORK+30720(rel)              rows[0,8)    C 341->341 40x40  sh 0,0,5,0  flags 70 misc e000  prm 0+0 */
    { 0x00007013, 0x01550005, 0x00280155, 0x08000028, 0xa040c8a0, 0x78002050, 0x00000040, 0xe0000000 },
    /* 192  GEMM         L05_VSSBlock0_28_mlp_fc2_Conv2d            28 fc2 (X scratch)                 in: t27@WORK+30720(rel)                                          out: s28@X+0(rel)                     rows[0,8)    C 341->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 17049+1376 L05_VSSBlock0_28_mlp_fc2_Conv2d */
    { 0x00003020, 0x01550000, 0x00280080, 0x08000028, 0x00407800, 0x00000000, 0x00429920, 0xa0000560 },
    /* 193  VEC_ADD      L05_VSSBlock0_29_Add                       29 Add -> block output             in: t21@WORK+15360(rel)(w), s28@X+0(rel)                         out: L05_VSSBlock0.out@B+0            rows[0,8)    C 128->128 40x40  sh 0,0,1,0  flags 70 misc 6200  prm 0+0 */
    { 0x00007012, 0x00800001, 0x00280080, 0x08000028, 0x00403c00, 0x00002000, 0x00000010, 0x62000000 },
    /* 194  LOOP TILE n=0 body=0 */
    { 0x00000001, 0x00000000, 0x0000000b, 0x00000028, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 195  GEMM         L05_VSSBlock1_01_proj_Conv2d               01 proj                            in: L05_VSSBlock0.out@B+0                                        out: t01@WORK+0(rel)                  rows[-2,10)  C 128->128 40x40  sh 0,0,0,0  flags 30 misc 8000  prm 18445+512 L05_VSSBlock1_01_proj_Conv2d */
    { 0x00003020, 0x00800000, 0x00280080, 0x0afe0028, 0x00100000, 0x00000000, 0x00480d40, 0x80000200 },
    /* 196  VEC_SILU     L05_VSSBlock1_02_proj_SiLU                 02 SiLU                            in: t01@WORK+0(rel)                                              out: t02@WORK+7680(rel)               rows[-2,10)  C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 2013+0 */
    { 0x00003011, 0x00800000, 0x00280080, 0x0afe0028, 0x00400000, 0x1e000000, 0x0007dd40, 0xa0000000 },
    /* 197  DW           L05_VSSBlock1_03_ls_fc1_DWConv2d           03 DW                              in: t02@WORK+7680(rel)                                           out: t03@WORK+0(rel)                  rows[-2,10)  C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 18977+0 L05_VSSBlock1_03_ls_fc1_DWConv2d */
    { 0x00003030, 0x00800000, 0x00280080, 0x0afe0028, 0x00401e00, 0x00000000, 0x004a2140, 0xa0000000 },
    /* 198  GEMM         L05_VSSBlock1_04_ls_fc2_Conv2d             04                                 in: t03@WORK+0(rel)                                              out: t04@WORK+15360(rel)              rows[-1,9)   C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 19041+512 L05_VSSBlock1_04_ls_fc2_Conv2d */
    { 0x00003020, 0x00800000, 0x00280080, 0x09ff0028, 0x00400000, 0x3c000000, 0x004a6140, 0xa0000200 },
    /* 199  VEC_SILU     L05_VSSBlock1_05_ls_SiLU                   05 SiLU                            in: t04@WORK+15360(rel)                                          out: t05@WORK+0(rel)                  rows[-1,9)   C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 521+0 */
    { 0x00003011, 0x00800000, 0x00280080, 0x09ff0028, 0x00403c00, 0x00000000, 0x00020940, 0xa0000000 },
    /* 200  GEMM         L05_VSSBlock1_06_ls_fc3_Conv2d             06 (scratch)                       in: t05@WORK+0(rel)                                              out: s06@A+0(rel)                     rows[-1,9)   C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 19573+512 L05_VSSBlock1_06_ls_fc3_Conv2d */
    { 0x00003020, 0x00800000, 0x00280080, 0x09ff0028, 0x00400000, 0x00000000, 0x004c7500, 0xa0000200 },
    /* 201  VEC_ADD      L05_VSSBlock1_07_ls_Add                    07 Add -> requant to 08            in: t02@WORK+7680(rel), s06@A+0(rel)                             out: t07@WORK+0(rel)                  rows[-1,9)   C 128->128 40x40  sh -1,0,1,0  flags 70 misc e000  prm 0+0 */
    { 0x00ff7012, 0x00800001, 0x00280080, 0x09ff0028, 0x00401e00, 0x00000000, 0x00000040, 0xe0000000 },
    /* 202  VEC_LN       L05_VSSBlock1_08_norm_LightNorm            08 LightNorm                       in: t07@WORK+0(rel)                                              out: t08@WORK+7680(rel)               rows[-1,9)   C 128->128 40x40  sh 0,0,22,21  flags 30 misc a000  prm 20105+0 */
    { 0x00003014, 0x00801516, 0x00280080, 0x09ff0028, 0x00400000, 0x1e000000, 0x004e8940, 0xa0000000 },
    /* 203  GEMM         L05_VSSBlock1_09_ss2d_in_proj_Conv2d       09 in_proj x half                  in: t08@WORK+7680(rel)                                           out: t09x@WORK+15360(rel)             rows[-1,9)   C 128->256 40x40  sh 0,0,0,0  flags 30 misc a000  prm 20145+1024 L05_VSSBlock1_09_ss2d_in_proj_Conv2d:x */
    { 0x00003020, 0x00800000, 0x00280100, 0x09ff0028, 0x00401e00, 0x3c000000, 0x004eb140, 0xa0000400 },
    /* 204  DW           L05_VSSBlock1_11_ss2d_DWConv2d             11 DW                              in: t09x@WORK+15360(rel)                                         out: t11@WORK+0(rel)                  rows[-1,9)   C 256->256 40x40  sh 0,0,0,0  flags 30 misc a000  prm 22281+0 L05_VSSBlock1_11_ss2d_DWConv2d */
    { 0x00003030, 0x01000000, 0x00280100, 0x09ff0028, 0x00403c00, 0x00000000, 0x00570940, 0xa0000000 },
    /* 205  VEC_SILU     L05_VSSBlock1_12_ss2d_SiLU_x               12 SiLU -> X                       in: t11@WORK+0(rel)                                              out: X@X+0                            rows[0,8)    C 256->256 40x40  sh 0,0,0,0  flags 30 misc 2000  prm 22273+0 */
    { 0x00003011, 0x01000000, 0x00280100, 0x08000028, 0x00400000, 0x00000000, 0x00570120, 0x20000000 },
    /* 206  SETK 0 */
    { 0x00000003, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 207  LOOP GROUP n=200 body=4 */
    { 0x00000001, 0x00c80000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 208  GEMM         L05_VSSBlock1_14_ss2d_XProj                14 XProj dir0                      in: X@X+0                                                        out: g_xp@WORK+256                    frame        C 256->40 40x40  sh 0,0,0,0  flags 30 misc 0090  prm 22409+320 L05_VSSBlock1_14_ss2d_XProj:dir0 */
    { 0x00003020, 0x01000000, 0x00280028, 0x00000028, 0x00200000, 0x01000000, 0x00578940, 0x00900140 },
    /* 209  GEMM         L05_VSSBlock1_15_ss2d_DtProj               15 DtProj dir0 (+ReLU)             in: g_xp@WORK+256                                                out: g_delta@WORK+0                   frame        C 8->256 40x40  sh 0,0,0,5  flags 31 misc 0088  prm 23717+64 L05_VSSBlock1_15_ss2d_DtProj:dir0 */
    { 0x00003120, 0x00080500, 0x00280100, 0x00000028, 0x00400100, 0x00000000, 0x005ca540, 0x00880040 },
    /* 210  SCAN         L05_VSSBlock1_16_ss2d_SelectiveScan        16 scan dir0                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+296                     frame        C 256->256 40x40  sh 0,0,0,0  flags 44 misc 00b0  prm 24133+8 L05_VSSBlock1_16_ss2d_SelectiveScan:dir0 */
    { 0x00004440, 0x01000000, 0x00280100, 0x00000028, 0x00200000, 0x01284000, 0x005e4540, 0x00b00008 },
    /* 211  VEC_ADD      L05_VSSBlock1_17_ss2d_CrossMerge           17 accumulate dir0                 in: g_y@WORK+296, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 256->256 40x40  sh -1,0,0,0  flags 7a misc 0548  prm 0+0 */
    { 0x00ff7a12, 0x01000000, 0x00280100, 0x00000028, 0x00400128, 0x00005000, 0x00000050, 0x05480000 },
    /* 212  SETK 1 */
    { 0x00000003, 0x00010000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 213  LOOP GROUP n=200 body=4 */
    { 0x00000001, 0x00c80000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 214  GEMM         L05_VSSBlock1_14_ss2d_XProj                14 XProj dir1                      in: X@X+0                                                        out: g_xp@WORK+256                    frame        C 256->40 40x40  sh 0,0,0,0  flags 30 misc 0090  prm 22736+320 L05_VSSBlock1_14_ss2d_XProj:dir1 */
    { 0x00003020, 0x01000000, 0x00280028, 0x00000028, 0x00200000, 0x01000000, 0x0058d040, 0x00900140 },
    /* 215  GEMM         L05_VSSBlock1_15_ss2d_DtProj               15 DtProj dir1 (+ReLU)             in: g_xp@WORK+256                                                out: g_delta@WORK+0                   frame        C 8->256 40x40  sh 0,0,0,5  flags 31 misc 0088  prm 23821+64 L05_VSSBlock1_15_ss2d_DtProj:dir1 */
    { 0x00003120, 0x00080500, 0x00280100, 0x00000028, 0x00400100, 0x00000000, 0x005d0d40, 0x00880040 },
    /* 216  SCAN         L05_VSSBlock1_16_ss2d_SelectiveScan        16 scan dir1                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+296                     frame        C 256->256 40x40  sh 0,0,0,0  flags 44 misc 00b0  prm 24270+8 L05_VSSBlock1_16_ss2d_SelectiveScan:dir1 */
    { 0x00004440, 0x01000000, 0x00280100, 0x00000028, 0x00200000, 0x01284000, 0x005ece40, 0x00b00008 },
    /* 217  VEC_ADD      L05_VSSBlock1_17_ss2d_CrossMerge           17 accumulate dir1                 in: g_y@WORK+296, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 256->256 40x40  sh 0,0,0,0  flags 72 misc 0548  prm 0+0 */
    { 0x00007212, 0x01000000, 0x00280100, 0x00000028, 0x00400128, 0x00005000, 0x00000050, 0x05480000 },
    /* 218  SETK 2 */
    { 0x00000003, 0x00020000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 219  LOOP GROUP n=200 body=4 */
    { 0x00000001, 0x00c80000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 220  GEMM         L05_VSSBlock1_14_ss2d_XProj                14 XProj dir2                      in: X@X+0                                                        out: g_xp@WORK+256                    frame        C 256->40 40x40  sh 0,0,0,0  flags 30 misc 0090  prm 23063+320 L05_VSSBlock1_14_ss2d_XProj:dir2 */
    { 0x00003020, 0x01000000, 0x00280028, 0x00000028, 0x00200000, 0x01000000, 0x005a1740, 0x00900140 },
    /* 221  GEMM         L05_VSSBlock1_15_ss2d_DtProj               15 DtProj dir2 (+ReLU)             in: g_xp@WORK+256                                                out: g_delta@WORK+0                   frame        C 8->256 40x40  sh 0,0,0,5  flags 31 misc 0088  prm 23925+64 L05_VSSBlock1_15_ss2d_DtProj:dir2 */
    { 0x00003120, 0x00080500, 0x00280100, 0x00000028, 0x00400100, 0x00000000, 0x005d7540, 0x00880040 },
    /* 222  SCAN         L05_VSSBlock1_16_ss2d_SelectiveScan        16 scan dir2                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+296                     frame        C 256->256 40x40  sh 0,0,0,0  flags 44 misc 00b0  prm 24407+8 L05_VSSBlock1_16_ss2d_SelectiveScan:dir2 */
    { 0x00004440, 0x01000000, 0x00280100, 0x00000028, 0x00200000, 0x01284000, 0x005f5740, 0x00b00008 },
    /* 223  VEC_ADD      L05_VSSBlock1_17_ss2d_CrossMerge           17 accumulate dir2                 in: g_y@WORK+296, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 256->256 40x40  sh 0,0,0,0  flags 72 misc 0548  prm 0+0 */
    { 0x00007212, 0x01000000, 0x00280100, 0x00000028, 0x00400128, 0x00005000, 0x00000050, 0x05480000 },
    /* 224  SETK 3 */
    { 0x00000003, 0x00030000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 225  LOOP GROUP n=200 body=4 */
    { 0x00000001, 0x00c80000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 226  GEMM         L05_VSSBlock1_14_ss2d_XProj                14 XProj dir3                      in: X@X+0                                                        out: g_xp@WORK+256                    frame        C 256->40 40x40  sh 0,0,0,0  flags 30 misc 0090  prm 23390+320 L05_VSSBlock1_14_ss2d_XProj:dir3 */
    { 0x00003020, 0x01000000, 0x00280028, 0x00000028, 0x00200000, 0x01000000, 0x005b5e40, 0x00900140 },
    /* 227  GEMM         L05_VSSBlock1_15_ss2d_DtProj               15 DtProj dir3 (+ReLU)             in: g_xp@WORK+256                                                out: g_delta@WORK+0                   frame        C 8->256 40x40  sh 0,0,0,5  flags 31 misc 0088  prm 24029+64 L05_VSSBlock1_15_ss2d_DtProj:dir3 */
    { 0x00003120, 0x00080500, 0x00280100, 0x00000028, 0x00400100, 0x00000000, 0x005ddd40, 0x00880040 },
    /* 228  SCAN         L05_VSSBlock1_16_ss2d_SelectiveScan        16 scan dir3                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+296                     frame        C 256->256 40x40  sh 0,0,0,0  flags 44 misc 00b0  prm 24544+8 L05_VSSBlock1_16_ss2d_SelectiveScan:dir3 */
    { 0x00004440, 0x01000000, 0x00280100, 0x00000028, 0x00200000, 0x01284000, 0x005fe040, 0x00b00008 },
    /* 229  VEC_ADD      L05_VSSBlock1_17_ss2d_CrossMerge           17 accumulate dir3                 in: g_y@WORK+296, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 256->256 40x40  sh 0,0,0,0  flags 72 misc 0548  prm 0+0 */
    { 0x00007212, 0x01000000, 0x00280100, 0x00000028, 0x00400128, 0x00005000, 0x00000050, 0x05480000 },
    /* 230  LOOP TILE n=0 body=0 */
    { 0x00000001, 0x00000000, 0x00000017, 0x00000028, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 231  VEC_RQ       L05_VSSBlock1_17_ss2d_CrossMerge           17' ACC -> int8                    in: ACC@ACC+0(w)                                                 out: t17@WORK+0(rel)                  rows[-1,9)   C 256->256 40x40  sh 1,0,0,0  flags 30 misc 8200  prm 0+0 */
    { 0x00013010, 0x01000000, 0x00280100, 0x09ff0028, 0x00500000, 0x00000000, 0x00000040, 0x82000000 },
    /* 232  VEC_LN       L05_VSSBlock1_18_ss2d_out_norm_LightNorm   18 out_norm                        in: t17@WORK+0(rel)                                              out: t18@WORK+15360(rel)              rows[-1,9)   C 256->256 40x40  sh 0,0,21,18  flags 30 misc a000  prm 24681+0 */
    { 0x00003014, 0x01001215, 0x00280100, 0x09ff0028, 0x00400000, 0x3c000000, 0x00606940, 0xa0000000 },
    /* 233  GEMM         L05_VSSBlock1_01_proj_Conv2d               01 (recompute)                     in: L05_VSSBlock0.out@B+0                                        out: r01@WORK+0(rel)                  rows[-2,10)  C 128->128 40x40  sh 0,0,0,0  flags 30 misc 8000  prm 18445+512 L05_VSSBlock1_01_proj_Conv2d */
    { 0x00003020, 0x00800000, 0x00280080, 0x0afe0028, 0x00100000, 0x00000000, 0x00480d40, 0x80000200 },
    /* 234  VEC_SILU     L05_VSSBlock1_02_proj_SiLU                 02 = r (recompute)                 in: r01@WORK+0(rel)                                              out: r02@WORK+7680(rel)               rows[-2,10)  C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 2013+0 */
    { 0x00003011, 0x00800000, 0x00280080, 0x0afe0028, 0x00400000, 0x1e000000, 0x0007dd40, 0xa0000000 },
    /* 235  DW           L05_VSSBlock1_03_ls_fc1_DWConv2d           03 (recompute)                     in: r02@WORK+7680(rel)                                           out: r03@WORK+0(rel)                  rows[-2,10)  C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 18977+0 L05_VSSBlock1_03_ls_fc1_DWConv2d */
    { 0x00003030, 0x00800000, 0x00280080, 0x0afe0028, 0x00401e00, 0x00000000, 0x004a2140, 0xa0000000 },
    /* 236  GEMM         L05_VSSBlock1_04_ls_fc2_Conv2d             04 (recompute)                     in: r03@WORK+0(rel)                                              out: r04@WORK+30720(rel)              rows[-1,9)   C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 19041+512 L05_VSSBlock1_04_ls_fc2_Conv2d */
    { 0x00003020, 0x00800000, 0x00280080, 0x09ff0028, 0x00400000, 0x78000000, 0x004a6140, 0xa0000200 },
    /* 237  VEC_SILU     L05_VSSBlock1_05_ls_SiLU                   05 (recompute)                     in: r04@WORK+30720(rel)                                          out: r05@WORK+0(rel)                  rows[-1,9)   C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 521+0 */
    { 0x00003011, 0x00800000, 0x00280080, 0x09ff0028, 0x00407800, 0x00000000, 0x00020940, 0xa0000000 },
    /* 238  GEMM         L05_VSSBlock1_06_ls_fc3_Conv2d             06 (recompute, X scratch)          in: r05@WORK+0(rel)                                              out: s06@X+0(rel)                     rows[-1,9)   C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 19573+512 L05_VSSBlock1_06_ls_fc3_Conv2d */
    { 0x00003020, 0x00800000, 0x00280080, 0x09ff0028, 0x00400000, 0x00000000, 0x004c7520, 0xa0000200 },
    /* 239  VEC_ADD      L05_VSSBlock1_07_ls_Add                    07 (recompute)                     in: r02@WORK+7680(rel), s06@X+0(rel)                             out: r07@WORK+0(rel)                  rows[-1,9)   C 128->128 40x40  sh -1,0,1,0  flags 70 misc e000  prm 0+0 */
    { 0x00ff7012, 0x00800001, 0x00280080, 0x09ff0028, 0x00401e00, 0x00002000, 0x00000040, 0xe0000000 },
    /* 240  VEC_LN       L05_VSSBlock1_08_norm_LightNorm            08 (recompute)                     in: r07@WORK+0(rel)                                              out: r08@WORK+30720(rel)              rows[-1,9)   C 128->128 40x40  sh 0,0,22,21  flags 30 misc a000  prm 20105+0 */
    { 0x00003014, 0x00801516, 0x00280080, 0x09ff0028, 0x00400000, 0x78000000, 0x004e8940, 0xa0000000 },
    /* 241  GEMM         L05_VSSBlock1_09_ss2d_in_proj_Conv2d       09 in_proj z half (recompute)      in: r08@WORK+30720(rel)                                          out: r09z@WORK+38400(rel)             rows[-1,9)   C 128->256 40x40  sh 0,0,0,0  flags 30 misc a000  prm 21209+1024 L05_VSSBlock1_09_ss2d_in_proj_Conv2d:z */
    { 0x00003020, 0x00800000, 0x00280100, 0x09ff0028, 0x00407800, 0x96000000, 0x0052d940, 0xa0000400 },
    /* 242  VEC_SILU     L05_VSSBlock1_10_ss2d_SiLU_z               10 = z (X scratch)                 in: r09z@WORK+38400(rel)                                         out: s10z@X+0(rel)                    rows[-1,9)   C 256->256 40x40  sh -1,0,0,0  flags 30 misc a000  prm 22273+0 */
    { 0x00ff3011, 0x01000000, 0x00280100, 0x09ff0028, 0x00409600, 0x00000000, 0x00570120, 0xa0000000 },
    /* 243  VEC_MUL      L05_VSSBlock1_19_ss2d_Mul                  19 gate -> requant to 20           in: t18@WORK+15360(rel), s10z@X+0(rel)                           out: t19@WORK+30720(rel)              rows[-1,9)   C 256->256 40x40  sh 0,0,4,0  flags 70 misc e000  prm 0+0 */
    { 0x00007013, 0x01000004, 0x00280100, 0x09ff0028, 0x00403c00, 0x78002000, 0x00000040, 0xe0000000 },
    /* 244  GEMM         L05_VSSBlock1_20_ss2d_out_proj_Conv2d      20 out_proj (X scratch)            in: t19@WORK+30720(rel)                                          out: s20@X+0(rel)                     rows[-1,9)   C 256->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 24729+1024 L05_VSSBlock1_20_ss2d_out_proj_Conv2d */
    { 0x00003020, 0x01000000, 0x00280080, 0x09ff0028, 0x00407800, 0x00000000, 0x00609920, 0xa0000400 },
    /* 245  VEC_ADD      L05_VSSBlock1_21_Add                       21 Add (wide, kept)                in: r02@WORK+7680(rel), s20@X+0(rel)                             out: t21@WORK+15360(rel)(w)           rows[-1,9)   C 128->128 40x40  sh -1,0,0,0  flags 72 misc e000  prm 0+0 */
    { 0x00ff7212, 0x00800000, 0x00280080, 0x09ff0028, 0x00401e00, 0x3c002000, 0x00000040, 0xe0000000 },
    /* 246  VEC_LN       L05_VSSBlock1_22_norm2_LightNorm           22 norm2                           in: t21@WORK+15360(rel)(w)                                       out: t22@WORK+0(rel)                  rows[-1,9)   C 128->128 40x40  sh 1,0,21,19  flags 30 misc a200  prm 25773+0 */
    { 0x00013014, 0x00801315, 0x00280080, 0x09ff0028, 0x00403c00, 0x00000000, 0x0064ad40, 0xa2000000 },
    /* 247  GEMM         L05_VSSBlock1_23_mlp_fc1_Conv2d            23 fc1 x half (X scratch)          in: t22@WORK+0(rel)                                              out: s23x@X+0(rel)                    rows[-1,9)   C 128->341 40x40  sh 0,0,0,0  flags 30 misc a000  prm 25813+1376 L05_VSSBlock1_23_mlp_fc1_Conv2d:x */
    { 0x00003020, 0x00800000, 0x00280155, 0x09ff0028, 0x00400000, 0x00000000, 0x0064d520, 0xa0000560 },
    /* 248  GEMM         L05_VSSBlock1_23_mlp_fc1_Conv2d            23 fc1 v half (X scratch)          in: t22@WORK+0(rel)                                              out: s23v@X+20640(rel)                rows[-1,9)   C 128->341 40x40  sh 0,0,0,0  flags 30 misc a000  prm 27243+1376 L05_VSSBlock1_23_mlp_fc1_Conv2d:v */
    { 0x00003020, 0x00800000, 0x00280155, 0x09ff0028, 0x00400000, 0x50a00000, 0x006a6b20, 0xa0000560 },
    /* 249  DW           L05_VSSBlock1_24_mlp_DWConv2d              24 DW                              in: s23x@X+0(rel)                                                out: t24@WORK+30720(rel)              rows[-1,9)   C 341->341 40x40  sh 0,0,0,0  flags 30 misc a000  prm 28673+0 L05_VSSBlock1_24_mlp_DWConv2d */
    { 0x00003030, 0x01550000, 0x00280155, 0x09ff0028, 0x00200000, 0x78000000, 0x00700140, 0xa0000000 },
    /* 250  VEC_ADD      L05_VSSBlock1_26_mlp_SiLU                  25 Add -> 26 SiLU (fused)          in: t24@WORK+30720(rel), s23x@X+0(rel)                           out: t26@WORK+51360(rel)              rows[0,8)    C 341->341 40x40  sh 0,0,1,0  flags f0 misc e000  prm 2013+0 */
    { 0x0000f012, 0x01550001, 0x00280155, 0x08000028, 0x00407800, 0xc8a02000, 0x0007dd40, 0xe0000000 },
    /* 251  VEC_MUL      L05_VSSBlock1_27_mlp_Mul                   27 Mul -> requant to 28            in: t26@WORK+51360(rel), s23v@X+20640(rel)                       out: t27@WORK+30720(rel)              rows[0,8)    C 341->341 40x40  sh 0,0,6,0  flags 70 misc e000  prm 0+0 */
    { 0x00007013, 0x01550006, 0x00280155, 0x08000028, 0xa040c8a0, 0x78002050, 0x00000040, 0xe0000000 },
    /* 252  GEMM         L05_VSSBlock1_28_mlp_fc2_Conv2d            28 fc2 (X scratch)                 in: t27@WORK+30720(rel)                                          out: s28@X+0(rel)                     rows[0,8)    C 341->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 28845+1376 L05_VSSBlock1_28_mlp_fc2_Conv2d */
    { 0x00003020, 0x01550000, 0x00280080, 0x08000028, 0x00407800, 0x00000000, 0x0070ad20, 0xa0000560 },
    /* 253  VEC_ADD      L05_VSSBlock1_29_Add                       29 Add -> block output             in: t21@WORK+15360(rel)(w), s28@X+0(rel)                         out: L05_VSSBlock1.out@A+0            rows[0,8)    C 128->128 40x40  sh -1,0,2,0  flags 70 misc 6200  prm 0+0 */
    { 0x00ff7012, 0x00800002, 0x00280080, 0x08000028, 0x00403c00, 0x00002000, 0x00000000, 0x62000000 },
    /* 254  LOOP TILE n=0 body=0 */
    { 0x00000001, 0x00000000, 0x0000000b, 0x00000028, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 255  GEMM         L05_VSSBlock2_01_proj_Conv2d               01 proj                            in: L05_VSSBlock1.out@A+0                                        out: t01@WORK+0(rel)                  rows[-2,10)  C 128->128 40x40  sh 0,0,0,0  flags 30 misc 8000  prm 30241+512 L05_VSSBlock2_01_proj_Conv2d */
    { 0x00003020, 0x00800000, 0x00280080, 0x0afe0028, 0x00000000, 0x00000000, 0x00762140, 0x80000200 },
    /* 256  VEC_SILU     L05_VSSBlock2_02_proj_SiLU                 02 SiLU                            in: t01@WORK+0(rel)                                              out: t02@WORK+7680(rel)               rows[-2,10)  C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 22273+0 */
    { 0x00003011, 0x00800000, 0x00280080, 0x0afe0028, 0x00400000, 0x1e000000, 0x00570140, 0xa0000000 },
    /* 257  DW           L05_VSSBlock2_03_ls_fc1_DWConv2d           03 DW                              in: t02@WORK+7680(rel)                                           out: t03@WORK+0(rel)                  rows[-2,10)  C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 30773+0 L05_VSSBlock2_03_ls_fc1_DWConv2d */
    { 0x00003030, 0x00800000, 0x00280080, 0x0afe0028, 0x00401e00, 0x00000000, 0x00783540, 0xa0000000 },
    /* 258  GEMM         L05_VSSBlock2_04_ls_fc2_Conv2d             04                                 in: t03@WORK+0(rel)                                              out: t04@WORK+15360(rel)              rows[-1,9)   C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 30837+512 L05_VSSBlock2_04_ls_fc2_Conv2d */
    { 0x00003020, 0x00800000, 0x00280080, 0x09ff0028, 0x00400000, 0x3c000000, 0x00787540, 0xa0000200 },
    /* 259  VEC_SILU     L05_VSSBlock2_05_ls_SiLU                   05 SiLU                            in: t04@WORK+15360(rel)                                          out: t05@WORK+0(rel)                  rows[-1,9)   C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 521+0 */
    { 0x00003011, 0x00800000, 0x00280080, 0x09ff0028, 0x00403c00, 0x00000000, 0x00020940, 0xa0000000 },
    /* 260  GEMM         L05_VSSBlock2_06_ls_fc3_Conv2d             06 (scratch)                       in: t05@WORK+0(rel)                                              out: s06@B+0(rel)                     rows[-1,9)   C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 31369+512 L05_VSSBlock2_06_ls_fc3_Conv2d */
    { 0x00003020, 0x00800000, 0x00280080, 0x09ff0028, 0x00400000, 0x00000000, 0x007a8910, 0xa0000200 },
    /* 261  VEC_ADD      L05_VSSBlock2_07_ls_Add                    07 Add -> requant to 08            in: t02@WORK+7680(rel), s06@B+0(rel)                             out: t07@WORK+0(rel)                  rows[-1,9)   C 128->128 40x40  sh -1,0,1,0  flags 70 misc e000  prm 0+0 */
    { 0x00ff7012, 0x00800001, 0x00280080, 0x09ff0028, 0x00401e00, 0x00001000, 0x00000040, 0xe0000000 },
    /* 262  VEC_LN       L05_VSSBlock2_08_norm_LightNorm            08 LightNorm                       in: t07@WORK+0(rel)                                              out: t08@WORK+7680(rel)               rows[-1,9)   C 128->128 40x40  sh 0,0,21,19  flags 30 misc a000  prm 31901+0 */
    { 0x00003014, 0x00801315, 0x00280080, 0x09ff0028, 0x00400000, 0x1e000000, 0x007c9d40, 0xa0000000 },
    /* 263  GEMM         L05_VSSBlock2_09_ss2d_in_proj_Conv2d       09 in_proj x half                  in: t08@WORK+7680(rel)                                           out: t09x@WORK+15360(rel)             rows[-1,9)   C 128->256 40x40  sh 0,0,0,0  flags 30 misc a000  prm 31941+1024 L05_VSSBlock2_09_ss2d_in_proj_Conv2d:x */
    { 0x00003020, 0x00800000, 0x00280100, 0x09ff0028, 0x00401e00, 0x3c000000, 0x007cc540, 0xa0000400 },
    /* 264  DW           L05_VSSBlock2_11_ss2d_DWConv2d             11 DW                              in: t09x@WORK+15360(rel)                                         out: t11@WORK+0(rel)                  rows[-1,9)   C 256->256 40x40  sh 0,0,0,0  flags 30 misc a000  prm 34069+0 L05_VSSBlock2_11_ss2d_DWConv2d */
    { 0x00003030, 0x01000000, 0x00280100, 0x09ff0028, 0x00403c00, 0x00000000, 0x00851540, 0xa0000000 },
    /* 265  VEC_SILU     L05_VSSBlock2_12_ss2d_SiLU_x               12 SiLU -> X                       in: t11@WORK+0(rel)                                              out: X@X+0                            rows[0,8)    C 256->256 40x40  sh 0,0,0,0  flags 30 misc 2000  prm 521+0 */
    { 0x00003011, 0x01000000, 0x00280100, 0x08000028, 0x00400000, 0x00000000, 0x00020920, 0x20000000 },
    /* 266  SETK 0 */
    { 0x00000003, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 267  LOOP GROUP n=200 body=4 */
    { 0x00000001, 0x00c80000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 268  GEMM         L05_VSSBlock2_14_ss2d_XProj                14 XProj dir0                      in: X@X+0                                                        out: g_xp@WORK+256                    frame        C 256->40 40x40  sh 0,0,0,0  flags 30 misc 0090  prm 34197+320 L05_VSSBlock2_14_ss2d_XProj:dir0 */
    { 0x00003020, 0x01000000, 0x00280028, 0x00000028, 0x00200000, 0x01000000, 0x00859540, 0x00900140 },
    /* 269  GEMM         L05_VSSBlock2_15_ss2d_DtProj               15 DtProj dir0 (+ReLU)             in: g_xp@WORK+256                                                out: g_delta@WORK+0                   frame        C 8->256 40x40  sh 0,0,0,5  flags 31 misc 0088  prm 35505+64 L05_VSSBlock2_15_ss2d_DtProj:dir0 */
    { 0x00003120, 0x00080500, 0x00280100, 0x00000028, 0x00400100, 0x00000000, 0x008ab140, 0x00880040 },
    /* 270  SCAN         L05_VSSBlock2_16_ss2d_SelectiveScan        16 scan dir0                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+296                     frame        C 256->256 40x40  sh 0,0,0,0  flags 44 misc 00b0  prm 35921+8 L05_VSSBlock2_16_ss2d_SelectiveScan:dir0 */
    { 0x00004440, 0x01000000, 0x00280100, 0x00000028, 0x00200000, 0x01284000, 0x008c5140, 0x00b00008 },
    /* 271  VEC_ADD      L05_VSSBlock2_17_ss2d_CrossMerge           17 accumulate dir0                 in: g_y@WORK+296, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 256->256 40x40  sh -2,0,0,0  flags 7a misc 0548  prm 0+0 */
    { 0x00fe7a12, 0x01000000, 0x00280100, 0x00000028, 0x00400128, 0x00005000, 0x00000050, 0x05480000 },
    /* 272  SETK 1 */
    { 0x00000003, 0x00010000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 273  LOOP GROUP n=200 body=4 */
    { 0x00000001, 0x00c80000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 274  GEMM         L05_VSSBlock2_14_ss2d_XProj                14 XProj dir1                      in: X@X+0                                                        out: g_xp@WORK+256                    frame        C 256->40 40x40  sh 0,0,0,0  flags 30 misc 0090  prm 34524+320 L05_VSSBlock2_14_ss2d_XProj:dir1 */
    { 0x00003020, 0x01000000, 0x00280028, 0x00000028, 0x00200000, 0x01000000, 0x0086dc40, 0x00900140 },
    /* 275  GEMM         L05_VSSBlock2_15_ss2d_DtProj               15 DtProj dir1 (+ReLU)             in: g_xp@WORK+256                                                out: g_delta@WORK+0                   frame        C 8->256 40x40  sh 0,0,0,5  flags 31 misc 0088  prm 35609+64 L05_VSSBlock2_15_ss2d_DtProj:dir1 */
    { 0x00003120, 0x00080500, 0x00280100, 0x00000028, 0x00400100, 0x00000000, 0x008b1940, 0x00880040 },
    /* 276  SCAN         L05_VSSBlock2_16_ss2d_SelectiveScan        16 scan dir1                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+296                     frame        C 256->256 40x40  sh 0,0,0,0  flags 44 misc 00b0  prm 36058+8 L05_VSSBlock2_16_ss2d_SelectiveScan:dir1 */
    { 0x00004440, 0x01000000, 0x00280100, 0x00000028, 0x00200000, 0x01284000, 0x008cda40, 0x00b00008 },
    /* 277  VEC_ADD      L05_VSSBlock2_17_ss2d_CrossMerge           17 accumulate dir1                 in: g_y@WORK+296, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 256->256 40x40  sh -1,0,0,0  flags 72 misc 0548  prm 0+0 */
    { 0x00ff7212, 0x01000000, 0x00280100, 0x00000028, 0x00400128, 0x00005000, 0x00000050, 0x05480000 },
    /* 278  SETK 2 */
    { 0x00000003, 0x00020000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 279  LOOP GROUP n=200 body=4 */
    { 0x00000001, 0x00c80000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 280  GEMM         L05_VSSBlock2_14_ss2d_XProj                14 XProj dir2                      in: X@X+0                                                        out: g_xp@WORK+256                    frame        C 256->40 40x40  sh 0,0,0,0  flags 30 misc 0090  prm 34851+320 L05_VSSBlock2_14_ss2d_XProj:dir2 */
    { 0x00003020, 0x01000000, 0x00280028, 0x00000028, 0x00200000, 0x01000000, 0x00882340, 0x00900140 },
    /* 281  GEMM         L05_VSSBlock2_15_ss2d_DtProj               15 DtProj dir2 (+ReLU)             in: g_xp@WORK+256                                                out: g_delta@WORK+0                   frame        C 8->256 40x40  sh 0,0,0,5  flags 31 misc 0088  prm 35713+64 L05_VSSBlock2_15_ss2d_DtProj:dir2 */
    { 0x00003120, 0x00080500, 0x00280100, 0x00000028, 0x00400100, 0x00000000, 0x008b8140, 0x00880040 },
    /* 282  SCAN         L05_VSSBlock2_16_ss2d_SelectiveScan        16 scan dir2                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+296                     frame        C 256->256 40x40  sh 0,0,0,0  flags 44 misc 00b0  prm 36195+8 L05_VSSBlock2_16_ss2d_SelectiveScan:dir2 */
    { 0x00004440, 0x01000000, 0x00280100, 0x00000028, 0x00200000, 0x01284000, 0x008d6340, 0x00b00008 },
    /* 283  VEC_ADD      L05_VSSBlock2_17_ss2d_CrossMerge           17 accumulate dir2                 in: g_y@WORK+296, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 256->256 40x40  sh 0,0,0,0  flags 72 misc 0548  prm 0+0 */
    { 0x00007212, 0x01000000, 0x00280100, 0x00000028, 0x00400128, 0x00005000, 0x00000050, 0x05480000 },
    /* 284  SETK 3 */
    { 0x00000003, 0x00030000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 285  LOOP GROUP n=200 body=4 */
    { 0x00000001, 0x00c80000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 286  GEMM         L05_VSSBlock2_14_ss2d_XProj                14 XProj dir3                      in: X@X+0                                                        out: g_xp@WORK+256                    frame        C 256->40 40x40  sh 0,0,0,0  flags 30 misc 0090  prm 35178+320 L05_VSSBlock2_14_ss2d_XProj:dir3 */
    { 0x00003020, 0x01000000, 0x00280028, 0x00000028, 0x00200000, 0x01000000, 0x00896a40, 0x00900140 },
    /* 287  GEMM         L05_VSSBlock2_15_ss2d_DtProj               15 DtProj dir3 (+ReLU)             in: g_xp@WORK+256                                                out: g_delta@WORK+0                   frame        C 8->256 40x40  sh 0,0,0,5  flags 31 misc 0088  prm 35817+64 L05_VSSBlock2_15_ss2d_DtProj:dir3 */
    { 0x00003120, 0x00080500, 0x00280100, 0x00000028, 0x00400100, 0x00000000, 0x008be940, 0x00880040 },
    /* 288  SCAN         L05_VSSBlock2_16_ss2d_SelectiveScan        16 scan dir3                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+296                     frame        C 256->256 40x40  sh 0,0,0,0  flags 44 misc 00b0  prm 36332+8 L05_VSSBlock2_16_ss2d_SelectiveScan:dir3 */
    { 0x00004440, 0x01000000, 0x00280100, 0x00000028, 0x00200000, 0x01284000, 0x008dec40, 0x00b00008 },
    /* 289  VEC_ADD      L05_VSSBlock2_17_ss2d_CrossMerge           17 accumulate dir3                 in: g_y@WORK+296, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 256->256 40x40  sh -1,0,0,0  flags 72 misc 0548  prm 0+0 */
    { 0x00ff7212, 0x01000000, 0x00280100, 0x00000028, 0x00400128, 0x00005000, 0x00000050, 0x05480000 },
    /* 290  LOOP TILE n=0 body=0 */
    { 0x00000001, 0x00000000, 0x00000017, 0x00000028, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 291  VEC_RQ       L05_VSSBlock2_17_ss2d_CrossMerge           17' ACC -> int8                    in: ACC@ACC+0(w)                                                 out: t17@WORK+0(rel)                  rows[-1,9)   C 256->256 40x40  sh 1,0,0,0  flags 30 misc 8200  prm 0+0 */
    { 0x00013010, 0x01000000, 0x00280100, 0x09ff0028, 0x00500000, 0x00000000, 0x00000040, 0x82000000 },
    /* 292  VEC_LN       L05_VSSBlock2_18_ss2d_out_norm_LightNorm   18 out_norm                        in: t17@WORK+0(rel)                                              out: t18@WORK+15360(rel)              rows[-1,9)   C 256->256 40x40  sh 0,0,21,18  flags 30 misc a000  prm 36469+0 */
    { 0x00003014, 0x01001215, 0x00280100, 0x09ff0028, 0x00400000, 0x3c000000, 0x008e7540, 0xa0000000 },
    /* 293  GEMM         L05_VSSBlock2_01_proj_Conv2d               01 (recompute)                     in: L05_VSSBlock1.out@A+0                                        out: r01@WORK+0(rel)                  rows[-2,10)  C 128->128 40x40  sh 0,0,0,0  flags 30 misc 8000  prm 30241+512 L05_VSSBlock2_01_proj_Conv2d */
    { 0x00003020, 0x00800000, 0x00280080, 0x0afe0028, 0x00000000, 0x00000000, 0x00762140, 0x80000200 },
    /* 294  VEC_SILU     L05_VSSBlock2_02_proj_SiLU                 02 = r (recompute)                 in: r01@WORK+0(rel)                                              out: r02@WORK+7680(rel)               rows[-2,10)  C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 22273+0 */
    { 0x00003011, 0x00800000, 0x00280080, 0x0afe0028, 0x00400000, 0x1e000000, 0x00570140, 0xa0000000 },
    /* 295  DW           L05_VSSBlock2_03_ls_fc1_DWConv2d           03 (recompute)                     in: r02@WORK+7680(rel)                                           out: r03@WORK+0(rel)                  rows[-2,10)  C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 30773+0 L05_VSSBlock2_03_ls_fc1_DWConv2d */
    { 0x00003030, 0x00800000, 0x00280080, 0x0afe0028, 0x00401e00, 0x00000000, 0x00783540, 0xa0000000 },
    /* 296  GEMM         L05_VSSBlock2_04_ls_fc2_Conv2d             04 (recompute)                     in: r03@WORK+0(rel)                                              out: r04@WORK+30720(rel)              rows[-1,9)   C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 30837+512 L05_VSSBlock2_04_ls_fc2_Conv2d */
    { 0x00003020, 0x00800000, 0x00280080, 0x09ff0028, 0x00400000, 0x78000000, 0x00787540, 0xa0000200 },
    /* 297  VEC_SILU     L05_VSSBlock2_05_ls_SiLU                   05 (recompute)                     in: r04@WORK+30720(rel)                                          out: r05@WORK+0(rel)                  rows[-1,9)   C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 521+0 */
    { 0x00003011, 0x00800000, 0x00280080, 0x09ff0028, 0x00407800, 0x00000000, 0x00020940, 0xa0000000 },
    /* 298  GEMM         L05_VSSBlock2_06_ls_fc3_Conv2d             06 (recompute, X scratch)          in: r05@WORK+0(rel)                                              out: s06@X+0(rel)                     rows[-1,9)   C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 31369+512 L05_VSSBlock2_06_ls_fc3_Conv2d */
    { 0x00003020, 0x00800000, 0x00280080, 0x09ff0028, 0x00400000, 0x00000000, 0x007a8920, 0xa0000200 },
    /* 299  VEC_ADD      L05_VSSBlock2_07_ls_Add                    07 (recompute)                     in: r02@WORK+7680(rel), s06@X+0(rel)                             out: r07@WORK+0(rel)                  rows[-1,9)   C 128->128 40x40  sh -1,0,1,0  flags 70 misc e000  prm 0+0 */
    { 0x00ff7012, 0x00800001, 0x00280080, 0x09ff0028, 0x00401e00, 0x00002000, 0x00000040, 0xe0000000 },
    /* 300  VEC_LN       L05_VSSBlock2_08_norm_LightNorm            08 (recompute)                     in: r07@WORK+0(rel)                                              out: r08@WORK+30720(rel)              rows[-1,9)   C 128->128 40x40  sh 0,0,21,19  flags 30 misc a000  prm 31901+0 */
    { 0x00003014, 0x00801315, 0x00280080, 0x09ff0028, 0x00400000, 0x78000000, 0x007c9d40, 0xa0000000 },
    /* 301  GEMM         L05_VSSBlock2_09_ss2d_in_proj_Conv2d       09 in_proj z half (recompute)      in: r08@WORK+30720(rel)                                          out: r09z@WORK+38400(rel)             rows[-1,9)   C 128->256 40x40  sh 0,0,0,0  flags 30 misc a000  prm 33005+1024 L05_VSSBlock2_09_ss2d_in_proj_Conv2d:z */
    { 0x00003020, 0x00800000, 0x00280100, 0x09ff0028, 0x00407800, 0x96000000, 0x0080ed40, 0xa0000400 },
    /* 302  VEC_SILU     L05_VSSBlock2_10_ss2d_SiLU_z               10 = z (X scratch)                 in: r09z@WORK+38400(rel)                                         out: s10z@X+0(rel)                    rows[-1,9)   C 256->256 40x40  sh 0,0,0,0  flags 30 misc a000  prm 521+0 */
    { 0x00003011, 0x01000000, 0x00280100, 0x09ff0028, 0x00409600, 0x00000000, 0x00020920, 0xa0000000 },
    /* 303  VEC_MUL      L05_VSSBlock2_19_ss2d_Mul                  19 gate -> requant to 20           in: t18@WORK+15360(rel), s10z@X+0(rel)                           out: t19@WORK+30720(rel)              rows[-1,9)   C 256->256 40x40  sh 0,0,4,0  flags 70 misc e000  prm 0+0 */
    { 0x00007013, 0x01000004, 0x00280100, 0x09ff0028, 0x00403c00, 0x78002000, 0x00000040, 0xe0000000 },
    /* 304  GEMM         L05_VSSBlock2_20_ss2d_out_proj_Conv2d      20 out_proj (X scratch)            in: t19@WORK+30720(rel)                                          out: s20@X+0(rel)                     rows[-1,9)   C 256->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 36517+1024 L05_VSSBlock2_20_ss2d_out_proj_Conv2d */
    { 0x00003020, 0x01000000, 0x00280080, 0x09ff0028, 0x00407800, 0x00000000, 0x008ea520, 0xa0000400 },
    /* 305  VEC_ADD      L05_VSSBlock2_21_Add                       21 Add (wide, kept)                in: r02@WORK+7680(rel), s20@X+0(rel)                             out: t21@WORK+15360(rel)(w)           rows[-1,9)   C 128->128 40x40  sh -1,0,0,0  flags 72 misc e000  prm 0+0 */
    { 0x00ff7212, 0x00800000, 0x00280080, 0x09ff0028, 0x00401e00, 0x3c002000, 0x00000040, 0xe0000000 },
    /* 306  VEC_LN       L05_VSSBlock2_22_norm2_LightNorm           22 norm2                           in: t21@WORK+15360(rel)(w)                                       out: t22@WORK+0(rel)                  rows[-1,9)   C 128->128 40x40  sh 1,0,21,19  flags 30 misc a200  prm 37561+0 */
    { 0x00013014, 0x00801315, 0x00280080, 0x09ff0028, 0x00403c00, 0x00000000, 0x0092b940, 0xa2000000 },
    /* 307  GEMM         L05_VSSBlock2_23_mlp_fc1_Conv2d            23 fc1 x half (X scratch)          in: t22@WORK+0(rel)                                              out: s23x@X+0(rel)                    rows[-1,9)   C 128->341 40x40  sh 0,0,0,0  flags 30 misc a000  prm 37601+1376 L05_VSSBlock2_23_mlp_fc1_Conv2d:x */
    { 0x00003020, 0x00800000, 0x00280155, 0x09ff0028, 0x00400000, 0x00000000, 0x0092e120, 0xa0000560 },
    /* 308  GEMM         L05_VSSBlock2_23_mlp_fc1_Conv2d            23 fc1 v half (X scratch)          in: t22@WORK+0(rel)                                              out: s23v@X+20640(rel)                rows[-1,9)   C 128->341 40x40  sh 0,0,0,0  flags 30 misc a000  prm 39031+1376 L05_VSSBlock2_23_mlp_fc1_Conv2d:v */
    { 0x00003020, 0x00800000, 0x00280155, 0x09ff0028, 0x00400000, 0x50a00000, 0x00987720, 0xa0000560 },
    /* 309  DW           L05_VSSBlock2_24_mlp_DWConv2d              24 DW                              in: s23x@X+0(rel)                                                out: t24@WORK+30720(rel)              rows[-1,9)   C 341->341 40x40  sh 0,0,0,0  flags 30 misc a000  prm 40461+0 L05_VSSBlock2_24_mlp_DWConv2d */
    { 0x00003030, 0x01550000, 0x00280155, 0x09ff0028, 0x00200000, 0x78000000, 0x009e0d40, 0xa0000000 },
    /* 310  VEC_ADD      L05_VSSBlock2_26_mlp_SiLU                  25 Add -> 26 SiLU (fused)          in: t24@WORK+30720(rel), s23x@X+0(rel)                           out: t26@WORK+51360(rel)              rows[0,8)    C 341->341 40x40  sh 0,-1,1,0  flags f0 misc e000  prm 521+0 */
    { 0xff00f012, 0x01550001, 0x00280155, 0x08000028, 0x00407800, 0xc8a02000, 0x00020940, 0xe0000000 },
    /* 311  VEC_MUL      L05_VSSBlock2_27_mlp_Mul                   27 Mul -> requant to 28            in: t26@WORK+51360(rel), s23v@X+20640(rel)                       out: t27@WORK+30720(rel)              rows[0,8)    C 341->341 40x40  sh 0,0,5,0  flags 70 misc e000  prm 0+0 */
    { 0x00007013, 0x01550005, 0x00280155, 0x08000028, 0xa040c8a0, 0x78002050, 0x00000040, 0xe0000000 },
    /* 312  GEMM         L05_VSSBlock2_28_mlp_fc2_Conv2d            28 fc2 (X scratch)                 in: t27@WORK+30720(rel)                                          out: s28@X+0(rel)                     rows[0,8)    C 341->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 40633+1376 L05_VSSBlock2_28_mlp_fc2_Conv2d */
    { 0x00003020, 0x01550000, 0x00280080, 0x08000028, 0x00407800, 0x00000000, 0x009eb920, 0xa0000560 },
    /* 313  VEC_ADD      L05_VSSBlock2_29_Add                       29 Add -> block output             in: t21@WORK+15360(rel)(w), s28@X+0(rel)                         out: L05_VSSBlock2.out@B+0            rows[0,8)    C 128->128 40x40  sh 0,-1,1,0  flags 70 misc 6200  prm 0+0 */
    { 0xff007012, 0x00800001, 0x00280080, 0x08000028, 0x00403c00, 0x00002000, 0x00000010, 0x62000000 },
    /* 314  VEC_RQ       L05_VSSBlock2_29_Add                       keep block output in SKIP (S5)     in: L05_VSSBlock2.out@B+0                                        out: S5@SKIP+51200                    frame        C 128->128 40x40  sh 0,0,0,0  flags 30 misc 0000  prm 0+0 */
    { 0x00003010, 0x00800000, 0x00280080, 0x00000028, 0x00100000, 0xc8000000, 0x00000030, 0x00000000 },
    /* 315  GEMM         L06_VisionClueMerge_02_pw_linear_Conv2d    VCM: S2D gather + 1x1              in: L05_VSSBlock2.out@B+0                                        out: vcm_pw@WORK+0                    frame        C 128->256 40x40  sh 0,0,0,0  flags 30 misc 0003  prm 42029+4096 L06_VisionClueMerge_02_pw_linear_Conv2d */
    { 0x00003020, 0x00800000, 0x00280100, 0x00000028, 0x00100000, 0x00000000, 0x00a42d40, 0x00031000 },
    /* 316  VEC_SILU     L06_VisionClueMerge_03_SiLU                VCM SiLU -> layer out              in: vcm_pw@WORK+0                                                out: L06.out@A+0                      frame        C 256->256 20x20  sh 0,0,0,0  flags 30 misc 0000  prm 1508+0 */
    { 0x00003011, 0x01000000, 0x00140100, 0x00000014, 0x00400000, 0x00000000, 0x0005e400, 0x00000000 },
    /* 317  LOOP TILE n=0 body=0 */
    { 0x00000001, 0x00000000, 0x0000000b, 0x00000014, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 318  GEMM         L07_VSSBlock_01_proj_Conv2d                01 proj                            in: L06.out@A+0                                                  out: t01@WORK+0(rel)                  rows[-2,10)  C 256->256 20x20  sh 0,0,0,0  flags 30 misc 8000  prm 46165+2048 L07_VSSBlock_01_proj_Conv2d */
    { 0x00003020, 0x01000000, 0x00140100, 0x0afe0014, 0x00000000, 0x00000000, 0x00b45540, 0x80000800 },
    /* 319  VEC_SILU     L07_VSSBlock_02_proj_SiLU                  02 SiLU                            in: t01@WORK+0(rel)                                              out: t02@WORK+7680(rel)               rows[-2,10)  C 256->256 20x20  sh 0,0,0,0  flags 30 misc a000  prm 48253+0 */
    { 0x00003011, 0x01000000, 0x00140100, 0x0afe0014, 0x00400000, 0x1e000000, 0x00bc7d40, 0xa0000000 },
    /* 320  DW           L07_VSSBlock_03_ls_fc1_DWConv2d            03 DW                              in: t02@WORK+7680(rel)                                           out: t03@WORK+0(rel)                  rows[-2,10)  C 256->256 20x20  sh 0,0,0,0  flags 30 misc a000  prm 48261+0 L07_VSSBlock_03_ls_fc1_DWConv2d */
    { 0x00003030, 0x01000000, 0x00140100, 0x0afe0014, 0x00401e00, 0x00000000, 0x00bc8540, 0xa0000000 },
    /* 321  GEMM         L07_VSSBlock_04_ls_fc2_Conv2d              04                                 in: t03@WORK+0(rel)                                              out: t04@WORK+15360(rel)              rows[-1,9)   C 256->256 20x20  sh 0,0,0,0  flags 30 misc a000  prm 48389+2048 L07_VSSBlock_04_ls_fc2_Conv2d */
    { 0x00003020, 0x01000000, 0x00140100, 0x09ff0014, 0x00400000, 0x3c000000, 0x00bd0540, 0xa0000800 },
    /* 322  VEC_SILU     L07_VSSBlock_05_ls_SiLU                    05 SiLU                            in: t04@WORK+15360(rel)                                          out: t05@WORK+0(rel)                  rows[-1,9)   C 256->256 20x20  sh 0,0,0,0  flags 30 misc a000  prm 521+0 */
    { 0x00003011, 0x01000000, 0x00140100, 0x09ff0014, 0x00403c00, 0x00000000, 0x00020940, 0xa0000000 },
    /* 323  GEMM         L07_VSSBlock_06_ls_fc3_Conv2d              06 (scratch)                       in: t05@WORK+0(rel)                                              out: s06@B+0(rel)                     rows[-1,9)   C 256->256 20x20  sh 0,0,0,0  flags 30 misc a000  prm 50477+2048 L07_VSSBlock_06_ls_fc3_Conv2d */
    { 0x00003020, 0x01000000, 0x00140100, 0x09ff0014, 0x00400000, 0x00000000, 0x00c52d10, 0xa0000800 },
    /* 324  VEC_ADD      L07_VSSBlock_07_ls_Add                     07 Add -> requant to 08            in: t02@WORK+7680(rel), s06@B+0(rel)                             out: t07@WORK+0(rel)                  rows[-1,9)   C 256->256 20x20  sh -1,0,2,0  flags 70 misc e000  prm 0+0 */
    { 0x00ff7012, 0x01000002, 0x00140100, 0x09ff0014, 0x00401e00, 0x00001000, 0x00000040, 0xe0000000 },
    /* 325  VEC_LN       L07_VSSBlock_08_norm_LightNorm             08 LightNorm                       in: t07@WORK+0(rel)                                              out: t08@WORK+7680(rel)               rows[-1,9)   C 256->256 20x20  sh 0,0,21,19  flags 30 misc a000  prm 52565+0 */
    { 0x00003014, 0x01001315, 0x00140100, 0x09ff0014, 0x00400000, 0x1e000000, 0x00cd5540, 0xa0000000 },
    /* 326  GEMM         L07_VSSBlock_09_ss2d_in_proj_Conv2d        09 in_proj x half                  in: t08@WORK+7680(rel)                                           out: t09x@WORK+15360(rel)             rows[-1,9)   C 256->512 20x20  sh 0,0,0,0  flags 30 misc a000  prm 52613+4096 L07_VSSBlock_09_ss2d_in_proj_Conv2d:x */
    { 0x00003020, 0x01000000, 0x00140200, 0x09ff0014, 0x00401e00, 0x3c000000, 0x00cd8540, 0xa0001000 },
    /* 327  DW           L07_VSSBlock_11_ss2d_DWConv2d              11 DW                              in: t09x@WORK+15360(rel)                                         out: t11@WORK+0(rel)                  rows[-1,9)   C 512->512 20x20  sh 0,0,0,0  flags 30 misc a000  prm 60965+0 L07_VSSBlock_11_ss2d_DWConv2d */
    { 0x00003030, 0x02000000, 0x00140200, 0x09ff0014, 0x00403c00, 0x00000000, 0x00ee2540, 0xa0000000 },
    /* 328  VEC_SILU     L07_VSSBlock_12_ss2d_SiLU_x                12 SiLU -> X                       in: t11@WORK+0(rel)                                              out: X@X+0                            rows[0,8)    C 512->512 20x20  sh 0,0,0,0  flags 30 misc 2000  prm 521+0 */
    { 0x00003011, 0x02000000, 0x00140200, 0x08000014, 0x00400000, 0x00000000, 0x00020920, 0x20000000 },
    /* 329  SETK 0 */
    { 0x00000003, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 330  LOOP GROUP n=50 body=4 */
    { 0x00000001, 0x00320000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 331  GEMM         L07_VSSBlock_14_ss2d_XProj                 14 XProj dir0                      in: X@X+0                                                        out: g_xp@WORK+512                    frame        C 512->48 20x20  sh 0,0,0,0  flags 30 misc 0090  prm 61221+768 L07_VSSBlock_14_ss2d_XProj:dir0 */
    { 0x00003020, 0x02000000, 0x00140030, 0x00000014, 0x00200000, 0x02000000, 0x00ef2540, 0x00900300 },
    /* 332  GEMM         L07_VSSBlock_15_ss2d_DtProj                15 DtProj dir0 (+ReLU)             in: g_xp@WORK+512                                                out: g_delta@WORK+0                   frame        C 16->512 20x20  sh 0,0,0,6  flags 31 misc 0088  prm 64325+256 L07_VSSBlock_15_ss2d_DtProj:dir0 */
    { 0x00003120, 0x00100600, 0x00140200, 0x00000014, 0x00400200, 0x00000000, 0x00fb4540, 0x00880100 },
    /* 333  SCAN         L07_VSSBlock_16_ss2d_SelectiveScan         16 scan dir0                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+560                     frame        C 512->512 20x20  sh 0,0,0,0  flags 44 misc 00b0  prm 65669+16 L07_VSSBlock_16_ss2d_SelectiveScan:dir0 */
    { 0x00004440, 0x02000000, 0x00140200, 0x00000014, 0x00200000, 0x02304000, 0x01008540, 0x00b00010 },
    /* 334  VEC_ADD      L07_VSSBlock_17_ss2d_CrossMerge            17 accumulate dir0                 in: g_y@WORK+560, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 512->512 20x20  sh 0,0,0,0  flags 7a misc 0548  prm 0+0 */
    { 0x00007a12, 0x02000000, 0x00140200, 0x00000014, 0x00400230, 0x00005000, 0x00000050, 0x05480000 },
    /* 335  SETK 1 */
    { 0x00000003, 0x00010000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 336  LOOP GROUP n=50 body=4 */
    { 0x00000001, 0x00320000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 337  GEMM         L07_VSSBlock_14_ss2d_XProj                 14 XProj dir1                      in: X@X+0                                                        out: g_xp@WORK+512                    frame        C 512->48 20x20  sh 0,0,0,0  flags 30 misc 0090  prm 61997+768 L07_VSSBlock_14_ss2d_XProj:dir1 */
    { 0x00003020, 0x02000000, 0x00140030, 0x00000014, 0x00200000, 0x02000000, 0x00f22d40, 0x00900300 },
    /* 338  GEMM         L07_VSSBlock_15_ss2d_DtProj                15 DtProj dir1 (+ReLU)             in: g_xp@WORK+512                                                out: g_delta@WORK+0                   frame        C 16->512 20x20  sh 0,0,0,6  flags 31 misc 0088  prm 64661+256 L07_VSSBlock_15_ss2d_DtProj:dir1 */
    { 0x00003120, 0x00100600, 0x00140200, 0x00000014, 0x00400200, 0x00000000, 0x00fc9540, 0x00880100 },
    /* 339  SCAN         L07_VSSBlock_16_ss2d_SelectiveScan         16 scan dir1                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+560                     frame        C 512->512 20x20  sh 0,0,0,0  flags 44 misc 00b0  prm 65942+16 L07_VSSBlock_16_ss2d_SelectiveScan:dir1 */
    { 0x00004440, 0x02000000, 0x00140200, 0x00000014, 0x00200000, 0x02304000, 0x01019640, 0x00b00010 },
    /* 340  VEC_ADD      L07_VSSBlock_17_ss2d_CrossMerge            17 accumulate dir1                 in: g_y@WORK+560, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 512->512 20x20  sh 0,0,0,0  flags 72 misc 0548  prm 0+0 */
    { 0x00007212, 0x02000000, 0x00140200, 0x00000014, 0x00400230, 0x00005000, 0x00000050, 0x05480000 },
    /* 341  SETK 2 */
    { 0x00000003, 0x00020000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 342  LOOP GROUP n=50 body=4 */
    { 0x00000001, 0x00320000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 343  GEMM         L07_VSSBlock_14_ss2d_XProj                 14 XProj dir2                      in: X@X+0                                                        out: g_xp@WORK+512                    frame        C 512->48 20x20  sh 0,0,0,0  flags 30 misc 0090  prm 62773+768 L07_VSSBlock_14_ss2d_XProj:dir2 */
    { 0x00003020, 0x02000000, 0x00140030, 0x00000014, 0x00200000, 0x02000000, 0x00f53540, 0x00900300 },
    /* 344  GEMM         L07_VSSBlock_15_ss2d_DtProj                15 DtProj dir2 (+ReLU)             in: g_xp@WORK+512                                                out: g_delta@WORK+0                   frame        C 16->512 20x20  sh 0,0,0,6  flags 31 misc 0088  prm 64997+256 L07_VSSBlock_15_ss2d_DtProj:dir2 */
    { 0x00003120, 0x00100600, 0x00140200, 0x00000014, 0x00400200, 0x00000000, 0x00fde540, 0x00880100 },
    /* 345  SCAN         L07_VSSBlock_16_ss2d_SelectiveScan         16 scan dir2                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+560                     frame        C 512->512 20x20  sh 0,0,0,0  flags 44 misc 00b0  prm 66215+16 L07_VSSBlock_16_ss2d_SelectiveScan:dir2 */
    { 0x00004440, 0x02000000, 0x00140200, 0x00000014, 0x00200000, 0x02304000, 0x0102a740, 0x00b00010 },
    /* 346  VEC_ADD      L07_VSSBlock_17_ss2d_CrossMerge            17 accumulate dir2                 in: g_y@WORK+560, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 512->512 20x20  sh 0,0,0,0  flags 72 misc 0548  prm 0+0 */
    { 0x00007212, 0x02000000, 0x00140200, 0x00000014, 0x00400230, 0x00005000, 0x00000050, 0x05480000 },
    /* 347  SETK 3 */
    { 0x00000003, 0x00030000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 348  LOOP GROUP n=50 body=4 */
    { 0x00000001, 0x00320000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 349  GEMM         L07_VSSBlock_14_ss2d_XProj                 14 XProj dir3                      in: X@X+0                                                        out: g_xp@WORK+512                    frame        C 512->48 20x20  sh 0,0,0,0  flags 30 misc 0090  prm 63549+768 L07_VSSBlock_14_ss2d_XProj:dir3 */
    { 0x00003020, 0x02000000, 0x00140030, 0x00000014, 0x00200000, 0x02000000, 0x00f83d40, 0x00900300 },
    /* 350  GEMM         L07_VSSBlock_15_ss2d_DtProj                15 DtProj dir3 (+ReLU)             in: g_xp@WORK+512                                                out: g_delta@WORK+0                   frame        C 16->512 20x20  sh 0,0,0,6  flags 31 misc 0088  prm 65333+256 L07_VSSBlock_15_ss2d_DtProj:dir3 */
    { 0x00003120, 0x00100600, 0x00140200, 0x00000014, 0x00400200, 0x00000000, 0x00ff3540, 0x00880100 },
    /* 351  SCAN         L07_VSSBlock_16_ss2d_SelectiveScan         16 scan dir3                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+560                     frame        C 512->512 20x20  sh 0,0,0,0  flags 44 misc 00b0  prm 66488+16 L07_VSSBlock_16_ss2d_SelectiveScan:dir3 */
    { 0x00004440, 0x02000000, 0x00140200, 0x00000014, 0x00200000, 0x02304000, 0x0103b840, 0x00b00010 },
    /* 352  VEC_ADD      L07_VSSBlock_17_ss2d_CrossMerge            17 accumulate dir3                 in: g_y@WORK+560, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 512->512 20x20  sh 0,0,0,0  flags 72 misc 0548  prm 0+0 */
    { 0x00007212, 0x02000000, 0x00140200, 0x00000014, 0x00400230, 0x00005000, 0x00000050, 0x05480000 },
    /* 353  LOOP TILE n=0 body=0 */
    { 0x00000001, 0x00000000, 0x00000017, 0x00000014, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 354  VEC_RQ       L07_VSSBlock_17_ss2d_CrossMerge            17' ACC -> int8                    in: ACC@ACC+0(w)                                                 out: t17@WORK+0(rel)                  rows[-1,9)   C 512->512 20x20  sh 1,0,0,0  flags 30 misc 8200  prm 0+0 */
    { 0x00013010, 0x02000000, 0x00140200, 0x09ff0014, 0x00500000, 0x00000000, 0x00000040, 0x82000000 },
    /* 355  VEC_LN       L07_VSSBlock_18_ss2d_out_norm_LightNorm    18 out_norm                        in: t17@WORK+0(rel)                                              out: t18@WORK+15360(rel)              rows[-1,9)   C 512->512 20x20  sh 0,0,21,18  flags 30 misc a000  prm 66761+0 */
    { 0x00003014, 0x02001215, 0x00140200, 0x09ff0014, 0x00400000, 0x3c000000, 0x0104c940, 0xa0000000 },
    /* 356  GEMM         L07_VSSBlock_01_proj_Conv2d                01 (recompute)                     in: L06.out@A+0                                                  out: r01@WORK+0(rel)                  rows[-2,10)  C 256->256 20x20  sh 0,0,0,0  flags 30 misc 8000  prm 46165+2048 L07_VSSBlock_01_proj_Conv2d */
    { 0x00003020, 0x01000000, 0x00140100, 0x0afe0014, 0x00000000, 0x00000000, 0x00b45540, 0x80000800 },
    /* 357  VEC_SILU     L07_VSSBlock_02_proj_SiLU                  02 = r (recompute)                 in: r01@WORK+0(rel)                                              out: r02@WORK+7680(rel)               rows[-2,10)  C 256->256 20x20  sh 0,0,0,0  flags 30 misc a000  prm 48253+0 */
    { 0x00003011, 0x01000000, 0x00140100, 0x0afe0014, 0x00400000, 0x1e000000, 0x00bc7d40, 0xa0000000 },
    /* 358  DW           L07_VSSBlock_03_ls_fc1_DWConv2d            03 (recompute)                     in: r02@WORK+7680(rel)                                           out: r03@WORK+0(rel)                  rows[-2,10)  C 256->256 20x20  sh 0,0,0,0  flags 30 misc a000  prm 48261+0 L07_VSSBlock_03_ls_fc1_DWConv2d */
    { 0x00003030, 0x01000000, 0x00140100, 0x0afe0014, 0x00401e00, 0x00000000, 0x00bc8540, 0xa0000000 },
    /* 359  GEMM         L07_VSSBlock_04_ls_fc2_Conv2d              04 (recompute)                     in: r03@WORK+0(rel)                                              out: r04@WORK+30720(rel)              rows[-1,9)   C 256->256 20x20  sh 0,0,0,0  flags 30 misc a000  prm 48389+2048 L07_VSSBlock_04_ls_fc2_Conv2d */
    { 0x00003020, 0x01000000, 0x00140100, 0x09ff0014, 0x00400000, 0x78000000, 0x00bd0540, 0xa0000800 },
    /* 360  VEC_SILU     L07_VSSBlock_05_ls_SiLU                    05 (recompute)                     in: r04@WORK+30720(rel)                                          out: r05@WORK+0(rel)                  rows[-1,9)   C 256->256 20x20  sh 0,0,0,0  flags 30 misc a000  prm 521+0 */
    { 0x00003011, 0x01000000, 0x00140100, 0x09ff0014, 0x00407800, 0x00000000, 0x00020940, 0xa0000000 },
    /* 361  GEMM         L07_VSSBlock_06_ls_fc3_Conv2d              06 (recompute, X scratch)          in: r05@WORK+0(rel)                                              out: s06@X+0(rel)                     rows[-1,9)   C 256->256 20x20  sh 0,0,0,0  flags 30 misc a000  prm 50477+2048 L07_VSSBlock_06_ls_fc3_Conv2d */
    { 0x00003020, 0x01000000, 0x00140100, 0x09ff0014, 0x00400000, 0x00000000, 0x00c52d20, 0xa0000800 },
    /* 362  VEC_ADD      L07_VSSBlock_07_ls_Add                     07 (recompute)                     in: r02@WORK+7680(rel), s06@X+0(rel)                             out: r07@WORK+0(rel)                  rows[-1,9)   C 256->256 20x20  sh -1,0,2,0  flags 70 misc e000  prm 0+0 */
    { 0x00ff7012, 0x01000002, 0x00140100, 0x09ff0014, 0x00401e00, 0x00002000, 0x00000040, 0xe0000000 },
    /* 363  VEC_LN       L07_VSSBlock_08_norm_LightNorm             08 (recompute)                     in: r07@WORK+0(rel)                                              out: r08@WORK+30720(rel)              rows[-1,9)   C 256->256 20x20  sh 0,0,21,19  flags 30 misc a000  prm 52565+0 */
    { 0x00003014, 0x01001315, 0x00140100, 0x09ff0014, 0x00400000, 0x78000000, 0x00cd5540, 0xa0000000 },
    /* 364  GEMM         L07_VSSBlock_09_ss2d_in_proj_Conv2d        09 in_proj z half (recompute)      in: r08@WORK+30720(rel)                                          out: r09z@WORK+38400(rel)             rows[-1,9)   C 256->512 20x20  sh 0,0,0,0  flags 30 misc a000  prm 56789+4096 L07_VSSBlock_09_ss2d_in_proj_Conv2d:z */
    { 0x00003020, 0x01000000, 0x00140200, 0x09ff0014, 0x00407800, 0x96000000, 0x00ddd540, 0xa0001000 },
    /* 365  VEC_SILU     L07_VSSBlock_10_ss2d_SiLU_z                10 = z (X scratch)                 in: r09z@WORK+38400(rel)                                         out: s10z@X+0(rel)                    rows[-1,9)   C 512->512 20x20  sh 0,0,0,0  flags 30 misc a000  prm 521+0 */
    { 0x00003011, 0x02000000, 0x00140200, 0x09ff0014, 0x00409600, 0x00000000, 0x00020920, 0xa0000000 },
    /* 366  VEC_MUL      L07_VSSBlock_19_ss2d_Mul                   19 gate -> requant to 20           in: t18@WORK+15360(rel), s10z@X+0(rel)                           out: t19@WORK+30720(rel)              rows[-1,9)   C 512->512 20x20  sh 0,0,4,0  flags 70 misc e000  prm 0+0 */
    { 0x00007013, 0x02000004, 0x00140200, 0x09ff0014, 0x00403c00, 0x78002000, 0x00000040, 0xe0000000 },
    /* 367  GEMM         L07_VSSBlock_20_ss2d_out_proj_Conv2d       20 out_proj (X scratch)            in: t19@WORK+30720(rel)                                          out: s20@X+0(rel)                     rows[-1,9)   C 512->256 20x20  sh 0,0,0,0  flags 30 misc a000  prm 66825+4096 L07_VSSBlock_20_ss2d_out_proj_Conv2d */
    { 0x00003020, 0x02000000, 0x00140100, 0x09ff0014, 0x00407800, 0x00000000, 0x01050920, 0xa0001000 },
    /* 368  VEC_ADD      L07_VSSBlock_21_Add                        21 Add (wide, kept)                in: r02@WORK+7680(rel), s20@X+0(rel)                             out: t21@WORK+15360(rel)(w)           rows[-1,9)   C 256->256 20x20  sh -1,0,0,0  flags 72 misc e000  prm 0+0 */
    { 0x00ff7212, 0x01000000, 0x00140100, 0x09ff0014, 0x00401e00, 0x3c002000, 0x00000040, 0xe0000000 },
    /* 369  VEC_LN       L07_VSSBlock_22_norm2_LightNorm            22 norm2                           in: t21@WORK+15360(rel)(w)                                       out: t22@WORK+0(rel)                  rows[-1,9)   C 256->256 20x20  sh 2,0,22,19  flags 30 misc a200  prm 70961+0 */
    { 0x00023014, 0x01001316, 0x00140100, 0x09ff0014, 0x00403c00, 0x00000000, 0x01153140, 0xa2000000 },
    /* 370  GEMM         L07_VSSBlock_23_mlp_fc1_Conv2d             23 fc1 x half (X scratch)          in: t22@WORK+0(rel)                                              out: s23x@X+0(rel)                    rows[-1,9)   C 256->682 20x20  sh 0,0,0,0  flags 30 misc a000  prm 71009+5472 L07_VSSBlock_23_mlp_fc1_Conv2d:x */
    { 0x00003020, 0x01000000, 0x001402aa, 0x09ff0014, 0x00400000, 0x00000000, 0x01156120, 0xa0001560 },
    /* 371  GEMM         L07_VSSBlock_23_mlp_fc1_Conv2d             23 fc1 v half (X scratch)          in: t22@WORK+0(rel)                                              out: s23v@X+20640(rel)                rows[-1,9)   C 256->682 20x20  sh 0,0,0,0  flags 30 misc a000  prm 76589+5472 L07_VSSBlock_23_mlp_fc1_Conv2d:v */
    { 0x00003020, 0x01000000, 0x001402aa, 0x09ff0014, 0x00400000, 0x50a00000, 0x012b2d20, 0xa0001560 },
    /* 372  DW           L07_VSSBlock_24_mlp_DWConv2d               24 DW                              in: s23x@X+0(rel)                                                out: t24@WORK+30720(rel)              rows[-1,9)   C 682->682 20x20  sh 0,0,0,0  flags 30 misc a000  prm 82169+0 L07_VSSBlock_24_mlp_DWConv2d */
    { 0x00003030, 0x02aa0000, 0x001402aa, 0x09ff0014, 0x00200000, 0x78000000, 0x0140f940, 0xa0000000 },
    /* 373  VEC_ADD      L07_VSSBlock_26_mlp_SiLU                   25 Add -> 26 SiLU (fused)          in: t24@WORK+30720(rel), s23x@X+0(rel)                           out: t26@WORK+51360(rel)              rows[0,8)    C 682->682 20x20  sh 0,-1,1,0  flags f0 misc e000  prm 521+0 */
    { 0xff00f012, 0x02aa0001, 0x001402aa, 0x08000014, 0x00407800, 0xc8a02000, 0x00020940, 0xe0000000 },
    /* 374  VEC_MUL      L07_VSSBlock_27_mlp_Mul                    27 Mul -> requant to 28            in: t26@WORK+51360(rel), s23v@X+20640(rel)                       out: t27@WORK+30720(rel)              rows[0,8)    C 682->682 20x20  sh 0,0,5,0  flags 70 misc e000  prm 0+0 */
    { 0x00007013, 0x02aa0005, 0x001402aa, 0x08000014, 0xa040c8a0, 0x78002050, 0x00000040, 0xe0000000 },
    /* 375  GEMM         L07_VSSBlock_28_mlp_fc2_Conv2d             28 fc2 (X scratch)                 in: t27@WORK+30720(rel)                                          out: s28@X+0(rel)                     rows[0,8)    C 682->256 20x20  sh 0,0,0,0  flags 30 misc a000  prm 82513+5504 L07_VSSBlock_28_mlp_fc2_Conv2d */
    { 0x00003020, 0x02aa0000, 0x00140100, 0x08000014, 0x00407800, 0x00000000, 0x01425120, 0xa0001580 },
    /* 376  VEC_ADD      L07_VSSBlock_29_Add                        29 Add -> block output             in: t21@WORK+15360(rel)(w), s28@X+0(rel)                         out: L07_VSSBlock.out@B+0             rows[0,8)    C 256->256 20x20  sh 0,0,2,0  flags 70 misc 6200  prm 0+0 */
    { 0x00007012, 0x01000002, 0x00140100, 0x08000014, 0x00403c00, 0x00002000, 0x00000010, 0x62000000 },
    /* 377  GEMM         L08_SPPF_01_cv1_Conv2d                     SPPF cv1                           in: L07_VSSBlock.out@B+0                                         out: cv1@WORK+0                       frame        C 256->128 20x20  sh 0,0,0,0  flags 30 misc 0000  prm 88057+1024 L08_SPPF_01_cv1_Conv2d */
    { 0x00003020, 0x01000000, 0x00140080, 0x00000014, 0x00100000, 0x00000000, 0x0157f940, 0x00000400 },
    /* 378  VEC_SILU     L08_SPPF_02_cv1_SiLU                       SPPF cv1 SiLU                      in: cv1@WORK+0                                                   out: cv1s@WORK+6400                   frame        C 128->128 20x20  sh 0,0,0,0  flags 30 misc 0000  prm 1508+0 */
    { 0x00003011, 0x00800000, 0x00140080, 0x00000014, 0x00400000, 0x19000000, 0x0005e440, 0x00000000 },
    /* 379  VEC_MAXPOOL  L08_SPPF_03_MaxPool2d_1                    SPPF MaxPool 1 (X)                 in: cv1s@WORK+6400                                               out: mp1@X+6400                       frame        C 128->128 20x20  sh 0,0,0,0  flags 30 misc 0000  prm 0+0 */
    { 0x00003015, 0x00800000, 0x00140080, 0x00000014, 0x00401900, 0x19000000, 0x00000020, 0x00000000 },
    /* 380  VEC_MAXPOOL  L08_SPPF_04_MaxPool2d_2                    SPPF MaxPool 2 (X)                 in: mp1@X+6400                                                   out: mp2@X+12800                      frame        C 128->128 20x20  sh 0,0,0,0  flags 30 misc 0000  prm 0+0 */
    { 0x00003015, 0x00800000, 0x00140080, 0x00000014, 0x00201900, 0x32000000, 0x00000020, 0x00000000 },
    /* 381  VEC_MAXPOOL  L08_SPPF_05_MaxPool2d_3                    SPPF MaxPool 3 (X)                 in: mp2@X+12800                                                  out: mp3@X+19200                      frame        C 128->128 20x20  sh 0,0,0,0  flags 30 misc 0000  prm 0+0 */
    { 0x00003015, 0x00800000, 0x00140080, 0x00000014, 0x00203200, 0x4b000000, 0x00000020, 0x00000000 },
    /* 382  VEC_RQ       L08_SPPF_06_Concat                         SPPF concat part 0 -> channels [0, 128) in: cv1s@WORK+6400                                               out: cat@WORK+12800                   frame        C 128->512 20x20  sh 0,0,0,0  flags 30 misc 0000  prm 0+0 */
    { 0x00003010, 0x00800000, 0x00140200, 0x00000014, 0x00401900, 0x32000000, 0x00000040, 0x00000000 },
    /* 383  VEC_RQ       L08_SPPF_06_Concat                         SPPF concat part 1 -> channels [128, 256) in: mp1@X+6400                                                   out: cat@WORK+12816                   frame        C 128->512 20x20  sh 0,0,0,0  flags 30 misc 0000  prm 0+0 */
    { 0x00003010, 0x00800000, 0x00140200, 0x00000014, 0x00201900, 0x32100000, 0x00000040, 0x00000000 },
    /* 384  VEC_RQ       L08_SPPF_06_Concat                         SPPF concat part 2 -> channels [256, 384) in: mp2@X+12800                                                  out: cat@WORK+12832                   frame        C 128->512 20x20  sh 0,0,0,0  flags 30 misc 0000  prm 0+0 */
    { 0x00003010, 0x00800000, 0x00140200, 0x00000014, 0x00203200, 0x32200000, 0x00000040, 0x00000000 },
    /* 385  VEC_RQ       L08_SPPF_06_Concat                         SPPF concat part 3 -> channels [384, 512) in: mp3@X+19200                                                  out: cat@WORK+12848                   frame        C 128->512 20x20  sh 0,0,0,0  flags 30 misc 0000  prm 0+0 */
    { 0x00003010, 0x00800000, 0x00140200, 0x00000014, 0x00204b00, 0x32300000, 0x00000040, 0x00000000 },
    /* 386  GEMM         L08_SPPF_07_cv2_Conv2d                     SPPF cv2                           in: cat@WORK+12800                                               out: cv2@WORK+38400                   frame        C 512->256 20x20  sh 0,0,0,0  flags 30 misc 0000  prm 89101+4096 L08_SPPF_07_cv2_Conv2d */
    { 0x00003020, 0x02000000, 0x00140100, 0x00000014, 0x00403200, 0x96000000, 0x015c0d40, 0x00001000 },
    /* 387  VEC_SILU     L08_SPPF_08_cv2_SiLU                       SPPF cv2 SiLU -> layer out         in: cv2@WORK+38400                                               out: L08.out@A+0                      frame        C 256->256 20x20  sh 0,0,0,0  flags 30 misc 0000  prm 93237+0 */
    { 0x00003011, 0x01000000, 0x00140100, 0x00000014, 0x00409600, 0x00000000, 0x016c3500, 0x00000000 },
    /* 388  VEC_RQ       L08_SPPF_08_cv2_SiLU                       keep SPPF output in SKIP (S8)      in: L08.out@A+0                                                  out: S8@SKIP+76800                    frame        C 256->256 20x20  sh 0,0,0,0  flags 30 misc 0000  prm 0+0 */
    { 0x00003010, 0x01000000, 0x00140100, 0x00000014, 0x00000000, 0x2c000000, 0x00000031, 0x00000000 },
    /* 389  LOOP TILE n=0 body=0 */
    { 0x00000001, 0x00000000, 0x0000000b, 0x00000028, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 390  GEMM         L11_XSSBlock_01_in_proj_Conv2d             01 proj                            in: L08.out@A+0, S5@SKIP+51200                                   out: t01@WORK+0(rel)                  rows[-2,10)  C 256->128 40x40  sh 0,1,0,0  flags 70 misc 8800  prm 93245+128 L11_XSSBlock_01_in_proj_Conv2d */
    { 0x01007020, 0x01000000, 0x00280080, 0x0afe0028, 0x00000000, 0x000030c8, 0x016c3d40, 0x88000080 },
    /* 391  VEC_SILU     L11_XSSBlock_02_in_proj_SiLU               02 SiLU                            in: t01@WORK+0(rel)                                              out: t02@WORK+7680(rel)               rows[-2,10)  C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 2013+0 */
    { 0x00003011, 0x00800000, 0x00280080, 0x0afe0028, 0x00400000, 0x1e000000, 0x0007dd40, 0xa0000000 },
    /* 392  DW           L11_XSSBlock_03_ls_fc1_DWConv2d            03 DW                              in: t02@WORK+7680(rel)                                           out: t03@WORK+0(rel)                  rows[-2,10)  C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 94801+0 L11_XSSBlock_03_ls_fc1_DWConv2d */
    { 0x00003030, 0x00800000, 0x00280080, 0x0afe0028, 0x00401e00, 0x00000000, 0x01725140, 0xa0000000 },
    /* 393  GEMM         L11_XSSBlock_04_ls_fc2_Conv2d              04                                 in: t03@WORK+0(rel)                                              out: t04@WORK+15360(rel)              rows[-1,9)   C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 94865+512 L11_XSSBlock_04_ls_fc2_Conv2d */
    { 0x00003020, 0x00800000, 0x00280080, 0x09ff0028, 0x00400000, 0x3c000000, 0x01729140, 0xa0000200 },
    /* 394  VEC_SILU     L11_XSSBlock_05_ls_SiLU                    05 SiLU                            in: t04@WORK+15360(rel)                                          out: t05@WORK+0(rel)                  rows[-1,9)   C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 521+0 */
    { 0x00003011, 0x00800000, 0x00280080, 0x09ff0028, 0x00403c00, 0x00000000, 0x00020940, 0xa0000000 },
    /* 395  GEMM         L11_XSSBlock_06_ls_fc3_Conv2d              06 (scratch)                       in: t05@WORK+0(rel)                                              out: s06@B+0(rel)                     rows[-1,9)   C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 95397+512 L11_XSSBlock_06_ls_fc3_Conv2d */
    { 0x00003020, 0x00800000, 0x00280080, 0x09ff0028, 0x00400000, 0x00000000, 0x0174a510, 0xa0000200 },
    /* 396  VEC_ADD      L11_XSSBlock_07_ls_Add                     07 Add -> requant to 08            in: t02@WORK+7680(rel), s06@B+0(rel)                             out: t07@WORK+0(rel)                  rows[-1,9)   C 128->128 40x40  sh -1,0,1,0  flags 70 misc e000  prm 0+0 */
    { 0x00ff7012, 0x00800001, 0x00280080, 0x09ff0028, 0x00401e00, 0x00001000, 0x00000040, 0xe0000000 },
    /* 397  VEC_LN       L11_XSSBlock_08_norm_LightNorm             08 LightNorm                       in: t07@WORK+0(rel)                                              out: t08@WORK+7680(rel)               rows[-1,9)   C 128->128 40x40  sh 0,0,21,20  flags 30 misc a000  prm 95929+0 */
    { 0x00003014, 0x00801415, 0x00280080, 0x09ff0028, 0x00400000, 0x1e000000, 0x0176b940, 0xa0000000 },
    /* 398  GEMM         L11_XSSBlock_09_ss2d_in_proj_Conv2d        09 in_proj x half                  in: t08@WORK+7680(rel)                                           out: t09x@WORK+15360(rel)             rows[-1,9)   C 128->256 40x40  sh 0,0,0,0  flags 30 misc a000  prm 95969+1024 L11_XSSBlock_09_ss2d_in_proj_Conv2d:x */
    { 0x00003020, 0x00800000, 0x00280100, 0x09ff0028, 0x00401e00, 0x3c000000, 0x0176e140, 0xa0000400 },
    /* 399  DW           L11_XSSBlock_11_ss2d_DWConv2d              11 DW                              in: t09x@WORK+15360(rel)                                         out: t11@WORK+0(rel)                  rows[-1,9)   C 256->256 40x40  sh 0,0,0,0  flags 30 misc a000  prm 98097+0 L11_XSSBlock_11_ss2d_DWConv2d */
    { 0x00003030, 0x01000000, 0x00280100, 0x09ff0028, 0x00403c00, 0x00000000, 0x017f3140, 0xa0000000 },
    /* 400  VEC_SILU     L11_XSSBlock_12_ss2d_SiLU_x                12 SiLU -> X                       in: t11@WORK+0(rel)                                              out: X@X+0                            rows[0,8)    C 256->256 40x40  sh 0,0,0,0  flags 30 misc 2000  prm 22273+0 */
    { 0x00003011, 0x01000000, 0x00280100, 0x08000028, 0x00400000, 0x00000000, 0x00570120, 0x20000000 },
    /* 401  SETK 0 */
    { 0x00000003, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 402  LOOP GROUP n=200 body=4 */
    { 0x00000001, 0x00c80000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 403  GEMM         L11_XSSBlock_14_ss2d_XProj                 14 XProj dir0                      in: X@X+0                                                        out: g_xp@WORK+256                    frame        C 256->40 40x40  sh 0,0,0,0  flags 30 misc 0090  prm 98225+320 L11_XSSBlock_14_ss2d_XProj:dir0 */
    { 0x00003020, 0x01000000, 0x00280028, 0x00000028, 0x00200000, 0x01000000, 0x017fb140, 0x00900140 },
    /* 404  GEMM         L11_XSSBlock_15_ss2d_DtProj                15 DtProj dir0 (+ReLU)             in: g_xp@WORK+256                                                out: g_delta@WORK+0                   frame        C 8->256 40x40  sh 0,0,0,5  flags 31 misc 0088  prm 99533+64 L11_XSSBlock_15_ss2d_DtProj:dir0 */
    { 0x00003120, 0x00080500, 0x00280100, 0x00000028, 0x00400100, 0x00000000, 0x0184cd40, 0x00880040 },
    /* 405  SCAN         L11_XSSBlock_16_ss2d_SelectiveScan         16 scan dir0                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+296                     frame        C 256->256 40x40  sh 0,0,0,0  flags 44 misc 00b0  prm 99949+8 L11_XSSBlock_16_ss2d_SelectiveScan:dir0 */
    { 0x00004440, 0x01000000, 0x00280100, 0x00000028, 0x00200000, 0x01284000, 0x01866d40, 0x00b00008 },
    /* 406  VEC_ADD      L11_XSSBlock_17_ss2d_CrossMerge            17 accumulate dir0                 in: g_y@WORK+296, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 256->256 40x40  sh 0,0,0,0  flags 7a misc 0548  prm 0+0 */
    { 0x00007a12, 0x01000000, 0x00280100, 0x00000028, 0x00400128, 0x00005000, 0x00000050, 0x05480000 },
    /* 407  SETK 1 */
    { 0x00000003, 0x00010000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 408  LOOP GROUP n=200 body=4 */
    { 0x00000001, 0x00c80000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 409  GEMM         L11_XSSBlock_14_ss2d_XProj                 14 XProj dir1                      in: X@X+0                                                        out: g_xp@WORK+256                    frame        C 256->40 40x40  sh 0,0,0,0  flags 30 misc 0090  prm 98552+320 L11_XSSBlock_14_ss2d_XProj:dir1 */
    { 0x00003020, 0x01000000, 0x00280028, 0x00000028, 0x00200000, 0x01000000, 0x0180f840, 0x00900140 },
    /* 410  GEMM         L11_XSSBlock_15_ss2d_DtProj                15 DtProj dir1 (+ReLU)             in: g_xp@WORK+256                                                out: g_delta@WORK+0                   frame        C 8->256 40x40  sh 0,0,0,5  flags 31 misc 0088  prm 99637+64 L11_XSSBlock_15_ss2d_DtProj:dir1 */
    { 0x00003120, 0x00080500, 0x00280100, 0x00000028, 0x00400100, 0x00000000, 0x01853540, 0x00880040 },
    /* 411  SCAN         L11_XSSBlock_16_ss2d_SelectiveScan         16 scan dir1                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+296                     frame        C 256->256 40x40  sh 0,0,0,0  flags 44 misc 00b0  prm 100086+8 L11_XSSBlock_16_ss2d_SelectiveScan:dir1 */
    { 0x00004440, 0x01000000, 0x00280100, 0x00000028, 0x00200000, 0x01284000, 0x0186f640, 0x00b00008 },
    /* 412  VEC_ADD      L11_XSSBlock_17_ss2d_CrossMerge            17 accumulate dir1                 in: g_y@WORK+296, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 256->256 40x40  sh -1,0,0,0  flags 72 misc 0548  prm 0+0 */
    { 0x00ff7212, 0x01000000, 0x00280100, 0x00000028, 0x00400128, 0x00005000, 0x00000050, 0x05480000 },
    /* 413  SETK 2 */
    { 0x00000003, 0x00020000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 414  LOOP GROUP n=200 body=4 */
    { 0x00000001, 0x00c80000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 415  GEMM         L11_XSSBlock_14_ss2d_XProj                 14 XProj dir2                      in: X@X+0                                                        out: g_xp@WORK+256                    frame        C 256->40 40x40  sh 0,0,0,0  flags 30 misc 0090  prm 98879+320 L11_XSSBlock_14_ss2d_XProj:dir2 */
    { 0x00003020, 0x01000000, 0x00280028, 0x00000028, 0x00200000, 0x01000000, 0x01823f40, 0x00900140 },
    /* 416  GEMM         L11_XSSBlock_15_ss2d_DtProj                15 DtProj dir2 (+ReLU)             in: g_xp@WORK+256                                                out: g_delta@WORK+0                   frame        C 8->256 40x40  sh 0,0,0,5  flags 31 misc 0088  prm 99741+64 L11_XSSBlock_15_ss2d_DtProj:dir2 */
    { 0x00003120, 0x00080500, 0x00280100, 0x00000028, 0x00400100, 0x00000000, 0x01859d40, 0x00880040 },
    /* 417  SCAN         L11_XSSBlock_16_ss2d_SelectiveScan         16 scan dir2                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+296                     frame        C 256->256 40x40  sh 0,0,0,0  flags 44 misc 00b0  prm 100223+8 L11_XSSBlock_16_ss2d_SelectiveScan:dir2 */
    { 0x00004440, 0x01000000, 0x00280100, 0x00000028, 0x00200000, 0x01284000, 0x01877f40, 0x00b00008 },
    /* 418  VEC_ADD      L11_XSSBlock_17_ss2d_CrossMerge            17 accumulate dir2                 in: g_y@WORK+296, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 256->256 40x40  sh -1,0,0,0  flags 72 misc 0548  prm 0+0 */
    { 0x00ff7212, 0x01000000, 0x00280100, 0x00000028, 0x00400128, 0x00005000, 0x00000050, 0x05480000 },
    /* 419  SETK 3 */
    { 0x00000003, 0x00030000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 420  LOOP GROUP n=200 body=4 */
    { 0x00000001, 0x00c80000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 421  GEMM         L11_XSSBlock_14_ss2d_XProj                 14 XProj dir3                      in: X@X+0                                                        out: g_xp@WORK+256                    frame        C 256->40 40x40  sh 0,0,0,0  flags 30 misc 0090  prm 99206+320 L11_XSSBlock_14_ss2d_XProj:dir3 */
    { 0x00003020, 0x01000000, 0x00280028, 0x00000028, 0x00200000, 0x01000000, 0x01838640, 0x00900140 },
    /* 422  GEMM         L11_XSSBlock_15_ss2d_DtProj                15 DtProj dir3 (+ReLU)             in: g_xp@WORK+256                                                out: g_delta@WORK+0                   frame        C 8->256 40x40  sh 0,0,0,5  flags 31 misc 0088  prm 99845+64 L11_XSSBlock_15_ss2d_DtProj:dir3 */
    { 0x00003120, 0x00080500, 0x00280100, 0x00000028, 0x00400100, 0x00000000, 0x01860540, 0x00880040 },
    /* 423  SCAN         L11_XSSBlock_16_ss2d_SelectiveScan         16 scan dir3                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+296                     frame        C 256->256 40x40  sh 0,0,0,0  flags 44 misc 00b0  prm 100360+8 L11_XSSBlock_16_ss2d_SelectiveScan:dir3 */
    { 0x00004440, 0x01000000, 0x00280100, 0x00000028, 0x00200000, 0x01284000, 0x01880840, 0x00b00008 },
    /* 424  VEC_ADD      L11_XSSBlock_17_ss2d_CrossMerge            17 accumulate dir3                 in: g_y@WORK+296, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 256->256 40x40  sh 0,0,0,0  flags 72 misc 0548  prm 0+0 */
    { 0x00007212, 0x01000000, 0x00280100, 0x00000028, 0x00400128, 0x00005000, 0x00000050, 0x05480000 },
    /* 425  LOOP TILE n=0 body=0 */
    { 0x00000001, 0x00000000, 0x00000018, 0x00000028, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 426  VEC_RQ       L11_XSSBlock_17_ss2d_CrossMerge            17' ACC -> int8                    in: ACC@ACC+0(w)                                                 out: t17@WORK+0(rel)                  rows[-1,9)   C 256->256 40x40  sh 3,0,0,0  flags 30 misc 8200  prm 0+0 */
    { 0x00033010, 0x01000000, 0x00280100, 0x09ff0028, 0x00500000, 0x00000000, 0x00000040, 0x82000000 },
    /* 427  VEC_LN       L11_XSSBlock_18_ss2d_out_norm_LightNorm    18 out_norm                        in: t17@WORK+0(rel)                                              out: t18@WORK+15360(rel)              rows[-1,9)   C 256->256 40x40  sh 0,0,21,18  flags 30 misc a000  prm 100497+0 */
    { 0x00003014, 0x01001215, 0x00280100, 0x09ff0028, 0x00400000, 0x3c000000, 0x01889140, 0xa0000000 },
    /* 428  GEMM         L11_XSSBlock_01_in_proj_Conv2d             01 (recompute)                     in: L08.out@A+0, S5@SKIP+51200                                   out: r01@WORK+0(rel)                  rows[-2,10)  C 256->128 40x40  sh 0,1,0,0  flags 70 misc 8800  prm 93245+128 L11_XSSBlock_01_in_proj_Conv2d */
    { 0x01007020, 0x01000000, 0x00280080, 0x0afe0028, 0x00000000, 0x000030c8, 0x016c3d40, 0x88000080 },
    /* 429  VEC_SILU     L11_XSSBlock_02_in_proj_SiLU               02 = r (recompute)                 in: r01@WORK+0(rel)                                              out: r02@WORK+7680(rel)               rows[-2,10)  C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 2013+0 */
    { 0x00003011, 0x00800000, 0x00280080, 0x0afe0028, 0x00400000, 0x1e000000, 0x0007dd40, 0xa0000000 },
    /* 430  DW           L11_XSSBlock_03_ls_fc1_DWConv2d            03 (recompute)                     in: r02@WORK+7680(rel)                                           out: r03@WORK+0(rel)                  rows[-2,10)  C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 94801+0 L11_XSSBlock_03_ls_fc1_DWConv2d */
    { 0x00003030, 0x00800000, 0x00280080, 0x0afe0028, 0x00401e00, 0x00000000, 0x01725140, 0xa0000000 },
    /* 431  GEMM         L11_XSSBlock_04_ls_fc2_Conv2d              04 (recompute)                     in: r03@WORK+0(rel)                                              out: r04@WORK+30720(rel)              rows[-1,9)   C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 94865+512 L11_XSSBlock_04_ls_fc2_Conv2d */
    { 0x00003020, 0x00800000, 0x00280080, 0x09ff0028, 0x00400000, 0x78000000, 0x01729140, 0xa0000200 },
    /* 432  VEC_SILU     L11_XSSBlock_05_ls_SiLU                    05 (recompute)                     in: r04@WORK+30720(rel)                                          out: r05@WORK+0(rel)                  rows[-1,9)   C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 521+0 */
    { 0x00003011, 0x00800000, 0x00280080, 0x09ff0028, 0x00407800, 0x00000000, 0x00020940, 0xa0000000 },
    /* 433  GEMM         L11_XSSBlock_06_ls_fc3_Conv2d              06 (recompute, X scratch)          in: r05@WORK+0(rel)                                              out: s06@X+0(rel)                     rows[-1,9)   C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 95397+512 L11_XSSBlock_06_ls_fc3_Conv2d */
    { 0x00003020, 0x00800000, 0x00280080, 0x09ff0028, 0x00400000, 0x00000000, 0x0174a520, 0xa0000200 },
    /* 434  VEC_ADD      L11_XSSBlock_07_ls_Add                     07 (recompute)                     in: r02@WORK+7680(rel), s06@X+0(rel)                             out: r07@WORK+0(rel)                  rows[-1,9)   C 128->128 40x40  sh -1,0,1,0  flags 70 misc e000  prm 0+0 */
    { 0x00ff7012, 0x00800001, 0x00280080, 0x09ff0028, 0x00401e00, 0x00002000, 0x00000040, 0xe0000000 },
    /* 435  VEC_LN       L11_XSSBlock_08_norm_LightNorm             08 (recompute)                     in: r07@WORK+0(rel)                                              out: r08@WORK+30720(rel)              rows[-1,9)   C 128->128 40x40  sh 0,0,21,20  flags 30 misc a000  prm 95929+0 */
    { 0x00003014, 0x00801415, 0x00280080, 0x09ff0028, 0x00400000, 0x78000000, 0x0176b940, 0xa0000000 },
    /* 436  GEMM         L11_XSSBlock_09_ss2d_in_proj_Conv2d        09 in_proj z half (recompute)      in: r08@WORK+30720(rel)                                          out: r09z@WORK+38400(rel)             rows[-1,9)   C 128->256 40x40  sh 0,0,0,0  flags 30 misc a000  prm 97033+1024 L11_XSSBlock_09_ss2d_in_proj_Conv2d:z */
    { 0x00003020, 0x00800000, 0x00280100, 0x09ff0028, 0x00407800, 0x96000000, 0x017b0940, 0xa0000400 },
    /* 437  VEC_SILU     L11_XSSBlock_10_ss2d_SiLU_z                10 = z (X scratch)                 in: r09z@WORK+38400(rel)                                         out: s10z@X+0(rel)                    rows[-1,9)   C 256->256 40x40  sh -1,0,0,0  flags 30 misc a000  prm 22273+0 */
    { 0x00ff3011, 0x01000000, 0x00280100, 0x09ff0028, 0x00409600, 0x00000000, 0x00570120, 0xa0000000 },
    /* 438  VEC_MUL      L11_XSSBlock_19_ss2d_Mul                   19 gate -> requant to 20           in: t18@WORK+15360(rel), s10z@X+0(rel)                           out: t19@WORK+30720(rel)              rows[-1,9)   C 256->256 40x40  sh 0,0,4,0  flags 70 misc e000  prm 0+0 */
    { 0x00007013, 0x01000004, 0x00280100, 0x09ff0028, 0x00403c00, 0x78002000, 0x00000040, 0xe0000000 },
    /* 439  GEMM         L11_XSSBlock_20_ss2d_out_proj_Conv2d       20 out_proj (X scratch)            in: t19@WORK+30720(rel)                                          out: s20@X+0(rel)                     rows[-1,9)   C 256->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 100545+1024 L11_XSSBlock_20_ss2d_out_proj_Conv2d */
    { 0x00003020, 0x01000000, 0x00280080, 0x09ff0028, 0x00407800, 0x00000000, 0x0188c120, 0xa0000400 },
    /* 440  VEC_ADD      L11_XSSBlock_21_Add                        21 Add (wide, kept)                in: r02@WORK+7680(rel), s20@X+0(rel)                             out: t21@WORK+15360(rel)(w)           rows[-1,9)   C 128->128 40x40  sh -1,0,0,0  flags 72 misc e000  prm 0+0 */
    { 0x00ff7212, 0x00800000, 0x00280080, 0x09ff0028, 0x00401e00, 0x3c002000, 0x00000040, 0xe0000000 },
    /* 441  VEC_LN       L11_XSSBlock_22_norm2_LightNorm            22 norm2                           in: t21@WORK+15360(rel)(w)                                       out: t22@WORK+0(rel)                  rows[-1,9)   C 128->128 40x40  sh 1,0,21,20  flags 30 misc a200  prm 101589+0 */
    { 0x00013014, 0x00801415, 0x00280080, 0x09ff0028, 0x00403c00, 0x00000000, 0x018cd540, 0xa2000000 },
    /* 442  GEMM         L11_XSSBlock_23_mlp_fc1_Conv2d             23 fc1 x half (X scratch)          in: t22@WORK+0(rel)                                              out: s23x@X+0(rel)                    rows[-1,9)   C 128->341 40x40  sh 0,0,0,0  flags 30 misc a000  prm 101629+1376 L11_XSSBlock_23_mlp_fc1_Conv2d:x */
    { 0x00003020, 0x00800000, 0x00280155, 0x09ff0028, 0x00400000, 0x00000000, 0x018cfd20, 0xa0000560 },
    /* 443  GEMM         L11_XSSBlock_23_mlp_fc1_Conv2d             23 fc1 v half (X scratch)          in: t22@WORK+0(rel)                                              out: s23v@X+20640(rel)                rows[-1,9)   C 128->341 40x40  sh 0,0,0,0  flags 30 misc a000  prm 103059+1376 L11_XSSBlock_23_mlp_fc1_Conv2d:v */
    { 0x00003020, 0x00800000, 0x00280155, 0x09ff0028, 0x00400000, 0x50a00000, 0x01929320, 0xa0000560 },
    /* 444  VEC_RQ       L11_XSSBlock_24_mlp_DWConv2d               24 DW input requant (DW has none)  in: s23x@X+0(rel)                                                out: rq24@WORK+51360(rel)             rows[-1,9)   C 341->341 40x40  sh -1,0,0,0  flags 30 misc a000  prm 0+0 */
    { 0x00ff3010, 0x01550000, 0x00280155, 0x09ff0028, 0x00200000, 0xc8a00000, 0x00000040, 0xa0000000 },
    /* 445  DW           L11_XSSBlock_24_mlp_DWConv2d               24 DW                              in: rq24@WORK+51360(rel)                                         out: t24@WORK+30720(rel)              rows[-1,9)   C 341->341 40x40  sh 0,0,0,0  flags 30 misc a000  prm 104489+0 L11_XSSBlock_24_mlp_DWConv2d */
    { 0x00003030, 0x01550000, 0x00280155, 0x09ff0028, 0x0040c8a0, 0x78000000, 0x01982940, 0xa0000000 },
    /* 446  VEC_ADD      L11_XSSBlock_26_mlp_SiLU                   25 Add -> 26 SiLU (fused)          in: t24@WORK+30720(rel), s23x@X+0(rel)                           out: t26@WORK+51360(rel)              rows[0,8)    C 341->341 40x40  sh 0,-1,1,0  flags f0 misc e000  prm 521+0 */
    { 0xff00f012, 0x01550001, 0x00280155, 0x08000028, 0x00407800, 0xc8a02000, 0x00020940, 0xe0000000 },
    /* 447  VEC_MUL      L11_XSSBlock_27_mlp_Mul                    27 Mul -> requant to 28            in: t26@WORK+51360(rel), s23v@X+20640(rel)                       out: t27@WORK+30720(rel)              rows[0,8)    C 341->341 40x40  sh 0,0,4,0  flags 70 misc e000  prm 0+0 */
    { 0x00007013, 0x01550004, 0x00280155, 0x08000028, 0xa040c8a0, 0x78002050, 0x00000040, 0xe0000000 },
    /* 448  GEMM         L11_XSSBlock_28_mlp_fc2_Conv2d             28 fc2 (X scratch)                 in: t27@WORK+30720(rel)                                          out: s28@X+0(rel)                     rows[0,8)    C 341->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 104661+1376 L11_XSSBlock_28_mlp_fc2_Conv2d */
    { 0x00003020, 0x01550000, 0x00280080, 0x08000028, 0x00407800, 0x00000000, 0x0198d520, 0xa0000560 },
    /* 449  VEC_ADD      L11_XSSBlock_29_Add                        29 Add -> block output             in: t21@WORK+15360(rel)(w), s28@X+0(rel)                         out: L11_XSSBlock_01.out@B+0          rows[0,8)    C 128->128 40x40  sh 0,0,1,0  flags 70 misc 6200  prm 0+0 */
    { 0x00007012, 0x00800001, 0x00280080, 0x08000028, 0x00403c00, 0x00002000, 0x00000010, 0x62000000 },
    /* 450  VEC_RQ       L11_XSSBlock_29_Add                        keep block output in SKIP (S11)    in: L11_XSSBlock_01.out@B+0                                      out: S11@SKIP+89600                   frame        C 128->128 40x40  sh 0,0,0,0  flags 30 misc 0000  prm 0+0 */
    { 0x00003010, 0x00800000, 0x00280080, 0x00000028, 0x00100000, 0x5e000000, 0x00000031, 0x00000000 },
    /* 451  LOOP TILE n=0 body=0 */
    { 0x00000001, 0x00000000, 0x0000000b, 0x00000050, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 452  GEMM         L14_XSSBlock_01_in_proj_Conv2d             01 proj                            in: L11_XSSBlock_01.out@B+0, S3@SKIP+0                           out: t01@WORK+0(rel)                  rows[-2,10)  C 128->64 80x80  sh 0,0,0,0  flags 70 misc 8800  prm 106057+64 L14_XSSBlock_01_in_proj_Conv2d */
    { 0x00007020, 0x00800000, 0x00500040, 0x0afe0050, 0x00100000, 0x00003000, 0x019e4940, 0x88000040 },
    /* 453  VEC_SILU     L14_XSSBlock_02_in_proj_SiLU               02 SiLU                            in: t01@WORK+0(rel)                                              out: t02@WORK+7680(rel)               rows[-2,10)  C 64->64 80x80  sh 0,0,0,0  flags 30 misc a000  prm 22273+0 */
    { 0x00003011, 0x00400000, 0x00500040, 0x0afe0050, 0x00400000, 0x1e000000, 0x00570140, 0xa0000000 },
    /* 454  DW           L14_XSSBlock_03_ls_fc1_DWConv2d            03 DW                              in: t02@WORK+7680(rel)                                           out: t03@WORK+0(rel)                  rows[-2,10)  C 64->64 80x80  sh 0,0,0,0  flags 30 misc a000  prm 106451+0 L14_XSSBlock_03_ls_fc1_DWConv2d */
    { 0x00003030, 0x00400000, 0x00500040, 0x0afe0050, 0x00401e00, 0x00000000, 0x019fd340, 0xa0000000 },
    /* 455  GEMM         L14_XSSBlock_04_ls_fc2_Conv2d              04                                 in: t03@WORK+0(rel)                                              out: t04@WORK+15360(rel)              rows[-1,9)   C 64->64 80x80  sh 0,0,0,0  flags 30 misc a000  prm 106483+128 L14_XSSBlock_04_ls_fc2_Conv2d */
    { 0x00003020, 0x00400000, 0x00500040, 0x09ff0050, 0x00400000, 0x3c000000, 0x019ff340, 0xa0000080 },
    /* 456  VEC_SILU     L14_XSSBlock_05_ls_SiLU                    05 SiLU                            in: t04@WORK+15360(rel)                                          out: t05@WORK+0(rel)                  rows[-1,9)   C 64->64 80x80  sh 0,0,0,0  flags 30 misc a000  prm 2013+0 */
    { 0x00003011, 0x00400000, 0x00500040, 0x09ff0050, 0x00403c00, 0x00000000, 0x0007dd40, 0xa0000000 },
    /* 457  GEMM         L14_XSSBlock_06_ls_fc3_Conv2d              06 (scratch)                       in: t05@WORK+0(rel)                                              out: s06@A+0(rel)                     rows[-1,9)   C 64->64 80x80  sh 0,0,0,0  flags 30 misc a000  prm 106621+128 L14_XSSBlock_06_ls_fc3_Conv2d */
    { 0x00003020, 0x00400000, 0x00500040, 0x09ff0050, 0x00400000, 0x00000000, 0x01a07d00, 0xa0000080 },
    /* 458  VEC_ADD      L14_XSSBlock_07_ls_Add                     07 Add -> requant to 08            in: t02@WORK+7680(rel), s06@A+0(rel)                             out: t07@WORK+0(rel)                  rows[-1,9)   C 64->64 80x80  sh 0,0,0,0  flags 70 misc e000  prm 0+0 */
    { 0x00007012, 0x00400000, 0x00500040, 0x09ff0050, 0x00401e00, 0x00000000, 0x00000040, 0xe0000000 },
    /* 459  VEC_LN       L14_XSSBlock_08_norm_LightNorm             08 LightNorm                       in: t07@WORK+0(rel)                                              out: t08@WORK+7680(rel)               rows[-1,9)   C 64->64 80x80  sh 0,0,22,20  flags 30 misc a000  prm 106759+0 */
    { 0x00003014, 0x00401416, 0x00500040, 0x09ff0050, 0x00400000, 0x1e000000, 0x01a10740, 0xa0000000 },
    /* 460  GEMM         L14_XSSBlock_09_ss2d_in_proj_Conv2d        09 in_proj x half                  in: t08@WORK+7680(rel)                                           out: t09x@WORK+15360(rel)             rows[-1,9)   C 64->128 80x80  sh 0,0,0,0  flags 30 misc a000  prm 106795+256 L14_XSSBlock_09_ss2d_in_proj_Conv2d:x */
    { 0x00003020, 0x00400000, 0x00500080, 0x09ff0050, 0x00401e00, 0x3c000000, 0x01a12b40, 0xa0000100 },
    /* 461  DW           L14_XSSBlock_11_ss2d_DWConv2d              11 DW                              in: t09x@WORK+15360(rel)                                         out: t11@WORK+0(rel)                  rows[-1,9)   C 128->128 80x80  sh 0,0,0,0  flags 30 misc a000  prm 107347+0 L14_XSSBlock_11_ss2d_DWConv2d */
    { 0x00003030, 0x00800000, 0x00500080, 0x09ff0050, 0x00403c00, 0x00000000, 0x01a35340, 0xa0000000 },
    /* 462  VEC_SILU     L14_XSSBlock_12_ss2d_SiLU_x                12 SiLU -> X                       in: t11@WORK+0(rel)                                              out: X@X+0                            rows[0,8)    C 128->128 80x80  sh 0,0,0,0  flags 30 misc 2000  prm 22273+0 */
    { 0x00003011, 0x00800000, 0x00500080, 0x08000050, 0x00400000, 0x00000000, 0x00570120, 0x20000000 },
    /* 463  SETK 0 */
    { 0x00000003, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 464  LOOP GROUP n=800 body=4 */
    { 0x00000001, 0x03200000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 465  GEMM         L14_XSSBlock_14_ss2d_XProj                 14 XProj dir0                      in: X@X+0                                                        out: g_xp@WORK+128                    frame        C 128->36 80x80  sh 0,0,0,0  flags 30 misc 0090  prm 107411+144 L14_XSSBlock_14_ss2d_XProj:dir0 */
    { 0x00003020, 0x00800000, 0x00500024, 0x00000050, 0x00200000, 0x00800000, 0x01a39340, 0x00900090 },
    /* 466  GEMM         L14_XSSBlock_15_ss2d_DtProj                15 DtProj dir0 (+ReLU)             in: g_xp@WORK+128                                                out: g_delta@WORK+0                   frame        C 4->128 80x80  sh 0,0,0,5  flags 31 misc 0088  prm 108015+32 L14_XSSBlock_15_ss2d_DtProj:dir0 */
    { 0x00003120, 0x00040500, 0x00500080, 0x00000050, 0x00400080, 0x00000000, 0x01a5ef40, 0x00880020 },
    /* 467  SCAN         L14_XSSBlock_16_ss2d_SelectiveScan         16 scan dir0                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+168                     frame        C 128->128 80x80  sh 0,0,0,0  flags 44 misc 00b0  prm 108223+4 L14_XSSBlock_16_ss2d_SelectiveScan:dir0 */
    { 0x00004440, 0x00800000, 0x00500080, 0x00000050, 0x00200000, 0x00a84000, 0x01a6bf40, 0x00b00004 },
    /* 468  VEC_ADD      L14_XSSBlock_17_ss2d_CrossMerge            17 accumulate dir0                 in: g_y@WORK+168, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 128->128 80x80  sh 0,0,0,0  flags 7a misc 0548  prm 0+0 */
    { 0x00007a12, 0x00800000, 0x00500080, 0x00000050, 0x004000a8, 0x00005000, 0x00000050, 0x05480000 },
    /* 469  SETK 1 */
    { 0x00000003, 0x00010000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 470  LOOP GROUP n=800 body=4 */
    { 0x00000001, 0x03200000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 471  GEMM         L14_XSSBlock_14_ss2d_XProj                 14 XProj dir1                      in: X@X+0                                                        out: g_xp@WORK+128                    frame        C 128->36 80x80  sh 0,0,0,0  flags 30 misc 0090  prm 107562+144 L14_XSSBlock_14_ss2d_XProj:dir1 */
    { 0x00003020, 0x00800000, 0x00500024, 0x00000050, 0x00200000, 0x00800000, 0x01a42a40, 0x00900090 },
    /* 472  GEMM         L14_XSSBlock_15_ss2d_DtProj                15 DtProj dir1 (+ReLU)             in: g_xp@WORK+128                                                out: g_delta@WORK+0                   frame        C 4->128 80x80  sh 0,0,0,5  flags 31 misc 0088  prm 108067+32 L14_XSSBlock_15_ss2d_DtProj:dir1 */
    { 0x00003120, 0x00040500, 0x00500080, 0x00000050, 0x00400080, 0x00000000, 0x01a62340, 0x00880020 },
    /* 473  SCAN         L14_XSSBlock_16_ss2d_SelectiveScan         16 scan dir1                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+168                     frame        C 128->128 80x80  sh 0,0,0,0  flags 44 misc 00b0  prm 108292+4 L14_XSSBlock_16_ss2d_SelectiveScan:dir1 */
    { 0x00004440, 0x00800000, 0x00500080, 0x00000050, 0x00200000, 0x00a84000, 0x01a70440, 0x00b00004 },
    /* 474  VEC_ADD      L14_XSSBlock_17_ss2d_CrossMerge            17 accumulate dir1                 in: g_y@WORK+168, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 128->128 80x80  sh 0,0,0,0  flags 72 misc 0548  prm 0+0 */
    { 0x00007212, 0x00800000, 0x00500080, 0x00000050, 0x004000a8, 0x00005000, 0x00000050, 0x05480000 },
    /* 475  SETK 2 */
    { 0x00000003, 0x00020000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 476  LOOP GROUP n=800 body=4 */
    { 0x00000001, 0x03200000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 477  GEMM         L14_XSSBlock_14_ss2d_XProj                 14 XProj dir2                      in: X@X+0                                                        out: g_xp@WORK+128                    frame        C 128->36 80x80  sh 0,0,0,0  flags 30 misc 0090  prm 107713+144 L14_XSSBlock_14_ss2d_XProj:dir2 */
    { 0x00003020, 0x00800000, 0x00500024, 0x00000050, 0x00200000, 0x00800000, 0x01a4c140, 0x00900090 },
    /* 478  GEMM         L14_XSSBlock_15_ss2d_DtProj                15 DtProj dir2 (+ReLU)             in: g_xp@WORK+128                                                out: g_delta@WORK+0                   frame        C 4->128 80x80  sh 0,0,0,5  flags 31 misc 0088  prm 108119+32 L14_XSSBlock_15_ss2d_DtProj:dir2 */
    { 0x00003120, 0x00040500, 0x00500080, 0x00000050, 0x00400080, 0x00000000, 0x01a65740, 0x00880020 },
    /* 479  SCAN         L14_XSSBlock_16_ss2d_SelectiveScan         16 scan dir2                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+168                     frame        C 128->128 80x80  sh 0,0,0,0  flags 44 misc 00b0  prm 108361+4 L14_XSSBlock_16_ss2d_SelectiveScan:dir2 */
    { 0x00004440, 0x00800000, 0x00500080, 0x00000050, 0x00200000, 0x00a84000, 0x01a74940, 0x00b00004 },
    /* 480  VEC_ADD      L14_XSSBlock_17_ss2d_CrossMerge            17 accumulate dir2                 in: g_y@WORK+168, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 128->128 80x80  sh -1,0,0,0  flags 72 misc 0548  prm 0+0 */
    { 0x00ff7212, 0x00800000, 0x00500080, 0x00000050, 0x004000a8, 0x00005000, 0x00000050, 0x05480000 },
    /* 481  SETK 3 */
    { 0x00000003, 0x00030000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 482  LOOP GROUP n=800 body=4 */
    { 0x00000001, 0x03200000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 483  GEMM         L14_XSSBlock_14_ss2d_XProj                 14 XProj dir3                      in: X@X+0                                                        out: g_xp@WORK+128                    frame        C 128->36 80x80  sh 0,0,0,0  flags 30 misc 0090  prm 107864+144 L14_XSSBlock_14_ss2d_XProj:dir3 */
    { 0x00003020, 0x00800000, 0x00500024, 0x00000050, 0x00200000, 0x00800000, 0x01a55840, 0x00900090 },
    /* 484  GEMM         L14_XSSBlock_15_ss2d_DtProj                15 DtProj dir3 (+ReLU)             in: g_xp@WORK+128                                                out: g_delta@WORK+0                   frame        C 4->128 80x80  sh 0,0,0,5  flags 31 misc 0088  prm 108171+32 L14_XSSBlock_15_ss2d_DtProj:dir3 */
    { 0x00003120, 0x00040500, 0x00500080, 0x00000050, 0x00400080, 0x00000000, 0x01a68b40, 0x00880020 },
    /* 485  SCAN         L14_XSSBlock_16_ss2d_SelectiveScan         16 scan dir3                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+168                     frame        C 128->128 80x80  sh 0,0,0,0  flags 44 misc 00b0  prm 108430+4 L14_XSSBlock_16_ss2d_SelectiveScan:dir3 */
    { 0x00004440, 0x00800000, 0x00500080, 0x00000050, 0x00200000, 0x00a84000, 0x01a78e40, 0x00b00004 },
    /* 486  VEC_ADD      L14_XSSBlock_17_ss2d_CrossMerge            17 accumulate dir3                 in: g_y@WORK+168, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 128->128 80x80  sh -1,0,0,0  flags 72 misc 0548  prm 0+0 */
    { 0x00ff7212, 0x00800000, 0x00500080, 0x00000050, 0x004000a8, 0x00005000, 0x00000050, 0x05480000 },
    /* 487  LOOP TILE n=0 body=0 */
    { 0x00000001, 0x00000000, 0x00000017, 0x00000050, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 488  VEC_RQ       L14_XSSBlock_17_ss2d_CrossMerge            17' ACC -> int8                    in: ACC@ACC+0(w)                                                 out: t17@WORK+0(rel)                  rows[-1,9)   C 128->128 80x80  sh 1,0,0,0  flags 30 misc 8200  prm 0+0 */
    { 0x00013010, 0x00800000, 0x00500080, 0x09ff0050, 0x00500000, 0x00000000, 0x00000040, 0x82000000 },
    /* 489  VEC_LN       L14_XSSBlock_18_ss2d_out_norm_LightNorm    18 out_norm                        in: t17@WORK+0(rel)                                              out: t18@WORK+15360(rel)              rows[-1,9)   C 128->128 80x80  sh 0,0,21,19  flags 30 misc a000  prm 108499+0 */
    { 0x00003014, 0x00801315, 0x00500080, 0x09ff0050, 0x00400000, 0x3c000000, 0x01a7d340, 0xa0000000 },
    /* 490  GEMM         L14_XSSBlock_01_in_proj_Conv2d             01 (recompute)                     in: L11_XSSBlock_01.out@B+0, S3@SKIP+0                           out: r01@WORK+0(rel)                  rows[-2,10)  C 128->64 80x80  sh 0,0,0,0  flags 70 misc 8800  prm 106057+64 L14_XSSBlock_01_in_proj_Conv2d */
    { 0x00007020, 0x00800000, 0x00500040, 0x0afe0050, 0x00100000, 0x00003000, 0x019e4940, 0x88000040 },
    /* 491  VEC_SILU     L14_XSSBlock_02_in_proj_SiLU               02 = r (recompute)                 in: r01@WORK+0(rel)                                              out: r02@WORK+7680(rel)               rows[-2,10)  C 64->64 80x80  sh 0,0,0,0  flags 30 misc a000  prm 22273+0 */
    { 0x00003011, 0x00400000, 0x00500040, 0x0afe0050, 0x00400000, 0x1e000000, 0x00570140, 0xa0000000 },
    /* 492  DW           L14_XSSBlock_03_ls_fc1_DWConv2d            03 (recompute)                     in: r02@WORK+7680(rel)                                           out: r03@WORK+0(rel)                  rows[-2,10)  C 64->64 80x80  sh 0,0,0,0  flags 30 misc a000  prm 106451+0 L14_XSSBlock_03_ls_fc1_DWConv2d */
    { 0x00003030, 0x00400000, 0x00500040, 0x0afe0050, 0x00401e00, 0x00000000, 0x019fd340, 0xa0000000 },
    /* 493  GEMM         L14_XSSBlock_04_ls_fc2_Conv2d              04 (recompute)                     in: r03@WORK+0(rel)                                              out: r04@WORK+30720(rel)              rows[-1,9)   C 64->64 80x80  sh 0,0,0,0  flags 30 misc a000  prm 106483+128 L14_XSSBlock_04_ls_fc2_Conv2d */
    { 0x00003020, 0x00400000, 0x00500040, 0x09ff0050, 0x00400000, 0x78000000, 0x019ff340, 0xa0000080 },
    /* 494  VEC_SILU     L14_XSSBlock_05_ls_SiLU                    05 (recompute)                     in: r04@WORK+30720(rel)                                          out: r05@WORK+0(rel)                  rows[-1,9)   C 64->64 80x80  sh 0,0,0,0  flags 30 misc a000  prm 2013+0 */
    { 0x00003011, 0x00400000, 0x00500040, 0x09ff0050, 0x00407800, 0x00000000, 0x0007dd40, 0xa0000000 },
    /* 495  GEMM         L14_XSSBlock_06_ls_fc3_Conv2d              06 (recompute, X scratch)          in: r05@WORK+0(rel)                                              out: s06@X+0(rel)                     rows[-1,9)   C 64->64 80x80  sh 0,0,0,0  flags 30 misc a000  prm 106621+128 L14_XSSBlock_06_ls_fc3_Conv2d */
    { 0x00003020, 0x00400000, 0x00500040, 0x09ff0050, 0x00400000, 0x00000000, 0x01a07d20, 0xa0000080 },
    /* 496  VEC_ADD      L14_XSSBlock_07_ls_Add                     07 (recompute)                     in: r02@WORK+7680(rel), s06@X+0(rel)                             out: r07@WORK+0(rel)                  rows[-1,9)   C 64->64 80x80  sh 0,0,0,0  flags 70 misc e000  prm 0+0 */
    { 0x00007012, 0x00400000, 0x00500040, 0x09ff0050, 0x00401e00, 0x00002000, 0x00000040, 0xe0000000 },
    /* 497  VEC_LN       L14_XSSBlock_08_norm_LightNorm             08 (recompute)                     in: r07@WORK+0(rel)                                              out: r08@WORK+30720(rel)              rows[-1,9)   C 64->64 80x80  sh 0,0,22,20  flags 30 misc a000  prm 106759+0 */
    { 0x00003014, 0x00401416, 0x00500040, 0x09ff0050, 0x00400000, 0x78000000, 0x01a10740, 0xa0000000 },
    /* 498  GEMM         L14_XSSBlock_09_ss2d_in_proj_Conv2d        09 in_proj z half (recompute)      in: r08@WORK+30720(rel)                                          out: r09z@WORK+38400(rel)             rows[-1,9)   C 64->128 80x80  sh 0,0,0,0  flags 30 misc a000  prm 107071+256 L14_XSSBlock_09_ss2d_in_proj_Conv2d:z */
    { 0x00003020, 0x00400000, 0x00500080, 0x09ff0050, 0x00407800, 0x96000000, 0x01a23f40, 0xa0000100 },
    /* 499  VEC_SILU     L14_XSSBlock_10_ss2d_SiLU_z                10 = z (X scratch)                 in: r09z@WORK+38400(rel)                                         out: s10z@X+0(rel)                    rows[-1,9)   C 128->128 80x80  sh -1,0,0,0  flags 30 misc a000  prm 22273+0 */
    { 0x00ff3011, 0x00800000, 0x00500080, 0x09ff0050, 0x00409600, 0x00000000, 0x00570120, 0xa0000000 },
    /* 500  VEC_MUL      L14_XSSBlock_19_ss2d_Mul                   19 gate -> requant to 20           in: t18@WORK+15360(rel), s10z@X+0(rel)                           out: t19@WORK+30720(rel)              rows[-1,9)   C 128->128 80x80  sh 0,0,4,0  flags 70 misc e000  prm 0+0 */
    { 0x00007013, 0x00800004, 0x00500080, 0x09ff0050, 0x00403c00, 0x78002000, 0x00000040, 0xe0000000 },
    /* 501  GEMM         L14_XSSBlock_20_ss2d_out_proj_Conv2d       20 out_proj (X scratch)            in: t19@WORK+30720(rel)                                          out: s20@X+0(rel)                     rows[-1,9)   C 128->64 80x80  sh 0,0,0,0  flags 30 misc a000  prm 108539+256 L14_XSSBlock_20_ss2d_out_proj_Conv2d */
    { 0x00003020, 0x00800000, 0x00500040, 0x09ff0050, 0x00407800, 0x00000000, 0x01a7fb20, 0xa0000100 },
    /* 502  VEC_ADD      L14_XSSBlock_21_Add                        21 Add (wide, kept)                in: r02@WORK+7680(rel), s20@X+0(rel)                             out: t21@WORK+15360(rel)(w)           rows[-1,9)   C 64->64 80x80  sh -1,0,0,0  flags 72 misc e000  prm 0+0 */
    { 0x00ff7212, 0x00400000, 0x00500040, 0x09ff0050, 0x00401e00, 0x3c002000, 0x00000040, 0xe0000000 },
    /* 503  VEC_LN       L14_XSSBlock_22_norm2_LightNorm            22 norm2                           in: t21@WORK+15360(rel)(w)                                       out: t22@WORK+0(rel)                  rows[-1,9)   C 64->64 80x80  sh 1,0,21,19  flags 30 misc a200  prm 108805+0 */
    { 0x00013014, 0x00401315, 0x00500040, 0x09ff0050, 0x00403c00, 0x00000000, 0x01a90540, 0xa2000000 },
    /* 504  GEMM         L14_XSSBlock_23_mlp_fc1_Conv2d             23 fc1 x half (X scratch)          in: t22@WORK+0(rel)                                              out: s23x@X+0(rel)                    rows[-1,9)   C 64->170 80x80  sh 0,0,0,0  flags 30 misc a000  prm 108841+344 L14_XSSBlock_23_mlp_fc1_Conv2d:x */
    { 0x00003020, 0x00400000, 0x005000aa, 0x09ff0050, 0x00400000, 0x00000000, 0x01a92920, 0xa0000158 },
    /* 505  GEMM         L14_XSSBlock_23_mlp_fc1_Conv2d             23 fc1 v half (X scratch)          in: t22@WORK+0(rel)                                              out: s23v@X+21120(rel)                rows[-1,9)   C 64->170 80x80  sh 0,0,0,0  flags 30 misc a000  prm 109213+344 L14_XSSBlock_23_mlp_fc1_Conv2d:v */
    { 0x00003020, 0x00400000, 0x005000aa, 0x09ff0050, 0x00400000, 0x52800000, 0x01aa9d20, 0xa0000158 },
    /* 506  DW           L14_XSSBlock_24_mlp_DWConv2d               24 DW                              in: s23x@X+0(rel)                                                out: t24@WORK+30720(rel)              rows[-1,9)   C 170->170 80x80  sh 0,0,0,0  flags 30 misc a000  prm 109585+0 L14_XSSBlock_24_mlp_DWConv2d */
    { 0x00003030, 0x00aa0000, 0x005000aa, 0x09ff0050, 0x00200000, 0x78000000, 0x01ac1140, 0xa0000000 },
    /* 507  VEC_ADD      L14_XSSBlock_26_mlp_SiLU                   25 Add -> 26 SiLU (fused)          in: t24@WORK+30720(rel), s23x@X+0(rel)                           out: t26@WORK+51840(rel)              rows[0,8)    C 170->170 80x80  sh 0,0,0,0  flags f0 misc e000  prm 521+0 */
    { 0x0000f012, 0x00aa0000, 0x005000aa, 0x08000050, 0x00407800, 0xca802000, 0x00020940, 0xe0000000 },
    /* 508  VEC_MUL      L14_XSSBlock_27_mlp_Mul                    27 Mul -> requant to 28            in: t26@WORK+51840(rel), s23v@X+21120(rel)                       out: t27@WORK+30720(rel)              rows[0,8)    C 170->170 80x80  sh 0,0,5,0  flags 70 misc e000  prm 0+0 */
    { 0x00007013, 0x00aa0005, 0x005000aa, 0x08000050, 0x8040ca80, 0x78002052, 0x00000040, 0xe0000000 },
    /* 509  GEMM         L14_XSSBlock_28_mlp_fc2_Conv2d             28 fc2 (X scratch)                 in: t27@WORK+30720(rel)                                          out: s28@X+0(rel)                     rows[0,8)    C 170->64 80x80  sh 0,0,0,0  flags 30 misc a000  prm 109673+352 L14_XSSBlock_28_mlp_fc2_Conv2d */
    { 0x00003020, 0x00aa0000, 0x00500040, 0x08000050, 0x00407800, 0x00000000, 0x01ac6920, 0xa0000160 },
    /* 510  VEC_ADD      L14_XSSBlock_29_Add                        29 Add -> block output             in: t21@WORK+15360(rel)(w), s28@X+0(rel)                         out: L14_XSSBlock_01.out@A+0          rows[0,8)    C 64->64 80x80  sh 0,-1,1,0  flags 70 misc 6200  prm 0+0 */
    { 0xff007012, 0x00400001, 0x00500040, 0x08000050, 0x00403c00, 0x00002000, 0x00000000, 0x62000000 },
    /* 511  LOOP TILE n=10 body=0 */
    { 0x00000001, 0x000a0000, 0x0000000e, 0x00000050, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 512  GEMM         L21_Detect0_01_box_Conv2d                  head0 01 box 3x3                   in: L14_XSSBlock_01.out@A+0                                      out: t01@WORK+0(rel)                  rows[-1,9)   C 64->64 80x80  sh 0,0,0,0  flags 30 misc 8001  prm 170785+1152 L21_Detect0_01_box_Conv2d */
    { 0x00003020, 0x00400000, 0x00500040, 0x09ff0050, 0x00000000, 0x00000000, 0x029b2140, 0x80010480 },
    /* 513  VEC_SILU     L21_Detect0_02_box_SiLU                    head0 02 SiLU                      in: t01@WORK+0(rel)                                              out: t02@WORK+7680(rel)               rows[-1,9)   C 64->64 80x80  sh 0,0,0,0  flags 30 misc a000  prm 93237+0 */
    { 0x00003011, 0x00400000, 0x00500040, 0x09ff0050, 0x00400000, 0x1e000000, 0x016c3540, 0xa0000000 },
    /* 514  GEMM         L21_Detect0_03_box_Conv2d                  head0 03 box 3x3                   in: t02@WORK+7680(rel)                                           out: t03@WORK+0(rel)                  rows[0,8)    C 64->64 80x80  sh 0,0,0,0  flags 30 misc a001  prm 171947+1152 L21_Detect0_03_box_Conv2d */
    { 0x00003020, 0x00400000, 0x00500040, 0x08000050, 0x00401e00, 0x00000000, 0x029fab40, 0xa0010480 },
    /* 515  VEC_SILU     L21_Detect0_04_box_SiLU                    head0 04 SiLU                      in: t03@WORK+0(rel)                                              out: t04@WORK+7680(rel)               rows[0,8)    C 64->64 80x80  sh 0,0,0,0  flags 30 misc a000  prm 39+0 */
    { 0x00003011, 0x00400000, 0x00500040, 0x08000050, 0x00400000, 0x1e000000, 0x00002740, 0xa0000000 },
    /* 516  GEMM         L21_Detect0_05_box_Conv2d                  head0 05 box 1x1 (64)              in: t04@WORK+7680(rel)                                           out: t05@WORK+0(rel)                  rows[0,8)    C 64->64 80x80  sh 0,0,0,0  flags 30 misc a000  prm 173109+128 L21_Detect0_05_box_Conv2d */
    { 0x00003020, 0x00400000, 0x00500040, 0x08000050, 0x00401e00, 0x00000000, 0x02a43540, 0xa0000080 },
    /* 517  GEMM         L21_Detect0_06_cls_Conv2d                  head0 06 cls 3x3                   in: L14_XSSBlock_01.out@A+0                                      out: t06@WORK+7680(rel)               rows[-1,9)   C 64->80 80x80  sh 0,0,0,0  flags 30 misc 8001  prm 173247+1440 L21_Detect0_06_cls_Conv2d */
    { 0x00003020, 0x00400000, 0x00500050, 0x09ff0050, 0x00000000, 0x1e000000, 0x02a4bf40, 0x800105a0 },
    /* 518  VEC_SILU     L21_Detect0_07_cls_SiLU                    head0 07 SiLU                      in: t06@WORK+7680(rel)                                           out: t07@WORK+17280(rel)              rows[-1,9)   C 80->80 80x80  sh 0,0,0,0  flags 30 misc a000  prm 93237+0 */
    { 0x00003011, 0x00500000, 0x00500050, 0x09ff0050, 0x00401e00, 0x43800000, 0x016c3540, 0xa0000000 },
    /* 519  GEMM         L21_Detect0_08_cls_Conv2d                  head0 08 cls 3x3                   in: t07@WORK+17280(rel)                                          out: t08@WORK+7680(rel)               rows[0,8)    C 80->80 80x80  sh 0,0,0,0  flags 30 misc a001  prm 174700+1800 L21_Detect0_08_cls_Conv2d */
    { 0x00003020, 0x00500000, 0x00500050, 0x08000050, 0x00404380, 0x1e000000, 0x02aa6c40, 0xa0010708 },
    /* 520  VEC_SILU     L21_Detect0_09_cls_SiLU                    head0 09 SiLU                      in: t08@WORK+7680(rel)                                           out: t09@WORK+17280(rel)              rows[0,8)    C 80->80 80x80  sh 0,0,0,0  flags 30 misc a000  prm 176513+0 */
    { 0x00003011, 0x00500000, 0x00500050, 0x08000050, 0x00401e00, 0x43800000, 0x02b18140, 0xa0000000 },
    /* 521  GEMM         L21_Detect0_10_cls_Conv2d                  head0 10 cls 1x1 (80)              in: t09@WORK+17280(rel)                                          out: t10@WORK+7680(rel)               rows[0,8)    C 80->80 80x80  sh 0,0,0,0  flags 30 misc a000  prm 176521+200 L21_Detect0_10_cls_Conv2d */
    { 0x00003020, 0x00500000, 0x00500050, 0x08000050, 0x00404380, 0x1e000000, 0x02b18940, 0xa00000c8 },
    /* 522  VEC_RQ       L21_Detect0_05_box_Conv2d                  head0 box -> hd ch [0, 64)         in: t05@WORK+0(rel)                                              out: hd.box@WORK+17280(rel)           rows[0,8)    C 64->192 80x80  sh 0,0,0,0  flags 30 misc a000  prm 0+0 */
    { 0x00003010, 0x00400000, 0x005000c0, 0x08000050, 0x00400000, 0x43800000, 0x00000040, 0xa0000000 },
    /* 523  VEC_RQ       L21_Detect0_10_cls_Conv2d                  head0 cls -> hd ch [64, 144)       in: t10@WORK+7680(rel)                                           out: hd.cls@WORK+17288(rel)           rows[0,8)    C 80->192 80x80  sh 0,0,0,0  flags 30 misc a000  prm 0+0 */
    { 0x00003010, 0x00500000, 0x005000c0, 0x08000050, 0x00401e00, 0x43880000, 0x00000040, 0xa0000000 },
    /* 524  VEC_RQ                                                  head0 zero -> hd ch [144, 192)     in: L14_XSSBlock_01.out@A+0                                      out: hd.zero@WORK+17298(rel)          rows[0,8)    C 48->192 80x80  sh 16,0,0,0  flags 30 misc 8000  prm 0+0 */
    { 0x00103010, 0x00300000, 0x005000c0, 0x08000050, 0x00000000, 0x43920000, 0x00000040, 0x80000000 },
    /* 525  VEC_OUTROWS  L21_Detect0_hd                             P3 <- head0 hd (rows = pixels x 3) in: hd@WORK+17280(rel)                                           out: OUT.P3@OUT+0                     rows[0,8)    C 192->192 80x80  sh 0,0,0,0  flags 30 misc 2000  prm 0+0 */
    { 0x00003017, 0x00c00000, 0x005000c0, 0x08000050, 0x00404380, 0x00000000, 0x00000060, 0x20000000 },
    /* 526  GEMM         L15_Conv_01_conv_Conv2d                    Conv 3x3 s2                        in: L14_XSSBlock_01.out@A+0                                      out: conv@WORK+0                      frame        C 64->64 80x80  sh 0,0,0,0  flags 30 misc 0002  prm 110035+1152 L15_Conv_01_conv_Conv2d */
    { 0x00003020, 0x00400000, 0x00500040, 0x00000050, 0x00000000, 0x00000000, 0x01add340, 0x00020480 },
    /* 527  VEC_SILU     L15_Conv_02_SiLU                           SiLU -> layer out                  in: conv@WORK+0                                                  out: L15.out@B+0                      frame        C 64->64 40x40  sh 0,0,0,0  flags 30 misc 0000  prm 1508+0 */
    { 0x00003011, 0x00400000, 0x00280040, 0x00000028, 0x00400000, 0x00000000, 0x0005e410, 0x00000000 },
    /* 528  LOOP TILE n=0 body=0 */
    { 0x00000001, 0x00000000, 0x0000000b, 0x00000028, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 529  GEMM         L17_XSSBlock_01_in_proj_Conv2d             01 proj                            in: L15.out@B+0, S11@SKIP+89600                                  out: t01@WORK+0(rel)                  rows[-2,10)  C 64->128 40x40  sh -1,1,0,0  flags 70 misc 8000  prm 111197+128 L17_XSSBlock_01_in_proj_Conv2d */
    { 0x01ff7020, 0x00400000, 0x00280080, 0x0afe0028, 0x00100000, 0x0000315e, 0x01b25d40, 0x80000080 },
    /* 530  VEC_SILU     L17_XSSBlock_02_in_proj_SiLU               02 SiLU                            in: t01@WORK+0(rel)                                              out: t02@WORK+7680(rel)               rows[-2,10)  C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 22273+0 */
    { 0x00003011, 0x00800000, 0x00280080, 0x0afe0028, 0x00400000, 0x1e000000, 0x00570140, 0xa0000000 },
    /* 531  DW           L17_XSSBlock_03_ls_fc1_DWConv2d            03 DW                              in: t02@WORK+7680(rel)                                           out: t03@WORK+0(rel)                  rows[-2,10)  C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 111985+0 L17_XSSBlock_03_ls_fc1_DWConv2d */
    { 0x00003030, 0x00800000, 0x00280080, 0x0afe0028, 0x00401e00, 0x00000000, 0x01b57140, 0xa0000000 },
    /* 532  GEMM         L17_XSSBlock_04_ls_fc2_Conv2d              04                                 in: t03@WORK+0(rel)                                              out: t04@WORK+15360(rel)              rows[-1,9)   C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 112049+512 L17_XSSBlock_04_ls_fc2_Conv2d */
    { 0x00003020, 0x00800000, 0x00280080, 0x09ff0028, 0x00400000, 0x3c000000, 0x01b5b140, 0xa0000200 },
    /* 533  VEC_SILU     L17_XSSBlock_05_ls_SiLU                    05 SiLU                            in: t04@WORK+15360(rel)                                          out: t05@WORK+0(rel)                  rows[-1,9)   C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 521+0 */
    { 0x00003011, 0x00800000, 0x00280080, 0x09ff0028, 0x00403c00, 0x00000000, 0x00020940, 0xa0000000 },
    /* 534  GEMM         L17_XSSBlock_06_ls_fc3_Conv2d              06 (scratch)                       in: t05@WORK+0(rel)                                              out: s06@A+0(rel)                     rows[-1,9)   C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 112581+512 L17_XSSBlock_06_ls_fc3_Conv2d */
    { 0x00003020, 0x00800000, 0x00280080, 0x09ff0028, 0x00400000, 0x00000000, 0x01b7c500, 0xa0000200 },
    /* 535  VEC_ADD      L17_XSSBlock_07_ls_Add                     07 Add -> requant to 08            in: t02@WORK+7680(rel), s06@A+0(rel)                             out: t07@WORK+0(rel)                  rows[-1,9)   C 128->128 40x40  sh -1,0,1,0  flags 70 misc e000  prm 0+0 */
    { 0x00ff7012, 0x00800001, 0x00280080, 0x09ff0028, 0x00401e00, 0x00000000, 0x00000040, 0xe0000000 },
    /* 536  VEC_LN       L17_XSSBlock_08_norm_LightNorm             08 LightNorm                       in: t07@WORK+0(rel)                                              out: t08@WORK+7680(rel)               rows[-1,9)   C 128->128 40x40  sh 0,0,21,19  flags 30 misc a000  prm 113113+0 */
    { 0x00003014, 0x00801315, 0x00280080, 0x09ff0028, 0x00400000, 0x1e000000, 0x01b9d940, 0xa0000000 },
    /* 537  GEMM         L17_XSSBlock_09_ss2d_in_proj_Conv2d        09 in_proj x half                  in: t08@WORK+7680(rel)                                           out: t09x@WORK+15360(rel)             rows[-1,9)   C 128->256 40x40  sh 0,0,0,0  flags 30 misc a000  prm 113153+1024 L17_XSSBlock_09_ss2d_in_proj_Conv2d:x */
    { 0x00003020, 0x00800000, 0x00280100, 0x09ff0028, 0x00401e00, 0x3c000000, 0x01ba0140, 0xa0000400 },
    /* 538  DW           L17_XSSBlock_11_ss2d_DWConv2d              11 DW                              in: t09x@WORK+15360(rel)                                         out: t11@WORK+0(rel)                  rows[-1,9)   C 256->256 40x40  sh 0,0,0,0  flags 30 misc a000  prm 115281+0 L17_XSSBlock_11_ss2d_DWConv2d */
    { 0x00003030, 0x01000000, 0x00280100, 0x09ff0028, 0x00403c00, 0x00000000, 0x01c25140, 0xa0000000 },
    /* 539  VEC_SILU     L17_XSSBlock_12_ss2d_SiLU_x                12 SiLU -> X                       in: t11@WORK+0(rel)                                              out: X@X+0                            rows[0,8)    C 256->256 40x40  sh 0,0,0,0  flags 30 misc 2000  prm 521+0 */
    { 0x00003011, 0x01000000, 0x00280100, 0x08000028, 0x00400000, 0x00000000, 0x00020920, 0x20000000 },
    /* 540  SETK 0 */
    { 0x00000003, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 541  LOOP GROUP n=200 body=4 */
    { 0x00000001, 0x00c80000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 542  GEMM         L17_XSSBlock_14_ss2d_XProj                 14 XProj dir0                      in: X@X+0                                                        out: g_xp@WORK+256                    frame        C 256->40 40x40  sh 0,0,0,0  flags 30 misc 0090  prm 115409+320 L17_XSSBlock_14_ss2d_XProj:dir0 */
    { 0x00003020, 0x01000000, 0x00280028, 0x00000028, 0x00200000, 0x01000000, 0x01c2d140, 0x00900140 },
    /* 543  GEMM         L17_XSSBlock_15_ss2d_DtProj                15 DtProj dir0 (+ReLU)             in: g_xp@WORK+256                                                out: g_delta@WORK+0                   frame        C 8->256 40x40  sh 0,0,0,5  flags 31 misc 0088  prm 116717+64 L17_XSSBlock_15_ss2d_DtProj:dir0 */
    { 0x00003120, 0x00080500, 0x00280100, 0x00000028, 0x00400100, 0x00000000, 0x01c7ed40, 0x00880040 },
    /* 544  SCAN         L17_XSSBlock_16_ss2d_SelectiveScan         16 scan dir0                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+296                     frame        C 256->256 40x40  sh 0,0,0,0  flags 44 misc 00b0  prm 117133+8 L17_XSSBlock_16_ss2d_SelectiveScan:dir0 */
    { 0x00004440, 0x01000000, 0x00280100, 0x00000028, 0x00200000, 0x01284000, 0x01c98d40, 0x00b00008 },
    /* 545  VEC_ADD      L17_XSSBlock_17_ss2d_CrossMerge            17 accumulate dir0                 in: g_y@WORK+296, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 256->256 40x40  sh 0,0,0,0  flags 7a misc 0548  prm 0+0 */
    { 0x00007a12, 0x01000000, 0x00280100, 0x00000028, 0x00400128, 0x00005000, 0x00000050, 0x05480000 },
    /* 546  SETK 1 */
    { 0x00000003, 0x00010000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 547  LOOP GROUP n=200 body=4 */
    { 0x00000001, 0x00c80000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 548  GEMM         L17_XSSBlock_14_ss2d_XProj                 14 XProj dir1                      in: X@X+0                                                        out: g_xp@WORK+256                    frame        C 256->40 40x40  sh 0,0,0,0  flags 30 misc 0090  prm 115736+320 L17_XSSBlock_14_ss2d_XProj:dir1 */
    { 0x00003020, 0x01000000, 0x00280028, 0x00000028, 0x00200000, 0x01000000, 0x01c41840, 0x00900140 },
    /* 549  GEMM         L17_XSSBlock_15_ss2d_DtProj                15 DtProj dir1 (+ReLU)             in: g_xp@WORK+256                                                out: g_delta@WORK+0                   frame        C 8->256 40x40  sh 0,0,0,5  flags 31 misc 0088  prm 116821+64 L17_XSSBlock_15_ss2d_DtProj:dir1 */
    { 0x00003120, 0x00080500, 0x00280100, 0x00000028, 0x00400100, 0x00000000, 0x01c85540, 0x00880040 },
    /* 550  SCAN         L17_XSSBlock_16_ss2d_SelectiveScan         16 scan dir1                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+296                     frame        C 256->256 40x40  sh 0,0,0,0  flags 44 misc 00b0  prm 117270+8 L17_XSSBlock_16_ss2d_SelectiveScan:dir1 */
    { 0x00004440, 0x01000000, 0x00280100, 0x00000028, 0x00200000, 0x01284000, 0x01ca1640, 0x00b00008 },
    /* 551  VEC_ADD      L17_XSSBlock_17_ss2d_CrossMerge            17 accumulate dir1                 in: g_y@WORK+296, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 256->256 40x40  sh 0,0,0,0  flags 72 misc 0548  prm 0+0 */
    { 0x00007212, 0x01000000, 0x00280100, 0x00000028, 0x00400128, 0x00005000, 0x00000050, 0x05480000 },
    /* 552  SETK 2 */
    { 0x00000003, 0x00020000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 553  LOOP GROUP n=200 body=4 */
    { 0x00000001, 0x00c80000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 554  GEMM         L17_XSSBlock_14_ss2d_XProj                 14 XProj dir2                      in: X@X+0                                                        out: g_xp@WORK+256                    frame        C 256->40 40x40  sh 0,0,0,0  flags 30 misc 0090  prm 116063+320 L17_XSSBlock_14_ss2d_XProj:dir2 */
    { 0x00003020, 0x01000000, 0x00280028, 0x00000028, 0x00200000, 0x01000000, 0x01c55f40, 0x00900140 },
    /* 555  GEMM         L17_XSSBlock_15_ss2d_DtProj                15 DtProj dir2 (+ReLU)             in: g_xp@WORK+256                                                out: g_delta@WORK+0                   frame        C 8->256 40x40  sh 0,0,0,5  flags 31 misc 0088  prm 116925+64 L17_XSSBlock_15_ss2d_DtProj:dir2 */
    { 0x00003120, 0x00080500, 0x00280100, 0x00000028, 0x00400100, 0x00000000, 0x01c8bd40, 0x00880040 },
    /* 556  SCAN         L17_XSSBlock_16_ss2d_SelectiveScan         16 scan dir2                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+296                     frame        C 256->256 40x40  sh 0,0,0,0  flags 44 misc 00b0  prm 117407+8 L17_XSSBlock_16_ss2d_SelectiveScan:dir2 */
    { 0x00004440, 0x01000000, 0x00280100, 0x00000028, 0x00200000, 0x01284000, 0x01ca9f40, 0x00b00008 },
    /* 557  VEC_ADD      L17_XSSBlock_17_ss2d_CrossMerge            17 accumulate dir2                 in: g_y@WORK+296, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 256->256 40x40  sh 0,0,0,0  flags 72 misc 0548  prm 0+0 */
    { 0x00007212, 0x01000000, 0x00280100, 0x00000028, 0x00400128, 0x00005000, 0x00000050, 0x05480000 },
    /* 558  SETK 3 */
    { 0x00000003, 0x00030000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 559  LOOP GROUP n=200 body=4 */
    { 0x00000001, 0x00c80000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 560  GEMM         L17_XSSBlock_14_ss2d_XProj                 14 XProj dir3                      in: X@X+0                                                        out: g_xp@WORK+256                    frame        C 256->40 40x40  sh 0,0,0,0  flags 30 misc 0090  prm 116390+320 L17_XSSBlock_14_ss2d_XProj:dir3 */
    { 0x00003020, 0x01000000, 0x00280028, 0x00000028, 0x00200000, 0x01000000, 0x01c6a640, 0x00900140 },
    /* 561  GEMM         L17_XSSBlock_15_ss2d_DtProj                15 DtProj dir3 (+ReLU)             in: g_xp@WORK+256                                                out: g_delta@WORK+0                   frame        C 8->256 40x40  sh 0,0,0,5  flags 31 misc 0088  prm 117029+64 L17_XSSBlock_15_ss2d_DtProj:dir3 */
    { 0x00003120, 0x00080500, 0x00280100, 0x00000028, 0x00400100, 0x00000000, 0x01c92540, 0x00880040 },
    /* 562  SCAN         L17_XSSBlock_16_ss2d_SelectiveScan         16 scan dir3                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+296                     frame        C 256->256 40x40  sh 0,0,0,0  flags 44 misc 00b0  prm 117544+8 L17_XSSBlock_16_ss2d_SelectiveScan:dir3 */
    { 0x00004440, 0x01000000, 0x00280100, 0x00000028, 0x00200000, 0x01284000, 0x01cb2840, 0x00b00008 },
    /* 563  VEC_ADD      L17_XSSBlock_17_ss2d_CrossMerge            17 accumulate dir3                 in: g_y@WORK+296, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 256->256 40x40  sh 0,0,0,0  flags 72 misc 0548  prm 0+0 */
    { 0x00007212, 0x01000000, 0x00280100, 0x00000028, 0x00400128, 0x00005000, 0x00000050, 0x05480000 },
    /* 564  LOOP TILE n=0 body=0 */
    { 0x00000001, 0x00000000, 0x00000017, 0x00000028, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 565  VEC_RQ       L17_XSSBlock_17_ss2d_CrossMerge            17' ACC -> int8                    in: ACC@ACC+0(w)                                                 out: t17@WORK+0(rel)                  rows[-1,9)   C 256->256 40x40  sh 0,0,0,0  flags 30 misc 8200  prm 0+0 */
    { 0x00003010, 0x01000000, 0x00280100, 0x09ff0028, 0x00500000, 0x00000000, 0x00000040, 0x82000000 },
    /* 566  VEC_LN       L17_XSSBlock_18_ss2d_out_norm_LightNorm    18 out_norm                        in: t17@WORK+0(rel)                                              out: t18@WORK+15360(rel)              rows[-1,9)   C 256->256 40x40  sh 0,0,20,17  flags 30 misc a000  prm 117681+0 */
    { 0x00003014, 0x01001114, 0x00280100, 0x09ff0028, 0x00400000, 0x3c000000, 0x01cbb140, 0xa0000000 },
    /* 567  GEMM         L17_XSSBlock_01_in_proj_Conv2d             01 (recompute)                     in: L15.out@B+0, S11@SKIP+89600                                  out: r01@WORK+0(rel)                  rows[-2,10)  C 64->128 40x40  sh -1,1,0,0  flags 70 misc 8000  prm 111197+128 L17_XSSBlock_01_in_proj_Conv2d */
    { 0x01ff7020, 0x00400000, 0x00280080, 0x0afe0028, 0x00100000, 0x0000315e, 0x01b25d40, 0x80000080 },
    /* 568  VEC_SILU     L17_XSSBlock_02_in_proj_SiLU               02 = r (recompute)                 in: r01@WORK+0(rel)                                              out: r02@WORK+7680(rel)               rows[-2,10)  C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 22273+0 */
    { 0x00003011, 0x00800000, 0x00280080, 0x0afe0028, 0x00400000, 0x1e000000, 0x00570140, 0xa0000000 },
    /* 569  DW           L17_XSSBlock_03_ls_fc1_DWConv2d            03 (recompute)                     in: r02@WORK+7680(rel)                                           out: r03@WORK+0(rel)                  rows[-2,10)  C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 111985+0 L17_XSSBlock_03_ls_fc1_DWConv2d */
    { 0x00003030, 0x00800000, 0x00280080, 0x0afe0028, 0x00401e00, 0x00000000, 0x01b57140, 0xa0000000 },
    /* 570  GEMM         L17_XSSBlock_04_ls_fc2_Conv2d              04 (recompute)                     in: r03@WORK+0(rel)                                              out: r04@WORK+30720(rel)              rows[-1,9)   C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 112049+512 L17_XSSBlock_04_ls_fc2_Conv2d */
    { 0x00003020, 0x00800000, 0x00280080, 0x09ff0028, 0x00400000, 0x78000000, 0x01b5b140, 0xa0000200 },
    /* 571  VEC_SILU     L17_XSSBlock_05_ls_SiLU                    05 (recompute)                     in: r04@WORK+30720(rel)                                          out: r05@WORK+0(rel)                  rows[-1,9)   C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 521+0 */
    { 0x00003011, 0x00800000, 0x00280080, 0x09ff0028, 0x00407800, 0x00000000, 0x00020940, 0xa0000000 },
    /* 572  GEMM         L17_XSSBlock_06_ls_fc3_Conv2d              06 (recompute, X scratch)          in: r05@WORK+0(rel)                                              out: s06@X+0(rel)                     rows[-1,9)   C 128->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 112581+512 L17_XSSBlock_06_ls_fc3_Conv2d */
    { 0x00003020, 0x00800000, 0x00280080, 0x09ff0028, 0x00400000, 0x00000000, 0x01b7c520, 0xa0000200 },
    /* 573  VEC_ADD      L17_XSSBlock_07_ls_Add                     07 (recompute)                     in: r02@WORK+7680(rel), s06@X+0(rel)                             out: r07@WORK+0(rel)                  rows[-1,9)   C 128->128 40x40  sh -1,0,1,0  flags 70 misc e000  prm 0+0 */
    { 0x00ff7012, 0x00800001, 0x00280080, 0x09ff0028, 0x00401e00, 0x00002000, 0x00000040, 0xe0000000 },
    /* 574  VEC_LN       L17_XSSBlock_08_norm_LightNorm             08 (recompute)                     in: r07@WORK+0(rel)                                              out: r08@WORK+30720(rel)              rows[-1,9)   C 128->128 40x40  sh 0,0,21,19  flags 30 misc a000  prm 113113+0 */
    { 0x00003014, 0x00801315, 0x00280080, 0x09ff0028, 0x00400000, 0x78000000, 0x01b9d940, 0xa0000000 },
    /* 575  GEMM         L17_XSSBlock_09_ss2d_in_proj_Conv2d        09 in_proj z half (recompute)      in: r08@WORK+30720(rel)                                          out: r09z@WORK+38400(rel)             rows[-1,9)   C 128->256 40x40  sh 0,0,0,0  flags 30 misc a000  prm 114217+1024 L17_XSSBlock_09_ss2d_in_proj_Conv2d:z */
    { 0x00003020, 0x00800000, 0x00280100, 0x09ff0028, 0x00407800, 0x96000000, 0x01be2940, 0xa0000400 },
    /* 576  VEC_SILU     L17_XSSBlock_10_ss2d_SiLU_z                10 = z (X scratch)                 in: r09z@WORK+38400(rel)                                         out: s10z@X+0(rel)                    rows[-1,9)   C 256->256 40x40  sh 0,0,0,0  flags 30 misc a000  prm 521+0 */
    { 0x00003011, 0x01000000, 0x00280100, 0x09ff0028, 0x00409600, 0x00000000, 0x00020920, 0xa0000000 },
    /* 577  VEC_MUL      L17_XSSBlock_19_ss2d_Mul                   19 gate -> requant to 20           in: t18@WORK+15360(rel), s10z@X+0(rel)                           out: t19@WORK+30720(rel)              rows[-1,9)   C 256->256 40x40  sh 0,0,3,0  flags 70 misc e000  prm 0+0 */
    { 0x00007013, 0x01000003, 0x00280100, 0x09ff0028, 0x00403c00, 0x78002000, 0x00000040, 0xe0000000 },
    /* 578  GEMM         L17_XSSBlock_20_ss2d_out_proj_Conv2d       20 out_proj (X scratch)            in: t19@WORK+30720(rel)                                          out: s20@X+0(rel)                     rows[-1,9)   C 256->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 117729+1024 L17_XSSBlock_20_ss2d_out_proj_Conv2d */
    { 0x00003020, 0x01000000, 0x00280080, 0x09ff0028, 0x00407800, 0x00000000, 0x01cbe120, 0xa0000400 },
    /* 579  VEC_ADD      L17_XSSBlock_21_Add                        21 Add (wide, kept)                in: r02@WORK+7680(rel), s20@X+0(rel)                             out: t21@WORK+15360(rel)(w)           rows[-1,9)   C 128->128 40x40  sh -1,0,0,0  flags 72 misc e000  prm 0+0 */
    { 0x00ff7212, 0x00800000, 0x00280080, 0x09ff0028, 0x00401e00, 0x3c002000, 0x00000040, 0xe0000000 },
    /* 580  VEC_LN       L17_XSSBlock_22_norm2_LightNorm            22 norm2                           in: t21@WORK+15360(rel)(w)                                       out: t22@WORK+0(rel)                  rows[-1,9)   C 128->128 40x40  sh 1,0,22,19  flags 30 misc a200  prm 118773+0 */
    { 0x00013014, 0x00801316, 0x00280080, 0x09ff0028, 0x00403c00, 0x00000000, 0x01cff540, 0xa2000000 },
    /* 581  GEMM         L17_XSSBlock_23_mlp_fc1_Conv2d             23 fc1 x half (X scratch)          in: t22@WORK+0(rel)                                              out: s23x@X+0(rel)                    rows[-1,9)   C 128->341 40x40  sh 0,0,0,0  flags 30 misc a000  prm 118813+1376 L17_XSSBlock_23_mlp_fc1_Conv2d:x */
    { 0x00003020, 0x00800000, 0x00280155, 0x09ff0028, 0x00400000, 0x00000000, 0x01d01d20, 0xa0000560 },
    /* 582  GEMM         L17_XSSBlock_23_mlp_fc1_Conv2d             23 fc1 v half (X scratch)          in: t22@WORK+0(rel)                                              out: s23v@X+20640(rel)                rows[-1,9)   C 128->341 40x40  sh 0,0,0,0  flags 30 misc a000  prm 120243+1376 L17_XSSBlock_23_mlp_fc1_Conv2d:v */
    { 0x00003020, 0x00800000, 0x00280155, 0x09ff0028, 0x00400000, 0x50a00000, 0x01d5b320, 0xa0000560 },
    /* 583  DW           L17_XSSBlock_24_mlp_DWConv2d               24 DW                              in: s23x@X+0(rel)                                                out: t24@WORK+30720(rel)              rows[-1,9)   C 341->341 40x40  sh 0,0,0,0  flags 30 misc a000  prm 121673+0 L17_XSSBlock_24_mlp_DWConv2d */
    { 0x00003030, 0x01550000, 0x00280155, 0x09ff0028, 0x00200000, 0x78000000, 0x01db4940, 0xa0000000 },
    /* 584  VEC_ADD      L17_XSSBlock_26_mlp_SiLU                   25 Add -> 26 SiLU (fused)          in: t24@WORK+30720(rel), s23x@X+0(rel)                           out: t26@WORK+51360(rel)              rows[0,8)    C 341->341 40x40  sh 0,0,1,0  flags f0 misc e000  prm 93237+0 */
    { 0x0000f012, 0x01550001, 0x00280155, 0x08000028, 0x00407800, 0xc8a02000, 0x016c3540, 0xe0000000 },
    /* 585  VEC_MUL      L17_XSSBlock_27_mlp_Mul                    27 Mul -> requant to 28            in: t26@WORK+51360(rel), s23v@X+20640(rel)                       out: t27@WORK+30720(rel)              rows[0,8)    C 341->341 40x40  sh 0,0,5,0  flags 70 misc e000  prm 0+0 */
    { 0x00007013, 0x01550005, 0x00280155, 0x08000028, 0xa040c8a0, 0x78002050, 0x00000040, 0xe0000000 },
    /* 586  GEMM         L17_XSSBlock_28_mlp_fc2_Conv2d             28 fc2 (X scratch)                 in: t27@WORK+30720(rel)                                          out: s28@X+0(rel)                     rows[0,8)    C 341->128 40x40  sh 0,0,0,0  flags 30 misc a000  prm 121845+1376 L17_XSSBlock_28_mlp_fc2_Conv2d */
    { 0x00003020, 0x01550000, 0x00280080, 0x08000028, 0x00407800, 0x00000000, 0x01dbf520, 0xa0000560 },
    /* 587  VEC_ADD      L17_XSSBlock_29_Add                        29 Add -> block output             in: t21@WORK+15360(rel)(w), s28@X+0(rel)                         out: L17_XSSBlock_01.out@A+0          rows[0,8)    C 128->128 40x40  sh 0,-1,1,0  flags 70 misc 6200  prm 0+0 */
    { 0xff007012, 0x00800001, 0x00280080, 0x08000028, 0x00403c00, 0x00002000, 0x00000000, 0x62000000 },
    /* 588  LOOP TILE n=5 body=0 */
    { 0x00000001, 0x00050000, 0x0000000e, 0x00000028, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 589  GEMM         L21_Detect1_01_box_Conv2d                  head1 01 box 3x3                   in: L17_XSSBlock_01.out@A+0                                      out: t01@WORK+0(rel)                  rows[-1,9)   C 128->64 40x40  sh 0,0,0,0  flags 30 misc 8001  prm 176734+2304 L21_Detect1_01_box_Conv2d */
    { 0x00003020, 0x00800000, 0x00280040, 0x09ff0028, 0x00000000, 0x00000000, 0x02b25e40, 0x80010900 },
    /* 590  VEC_SILU     L21_Detect1_02_box_SiLU                    head1 02 SiLU                      in: t01@WORK+0(rel)                                              out: t02@WORK+3840(rel)               rows[-1,9)   C 64->64 40x40  sh 0,0,0,0  flags 30 misc a000  prm 1508+0 */
    { 0x00003011, 0x00400000, 0x00280040, 0x09ff0028, 0x00400000, 0x0f000000, 0x0005e440, 0xa0000000 },
    /* 591  GEMM         L21_Detect1_03_box_Conv2d                  head1 03 box 3x3                   in: t02@WORK+3840(rel)                                           out: t03@WORK+0(rel)                  rows[0,8)    C 64->64 40x40  sh 0,0,0,0  flags 30 misc a001  prm 179048+1152 L21_Detect1_03_box_Conv2d */
    { 0x00003020, 0x00400000, 0x00280040, 0x08000028, 0x00400f00, 0x00000000, 0x02bb6840, 0xa0010480 },
    /* 592  VEC_SILU     L21_Detect1_04_box_SiLU                    head1 04 SiLU                      in: t03@WORK+0(rel)                                              out: t04@WORK+3840(rel)               rows[0,8)    C 64->64 40x40  sh 0,0,0,0  flags 30 misc a000  prm 1508+0 */
    { 0x00003011, 0x00400000, 0x00280040, 0x08000028, 0x00400000, 0x0f000000, 0x0005e440, 0xa0000000 },
    /* 593  GEMM         L21_Detect1_05_box_Conv2d                  head1 05 box 1x1 (64)              in: t04@WORK+3840(rel)                                           out: t05@WORK+0(rel)                  rows[0,8)    C 64->64 40x40  sh 0,0,0,0  flags 30 misc a000  prm 180210+128 L21_Detect1_05_box_Conv2d */
    { 0x00003020, 0x00400000, 0x00280040, 0x08000028, 0x00400f00, 0x00000000, 0x02bff240, 0xa0000080 },
    /* 594  GEMM         L21_Detect1_06_cls_Conv2d                  head1 06 cls 3x3                   in: L17_XSSBlock_01.out@A+0                                      out: t06@WORK+3840(rel)               rows[-1,9)   C 128->80 40x40  sh 0,0,0,0  flags 30 misc 8001  prm 180348+2880 L21_Detect1_06_cls_Conv2d */
    { 0x00003020, 0x00800000, 0x00280050, 0x09ff0028, 0x00000000, 0x0f000000, 0x02c07c40, 0x80010b40 },
    /* 595  VEC_SILU     L21_Detect1_07_cls_SiLU                    head1 07 SiLU                      in: t06@WORK+3840(rel)                                           out: t07@WORK+8640(rel)               rows[-1,9)   C 80->80 40x40  sh 0,0,0,0  flags 30 misc a000  prm 93237+0 */
    { 0x00003011, 0x00500000, 0x00280050, 0x09ff0028, 0x00400f00, 0x21c00000, 0x016c3540, 0xa0000000 },
    /* 596  GEMM         L21_Detect1_08_cls_Conv2d                  head1 08 cls 3x3                   in: t07@WORK+8640(rel)                                           out: t08@WORK+3840(rel)               rows[0,8)    C 80->80 40x40  sh 0,0,0,0  flags 30 misc a001  prm 183241+1800 L21_Detect1_08_cls_Conv2d */
    { 0x00003020, 0x00500000, 0x00280050, 0x08000028, 0x004021c0, 0x0f000000, 0x02cbc940, 0xa0010708 },
    /* 597  VEC_SILU     L21_Detect1_09_cls_SiLU                    head1 09 SiLU                      in: t08@WORK+3840(rel)                                           out: t09@WORK+8640(rel)               rows[0,8)    C 80->80 40x40  sh 0,0,0,0  flags 30 misc a000  prm 185054+0 */
    { 0x00003011, 0x00500000, 0x00280050, 0x08000028, 0x00400f00, 0x21c00000, 0x02d2de40, 0xa0000000 },
    /* 598  GEMM         L21_Detect1_10_cls_Conv2d                  head1 10 cls 1x1 (80)              in: t09@WORK+8640(rel)                                           out: t10@WORK+3840(rel)               rows[0,8)    C 80->80 40x40  sh 0,0,0,0  flags 30 misc a000  prm 185062+200 L21_Detect1_10_cls_Conv2d */
    { 0x00003020, 0x00500000, 0x00280050, 0x08000028, 0x004021c0, 0x0f000000, 0x02d2e640, 0xa00000c8 },
    /* 599  VEC_RQ       L21_Detect1_05_box_Conv2d                  head1 box -> hd ch [0, 64)         in: t05@WORK+0(rel)                                              out: hd.box@WORK+8640(rel)            rows[0,8)    C 64->192 40x40  sh 0,0,0,0  flags 30 misc a000  prm 0+0 */
    { 0x00003010, 0x00400000, 0x002800c0, 0x08000028, 0x00400000, 0x21c00000, 0x00000040, 0xa0000000 },
    /* 600  VEC_RQ       L21_Detect1_10_cls_Conv2d                  head1 cls -> hd ch [64, 144)       in: t10@WORK+3840(rel)                                           out: hd.cls@WORK+8648(rel)            rows[0,8)    C 80->192 40x40  sh 0,0,0,0  flags 30 misc a000  prm 0+0 */
    { 0x00003010, 0x00500000, 0x002800c0, 0x08000028, 0x00400f00, 0x21c80000, 0x00000040, 0xa0000000 },
    /* 601  VEC_RQ                                                  head1 zero -> hd ch [144, 192)     in: L17_XSSBlock_01.out@A+0                                      out: hd.zero@WORK+8658(rel)           rows[0,8)    C 48->192 40x40  sh 16,0,0,0  flags 30 misc 8000  prm 0+0 */
    { 0x00103010, 0x00300000, 0x002800c0, 0x08000028, 0x00000000, 0x21d20000, 0x00000040, 0x80000000 },
    /* 602  VEC_OUTROWS  L21_Detect1_hd                             P4 <- head1 hd (rows = pixels x 3) in: hd@WORK+8640(rel)                                            out: OUT.P4@OUT+262144                rows[0,8)    C 192->192 40x40  sh 0,0,0,0  flags 30 misc 2000  prm 0+0 */
    { 0x00003017, 0x00c00000, 0x002800c0, 0x08000028, 0x004021c0, 0x00000000, 0x00000064, 0x20000000 },
    /* 603  GEMM         L18_Conv_01_conv_Conv2d                    Conv 3x3 s2                        in: L17_XSSBlock_01.out@A+0                                      out: conv@WORK+0                      frame        C 128->128 40x40  sh 0,0,0,0  flags 30 misc 0002  prm 123241+4608 L18_Conv_01_conv_Conv2d */
    { 0x00003020, 0x00800000, 0x00280080, 0x00000028, 0x00000000, 0x00000000, 0x01e16940, 0x00021200 },
    /* 604  VEC_SILU     L18_Conv_02_SiLU                           SiLU -> layer out                  in: conv@WORK+0                                                  out: L18.out@B+0                      frame        C 128->128 20x20  sh 0,0,0,0  flags 30 misc 0000  prm 127869+0 */
    { 0x00003011, 0x00800000, 0x00140080, 0x00000014, 0x00400000, 0x00000000, 0x01f37d10, 0x00000000 },
    /* 605  LOOP TILE n=0 body=0 */
    { 0x00000001, 0x00000000, 0x0000000b, 0x00000014, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 606  GEMM         L20_XSSBlock_01_in_proj_Conv2d             01 proj                            in: L18.out@B+0, S8@SKIP+76800                                   out: t01@WORK+0(rel)                  rows[-2,10)  C 128->256 20x20  sh 0,1,0,0  flags 70 misc 8000  prm 127877+256 L20_XSSBlock_01_in_proj_Conv2d */
    { 0x01007020, 0x00800000, 0x00140100, 0x0afe0014, 0x00100000, 0x0000312c, 0x01f38540, 0x80000100 },
    /* 607  VEC_SILU     L20_XSSBlock_02_in_proj_SiLU               02 SiLU                            in: t01@WORK+0(rel)                                              out: t02@WORK+7680(rel)               rows[-2,10)  C 256->256 20x20  sh 0,0,0,0  flags 30 misc a000  prm 2013+0 */
    { 0x00003011, 0x01000000, 0x00140100, 0x0afe0014, 0x00400000, 0x1e000000, 0x0007dd40, 0xa0000000 },
    /* 608  DW           L20_XSSBlock_03_ls_fc1_DWConv2d            03 DW                              in: t02@WORK+7680(rel)                                           out: t03@WORK+0(rel)                  rows[-2,10)  C 256->256 20x20  sh 0,0,0,0  flags 30 misc a000  prm 130989+0 L20_XSSBlock_03_ls_fc1_DWConv2d */
    { 0x00003030, 0x01000000, 0x00140100, 0x0afe0014, 0x00401e00, 0x00000000, 0x01ffad40, 0xa0000000 },
    /* 609  GEMM         L20_XSSBlock_04_ls_fc2_Conv2d              04                                 in: t03@WORK+0(rel)                                              out: t04@WORK+15360(rel)              rows[-1,9)   C 256->256 20x20  sh 0,0,0,0  flags 30 misc a000  prm 131117+2048 L20_XSSBlock_04_ls_fc2_Conv2d */
    { 0x00003020, 0x01000000, 0x00140100, 0x09ff0014, 0x00400000, 0x3c000000, 0x02002d40, 0xa0000800 },
    /* 610  VEC_SILU     L20_XSSBlock_05_ls_SiLU                    05 SiLU                            in: t04@WORK+15360(rel)                                          out: t05@WORK+0(rel)                  rows[-1,9)   C 256->256 20x20  sh 0,0,0,0  flags 30 misc a000  prm 2013+0 */
    { 0x00003011, 0x01000000, 0x00140100, 0x09ff0014, 0x00403c00, 0x00000000, 0x0007dd40, 0xa0000000 },
    /* 611  GEMM         L20_XSSBlock_06_ls_fc3_Conv2d              06 (scratch)                       in: t05@WORK+0(rel)                                              out: s06@A+0(rel)                     rows[-1,9)   C 256->256 20x20  sh 0,0,0,0  flags 30 misc a000  prm 133205+2048 L20_XSSBlock_06_ls_fc3_Conv2d */
    { 0x00003020, 0x01000000, 0x00140100, 0x09ff0014, 0x00400000, 0x00000000, 0x02085500, 0xa0000800 },
    /* 612  VEC_ADD      L20_XSSBlock_07_ls_Add                     07 Add -> requant to 08            in: t02@WORK+7680(rel), s06@A+0(rel)                             out: t07@WORK+0(rel)                  rows[-1,9)   C 256->256 20x20  sh -2,0,2,0  flags 70 misc e000  prm 0+0 */
    { 0x00fe7012, 0x01000002, 0x00140100, 0x09ff0014, 0x00401e00, 0x00000000, 0x00000040, 0xe0000000 },
    /* 613  VEC_LN       L20_XSSBlock_08_norm_LightNorm             08 LightNorm                       in: t07@WORK+0(rel)                                              out: t08@WORK+7680(rel)               rows[-1,9)   C 256->256 20x20  sh 0,0,21,18  flags 30 misc a000  prm 135293+0 */
    { 0x00003014, 0x01001215, 0x00140100, 0x09ff0014, 0x00400000, 0x1e000000, 0x02107d40, 0xa0000000 },
    /* 614  GEMM         L20_XSSBlock_09_ss2d_in_proj_Conv2d        09 in_proj x half                  in: t08@WORK+7680(rel)                                           out: t09x@WORK+15360(rel)             rows[-1,9)   C 256->512 20x20  sh 0,0,0,0  flags 30 misc a000  prm 135341+4096 L20_XSSBlock_09_ss2d_in_proj_Conv2d:x */
    { 0x00003020, 0x01000000, 0x00140200, 0x09ff0014, 0x00401e00, 0x3c000000, 0x0210ad40, 0xa0001000 },
    /* 615  DW           L20_XSSBlock_11_ss2d_DWConv2d              11 DW                              in: t09x@WORK+15360(rel)                                         out: t11@WORK+0(rel)                  rows[-1,9)   C 512->512 20x20  sh 0,0,0,0  flags 30 misc a000  prm 143693+0 L20_XSSBlock_11_ss2d_DWConv2d */
    { 0x00003030, 0x02000000, 0x00140200, 0x09ff0014, 0x00403c00, 0x00000000, 0x02314d40, 0xa0000000 },
    /* 616  VEC_SILU     L20_XSSBlock_12_ss2d_SiLU_x                12 SiLU -> X                       in: t11@WORK+0(rel)                                              out: X@X+0                            rows[0,8)    C 512->512 20x20  sh 0,0,0,0  flags 30 misc 2000  prm 22273+0 */
    { 0x00003011, 0x02000000, 0x00140200, 0x08000014, 0x00400000, 0x00000000, 0x00570120, 0x20000000 },
    /* 617  SETK 0 */
    { 0x00000003, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 618  LOOP GROUP n=50 body=4 */
    { 0x00000001, 0x00320000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 619  GEMM         L20_XSSBlock_14_ss2d_XProj                 14 XProj dir0                      in: X@X+0                                                        out: g_xp@WORK+512                    frame        C 512->48 20x20  sh 0,0,0,0  flags 30 misc 0090  prm 143949+768 L20_XSSBlock_14_ss2d_XProj:dir0 */
    { 0x00003020, 0x02000000, 0x00140030, 0x00000014, 0x00200000, 0x02000000, 0x02324d40, 0x00900300 },
    /* 620  GEMM         L20_XSSBlock_15_ss2d_DtProj                15 DtProj dir0 (+ReLU)             in: g_xp@WORK+512                                                out: g_delta@WORK+0                   frame        C 16->512 20x20  sh 0,0,0,6  flags 31 misc 0088  prm 147053+256 L20_XSSBlock_15_ss2d_DtProj:dir0 */
    { 0x00003120, 0x00100600, 0x00140200, 0x00000014, 0x00400200, 0x00000000, 0x023e6d40, 0x00880100 },
    /* 621  SCAN         L20_XSSBlock_16_ss2d_SelectiveScan         16 scan dir0                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+560                     frame        C 512->512 20x20  sh 0,0,0,0  flags 44 misc 00b0  prm 148397+16 L20_XSSBlock_16_ss2d_SelectiveScan:dir0 */
    { 0x00004440, 0x02000000, 0x00140200, 0x00000014, 0x00200000, 0x02304000, 0x0243ad40, 0x00b00010 },
    /* 622  VEC_ADD      L20_XSSBlock_17_ss2d_CrossMerge            17 accumulate dir0                 in: g_y@WORK+560, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 512->512 20x20  sh 0,0,0,0  flags 7a misc 0548  prm 0+0 */
    { 0x00007a12, 0x02000000, 0x00140200, 0x00000014, 0x00400230, 0x00005000, 0x00000050, 0x05480000 },
    /* 623  SETK 1 */
    { 0x00000003, 0x00010000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 624  LOOP GROUP n=50 body=4 */
    { 0x00000001, 0x00320000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 625  GEMM         L20_XSSBlock_14_ss2d_XProj                 14 XProj dir1                      in: X@X+0                                                        out: g_xp@WORK+512                    frame        C 512->48 20x20  sh 0,0,0,0  flags 30 misc 0090  prm 144725+768 L20_XSSBlock_14_ss2d_XProj:dir1 */
    { 0x00003020, 0x02000000, 0x00140030, 0x00000014, 0x00200000, 0x02000000, 0x02355540, 0x00900300 },
    /* 626  GEMM         L20_XSSBlock_15_ss2d_DtProj                15 DtProj dir1 (+ReLU)             in: g_xp@WORK+512                                                out: g_delta@WORK+0                   frame        C 16->512 20x20  sh 0,0,0,6  flags 31 misc 0088  prm 147389+256 L20_XSSBlock_15_ss2d_DtProj:dir1 */
    { 0x00003120, 0x00100600, 0x00140200, 0x00000014, 0x00400200, 0x00000000, 0x023fbd40, 0x00880100 },
    /* 627  SCAN         L20_XSSBlock_16_ss2d_SelectiveScan         16 scan dir1                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+560                     frame        C 512->512 20x20  sh 0,0,0,0  flags 44 misc 00b0  prm 148670+16 L20_XSSBlock_16_ss2d_SelectiveScan:dir1 */
    { 0x00004440, 0x02000000, 0x00140200, 0x00000014, 0x00200000, 0x02304000, 0x0244be40, 0x00b00010 },
    /* 628  VEC_ADD      L20_XSSBlock_17_ss2d_CrossMerge            17 accumulate dir1                 in: g_y@WORK+560, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 512->512 20x20  sh 0,0,0,0  flags 72 misc 0548  prm 0+0 */
    { 0x00007212, 0x02000000, 0x00140200, 0x00000014, 0x00400230, 0x00005000, 0x00000050, 0x05480000 },
    /* 629  SETK 2 */
    { 0x00000003, 0x00020000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 630  LOOP GROUP n=50 body=4 */
    { 0x00000001, 0x00320000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 631  GEMM         L20_XSSBlock_14_ss2d_XProj                 14 XProj dir2                      in: X@X+0                                                        out: g_xp@WORK+512                    frame        C 512->48 20x20  sh 0,0,0,0  flags 30 misc 0090  prm 145501+768 L20_XSSBlock_14_ss2d_XProj:dir2 */
    { 0x00003020, 0x02000000, 0x00140030, 0x00000014, 0x00200000, 0x02000000, 0x02385d40, 0x00900300 },
    /* 632  GEMM         L20_XSSBlock_15_ss2d_DtProj                15 DtProj dir2 (+ReLU)             in: g_xp@WORK+512                                                out: g_delta@WORK+0                   frame        C 16->512 20x20  sh 0,0,0,6  flags 31 misc 0088  prm 147725+256 L20_XSSBlock_15_ss2d_DtProj:dir2 */
    { 0x00003120, 0x00100600, 0x00140200, 0x00000014, 0x00400200, 0x00000000, 0x02410d40, 0x00880100 },
    /* 633  SCAN         L20_XSSBlock_16_ss2d_SelectiveScan         16 scan dir2                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+560                     frame        C 512->512 20x20  sh 0,0,0,0  flags 44 misc 00b0  prm 148943+16 L20_XSSBlock_16_ss2d_SelectiveScan:dir2 */
    { 0x00004440, 0x02000000, 0x00140200, 0x00000014, 0x00200000, 0x02304000, 0x0245cf40, 0x00b00010 },
    /* 634  VEC_ADD      L20_XSSBlock_17_ss2d_CrossMerge            17 accumulate dir2                 in: g_y@WORK+560, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 512->512 20x20  sh 0,0,0,0  flags 72 misc 0548  prm 0+0 */
    { 0x00007212, 0x02000000, 0x00140200, 0x00000014, 0x00400230, 0x00005000, 0x00000050, 0x05480000 },
    /* 635  SETK 3 */
    { 0x00000003, 0x00030000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 636  LOOP GROUP n=50 body=4 */
    { 0x00000001, 0x00320000, 0x00000004, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00020000 },
    /* 637  GEMM         L20_XSSBlock_14_ss2d_XProj                 14 XProj dir3                      in: X@X+0                                                        out: g_xp@WORK+512                    frame        C 512->48 20x20  sh 0,0,0,0  flags 30 misc 0090  prm 146277+768 L20_XSSBlock_14_ss2d_XProj:dir3 */
    { 0x00003020, 0x02000000, 0x00140030, 0x00000014, 0x00200000, 0x02000000, 0x023b6540, 0x00900300 },
    /* 638  GEMM         L20_XSSBlock_15_ss2d_DtProj                15 DtProj dir3 (+ReLU)             in: g_xp@WORK+512                                                out: g_delta@WORK+0                   frame        C 16->512 20x20  sh 0,0,0,6  flags 31 misc 0088  prm 148061+256 L20_XSSBlock_15_ss2d_DtProj:dir3 */
    { 0x00003120, 0x00100600, 0x00140200, 0x00000014, 0x00400200, 0x00000000, 0x02425d40, 0x00880100 },
    /* 639  SCAN         L20_XSSBlock_16_ss2d_SelectiveScan         16 scan dir3                       in: X@X+0, g_delta@WORK+0                                        out: g_y@WORK+560                     frame        C 512->512 20x20  sh 0,0,0,0  flags 44 misc 00b0  prm 149216+16 L20_XSSBlock_16_ss2d_SelectiveScan:dir3 */
    { 0x00004440, 0x02000000, 0x00140200, 0x00000014, 0x00200000, 0x02304000, 0x0246e040, 0x00b00010 },
    /* 640  VEC_ADD      L20_XSSBlock_17_ss2d_CrossMerge            17 accumulate dir3                 in: g_y@WORK+560, ACC@ACC+0(w)                                   out: ACC@ACC+0(w)                     frame        C 512->512 20x20  sh -1,0,0,0  flags 72 misc 0548  prm 0+0 */
    { 0x00ff7212, 0x02000000, 0x00140200, 0x00000014, 0x00400230, 0x00005000, 0x00000050, 0x05480000 },
    /* 641  LOOP TILE n=0 body=0 */
    { 0x00000001, 0x00000000, 0x00000017, 0x00000014, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 642  VEC_RQ       L20_XSSBlock_17_ss2d_CrossMerge            17' ACC -> int8                    in: ACC@ACC+0(w)                                                 out: t17@WORK+0(rel)                  rows[-1,9)   C 512->512 20x20  sh 1,0,0,0  flags 30 misc 8200  prm 0+0 */
    { 0x00013010, 0x02000000, 0x00140200, 0x09ff0014, 0x00500000, 0x00000000, 0x00000040, 0x82000000 },
    /* 643  VEC_LN       L20_XSSBlock_18_ss2d_out_norm_LightNorm    18 out_norm                        in: t17@WORK+0(rel)                                              out: t18@WORK+15360(rel)              rows[-1,9)   C 512->512 20x20  sh 0,0,21,17  flags 30 misc a000  prm 149489+0 */
    { 0x00003014, 0x02001115, 0x00140200, 0x09ff0014, 0x00400000, 0x3c000000, 0x0247f140, 0xa0000000 },
    /* 644  GEMM         L20_XSSBlock_01_in_proj_Conv2d             01 (recompute)                     in: L18.out@B+0, S8@SKIP+76800                                   out: r01@WORK+0(rel)                  rows[-2,10)  C 128->256 20x20  sh 0,1,0,0  flags 70 misc 8000  prm 127877+256 L20_XSSBlock_01_in_proj_Conv2d */
    { 0x01007020, 0x00800000, 0x00140100, 0x0afe0014, 0x00100000, 0x0000312c, 0x01f38540, 0x80000100 },
    /* 645  VEC_SILU     L20_XSSBlock_02_in_proj_SiLU               02 = r (recompute)                 in: r01@WORK+0(rel)                                              out: r02@WORK+7680(rel)               rows[-2,10)  C 256->256 20x20  sh 0,0,0,0  flags 30 misc a000  prm 2013+0 */
    { 0x00003011, 0x01000000, 0x00140100, 0x0afe0014, 0x00400000, 0x1e000000, 0x0007dd40, 0xa0000000 },
    /* 646  DW           L20_XSSBlock_03_ls_fc1_DWConv2d            03 (recompute)                     in: r02@WORK+7680(rel)                                           out: r03@WORK+0(rel)                  rows[-2,10)  C 256->256 20x20  sh 0,0,0,0  flags 30 misc a000  prm 130989+0 L20_XSSBlock_03_ls_fc1_DWConv2d */
    { 0x00003030, 0x01000000, 0x00140100, 0x0afe0014, 0x00401e00, 0x00000000, 0x01ffad40, 0xa0000000 },
    /* 647  GEMM         L20_XSSBlock_04_ls_fc2_Conv2d              04 (recompute)                     in: r03@WORK+0(rel)                                              out: r04@WORK+30720(rel)              rows[-1,9)   C 256->256 20x20  sh 0,0,0,0  flags 30 misc a000  prm 131117+2048 L20_XSSBlock_04_ls_fc2_Conv2d */
    { 0x00003020, 0x01000000, 0x00140100, 0x09ff0014, 0x00400000, 0x78000000, 0x02002d40, 0xa0000800 },
    /* 648  VEC_SILU     L20_XSSBlock_05_ls_SiLU                    05 (recompute)                     in: r04@WORK+30720(rel)                                          out: r05@WORK+0(rel)                  rows[-1,9)   C 256->256 20x20  sh 0,0,0,0  flags 30 misc a000  prm 2013+0 */
    { 0x00003011, 0x01000000, 0x00140100, 0x09ff0014, 0x00407800, 0x00000000, 0x0007dd40, 0xa0000000 },
    /* 649  GEMM         L20_XSSBlock_06_ls_fc3_Conv2d              06 (recompute, X scratch)          in: r05@WORK+0(rel)                                              out: s06@X+0(rel)                     rows[-1,9)   C 256->256 20x20  sh 0,0,0,0  flags 30 misc a000  prm 133205+2048 L20_XSSBlock_06_ls_fc3_Conv2d */
    { 0x00003020, 0x01000000, 0x00140100, 0x09ff0014, 0x00400000, 0x00000000, 0x02085520, 0xa0000800 },
    /* 650  VEC_ADD      L20_XSSBlock_07_ls_Add                     07 (recompute)                     in: r02@WORK+7680(rel), s06@X+0(rel)                             out: r07@WORK+0(rel)                  rows[-1,9)   C 256->256 20x20  sh -2,0,2,0  flags 70 misc e000  prm 0+0 */
    { 0x00fe7012, 0x01000002, 0x00140100, 0x09ff0014, 0x00401e00, 0x00002000, 0x00000040, 0xe0000000 },
    /* 651  VEC_LN       L20_XSSBlock_08_norm_LightNorm             08 (recompute)                     in: r07@WORK+0(rel)                                              out: r08@WORK+30720(rel)              rows[-1,9)   C 256->256 20x20  sh 0,0,21,18  flags 30 misc a000  prm 135293+0 */
    { 0x00003014, 0x01001215, 0x00140100, 0x09ff0014, 0x00400000, 0x78000000, 0x02107d40, 0xa0000000 },
    /* 652  GEMM         L20_XSSBlock_09_ss2d_in_proj_Conv2d        09 in_proj z half (recompute)      in: r08@WORK+30720(rel)                                          out: r09z@WORK+38400(rel)             rows[-1,9)   C 256->512 20x20  sh 0,0,0,0  flags 30 misc a000  prm 139517+4096 L20_XSSBlock_09_ss2d_in_proj_Conv2d:z */
    { 0x00003020, 0x01000000, 0x00140200, 0x09ff0014, 0x00407800, 0x96000000, 0x0220fd40, 0xa0001000 },
    /* 653  VEC_SILU     L20_XSSBlock_10_ss2d_SiLU_z                10 = z (X scratch)                 in: r09z@WORK+38400(rel)                                         out: s10z@X+0(rel)                    rows[-1,9)   C 512->512 20x20  sh -1,0,0,0  flags 30 misc a000  prm 22273+0 */
    { 0x00ff3011, 0x02000000, 0x00140200, 0x09ff0014, 0x00409600, 0x00000000, 0x00570120, 0xa0000000 },
    /* 654  VEC_MUL      L20_XSSBlock_19_ss2d_Mul                   19 gate -> requant to 20           in: t18@WORK+15360(rel), s10z@X+0(rel)                           out: t19@WORK+30720(rel)              rows[-1,9)   C 512->512 20x20  sh 0,0,5,0  flags 70 misc e000  prm 0+0 */
    { 0x00007013, 0x02000005, 0x00140200, 0x09ff0014, 0x00403c00, 0x78002000, 0x00000040, 0xe0000000 },
    /* 655  GEMM         L20_XSSBlock_20_ss2d_out_proj_Conv2d       20 out_proj (X scratch)            in: t19@WORK+30720(rel)                                          out: s20@X+0(rel)                     rows[-1,9)   C 512->256 20x20  sh 0,0,0,0  flags 30 misc a000  prm 149553+4096 L20_XSSBlock_20_ss2d_out_proj_Conv2d */
    { 0x00003020, 0x02000000, 0x00140100, 0x09ff0014, 0x00407800, 0x00000000, 0x02483120, 0xa0001000 },
    /* 656  VEC_ADD      L20_XSSBlock_21_Add                        21 Add (wide, kept)                in: r02@WORK+7680(rel), s20@X+0(rel)                             out: t21@WORK+15360(rel)(w)           rows[-1,9)   C 256->256 20x20  sh -1,0,0,0  flags 72 misc e000  prm 0+0 */
    { 0x00ff7212, 0x01000000, 0x00140100, 0x09ff0014, 0x00401e00, 0x3c002000, 0x00000040, 0xe0000000 },
    /* 657  VEC_LN       L20_XSSBlock_22_norm2_LightNorm            22 norm2                           in: t21@WORK+15360(rel)(w)                                       out: t22@WORK+0(rel)                  rows[-1,9)   C 256->256 20x20  sh 1,0,22,18  flags 30 misc a200  prm 153689+0 */
    { 0x00013014, 0x01001216, 0x00140100, 0x09ff0014, 0x00403c00, 0x00000000, 0x02585940, 0xa2000000 },
    /* 658  GEMM         L20_XSSBlock_23_mlp_fc1_Conv2d             23 fc1 x half (X scratch)          in: t22@WORK+0(rel)                                              out: s23x@X+0(rel)                    rows[-1,9)   C 256->682 20x20  sh 0,0,0,0  flags 30 misc a000  prm 153737+5472 L20_XSSBlock_23_mlp_fc1_Conv2d:x */
    { 0x00003020, 0x01000000, 0x001402aa, 0x09ff0014, 0x00400000, 0x00000000, 0x02588920, 0xa0001560 },
    /* 659  GEMM         L20_XSSBlock_23_mlp_fc1_Conv2d             23 fc1 v half (X scratch)          in: t22@WORK+0(rel)                                              out: s23v@X+20640(rel)                rows[-1,9)   C 256->682 20x20  sh 0,0,0,0  flags 30 misc a000  prm 159317+5472 L20_XSSBlock_23_mlp_fc1_Conv2d:v */
    { 0x00003020, 0x01000000, 0x001402aa, 0x09ff0014, 0x00400000, 0x50a00000, 0x026e5520, 0xa0001560 },
    /* 660  DW           L20_XSSBlock_24_mlp_DWConv2d               24 DW                              in: s23x@X+0(rel)                                                out: t24@WORK+30720(rel)              rows[-1,9)   C 682->682 20x20  sh 0,0,0,0  flags 30 misc a000  prm 164897+0 L20_XSSBlock_24_mlp_DWConv2d */
    { 0x00003030, 0x02aa0000, 0x001402aa, 0x09ff0014, 0x00200000, 0x78000000, 0x02842140, 0xa0000000 },
    /* 661  VEC_ADD      L20_XSSBlock_26_mlp_SiLU                   25 Add -> 26 SiLU (fused)          in: t24@WORK+30720(rel), s23x@X+0(rel)                           out: t26@WORK+51360(rel)              rows[0,8)    C 682->682 20x20  sh 0,-1,2,0  flags f0 misc e000  prm 93237+0 */
    { 0xff00f012, 0x02aa0002, 0x001402aa, 0x08000014, 0x00407800, 0xc8a02000, 0x016c3540, 0xe0000000 },
    /* 662  VEC_MUL      L20_XSSBlock_27_mlp_Mul                    27 Mul -> requant to 28            in: t26@WORK+51360(rel), s23v@X+20640(rel)                       out: t27@WORK+30720(rel)              rows[0,8)    C 682->682 20x20  sh 0,0,5,0  flags 70 misc e000  prm 0+0 */
    { 0x00007013, 0x02aa0005, 0x001402aa, 0x08000014, 0xa040c8a0, 0x78002050, 0x00000040, 0xe0000000 },
    /* 663  GEMM         L20_XSSBlock_28_mlp_fc2_Conv2d             28 fc2 (X scratch)                 in: t27@WORK+30720(rel)                                          out: s28@X+0(rel)                     rows[0,8)    C 682->256 20x20  sh 0,0,0,0  flags 30 misc a000  prm 165241+5504 L20_XSSBlock_28_mlp_fc2_Conv2d */
    { 0x00003020, 0x02aa0000, 0x00140100, 0x08000014, 0x00407800, 0x00000000, 0x02857920, 0xa0001580 },
    /* 664  VEC_ADD      L20_XSSBlock_29_Add                        29 Add -> block output             in: t21@WORK+15360(rel)(w), s28@X+0(rel)                         out: L20_XSSBlock_01.out@A+0          rows[0,8)    C 256->256 20x20  sh 0,0,1,0  flags 70 misc 6200  prm 0+0 */
    { 0x00007012, 0x01000001, 0x00140100, 0x08000014, 0x00403c00, 0x00002000, 0x00000000, 0x62000000 },
    /* 665  LOOP TILE n=3 body=0 */
    { 0x00000001, 0x00030000, 0x0000000e, 0x00000014, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
    /* 666  GEMM         L21_Detect2_01_box_Conv2d                  head2 01 box 3x3                   in: L20_XSSBlock_01.out@A+0                                      out: t01@WORK+0(rel)                  rows[-1,9)   C 256->64 20x20  sh 0,0,0,0  flags 30 misc 8001  prm 185275+4608 L21_Detect2_01_box_Conv2d */
    { 0x00003020, 0x01000000, 0x00140040, 0x09ff0014, 0x00000000, 0x00000000, 0x02d3bb40, 0x80011200 },
    /* 667  VEC_SILU     L21_Detect2_02_box_SiLU                    head2 02 SiLU                      in: t01@WORK+0(rel)                                              out: t02@WORK+1920(rel)               rows[-1,9)   C 64->64 20x20  sh 0,0,0,0  flags 30 misc a000  prm 1508+0 */
    { 0x00003011, 0x00400000, 0x00140040, 0x09ff0014, 0x00400000, 0x07800000, 0x0005e440, 0xa0000000 },
    /* 668  GEMM         L21_Detect2_03_box_Conv2d                  head2 03 box 3x3                   in: t02@WORK+1920(rel)                                           out: t03@WORK+0(rel)                  rows[0,8)    C 64->64 20x20  sh 0,0,0,0  flags 30 misc a001  prm 189893+1152 L21_Detect2_03_box_Conv2d */
    { 0x00003020, 0x00400000, 0x00140040, 0x08000014, 0x00400780, 0x00000000, 0x02e5c540, 0xa0010480 },
    /* 669  VEC_SILU     L21_Detect2_04_box_SiLU                    head2 04 SiLU                      in: t03@WORK+0(rel)                                              out: t04@WORK+1920(rel)               rows[0,8)    C 64->64 20x20  sh 0,0,0,0  flags 30 misc a000  prm 39+0 */
    { 0x00003011, 0x00400000, 0x00140040, 0x08000014, 0x00400000, 0x07800000, 0x00002740, 0xa0000000 },
    /* 670  GEMM         L21_Detect2_05_box_Conv2d                  head2 05 box 1x1 (64)              in: t04@WORK+1920(rel)                                           out: t05@WORK+0(rel)                  rows[0,8)    C 64->64 20x20  sh 0,0,0,0  flags 30 misc a000  prm 191055+128 L21_Detect2_05_box_Conv2d */
    { 0x00003020, 0x00400000, 0x00140040, 0x08000014, 0x00400780, 0x00000000, 0x02ea4f40, 0xa0000080 },
    /* 671  GEMM         L21_Detect2_06_cls_Conv2d                  head2 06 cls 3x3                   in: L20_XSSBlock_01.out@A+0                                      out: t06@WORK+1920(rel)               rows[-1,9)   C 256->80 20x20  sh 0,0,0,0  flags 30 misc 8001  prm 191193+5760 L21_Detect2_06_cls_Conv2d */
    { 0x00003020, 0x01000000, 0x00140050, 0x09ff0014, 0x00000000, 0x07800000, 0x02ead940, 0x80011680 },
    /* 672  VEC_SILU     L21_Detect2_07_cls_SiLU                    head2 07 SiLU                      in: t06@WORK+1920(rel)                                           out: t07@WORK+4320(rel)               rows[-1,9)   C 80->80 20x20  sh 0,0,0,0  flags 30 misc a000  prm 93237+0 */
    { 0x00003011, 0x00500000, 0x00140050, 0x09ff0014, 0x00400780, 0x10e00000, 0x016c3540, 0xa0000000 },
    /* 673  GEMM         L21_Detect2_08_cls_Conv2d                  head2 08 cls 3x3                   in: t07@WORK+4320(rel)                                           out: t08@WORK+1920(rel)               rows[0,8)    C 80->80 20x20  sh 0,0,0,0  flags 30 misc a001  prm 196966+1800 L21_Detect2_08_cls_Conv2d */
    { 0x00003020, 0x00500000, 0x00140050, 0x08000014, 0x004010e0, 0x07800000, 0x03016640, 0xa0010708 },
    /* 674  VEC_SILU     L21_Detect2_09_cls_SiLU                    head2 09 SiLU                      in: t08@WORK+1920(rel)                                           out: t09@WORK+4320(rel)               rows[0,8)    C 80->80 20x20  sh 0,0,0,0  flags 30 misc a000  prm 176513+0 */
    { 0x00003011, 0x00500000, 0x00140050, 0x08000014, 0x00400780, 0x10e00000, 0x02b18140, 0xa0000000 },
    /* 675  GEMM         L21_Detect2_10_cls_Conv2d                  head2 10 cls 1x1 (80)              in: t09@WORK+4320(rel)                                           out: t10@WORK+1920(rel)               rows[0,8)    C 80->80 20x20  sh 0,0,0,0  flags 30 misc a000  prm 198779+200 L21_Detect2_10_cls_Conv2d */
    { 0x00003020, 0x00500000, 0x00140050, 0x08000014, 0x004010e0, 0x07800000, 0x03087b40, 0xa00000c8 },
    /* 676  VEC_RQ       L21_Detect2_05_box_Conv2d                  head2 box -> hd ch [0, 64)         in: t05@WORK+0(rel)                                              out: hd.box@WORK+4320(rel)            rows[0,8)    C 64->192 20x20  sh 0,0,0,0  flags 30 misc a000  prm 0+0 */
    { 0x00003010, 0x00400000, 0x001400c0, 0x08000014, 0x00400000, 0x10e00000, 0x00000040, 0xa0000000 },
    /* 677  VEC_RQ       L21_Detect2_10_cls_Conv2d                  head2 cls -> hd ch [64, 144)       in: t10@WORK+1920(rel)                                           out: hd.cls@WORK+4328(rel)            rows[0,8)    C 80->192 20x20  sh 0,0,0,0  flags 30 misc a000  prm 0+0 */
    { 0x00003010, 0x00500000, 0x001400c0, 0x08000014, 0x00400780, 0x10e80000, 0x00000040, 0xa0000000 },
    /* 678  VEC_RQ                                                  head2 zero -> hd ch [144, 192)     in: L20_XSSBlock_01.out@A+0                                      out: hd.zero@WORK+4338(rel)           rows[0,8)    C 48->192 20x20  sh 16,0,0,0  flags 30 misc 8000  prm 0+0 */
    { 0x00103010, 0x00300000, 0x001400c0, 0x08000014, 0x00000000, 0x10f20000, 0x00000040, 0x80000000 },
    /* 679  VEC_OUTROWS  L21_Detect2_hd                             P5 <- head2 hd (rows = pixels x 3) in: hd@WORK+4320(rel)                                            out: OUT.P5@OUT+524288                rows[0,8)    C 192->192 20x20  sh 0,0,0,0  flags 30 misc 2000  prm 0+0 */
    { 0x00003017, 0x00c00000, 0x001400c0, 0x08000014, 0x004010e0, 0x00000000, 0x00000068, 0x20000000 },
    /* 680  END */
    { 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 },
};

#endif /* EMY_PROGRAM_H_ */

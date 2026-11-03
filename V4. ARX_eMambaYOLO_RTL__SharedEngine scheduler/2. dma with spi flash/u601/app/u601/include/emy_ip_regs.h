/* eMambaYOLO_IP v2 (공유 엔진) 레지스터 · BRAM 슬롯 상수 — docs/CPU_SEQUENCE.md §1 · §2 와 S_AXI.sv 헤더에서
 * 기준 주소는 플랫폼의 memorymap_info.h (EMAMBA_IP_SLAVE_BASEADDR, INPUT/WB/OUTPUT_BRAM_SLAVE_BASEADDR) 를 쓴다.
 * 모든 레지스터는 32 bit, 바이트 오프셋. 쓰기는 WSTRB 를 무시한다 (항상 워드 전체).
 * (tools/gen_board_headers.py 가 만든 파일 — 값을 고치면 같은 자리의 값만 바꿀 것, 배열 크기는 그대로)
 */
#ifndef EMY_IP_REGS_H_
#define EMY_IP_REGS_H_
#include <stdint.h>

/* ---- 부팅 스트림 (vectors/img/boot.bin = 순서표 32 KB + 가중치 이미지; main.c 가 emy_program · emy_regions 로 조립) ---- */
#define EMY_BOOT_BYTES   6400512u   /* = WB_COUNT 기대값 */
#define EMY_BOOT_CHUNKS  391u      /* 16 KB 청크 수 (마지막 10752 B) */
#define EMY_BOOT_SHA256  "d51ef861c3dbec45cfb4d31ab4a09ec674c0f7fb22591d9e59adda503e318857"

/* ---- S_AXI 레지스터 오프셋 ---- */
#define EMY_REG_CTRL        0x00u  /* W: [31] START (1 프레임, 자동 0) · [30] WB_LOAD (부팅 스트림을 0 바이트부터) ; R: [15] FRAME_DONE · [14] WB_DONE */
#define EMY_REG_STATUS      0x04u  /* R: [1:0] IN_FULL · [3:2] WB_FULL · [9:4] OUT_FULL {P5s1,P5s0,P4s1,P4s0,P3s1,P3s0} · [16] WB_DONE · [17] FRAME_DONE */
#define EMY_REG_IN_LEN0     0x08u  /* W: IN 슬롯 0 에 넣은 바이트 수 (4 의 배수, ≤ 16,384); 쓰면 그 슬롯이 FULL */
#define EMY_REG_IN_LEN1     0x0Cu  /* W: IN 슬롯 1 */
#define EMY_REG_WB_LEN0     0x10u  /* W: WB 슬롯 0 */
#define EMY_REG_WB_LEN1     0x14u  /* W: WB 슬롯 1 */
#define EMY_REG_OUT_RELEASE 0x18u  /* W: 1 인 비트의 OUT 슬롯을 비운다 (STATUS[9:4] 와 같은 비트 순서) ; R: OUT_FULL */
#define EMY_REG_FRAME_COUNT 0x1Cu  /* R: START 뒤 끝난 프레임 수 */
#define EMY_REG_WB_COUNT    0x20u  /* R: WB_LOAD 뒤 받은 부팅 바이트 수 (끝 값 EMY_BOOT_BYTES) */
#define EMY_REG_SEQ         0x24u  /* R: [9:0] PC · [17:16] ACTIVE 엔진 · [18] ACTIVE_V · [19] BUSY · [20] OUT_FIFO_OVF · [21] WB_OVF · [31:24] BUF_FAULT (sticky) ; W 0: sticky 비트 지움 */
#define EMY_REG_PIX_COUNT   0x28u  /* R: 입력 링에 쓴 픽셀 수 (프레임당 409,600) */
#define EMY_REG_INFO        0x2Cu  /* R: {OUT_AW, WB_AW, IN_AW, 버전} = 0x0D0F0F02 */
#define EMY_REG_IN_ROWS     0x30u  /* R: [15:0] 이번 프레임에 받은 입력 행 수 (끝 640) */
#define EMY_REG_OUT_ROWS    0x34u  /* R: 이번 프레임에 BRAM_OUT 에 쓴 행 수 (끝 25,200) */
#define EMY_REG_FILTER      0x38u  /* R/W: [0] FILTER_EN · [1] DET_EN (후보당 DET 행 하나, B 안) · [2] NMS_EN (어댑터가 NMS 까지, 검출 행 + END) · [15:8] QTHR0 (P3) · [23:16] QTHR1 (P4) · [31:24] QTHR2 (P5), signed int8 cls logit 문턱.
                                      1 이면 어댑터가 문턱을 넘는 픽셀만 (META 행, box 행) 으로 내보내고 프레임 끝에 헤드마다 END 행. 리셋 0xFCFEFC00 (= 옛 문턱 −4 / −2 / −4 = conf 0.25, 꺼짐; 앱은 2026-10-22 부터 1 / 1 / 1 = conf > 0.5 를 쓴다) */
#define EMY_REG_CMD0        0x40u  /* R: 실행 중인 256 bit 명령 (CMD0 .. CMD7 = 0x40 .. 0x5C) — 디버그 */

/* ---- 비트 ---- */
#define EMY_CTRL_START      (1u << 31)
#define EMY_CTRL_WB_LOAD    (1u << 30)
#define EMY_CTRL_FRAME_DONE (1u << 15)
#define EMY_CTRL_WB_DONE    (1u << 14)
#define EMY_ST_IN_FULL(k)   (1u << (k))              /* IN 슬롯 k 가 차 있음 */
#define EMY_ST_WB_FULL(k)   (1u << (2 + (k)))        /* WB 슬롯 k 가 차 있음 */
#define EMY_ST_OUT_FULL(s, k) (1u << (4 + 2 * (s) + (k)))  /* 헤드 s (0 P3 1 P4 2 P5) 슬롯 k 가 차 있음 */
#define EMY_ST_OUT_ANY      0x3F0u
#define EMY_ST_WB_DONE      (1u << 16)
#define EMY_ST_FRAME_DONE   (1u << 17)
#define EMY_SEQ_BUSY        (1u << 19)
#define EMY_SEQ_OUT_OVF     (1u << 20)
#define EMY_SEQ_WB_OVF      (1u << 21)
#define EMY_SEQ_FAULT_MASK  (0xFFu << 24)
#define EMY_SEQ_ERR_MASK    (EMY_SEQ_BUSY | EMY_SEQ_OUT_OVF | EMY_SEQ_WB_OVF | EMY_SEQ_FAULT_MASK)  /* 프레임 뒤 0 이어야 함 */
#define EMY_INFO_EXPECT     0x0D0F0F02u
/* FILTER 값: EN | QTHR0 << 8 | QTHR1 << 16 | QTHR2 << 24 (int8 → 8 bit) */
#define EMY_FILTER_VALUE(en, q0, q1, q2) ((uint32_t)((en) & 1u) | ((uint32_t)((q0) & 0xFF) << 8) | ((uint32_t)((q1) & 0xFF) << 16) | ((uint32_t)((q2) & 0xFF) << 24))
/* META / END 행 (64 B): 바이트 0-1 픽셀 (LE) · 2 헤드 · 3 cls · 4 qmax · 5 형식 (META 0x01, END 0xFF; END 는 0-1 = 후보 수) */
#define EMY_ROW_FMT_META    0x01u
#define EMY_ROW_FMT_END     0xFFu
/* DET 모드 (FILTER[1] = DET_EN, B 안): 후보당 DET 행 하나 — 워드 0 = 픽셀 | 헤드 << 16 | cls << 24, 워드 1 = qmax | 0x02 << 8 | conf16 << 16,
   워드 2 = x1 | y1 << 16, 워드 3 = x2 | y2 << 16 (int16, 1/16 px; (cx·256+128 ∓ d)·stride >> 4, C emy_head_post 와 비트 동일). 나머지 0. */
#define EMY_FILTER_DET_EN   0x2u
#define EMY_ROW_FMT_DET     0x02u
#define EMY_DET_PIXEL(w0)   ((uint16_t)((w0) & 0xFFFFu))
#define EMY_DET_HEAD(w0)    ((uint8_t)((w0) >> 16))
#define EMY_DET_CLS(w0)     ((uint8_t)((w0) >> 24))
#define EMY_DET_QMAX(w1)    ((int8_t)((w1) & 0xFFu))
#define EMY_DET_FMT(w1)     ((uint8_t)((w1) >> 8))
#define EMY_DET_CONF(w1)    ((uint16_t)((w1) >> 16))
#define EMY_DET_LO16(w)     ((int16_t)((w) & 0xFFFFu))
#define EMY_DET_HI16(w)     ((int16_t)((w) >> 16))
/* NMS 모드 (FILTER[2] = NMS_EN, DET_EN 과 함께): 어댑터가 NMS 까지 한다 — 헤드 0 슬롯에 검출 행 (형식 0x03, 바이트 배치는 DET 행과 같음: EMY_DET_* 매크로)
 * 을 conf 내림차순으로, 그 뒤 END 3 개. 헤드 0 END 워드 0 = 검출 수 | 0 << 16, 헤드 1 · 2 END = 0; END 워드 2 = 그 헤드의 후보 수 | 버린 후보 << 16 (헤드 0).
 * OUT_ROWS = 검출 + 3. 후보 저장소 512, 검출 최대 300 (EMY_HP_MAX_DET). */
#define EMY_FILTER_NMS_EN   0x4u
#define EMY_ROW_FMT_NMS     0x03u
#define EMY_NMS_CAND_MAX    512u
#define EMY_END_COUNT(w0)   ((uint16_t)((w0) & 0xFFFFu))
#define EMY_END_NCAND(w2)   ((uint16_t)((w2) & 0xFFFFu))
#define EMY_END_NDROP(w2)   ((uint16_t)((w2) >> 16))

/* ---- BRAM 슬롯 (바이트 오프셋, 각 BRAM 의 기준 주소에 더함) ---- */
#define EMY_SLOT_BYTES      16384u   /* BRAM_IN / BRAM_WB: 슬롯 k = [k * 16 KB, (k+1) * 16 KB) */
#define EMY_OUT_SLOT_BASE_P3(k) (0x0000u + (k) * 0x0800u)   /* P3 슬롯 32 행 = 2,048 B */
#define EMY_OUT_SLOT_BASE_P4(k) (0x1000u + (k) * 0x0400u)   /* P4 슬롯 16 행 = 1,024 B */
#define EMY_OUT_SLOT_BASE_P5(k) (0x1800u + (k) * 0x0400u)   /* P5 슬롯 16 행 */
static const uint32_t emy_out_slot_base[3][2] = { {0x0000u, 0x0800u}, {0x1000u, 0x1400u}, {0x1800u, 0x1C00u} };
static const uint32_t emy_out_slot_rows[3]    = { 32u, 16u, 16u };   /* 슬롯 처리 횟수: P3 600 · P4 300 · P5 75 = 975 */

/* ---- 프레임 뒤 기대값 ---- */
#define EMY_EXPECT_IN_ROWS   640u
#define EMY_EXPECT_PIX_COUNT 409600u
#define EMY_EXPECT_FRAME_CYCLES 102798108u   /* 시뮬 실측 (100 MHz 에서 1.03 s), 참고용 */

#endif /* EMY_IP_REGS_H_ */

/*
 * u504_theta 앱 — u504_eta (카메라) + 화면 라벨 (src/emy_label.c: 상자 위에 클래스 이름 · conf, 왼쪽 위 상태 줄 FRAME · ms · DET) + 프레임마다 주기 (ms) 출력
 *   스위치 EMY_CAM_LABELS (1) · EMY_CAM_LABEL_NAMES (1: COCO 이름, 0: C56 같은 번호) · EMY_CAM_STATUS (1). 나머지는 eta 와 같다 (아래).
 *
 * u504_eta 앱 — u504_zeta (NMS 모드) + 카메라 경로 (docs/CAMERA_ZETA_PLAN.html, 2026-10-22)
 *
 *   EMY_CAM_SRC 1 (기본): HDMI 카메라 프레임 (VIM → DDR XBGR) 을 CPU 가 640×640 HWC int8 로 변환해 스테이징에 두고 (src/emy_camera.c),
 *   그것을 IP 에 넣어 (청크 15,360 B = 8 행, 80 개) 검출을 받아 캡처 버퍼에 박스를 그려 VOM 으로 보인다. 골든 비교 없음.
 *   EMY_CAM_SELFTEST 1: 카메라 대신 골든 int8 프레임을 FHD XBGR 로 펼친 합성 버퍼를 같은 변환기에 통과시켜 (스테이징 == 골든 프레임이어야 함)
 *   검출 6 / 6 을 기대 표와 비교한다 — PC 모의 IP 와 보드 (화면에는 합성 프레임 + 박스) 모두. 변환 · 청크 · 스테이징 · 그리기 경로의 검증.
 *   EMY_CAM_SRC 0: u504_zeta 와 같은 골든 테스트 (아래 설명).
 *
 * u504_zeta 앱 — NMS 모드 (FILTER[2], L5): IP 가 sigmoid · DFL · 좌표 · NMS 까지 끝내고 검출 행만, CPU 는 읽기만
 *
 *   u504_epsilon (DET 모드) 과 같은 IP 순서 (docs/CPU_SEQUENCE.md) 이지만 FILTER = EN | DET_EN | NMS_EN | QTHR 를 써서 어댑터가 DET 행을
 *   저장소 (512) 에 모았다가 프레임 끝에 NMS (emy_nms: conf 내림차순 · 동률 앵커 번호, 같은 cls, 10·inter > 7·uni — C emy_head_post.c 와 비트 동일)
 *   를 돌리고 **검출 행** (형식 0x03, 바이트 배치는 DET 행과 같음) 을 헤드 0 (P3) 슬롯으로 conf 순서대로 내보낸다. 그 뒤 END 3 개:
 *     헤드 0 END 워드 0 = 검출 수 | 0 << 16, 헤드 1 · 2 END 워드 0 = 0 | 헤드 << 16;  END 워드 2 = 그 헤드의 후보 수 | 버린 후보 << 16 (헤드 0).
 *   CPU 는 헤드 0 슬롯의 행을 END 까지 읽어 (행마다 워드 4 개) 검출 목록 (float) 으로 바꾸기만 한다. 후처리 연산은 없다.
 *   통신량: epsilon 의 102 행 (후보 99 + END 3) → 검출 20 + END 3 = 23 행.
 *   골든 검사 (EMY_GOLDEN_CHECK): 받은 검출 행의 워드 4 개를 include/emy_expected_nms.h (tools/gen_cand_golden.py --nms, 골든 후보에 같은 정수 NMS)
 *   와 순서대로 비교; END 의 후보 수를 emy_expected_nms_cand_n 과 비교; 검출 20 개는 emy_expected_det.h (float 참조) 와 비교.
 *   시간 분해: emy_boot · emy_frame = emy_in_copy + emy_out_read + emy_idle + emy_printf, emy_head_post = 검출 비교만.
 */
#include <stdint.h>
#include <string.h>

#include "platform_info.h"
#include "memorymap_info.h"
#include "ervp_printf.h"
#include "ervp_core_id.h"
#include "ervp_mmio_util.h"
#include "ervp_profiling.h"
#include "edge_video_system.h"

#include "emy_ip_regs.h"
#include "emy_program.h"
#include "emy_weights.h"
#include "emy_camera.h"                  /* emy_det_t, 카메라 API, EMY_CAM_720P / PIPELINE / VDMA 스위치 */
#include "emy_label.h"                   /* 화면 라벨 (theta) */
#include "ervp_real_clock.h"             /* 프레임 주기 (µs tick) */
#ifndef EMY_CAM_LABELS
#define EMY_CAM_LABELS 1                 /* 1: 상자 위에 "NAME 92%" 띠 */
#endif
#ifndef EMY_CAM_LABEL_NAMES
#define EMY_CAM_LABEL_NAMES 1            /* 1: COCO 이름, 0: 클래스 번호 */
#endif
#ifndef EMY_CAM_STATUS
#define EMY_CAM_STATUS 1                 /* 1: 왼쪽 위 상태 줄 FRAME n  ms  DET k */
#endif

/* ---- 카메라 스위치 ---- */
#ifndef EMY_CAM_SRC
#define EMY_CAM_SRC 1                    /* 1: 카메라 경로 (cam_loop). 0: u504_zeta 골든 테스트 */
#endif
#ifndef EMY_CAM_SELFTEST
#define EMY_CAM_SELFTEST 0               /* 1: 카메라 대신 골든 프레임을 펼친 합성 FHD 버퍼 → 변환기 → IP → 기대 표 비교 */
#endif
#ifndef EMY_CAM_FRAMES
#define EMY_CAM_FRAMES (EMY_CAM_SELFTEST ? 1 : 0)   /* 카메라 루프 프레임 수 (0 = 'x' 키까지) */
#endif
#ifndef EMY_CAM_SINGLE
#define EMY_CAM_SINGLE 0                 /* 1: 'c' 키마다 한 프레임 */
#endif
#define EMY_CAM_GOLDEN (!EMY_CAM_SRC || EMY_CAM_SELFTEST)   /* 골든 프레임 · 기대 표 헤더가 필요한 빌드 */
#if EMY_CAM_GOLDEN
#include "emy_input_frame.h"
#include "emy_expected_det.h"
#include "emy_expected_nms.h"
#endif
#ifndef EMY_FRAME_BYTES
#define EMY_FRAME_BYTES EMY_CAM_FRAME_BYTES   /* emy_input_frame.h 가 없는 빌드 */
#endif
#define EMY_HP_MAX_DET 300
#define EMY_BIGDATA __attribute__((aligned(8)))   /* was in emy_head_post.h (removed here): alignment only, no cache on this platform */

#ifndef EMY_RUN_GOLDEN_TEST
#define EMY_RUN_GOLDEN_TEST 1
#endif
#ifndef EMY_GOLDEN_CHECK
#define EMY_GOLDEN_CHECK 1               /* 1: 받은 검출 행을 emy_expected_nms 와 비교 (테스트). 0: 운용 (비교 없음) */
#endif
#ifndef EMY_RUN_HEAD_POST
#define EMY_RUN_HEAD_POST 1
#endif
#ifndef EMY_RUN_CAMERA_DEMO
#define EMY_RUN_CAMERA_DEMO 1
#endif
#ifndef EMY_FRAMES
#define EMY_FRAMES 1
#endif
#ifndef EMY_SHOW_MISMATCH
#define EMY_SHOW_MISMATCH 10
#endif
#ifndef EMY_QUIET
#define EMY_QUIET 1
#endif
#ifndef EMY_QTHR0
#define EMY_QTHR0 (1)                    /* P3 (cls shift 2): conf > 0.5 ⇔ q ≥ 1  [2026-10-22; conf 0.25 was −4] */
#endif
#ifndef EMY_QTHR1
#define EMY_QTHR1 (1)                    /* P4 (cls shift 1): conf > 0.5 ⇔ q ≥ 1  [conf 0.25 was −2] */
#endif
#ifndef EMY_QTHR2
#define EMY_QTHR2 (1)                    /* P5 (cls shift 2): conf > 0.5 ⇔ q ≥ 1  [conf 0.25 was −4] */
#endif
#if EMY_CAM_SRC                          /* 카메라 빌드: 골든 테스트 · GUI 카메라 데모는 돌지 않는다 */
#undef  EMY_RUN_GOLDEN_TEST
#define EMY_RUN_GOLDEN_TEST 0
#undef  EMY_RUN_CAMERA_DEMO
#define EMY_RUN_CAMERA_DEMO 0
#if !EMY_CAM_SELFTEST                    /* 실제 카메라: 골든이 없다 */
#undef  EMY_GOLDEN_CHECK
#define EMY_GOLDEN_CHECK 0
#undef  EMY_RUN_HEAD_POST
#define EMY_RUN_HEAD_POST 0
#endif
#endif

#define EMY_POLL_SLOT   (50u * 1000u * 1000u)
#define EMY_POLL_FRAME  (400u * 1000u * 1000u)

#define EMY_IP   ((uint32_t)EMAMBA_IP_SLAVE_BASEADDR)
#define EMY_IN   ((uint32_t)INPUT_BRAM_SLAVE_BASEADDR)
#define EMY_WB   ((uint32_t)WB_BRAM_SLAVE_BASEADDR)
#define EMY_OUT  ((uint32_t)OUTPUT_BRAM_SLAVE_BASEADDR)

static inline uint32_t reg_rd(uint32_t off)             { return mmio_read_data((mmio_addr_t)(EMY_IP + off)); }
static inline void     reg_wr(uint32_t off, uint32_t v) { mmio_write_data((mmio_addr_t)(EMY_IP + off), v); }
static inline void     barrier(void)                    { __sync_synchronize(); }

static void bram_write(uint32_t base, const uint32_t *src, uint32_t nwords)
{
    for (uint32_t i = 0; i < nwords; i++)
        mmio_write_data((mmio_addr_t)(base + 4u * i), src[i]);
}

static const uint8_t *frame_src;                       /* 이번 프레임의 입력 바이트 (골든 배열 또는 카메라 스테이징) */
static uint32_t       frame_chunk = EMY_SLOT_BYTES;    /* IN 청크 크기: 골든 16,384 (75 개), 카메라 15,360 = 8 행 (80 개) */
#if EMY_CAM_SRC && EMY_CAM_PIPELINE
static void cam_idle_step(void);                       /* IP 를 기다리는 폴링 사이에 다음 프레임의 캡처 · 변환을 한 행씩 */
#endif

/* ------------------------------------------------------------------------------------------------ */
/* 0. 부팅 스트림 조립 (순서표 1,024 줄 + 영역 844 개 = boot.bin) */
static uint8_t emy_boot_stream[EMY_BOOT_BYTES] EMY_BIGDATA;

static int emy_build_boot(void)
{
    if (EMY_PROGRAM_BYTES + EMY_IMAGE_BYTES != EMY_BOOT_BYTES) {
        printf("emy_build_boot: 크기 불일치 program %lu + image %lu != boot %lu\n", (unsigned long)EMY_PROGRAM_BYTES,
               (unsigned long)EMY_IMAGE_BYTES, (unsigned long)EMY_BOOT_BYTES);
        return -1;
    }
    memset(emy_boot_stream, 0, EMY_PROGRAM_BYTES);
    memcpy(emy_boot_stream, emy_program, sizeof(emy_program));
    uint32_t pos = 0;
    for (uint32_t i = 0; i < EMY_REGION_COUNT; i++) {
        const emy_region_t *r = &emy_regions[i];
        if (r->byte_offset != pos || (r->bytes & 31u)) {
            printf("emy_build_boot: 영역 %lu %s/%s 가 offset %lu 에 있음 (기대 %lu)\n", (unsigned long)i, r->step, r->name,
                   (unsigned long)r->byte_offset, (unsigned long)pos);
            return -2;
        }
        memcpy(emy_boot_stream + EMY_PROGRAM_BYTES + pos, r->data, r->bytes);
        pos += r->bytes;
    }
    if (pos != EMY_IMAGE_BYTES) {
        printf("emy_build_boot: 영역 합 %lu != 이미지 %lu\n", (unsigned long)pos, (unsigned long)EMY_IMAGE_BYTES);
        return -3;
    }
    printf("emy_build_boot: 순서표 %lu 줄 + 영역 %lu 개 = %lu B\n", (unsigned long)EMY_PROGRAM_LINES, (unsigned long)EMY_REGION_COUNT,
           (unsigned long)(EMY_PROGRAM_BYTES + pos));
    return 0;
}

/* ------------------------------------------------------------------------------------------------ */
/* 1. 부팅 (CPU_SEQUENCE §3) + FILTER 레지스터 */
static int emy_boot(void)
{
    uint32_t info = reg_rd(EMY_REG_INFO);
    if (info != EMY_INFO_EXPECT) {
        printf("emy_boot: INFO %08lx != %08lx\n", (unsigned long)info, (unsigned long)EMY_INFO_EXPECT);
        return -1;
    }
    reg_wr(EMY_REG_CTRL, EMY_CTRL_WB_LOAD);
    barrier();
    uint32_t pos = 0, k = 0, chunks = 0;
    while (pos < EMY_BOOT_BYTES) {
        uint32_t poll = 0;
        while (reg_rd(EMY_REG_STATUS) & EMY_ST_WB_FULL(k)) {
            if (++poll > EMY_POLL_SLOT) {
                printf("emy_boot: WB 슬롯 %lu 가 비지 않음 (pos %lu, STATUS %08lx, WB_COUNT %lu)\n", (unsigned long)k, (unsigned long)pos,
                       (unsigned long)reg_rd(EMY_REG_STATUS), (unsigned long)reg_rd(EMY_REG_WB_COUNT));
                return -2;
            }
        }
        uint32_t n = EMY_BOOT_BYTES - pos;
        if (n > EMY_SLOT_BYTES) n = EMY_SLOT_BYTES;
        n &= ~3u;
        bram_write(EMY_WB + k * EMY_SLOT_BYTES, (const uint32_t *)(emy_boot_stream + pos), n / 4u);
        barrier();
        reg_wr(k ? EMY_REG_WB_LEN1 : EMY_REG_WB_LEN0, n);
        pos += n; k ^= 1u; chunks++;
        if ((chunks % 100u) == 0u) printf("  boot %lu / %lu B\n", (unsigned long)pos, (unsigned long)EMY_BOOT_BYTES);
    }
    uint32_t poll = 0;
    while (!(reg_rd(EMY_REG_CTRL) & EMY_CTRL_WB_DONE)) {
        if (++poll > EMY_POLL_SLOT) {
            printf("emy_boot: WB_DONE 없음 (STATUS %08lx, WB_COUNT %lu)\n", (unsigned long)reg_rd(EMY_REG_STATUS), (unsigned long)reg_rd(EMY_REG_WB_COUNT));
            return -3;
        }
    }
    uint32_t cnt = reg_rd(EMY_REG_WB_COUNT), seq = reg_rd(EMY_REG_SEQ);
    if (cnt != EMY_BOOT_BYTES || (seq & EMY_SEQ_WB_OVF)) {
        printf("emy_boot: WB_COUNT %lu (기대 %lu), SEQ %08lx\n", (unsigned long)cnt, (unsigned long)EMY_BOOT_BYTES, (unsigned long)seq);
        return -4;
    }
    printf("emy_boot: OK — %lu B, 청크 %lu 개, WB_COUNT %lu\n", (unsigned long)pos, (unsigned long)chunks, (unsigned long)cnt);

    /* 후보 필터: 문턱은 상수 (conf_thres 0.5 (2026-10-22 부터; 전 0.25) 와 양자화 shift 2/1/2 로 정해짐, 이미지마다 바뀌지 않음) — 부팅 뒤 한 번 */
    uint32_t fv = EMY_FILTER_VALUE(1, EMY_QTHR0, EMY_QTHR1, EMY_QTHR2) | EMY_FILTER_DET_EN | EMY_FILTER_NMS_EN;
    reg_wr(EMY_REG_FILTER, fv);
    barrier();
    uint32_t rb = reg_rd(EMY_REG_FILTER);
    if (rb != fv) { printf("emy_boot: FILTER 읽기 %08lx != %08lx\n", (unsigned long)rb, (unsigned long)fv); return -5; }
    printf("emy_boot: FILTER = %08lx (EN, DET, NMS, qthr %d / %d / %d)\n", (unsigned long)rb, EMY_QTHR0, EMY_QTHR1, EMY_QTHR2);
    return 0;
}

/* ------------------------------------------------------------------------------------------------ */
/* 2. 프레임 하나: 헤드 0 슬롯의 검출 행을 END 까지 읽어 검출 목록으로 */
typedef struct {
    uint32_t rows[3], cand[3], bad[3], slots, in_chunks, polls, shown, proto_err;   /* cand[0] = 받은 검출 행 수 */
    uint32_t idle_polls, idle_runs, dets;
    uint8_t  head_end[3];
    uint16_t end_count[3], end_ncand[3], end_ndrop;
} emy_result_t;
static emy_det_t emy_dets[EMY_HP_MAX_DET];

static const char *const head_name[3] = { "P3", "P4", "P5" };

#if EMY_GOLDEN_CHECK
/* 받은 검출 행 (순번 idx) 의 워드 4 개를 기대 표와 비교. 반환 = 다른 워드 수 */
static uint32_t check_det(emy_result_t *res, int s, uint32_t idx, const uint32_t w[4])
{
    uint32_t bad = 0;
    if (idx >= EMY_EXPECTED_NMS_N) { bad = 4; }
    else {
        const uint32_t *e = emy_expected_nms[idx].w;
        bad = (w[0] != e[0]) + (w[1] != e[1]) + (w[2] != e[2]) + (w[3] != e[3]);
        if (bad && res->shown < EMY_SHOW_MISMATCH) {
            profiling_start_by_name("emy_printf");
            printf("  MISMATCH %s det %lu: got %08lx %08lx %08lx %08lx, exp %08lx %08lx %08lx %08lx (%lu words differ)\n", head_name[s], (unsigned long)idx,
                   (unsigned long)w[0], (unsigned long)w[1], (unsigned long)w[2], (unsigned long)w[3],
                   (unsigned long)e[0], (unsigned long)e[1], (unsigned long)e[2], (unsigned long)e[3], (unsigned long)bad);
            profiling_end_by_name("emy_printf");
            res->shown++;
        }
    }
    return bad;
}
#endif


/* 슬롯 하나: END 행까지만 읽는다. 모든 행이 어댑터가 만든 것 (검출 0x03 / END 0xFF) 이라 워드 1 의 형식 바이트가 확정적이다.
   검출 행 (헤드 0 만): 워드 4 개를 읽어 검출 목록 (float) 에 바로. END: 워드 0 = 수, 워드 2 = 그 헤드의 후보 수 | 버린 후보 << 16 */
static void take_out_slot(int s, uint32_t k, emy_result_t *res)
{
    uint32_t nr = emy_out_slot_rows[s];
    uint32_t src = EMY_OUT + emy_out_slot_base[s][k];
    profiling_start_by_name("emy_out_read");
    for (uint32_t r = 0; r < nr && !res->head_end[s]; r++) {
        uint32_t a = src + r * 64u, w[4];
        res->rows[s]++;
        w[0] = mmio_read_data((mmio_addr_t)(a)); w[1] = mmio_read_data((mmio_addr_t)(a + 4u));
        uint8_t fmt = EMY_DET_FMT(w[1]), head = EMY_DET_HEAD(w[0]);
        if (fmt == EMY_ROW_FMT_END) {
            w[2] = mmio_read_data((mmio_addr_t)(a + 8u));
            res->head_end[s] = 1; res->end_count[s] = EMY_END_COUNT(w[0]); res->end_ncand[s] = EMY_END_NCAND(w[2]);
            if (s == 0) res->end_ndrop = EMY_END_NDROP(w[2]);
            if (head != (uint8_t)s || res->end_count[s] != ((s == 0) ? res->dets : 0u)) res->proto_err++;
            break;
        }
        if (fmt != EMY_ROW_FMT_NMS || s != 0 || head > 2u) { res->proto_err++; continue; }
        w[2] = mmio_read_data((mmio_addr_t)(a + 8u)); w[3] = mmio_read_data((mmio_addr_t)(a + 12u));
#if EMY_GOLDEN_CHECK
        res->bad[s] += check_det(res, s, res->dets, w);
#endif
        if (res->dets < EMY_HP_MAX_DET) {
            emy_det_t *d = &emy_dets[res->dets];
            d->x1 = (float)EMY_DET_LO16(w[2]) * (1.0f / 16.0f); d->y1 = (float)EMY_DET_HI16(w[2]) * (1.0f / 16.0f);
            d->x2 = (float)EMY_DET_LO16(w[3]) * (1.0f / 16.0f); d->y2 = (float)EMY_DET_HI16(w[3]) * (1.0f / 16.0f);
            d->conf = (float)EMY_DET_CONF(w[1]) * (1.0f / 65536.0f); d->cls = EMY_DET_CLS(w[0]);
        }
        res->dets++; res->cand[s]++;
    }
    profiling_end_by_name("emy_out_read");
    res->slots++;
}

static int emy_frame_run(int frame_no, emy_result_t *res)
{
    uint32_t in_pos = 0, in_k = 0, out_k[3] = { 0, 0, 0 }, st, poll = 0, idle = 0;
    int idling = 0;
    memset(res, 0, sizeof(*res));
    reg_wr(EMY_REG_SEQ, 0);
    barrier();
    reg_wr(EMY_REG_CTRL, EMY_CTRL_START);
    barrier();
    do {
        st = reg_rd(EMY_REG_STATUS); res->polls++;
        int can_in = (in_pos < EMY_FRAME_BYTES) && !(st & EMY_ST_IN_FULL(in_k));
        int progressed = can_in || (st & (EMY_ST_OUT_FULL(0, out_k[0]) | EMY_ST_OUT_FULL(1, out_k[1]) | EMY_ST_OUT_FULL(2, out_k[2]))) != 0u;
        if (!progressed) {
            if (!idling) { profiling_start_by_name("emy_idle"); idling = 1; res->idle_runs++; }
            res->idle_polls++;
#if EMY_CAM_SRC && EMY_CAM_PIPELINE
            cam_idle_step();
#endif
        } else if (idling) { profiling_end_by_name("emy_idle"); idling = 0; }
        if (can_in) {
            uint32_t n = EMY_FRAME_BYTES - in_pos;
            if (n > frame_chunk) n = frame_chunk;
            profiling_start_by_name("emy_in_copy");
#if EMY_CAM_SRC && EMY_CAM_VDMA
            emy_vdma_copy(EMY_IN + in_k * EMY_SLOT_BYTES, (uint32_t)(uintptr_t)(frame_src + in_pos), n);   /* 3 단계: VDMA 가 스테이징 → 슬롯 */
#else
            bram_write(EMY_IN + in_k * EMY_SLOT_BYTES, (const uint32_t *)(frame_src + in_pos), n / 4u);
#endif
            barrier();
            reg_wr(in_k ? EMY_REG_IN_LEN1 : EMY_REG_IN_LEN0, n);
            profiling_end_by_name("emy_in_copy");
            in_pos += n; in_k ^= 1u; res->in_chunks++;
        }
        for (int s = 0; s < 3; s++) {
            uint32_t k = out_k[s];
            if (st & EMY_ST_OUT_FULL(s, k)) {
                take_out_slot(s, k, res);
                barrier();
                reg_wr(EMY_REG_OUT_RELEASE, EMY_ST_OUT_FULL(s, k) >> 4);
                out_k[s] ^= 1u;
#if !EMY_QUIET
                if (res->head_end[s]) {
                    profiling_start_by_name("emy_printf");
                    printf("  frame %d %s: 검출 %lu (END %u), 행 %lu, 불일치 %lu 워드\n", frame_no, head_name[s], (unsigned long)res->cand[s],
                           res->end_count[s], (unsigned long)res->rows[s], (unsigned long)res->bad[s]);
                    profiling_end_by_name("emy_printf");
                }
#endif
            }
        }
        if (progressed) idle = 0; else idle++;
        if (idle > EMY_POLL_SLOT || ++poll > EMY_POLL_FRAME) {
            if (idling) profiling_end_by_name("emy_idle");
            printf("emy_frame: 멈춤 — STATUS %08lx SEQ %08lx IN_ROWS %lu OUT_ROWS %lu PIX %lu (in %lu B, 후보 %lu/%lu/%lu)\n",
                   (unsigned long)st, (unsigned long)reg_rd(EMY_REG_SEQ), (unsigned long)reg_rd(EMY_REG_IN_ROWS),
                   (unsigned long)reg_rd(EMY_REG_OUT_ROWS), (unsigned long)reg_rd(EMY_REG_PIX_COUNT), (unsigned long)in_pos,
                   (unsigned long)res->cand[0], (unsigned long)res->cand[1], (unsigned long)res->cand[2]);
            for (int i = 0; i < 8; i++) printf("  CMD%d %08lx\n", i, (unsigned long)reg_rd(EMY_REG_CMD0 + 4u * i));
            return -10;
        }
    } while (!(st & EMY_ST_FRAME_DONE) || (st & EMY_ST_OUT_ANY));
    if (idling) profiling_end_by_name("emy_idle");

    uint32_t seq = reg_rd(EMY_REG_SEQ), fc = reg_rd(EMY_REG_FRAME_COUNT), orows = reg_rd(EMY_REG_OUT_ROWS),
             irows = reg_rd(EMY_REG_IN_ROWS), pix = reg_rd(EMY_REG_PIX_COUNT);
    uint32_t exp_rows = res->dets + 3u;
    int proto = 0;
    if (seq & EMY_SEQ_ERR_MASK)        { printf("  SEQ %08lx: BUSY / OVF / BUF_FAULT\n", (unsigned long)seq); proto = -11; }
    if (fc != 1u)                      { printf("  FRAME_COUNT %lu (기대 1: START 마다 0 으로 리셋, 프레임 끝에 1 — S_AXI.sv)\n", (unsigned long)fc); proto = -12; }   /* [2026-10-22] 전에는 frame_no + 1 을 기대 — 두 번째 프레임부터 틀렸음 (보드 첫 다중 프레임 실행에서 발견) */
    if (orows != exp_rows)             { printf("  OUT_ROWS %lu (기대 %lu = 검출 + END 3)\n", (unsigned long)orows, (unsigned long)exp_rows); proto = -13; }
    if (irows != EMY_EXPECT_IN_ROWS)   { printf("  IN_ROWS %lu (기대 %lu)\n", (unsigned long)irows, (unsigned long)EMY_EXPECT_IN_ROWS); proto = -14; }
    if (pix != EMY_EXPECT_PIX_COUNT)   { printf("  PIX_COUNT %lu (기대 %lu)\n", (unsigned long)pix, (unsigned long)EMY_EXPECT_PIX_COUNT); proto = -15; }
    for (int s = 0; s < 3; s++)
        if (!res->head_end[s]) { printf("  %s: END 행 없음 (후보 %lu)\n", head_name[s], (unsigned long)res->cand[s]); proto = -16; }
    if (res->proto_err)                { printf("  검출 / END 형식 오류 %lu 회\n", (unsigned long)res->proto_err); proto = -17; }
#if EMY_CAM_GOLDEN
    if (res->end_ndrop)                { printf("  후보 저장소 넘침: %u 개 버림\n", res->end_ndrop); proto = -18; }
#else
    if (res->end_ndrop)                printf("  경고: 후보 저장소 (512) 넘침 — %u 개 버림 (QTHR 을 올릴 것)\n", res->end_ndrop);   /* 카메라: FAIL 아님 */
#endif
#if EMY_GOLDEN_CHECK
    for (int s = 0; s < 3; s++)
        if (res->end_ncand[s] != emy_expected_nms_cand_n[s]) { printf("  %s: 후보 %u (기대 %u)\n", head_name[s], res->end_ncand[s], emy_expected_nms_cand_n[s]); proto = -19; }
#endif
    if (proto) return proto;
    return (int)(res->bad[0] + res->bad[1] + res->bad[2]);
}

/* ------------------------------------------------------------------------------------------------ */
/* 3. IP 가 낸 검출 목록을 기대 목록 (float 참조) 과 비교. 반환 0 = 일치. */

#if !EMY_QUIET || EMY_CAM_SRC
/* 좌표를 ±ddd.dd 로 (FPU 없음 → 정수). 음수 (상자가 영상 밖으로 조금 나간 경우, IP 좌표는 int16 1/16 px) 도 바르게 찍는다 — 전에는 "0.-62" 로 나왔다 */
static const char *fmt2(float v, char *buf)
{
    int c = (int)(v * 100.0f + (v < 0 ? -0.5f : 0.5f)), a = c < 0 ? -c : c;
    int n = 0; if (c < 0) buf[n++] = '-';
    int ip = a / 100, fp = a % 100;
    char tmp[8]; int k = 0; do { tmp[k++] = (char)('0' + ip % 10); ip /= 10; } while (ip);
    while (k) buf[n++] = tmp[--k];
    buf[n++] = '.'; buf[n++] = (char)('0' + fp / 10); buf[n++] = (char)('0' + fp % 10); buf[n] = 0;
    return buf;
}
static void print_det(int i, const emy_det_t *d, const char *tag)
{
    char b1[12], b2[12], b3[12], b4[12];
    int cf = (int)(d->conf * 10000.0f + 0.5f);
    printf("  det %2d: cls %2d conf 0.%04d  box [%7s %7s %7s %7s] %s\n", i, d->cls, cf, fmt2(d->x1, b1), fmt2(d->y1, b2), fmt2(d->x2, b3), fmt2(d->y2, b4), tag);
}
#endif

#if EMY_RUN_HEAD_POST
static int head_post_and_check(int frame_no, const emy_result_t *res)
{
    int n = (res->dets < EMY_HP_MAX_DET) ? (int)res->dets : EMY_HP_MAX_DET;
    profiling_start_by_name("emy_head_post");
    printf("frame %d head (b): 후보 %u / %u / %u (버림 %u), IP 검출 %d (기대 %d)\n", frame_no, res->end_ncand[0], res->end_ncand[1], res->end_ncand[2],
           res->end_ndrop, n, EMY_EXPECTED_DET_N);
    static uint8_t used[EMY_EXPECTED_DET_N];
    memset(used, 0, sizeof(used));
    int matched = 0;
    for (int i = 0; i < n; i++) {
        int best = -1; float bd = 1e30f;
        for (int j = 0; j < EMY_EXPECTED_DET_N; j++) {
            const emy_expected_det_t *e = &emy_expected_det[j];
            if (used[j] || e->cls != emy_dets[i].cls) continue;
            float d = emy_dets[i].x1 - e->x1; if (d < 0) d = -d;
            float t = emy_dets[i].y1 - e->y1; if (t < 0) t = -t; d += t;
            t = emy_dets[i].x2 - e->x2; if (t < 0) t = -t; d += t;
            t = emy_dets[i].y2 - e->y2; if (t < 0) t = -t; d += t;
            if (d < bd) { bd = d; best = j; }
        }
        int ok = 0;
        if (best >= 0) {
            const emy_expected_det_t *e = &emy_expected_det[best];
            float dc = emy_dets[i].conf - e->conf; if (dc < 0) dc = -dc;
            float m = 0, t;
            t = emy_dets[i].x1 - e->x1; if (t < 0) t = -t; if (t > m) m = t;
            t = emy_dets[i].y1 - e->y1; if (t < 0) t = -t; if (t > m) m = t;
            t = emy_dets[i].x2 - e->x2; if (t < 0) t = -t; if (t > m) m = t;
            t = emy_dets[i].y2 - e->y2; if (t < 0) t = -t; if (t > m) m = t;
            ok = (m <= 0.5f) && (dc <= 1e-3f);
            if (ok) { used[best] = 1; matched++; }
        }
#if !EMY_QUIET
        profiling_start_by_name("emy_det_print");
        print_det(i, &emy_dets[i], ok ? "ok" : "** no match **");
        profiling_end_by_name("emy_det_print");
#endif
    }
    int pass = (matched == EMY_EXPECTED_DET_N) && (n == EMY_EXPECTED_DET_N) && (res->end_ndrop == 0);
    profiling_end_by_name("emy_head_post");
    printf("frame %d head (b): 기대 %d 개 중 %d 개 일치 → %s\n", frame_no, EMY_EXPECTED_DET_N, matched, pass ? "PASS" : "FAIL");
    return pass ? 0 : 1;
}
#endif

/* ------------------------------------------------------------------------------------------------ */
#if EMY_RUN_GOLDEN_TEST
static int golden_test(void)
{
    int fails = 0;
    frame_src = (const uint8_t *)emy_input_frame; frame_chunk = EMY_SLOT_BYTES;
    printf("\n=== eMambaYOLO_IP v2 골든 테스트 + NMS 모드 (u504_zeta: IP 가 sigmoid · DFL · 좌표 · NMS, CPU 는 읽기만) ===\n");
    printf("IP @%08lx  IN @%08lx  WB @%08lx  OUT @%08lx\n", (unsigned long)EMY_IP, (unsigned long)EMY_IN, (unsigned long)EMY_WB, (unsigned long)EMY_OUT);
    printf("boot %lu B (sha %s)  frame %lu B  expected cands %u / %u / %u  golden check %d  expected dets %d (NMS rows %d)\n", (unsigned long)EMY_BOOT_BYTES,
           EMY_BOOT_SHA256, (unsigned long)EMY_FRAME_BYTES, emy_expected_nms_cand_n[0], emy_expected_nms_cand_n[1],
           emy_expected_nms_cand_n[2], EMY_GOLDEN_CHECK, EMY_EXPECTED_DET_N, EMY_EXPECTED_NMS_N);

    int rc = emy_build_boot();
    if (rc) { printf("*** BOOT STREAM BUILD FAIL (%d) ***\n", rc); return 1; }
    profiling_start_by_name("emy_boot");
    rc = emy_boot();
    profiling_end_by_name("emy_boot");
    if (rc) { printf("*** BOOT FAIL (%d) ***\n", rc); return 1; }

    for (int f = 0; f < EMY_FRAMES; f++) {
        emy_result_t res;
        profiling_start_by_name("emy_frame");
        rc = emy_frame_run(f, &res);
        profiling_end_by_name("emy_frame");
        printf("frame %d: IN 청크 %lu, OUT 슬롯 %lu, 행 %lu/%lu/%lu, 검출 %lu, 후보 %u/%u/%u, STATUS 폴링 %lu (빈 %lu, 대기 구간 %lu), 불일치 %lu 워드\n", f,
               (unsigned long)res.in_chunks, (unsigned long)res.slots, (unsigned long)res.rows[0], (unsigned long)res.rows[1], (unsigned long)res.rows[2],
               (unsigned long)res.dets, res.end_ncand[0], res.end_ncand[1], res.end_ncand[2], (unsigned long)res.polls, (unsigned long)res.idle_polls,
               (unsigned long)res.idle_runs, (unsigned long)res.bad[0]);
        if (rc == 0)      printf("frame %d: PASS — 검출 %lu 개 %s\n", f, (unsigned long)res.dets,
                                 EMY_GOLDEN_CHECK ? "모두 기대 표와 일치" : "받음 (골든 비교 없음)");
        else if (rc > 0)  { printf("frame %d: *** MISMATCH %d words ***\n", f, rc); fails++; }
        else              { printf("frame %d: *** PROTOCOL ERROR %d ***\n", f, rc); fails++; continue; }
#if EMY_RUN_HEAD_POST
        fails += head_post_and_check(f, &res);
#endif
    }
    profiling_print();
    printf("=== %s ===\n\n", fails ? "FAIL" : "PASS");
    return fails;
}
#endif /* EMY_RUN_GOLDEN_TEST */

#if EMY_RUN_CAMERA_DEMO
/* 원래 main 의 카메라 데모 (GUI) — 그대로 */
static void camera_demo(void)
{
    while(edge_video_system_config_gui())
    {
      edge_video_system_start();
      edge_video_system_display_direct(1);
    }
    printf(" ");
}
#endif

#if EMY_CAM_SRC
/* ------------------------------------------------------------------------------------------------ */
/* 4. 카메라 루프 (docs/CAMERA_ZETA_PLAN.html §02 · §05): 캡처 → 변환 (스테이징) → IP → 검출 → 캡처 버퍼에 박스 → VOM */
static uint8_t cam_staging[EMY_CAM_PIPELINE ? 2 : 1][EMY_CAM_FRAME_BYTES] EMY_BIGDATA;
#if EMY_CAM_SELFTEST
static int cam_selftest_buf = 0;                       /* 합성 프레임 (변환 소스, 손대지 않음) · VIM 없음 */
static int cam_selftest_disp = 1;                      /* 같은 합성 프레임의 사본 — 박스는 여기에 그려 화면에 보인다 (소스에 그리면 다음 변환에 섞임) */
#endif

/* 캡처 한 장: 셀프테스트는 합성 버퍼, 아니면 VIM 완성 버퍼 (VIM 정지) */
static int cam_take(int wait_fresh)
{
#if EMY_CAM_SELFTEST
    (void)wait_fresh;
    return cam_selftest_buf;
#else
    profiling_start_by_name("emy_cam_capture");
    int b = emy_cam_capture(wait_fresh);
    profiling_end_by_name("emy_cam_capture");
    return b;
#endif
}

/* 변환 전부 (직렬) 뒤 VIM 재가동 */
static void cam_convert(int buf, uint8_t *stg)
{
    profiling_start_by_name("emy_cam_convert");
    emy_cam_convert_all(emy_cam_img(buf), stg);
    profiling_end_by_name("emy_cam_convert");
#if !EMY_CAM_SELFTEST
    emy_cam_resume();
#endif
}

#if EMY_CAM_PIPELINE
static struct { int state, buf, row; uint8_t *stg; } cam_job;   /* 0 대기 (첫 유휴에 캡처) · 1 변환 중 · 2 끝 */
static void cam_idle_step(void)
{
    if (cam_job.state == 0) {
        cam_job.buf = cam_take(1); cam_job.row = emy_cam_geom.pad_rows;
        cam_job.state = (cam_job.buf >= 0) ? 1 : 2;
        return;
    }
    if (cam_job.state == 1) {                          /* 한 행 (≈ 2–3 ms) 씩 */
        profiling_start_by_name("emy_cam_convert");
        cam_job.row = emy_cam_convert_rows(emy_cam_img(cam_job.buf), cam_job.stg, cam_job.row, 1);
        profiling_end_by_name("emy_cam_convert");
        if (cam_job.row >= emy_cam_geom.pad_rows + emy_cam_geom.img_rows) {
#if !EMY_CAM_SELFTEST
            emy_cam_resume();
#endif
            cam_job.state = 2;
        }
    }
}
#endif

static void cam_loop(void)
{
    printf("\n=== u504_eta: 카메라 → IP (NMS 모드) → 박스  [%s · %s · 청크 %u B × %u%s] ===\n",
           EMY_CAM_SELFTEST ? "셀프테스트 (합성 프레임 = 골든)" : "HDMI 카메라", EMY_CAM_PIPELINE ? "겹침" : "직렬",
           (unsigned)EMY_CAM_CHUNK_BYTES, (unsigned)EMY_CAM_CHUNKS, EMY_CAM_VDMA ? " · VDMA" : "");
    printf("IP @%08lx  IN @%08lx  WB @%08lx  OUT @%08lx  FILTER qthr %d / %d / %d\n", (unsigned long)EMY_IP, (unsigned long)EMY_IN, (unsigned long)EMY_WB,
           (unsigned long)EMY_OUT, EMY_QTHR0, EMY_QTHR1, EMY_QTHR2);
    int rc = emy_build_boot();
    if (rc) { printf("*** BOOT STREAM BUILD FAIL (%d) ***\n", rc); return; }
    profiling_start_by_name("emy_boot");
    rc = emy_boot();
    profiling_end_by_name("emy_boot");
    if (rc) { printf("*** BOOT FAIL (%d) ***\n", rc); return; }

    emy_cam_setup(!EMY_CAM_SELFTEST);
#if EMY_CAM_SELFTEST
    emy_cam_fill_from_golden(cam_selftest_buf, emy_input_frame);      /* 기하를 골든의 레터박스에 맞추고 합성 XBGR 프레임을 버퍼에 */
    emy_cam_fill_from_golden(cam_selftest_disp, emy_input_frame);     /* 표시 · 박스용 사본 */
#endif
    printf("emy_cam: 소스 %dx%d, 배율 1/%d (표본 오프셋 %d), 패딩 %d 행 + 영상 %d 행 + 패딩 %d 행\n", emy_cam_geom.src_w, emy_cam_geom.src_h, emy_cam_geom.scale,
           emy_cam_geom.src_off, emy_cam_geom.pad_rows, emy_cam_geom.img_rows, EMY_CAM_H - emy_cam_geom.pad_rows - emy_cam_geom.img_rows);
    for (int i = 0; i < (EMY_CAM_PIPELINE ? 2 : 1); i++) emy_cam_staging_init(cam_staging[i]);
    frame_chunk = EMY_CAM_CHUNK_BYTES;

    int capbuf = cam_take(0);
    if (capbuf < 0) { printf("*** 캡처 실패 ***\n"); return; }
    cam_convert(capbuf, cam_staging[0]);
#if EMY_CAM_SELFTEST
    {   /* 변환기 검증: 스테이징 전체 == 골든 프레임 (워드 비교) */
        const uint32_t *a = (const uint32_t *)cam_staging[0], *g = (const uint32_t *)(const void *)emy_input_frame;
        uint32_t bad = 0, first = 0xFFFFFFFFu;
        for (uint32_t i = 0; i < EMY_FRAME_BYTES / 4u; i++) if (a[i] != g[i]) { if (!bad) first = i; bad++; }
        printf("selftest: 변환 결과 vs 골든 프레임 — 다른 워드 %lu / %lu%s", (unsigned long)bad, (unsigned long)(EMY_FRAME_BYTES / 4u), bad ? "" : " (일치)\n");
        if (bad) printf(" (첫 불일치 워드 %lu: %08lx != %08lx)\n", (unsigned long)first, (unsigned long)a[first], (unsigned long)g[first]);
    }
#endif

    int frames = 0, fails = 0;
    uint64_t t_prev = get_real_clock_tick(); unsigned frame_ms = 0;
    for (int f = 0; ; f++) {
#if EMY_CAM_SINGLE
        printf("c: 다음 프레임, x: 종료\n");
        for (;;) { int k = emy_cam_key(); if (k == 'c') break; if (k == 'x') goto done; }
#endif
        frame_src = cam_staging[EMY_CAM_PIPELINE ? (f & 1) : 0];
#if EMY_CAM_SELFTEST
        {   /* 프레임마다 스테이징 == 골든 (겹침 모드에서는 유휴 훅이 만든 것) */
            const uint32_t *a = (const uint32_t *)frame_src, *g = (const uint32_t *)(const void *)emy_input_frame;
            uint32_t bad = 0, r0 = 0, r1 = 0;
            for (uint32_t i = 0; i < EMY_FRAME_BYTES / 4u; i++) if (a[i] != g[i]) { uint32_t r = i / (EMY_CAM_ROW_BYTES / 4u); if (!bad) r0 = r; r1 = r; bad++; }
            if (bad) { printf("frame %d: *** 스테이징 != 골든: 워드 %lu, 행 %lu … %lu ***\n", f, (unsigned long)bad, (unsigned long)r0, (unsigned long)r1); fails++; }
            else printf("frame %d: 스테이징 == 골든 프레임\n", f);
        }
#endif
#if EMY_CAM_PIPELINE
        cam_job.state = 0; cam_job.buf = -1; cam_job.stg = cam_staging[(f & 1) ^ 1];
#endif
        emy_result_t res;
        profiling_start_by_name("emy_frame");
        rc = emy_frame_run(f, &res);
        profiling_end_by_name("emy_frame");
        if (rc < 0) { printf("frame %d: *** PROTOCOL ERROR %d ***\n", f, rc); fails++; break; }
        if (rc > 0) { printf("frame %d: *** MISMATCH %d words ***\n", f, rc); fails++; }
        int n = (res.dets < EMY_HP_MAX_DET) ? (int)res.dets : EMY_HP_MAX_DET;
        { uint64_t t = get_real_clock_tick(); frame_ms = (unsigned)((t - t_prev) / 1000u); t_prev = t; }   /* 이 프레임의 주기 (캡처 · 변환 · IP · 그리기 포함) */
        printf("frame %d: 검출 %d (후보 %u / %u / %u, 버림 %u), IN 청크 %lu, OUT 슬롯 %lu, 폴링 %lu (빈 %lu), 주기 %u ms\n", f, n, res.end_ncand[0], res.end_ncand[1],
               res.end_ncand[2], res.end_ndrop, (unsigned long)res.in_chunks, (unsigned long)res.slots, (unsigned long)res.polls, (unsigned long)res.idle_polls, frame_ms);
        for (int i = 0; i < n; i++) print_det(i, &emy_dets[i], "");
#if EMY_RUN_HEAD_POST
        fails += head_post_and_check(f, &res);
#endif
#if EMY_CAM_SELFTEST
        int drawbuf = cam_selftest_disp;
#else
        int drawbuf = capbuf;
#endif
        profiling_start_by_name("emy_cam_draw");
        emy_cam_draw_dets(drawbuf, emy_dets, n);
#if EMY_CAM_LABELS
        emy_label_dets(drawbuf, emy_dets, n, EMY_CAM_LABEL_NAMES);
#endif
#if EMY_CAM_STATUS
        emy_label_status(drawbuf, f, frame_ms, n);
#endif
        profiling_end_by_name("emy_cam_draw");
        emy_cam_show(drawbuf);
#if defined(EMY_HOST_MOCK) && EMY_CAM_SELFTEST
        emy_cam_mock_dump_ppm(drawbuf, "theta_frame.ppm");
#endif
        frames++;
        if (EMY_CAM_FRAMES && frames >= EMY_CAM_FRAMES) break;
        if (emy_cam_key() == 'x') break;
#if EMY_CAM_PIPELINE
        while (cam_job.state != 2) cam_idle_step();    /* 변환이 IP 보다 늦었으면 남은 행을 여기서 */
        if (cam_job.buf < 0) { printf("*** 캡처 실패 ***\n"); fails++; break; }
        capbuf = cam_job.buf;
#else
        capbuf = cam_take(1);
        if (capbuf < 0) { printf("*** 캡처 실패 ***\n"); fails++; break; }
        cam_convert(capbuf, cam_staging[0]);
#endif
    }
#if EMY_CAM_SINGLE
done:
#endif
    profiling_print();
    printf("=== %s: 프레임 %d, 실패 %d, VIM_IDX 변화 %lu ===\n\n", fails ? "FAIL" : "PASS", frames, fails, (unsigned long)emy_cam_idx_switches());
}
#endif /* EMY_CAM_SRC */

void main(void)
{
  if(EXCLUSIVE_ID==0)
  {
#if EMY_CAM_SRC
    cam_loop();
#else
#if EMY_RUN_GOLDEN_TEST
    golden_test();
#endif
#if EMY_RUN_CAMERA_DEMO
    camera_demo();
#endif
#endif
  }
}

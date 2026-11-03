/* u504_eta — 카메라 경로 구현 (include/emy_camera.h 참고). 플랫폼 호출은 이 파일에만 있다.
 * EMY_HOST_MOCK (PC 모의 빌드): 버퍼는 malloc, VIM · VOM · 키는 빈 함수. 변환 · 그리기 · 합성은 보드와 같은 코드가 돈다. */
#include <stdint.h>
#include <string.h>
#include "emy_camera.h"

#ifndef EMY_HOST_MOCK
#include "platform_info.h"
#include "memorymap_info.h"
#include "ervp_printf.h"
#include "ervp_mmio_util.h"
#include "ervp_delay.h"
#include "ervp_mcom_input.h"
#include "ervp_image.h"
#include "edge_video_system.h"
#else
#include <stdio.h>
#include <stdlib.h>
#endif

#define NBUF (EMY_CAM_PIPELINE ? 5 : 4)        /* VIM 2 + 보존 (직렬 1, 겹침 2) + 표시 중 1 */
#define BUF_W 1920
#define BUF_H 1080

emy_cam_geom_t emy_cam_geom = { EMY_CAM_SCALE, EMY_CAM_PAD_ROWS, EMY_CAM_IMG_ROWS, EMY_CAM_SRC_OFF, EMY_CAM_SRC_W, EMY_CAM_SRC_H };

static emy_cam_img_t bufs[5];
static uint8_t  bstate[5];                      /* 0 빈, 1 VIM 이 쓰는 중, 2 보존 (캡처 · 변환 · 박스 대기), 3 화면에 보이는 중 */
static int      vimbuf[2] = { 0, 1 };           /* VIM ADDR0 / ADDR1 에 걸린 버퍼 번호 */
static int      displayed = -1, prev_idx = -1, resume_idx = -1, cam_on = 0;
static uint32_t idx_switches = 0;
#ifndef EMY_HOST_MOCK
static ErvpImage *imgs[5];
#endif

#if EMY_CAM_SRAM_CODE && !defined(EMY_HOST_MOCK)
static void conv_core_to_sram(void);            /* 아래 (변환 절) 에 정의 — setup 이 먼저 호출한다 */
#endif

const emy_cam_img_t *emy_cam_img(int buf) { return &bufs[buf]; }
uint32_t emy_cam_idx_switches(void) { return idx_switches; }

static int find_free(void)
{
    for (int i = 0; i < NBUF; i++) if (bstate[i] == 0) return i;
    return -1;
}

/* ------------------------------------------------------------------------------------------------ */
/* 플랫폼 층 */
#ifndef EMY_HOST_MOCK

static inline int  hw_idx(void)            { return vim_get_idx() & 1; }
static inline uint32_t hw_status(void)     { return (uint32_t)vim_get_status(); }
static inline void hw_vim_off(void)        { vim_disable(); }
static inline void hw_vim_on(void)         { vim_enable_hdmi(); }
static inline void hw_vim_base(int k, uintptr_t a) { if (k) vim_set_base1((unsigned int)a); else vim_set_base0((unsigned int)a); }
static inline void hw_vom_base(uintptr_t a) { vom_set_base((unsigned int)a); }
static inline void hw_delay_ms(int ms)     { delay_ms(ms); }

void emy_cam_setup(int with_camera)
{
    edge_video_system_init();
    edge_video_system_config.camera_hw = with_camera ? CAMERA_HW_HDMI : CAMERA_HW_NONE;   /* test_video_const 와 같은 고정 설정 */
    edge_video_system_config.camera_resolution = IMAGE_RESOLUTION_FHD;
    edge_video_system_config.display_hw = DISPLAY_HW_HDMI;
    edge_video_system_config.display_resolution = IMAGE_RESOLUTION_FHD;
    edge_video_system_config.image_format = IMAGE_FMT_XBGR_8888_PACKED;
    for (int i = 0; i < NBUF; i++) {
        imgs[i] = image_alloc_option(BUF_W, BUF_H, IMAGE_FMT_XBGR_8888_PACKED, 1, 1);   /* 정렬 · 영구 (DDR, 8.3 MB) */
        image_clear(imgs[i], 0);
        bufs[i].base = (uintptr_t)imgs[i]->addr[0]; bufs[i].stride = imgs[i]->stride[0]; bufs[i].w = BUF_W; bufs[i].h = BUF_H;
        bstate[i] = 0;
        printf("emy_cam: 버퍼 %d @%08lx stride %lu\n", i, (unsigned long)bufs[i].base, (unsigned long)bufs[i].stride);
    }
    edge_video_system_register_frame(imgs[2], imgs[0], imgs[1]);   /* out = 2 (검정), in0 / in1 = 0 / 1 */
    edge_video_system_start();                                    /* ADV7619 · VIM (with_camera), SIL1136 · VOM. 라이브러리가 찍는 "Input: HDMI (1920x1080)" 은 버퍼 크기 (FHD 프레임 버퍼) 이다 */
    cam_on = with_camera;
    if (with_camera) {
#if EMY_CAM_720P
        vim_disable(); vim_set_size(EMY_CAM_SRC_W, EMY_CAM_SRC_H); vim_enable_hdmi();   /* 720p 소스: 버퍼 · stride 는 FHD 그대로, 그림은 좌상단 */
        printf("emy_cam: VIM 크기를 %dx%d 로 바꿈 (위 라이브러리 줄의 1920x1080 은 프레임 버퍼 크기; 출력 HDMI 는 FHD 그대로)\n", EMY_CAM_SRC_W, EMY_CAM_SRC_H);
#endif
        bstate[0] = bstate[1] = 1; vimbuf[0] = 0; vimbuf[1] = 1;
        prev_idx = resume_idx = hw_idx();
    }
    bstate[2] = 3; displayed = 2;
#if EMY_CAM_SRAM_CODE
    conv_core_to_sram();
#endif
    printf("emy_cam: setup 끝 (카메라 %s, 소스 %dx%d /%d, 버퍼 %d 장)\n", with_camera ? "on" : "off", EMY_CAM_SRC_W, EMY_CAM_SRC_H, EMY_CAM_SCALE, NBUF);
}

int emy_cam_key(void) { return has_input_from_mcom() ? getc_from_mcom() : -1; }

#else  /* ---- PC 모의 ---- */

static int mock_idx = 0;
static inline int  hw_idx(void)            { return mock_idx; }
static inline uint32_t hw_status(void)     { return 0; }
static inline void hw_vim_off(void)        { }
static inline void hw_vim_on(void)         { mock_idx ^= 1; }
static inline void hw_vim_base(int k, uintptr_t a) { (void)k; (void)a; }
static inline void hw_vom_base(uintptr_t a) { (void)a; }
static inline void hw_delay_ms(int ms)     { (void)ms; }

void emy_cam_setup(int with_camera)
{
    for (int i = 0; i < NBUF; i++) {
        bufs[i].base = (uintptr_t)calloc((size_t)BUF_W * BUF_H, 4); bufs[i].stride = BUF_W * 4; bufs[i].w = BUF_W; bufs[i].h = BUF_H; bstate[i] = 0;
        if (!bufs[i].base) { fprintf(stderr, "emy_cam mock: calloc\n"); exit(5); }
    }
    cam_on = with_camera;
    if (with_camera) { bstate[0] = bstate[1] = 1; vimbuf[0] = 0; vimbuf[1] = 1; prev_idx = resume_idx = 0; }
    bstate[2] = 3; displayed = 2;
    printf("emy_cam(mock): setup (카메라 %s, 버퍼 %d 장)\n", with_camera ? "on" : "off", NBUF);
}

int emy_cam_key(void) { return -1; }

#endif

/* ------------------------------------------------------------------------------------------------ */
/* 캡처 · 재가동 · 표시 (풀 운용은 보드 · PC 공통) */
int emy_cam_capture(int wait_fresh)
{
    if (!cam_on) return -1;
    if (wait_fresh && resume_idx >= 0) {            /* 재가동 뒤 완성 프레임이 한 장은 새로 들어왔는지 (IDX 변화) */
        int t = 0;
        while (hw_idx() == resume_idx && t < 300) { hw_delay_ms(1); t++; }
        if (t >= 300) printf("emy_cam: 재가동 뒤 300 ms 동안 VIM_IDX 변화 없음 (IDX %d, VIM_STATUS %08lx) — 소스가 1080p 를 보내는지 (720p 면 EMY_CAM_720P 1) · VIM 재시작 확인\n",
                             hw_idx(), (unsigned long)hw_status());
    }
    int idx = hw_idx();
    hw_vim_off();
    if (prev_idx >= 0 && idx != prev_idx) idx_switches++;
    prev_idx = idx;
    int cap = vimbuf[idx];
    int f = find_free();
    if (f < 0) { printf("emy_cam: 빈 버퍼 없음 (상태 %d %d %d %d %d)\n", bstate[0], bstate[1], bstate[2], bstate[3], bstate[4]); hw_vim_on(); return -1; }
    hw_vim_base(idx, bufs[f].base);                 /* 꺼진 상태에서 ADDR 재기록 — 캡처 버퍼는 이제 VIM 집합 밖 */
    vimbuf[idx] = f; bstate[f] = 1; bstate[cap] = 2;
    return cap;
}

void emy_cam_resume(void)
{
    if (!cam_on) return;
    resume_idx = hw_idx();
    hw_vim_on();
}

void emy_cam_show(int buf)
{
    hw_vom_base(bufs[buf].base);
    if (displayed >= 0 && displayed != buf && bstate[displayed] == 3) bstate[displayed] = 0;
    bstate[buf] = 3; displayed = buf;
}

void emy_cam_release(int buf) { if (buf >= 0 && buf < NBUF && bstate[buf] == 2) bstate[buf] = 0; }

/* ------------------------------------------------------------------------------------------------ */
/* 변환: XBGR 워드 (R<<24 | G<<16 | B<<8) → HWC int8 (R, G, B), 1/SCALE 최근접 (SRC_OFF 로 블록 가운데 표본) */
void emy_cam_staging_init(uint8_t *stg)
{
    const emy_cam_geom_t *g = &emy_cam_geom;
    uint32_t *d = (uint32_t *)stg;
    for (uint32_t i = 0; i < (uint32_t)g->pad_rows * EMY_CAM_ROW_BYTES / 4u; i++) d[i] = EMY_CAM_PAD_WORD;
    d = (uint32_t *)(stg + (uint32_t)(g->pad_rows + g->img_rows) * EMY_CAM_ROW_BYTES);
    for (uint32_t i = 0; i < (uint32_t)(EMY_CAM_H - g->pad_rows - g->img_rows) * EMY_CAM_ROW_BYTES / 4u; i++) d[i] = EMY_CAM_PAD_WORD;
}

/* 핫 루프 v2 (SWAR). 전역 · 호출 없음 → 코드를 SRAM 에 복사해도 돈다. rows 개의 스테이징 행을 만든다; src 는 행마다 stride_words·sc 만큼 전진 */
__attribute__((noinline)) void emy_cam_conv_core(const uint32_t *src, uint32_t stride_words, uint32_t *dst, int rows, int sc)
{
    for (int h = 0; h < rows; h++, src += stride_words * (uint32_t)sc, dst += EMY_CAM_ROW_BYTES / 4) {
        const uint32_t *s = src; uint32_t *d = dst;
        for (int w = 0; w < EMY_CAM_W; w += 4, s += 4 * sc, d += 3) {                          /* 픽셀 4 개 (워드 4 읽기) → 바이트 12 = 워드 3 */
            uint32_t ra = EMY_CAM_RGB(EMY_CAM_QWORD(s[0])), rb = EMY_CAM_RGB(EMY_CAM_QWORD(s[sc]));
            uint32_t rc = EMY_CAM_RGB(EMY_CAM_QWORD(s[2 * sc])), rd = EMY_CAM_RGB(EMY_CAM_QWORD(s[3 * sc]));
            d[0] = ra | (rb << 24);                 /* R0 G0 B0 R1 */
            d[1] = (rb >> 8) | (rc << 16);          /* G1 B1 R2 G2 */
            d[2] = (rc >> 16) | (rd << 8);          /* B2 R3 G3 B3 */
        }
    }
}
__attribute__((noinline)) static void conv_core_end_marker(void) { }

typedef void (*conv_fn_t)(const uint32_t *, uint32_t, uint32_t *, int, int);
static conv_fn_t conv_fn = emy_cam_conv_core;

#if EMY_CAM_SRAM_CODE && !defined(EMY_HOST_MOCK)
static void conv_core_to_sram(void)
{
    uintptr_t f0 = (uintptr_t)emy_cam_conv_core, f1 = (uintptr_t)conv_core_end_marker;
    uint32_t len = (f1 > f0 && f1 - f0 < 4096u) ? (uint32_t)(f1 - f0) : 2048u;
    memcpy((void *)(uintptr_t)EMY_CAM_SRAM_CODE_ADDR, (const void *)f0, len);
    conv_fn = (conv_fn_t)(uintptr_t)EMY_CAM_SRAM_CODE_ADDR;
    printf("emy_cam: 변환 핫 루프 %lu B 를 SRAM %08lx 에 복사 (DRAM 코드 @%08lx)\n", (unsigned long)len, (unsigned long)EMY_CAM_SRAM_CODE_ADDR, (unsigned long)f0);
}
#endif

int emy_cam_convert_rows(const emy_cam_img_t *src, uint8_t *stg, int row0, int nrows)
{
    const emy_cam_geom_t *g = &emy_cam_geom;
    int end = row0 + nrows;
    if (end > EMY_CAM_H) end = EMY_CAM_H;
    int h0 = row0 < g->pad_rows ? g->pad_rows : row0, h1 = end > g->pad_rows + g->img_rows ? g->pad_rows + g->img_rows : end;   /* 영상 행만; 패딩은 staging_init */
    if (h1 > h0) {
        uint32_t sr = (uint32_t)(h0 - g->pad_rows) * (uint32_t)g->scale + (uint32_t)g->src_off;
        const uint32_t *s = (const uint32_t *)(src->base + sr * src->stride) + g->src_off;
        conv_fn(s, src->stride / 4u, (uint32_t *)(stg + (uint32_t)h0 * EMY_CAM_ROW_BYTES), h1 - h0, g->scale);
    }
    return end;
}

void emy_cam_convert_all(const emy_cam_img_t *src, uint8_t *stg)
{
    (void)emy_cam_convert_rows(src, stg, emy_cam_geom.pad_rows, emy_cam_geom.img_rows);
}

/* ------------------------------------------------------------------------------------------------ */
/* 박스: 640 좌표 → 소스 좌표 (×SCALE, y − 140), 둘레 3 px */
static const uint32_t cls_color[8] = {
    0xFF000000u, 0x00FF0000u, 0x0000FF00u, 0xFFFF0000u, 0xFF00FF00u, 0x00FFFF00u, 0xFFFFFF00u, 0xFF800000u   /* R G B Y M C W 주황 */
};

uint32_t emy_cam_cls_color(int cls) { return cls_color[cls & 7]; }

#ifdef EMY_HOST_MOCK
void emy_cam_mock_dump_ppm(int buf, const char *path)
{
    FILE *f = fopen(path, "wb");
    if (!f) { fprintf(stderr, "ppm: cannot open %s\n", path); return; }
    const emy_cam_img_t *img = &bufs[buf];
    fprintf(f, "P6\n%d %d\n255\n", emy_cam_geom.src_w, emy_cam_geom.src_h);
    for (int y = 0; y < emy_cam_geom.src_h; y++) {
        const uint32_t *p = (const uint32_t *)(img->base + (uint32_t)y * img->stride);
        for (int x = 0; x < emy_cam_geom.src_w; x++) { unsigned char rgb[3] = { (unsigned char)(p[x] >> 24), (unsigned char)(p[x] >> 16), (unsigned char)(p[x] >> 8) }; fwrite(rgb, 1, 3, f); }
    }
    fclose(f);
    printf("emy_cam(mock): 버퍼 %d → %s (%dx%d)\n", buf, path, emy_cam_geom.src_w, emy_cam_geom.src_h);
}
#endif

static inline int clampi(int v, int lo, int hi) { return v < lo ? lo : (v > hi ? hi : v); }

static void hline(const emy_cam_img_t *img, int y, int x1, int x2, uint32_t c)
{
    uint32_t *p = (uint32_t *)(img->base + (uint32_t)y * img->stride);
    for (int x = x1; x <= x2; x++) p[x] = c;
}
static void vline(const emy_cam_img_t *img, int x, int y1, int y2, uint32_t c)
{
    for (int y = y1; y <= y2; y++) *(uint32_t *)(img->base + (uint32_t)y * img->stride + 4u * (uint32_t)x) = c;
}

void emy_cam_draw_dets(int buf, const emy_det_t *d, int n)
{
    const emy_cam_img_t *img = &bufs[buf];
    const emy_cam_geom_t *g = &emy_cam_geom;
    const int W = g->src_w, H = g->src_h, sc = g->scale, pad = g->pad_rows;
    for (int i = 0; i < n; i++) {
        int x1 = clampi((int)(d[i].x1 * sc), 0, W - 1), x2 = clampi((int)(d[i].x2 * sc), 0, W - 1);
        int y1 = clampi((int)((d[i].y1 - pad) * sc), 0, H - 1), y2 = clampi((int)((d[i].y2 - pad) * sc), 0, H - 1);
        if (x2 <= x1 || y2 <= y1) continue;
        uint32_t c = cls_color[d[i].cls & 7];
        for (int t = 0; t < 3; t++) {
            if (y1 + t <= y2) hline(img, y1 + t, x1, x2, c);
            if (y2 - t >= y1) hline(img, y2 - t, x1, x2, c);
            if (x1 + t <= x2) vline(img, x1 + t, y1, y2, c);
            if (x2 - t >= x1) vline(img, x2 - t, y1, y2, c);
        }
    }
}

/* 셀프테스트용 합성 프레임: 골든 int8 q → p = (q·255 + 32) / 64 (round(p·64/255) == q 가 0 … 64 전부 성립), scale×scale 복제.
 * 먼저 골든의 레터박스 (위 · 아래의 0x1D 행 수) 를 재서 기하를 맞춘다: 골든 프레임은 패딩 107 · 영상 426 행 → 배율 2 (1280×852 ≤ 1920×1080). */
void emy_cam_fill_from_golden(int buf, const int8_t frame[EMY_CAM_H][EMY_CAM_W][3])
{
    const emy_cam_img_t *img = &bufs[buf];
    int pad = 0;
    for (; pad < EMY_CAM_H / 2; pad++) {
        const uint32_t *w = (const uint32_t *)(const void *)frame[pad];
        int all = 1;
        for (int i = 0; i < EMY_CAM_ROW_BYTES / 4 && all; i++) all = (w[i] == EMY_CAM_PAD_WORD);
        if (!all) break;
    }
    int img_rows = EMY_CAM_H - 2 * pad, sc = 1;
    while (sc < 3 && EMY_CAM_W * (sc + 1) <= BUF_W && img_rows * (sc + 1) <= BUF_H) sc++;
    emy_cam_geom.scale = sc; emy_cam_geom.pad_rows = pad; emy_cam_geom.img_rows = img_rows; emy_cam_geom.src_off = 0;
    emy_cam_geom.src_w = EMY_CAM_W * sc; emy_cam_geom.src_h = img_rows * sc;
    printf("emy_cam: 셀프테스트 기하 — 골든 레터박스 %d 행, 영상 %d 행, 배율 %d → 합성 %dx%d\n", pad, img_rows, sc, emy_cam_geom.src_w, emy_cam_geom.src_h);
    for (int R = 0; R < emy_cam_geom.src_h; R++) {
        uint32_t *row = (uint32_t *)(img->base + (uint32_t)R * img->stride);
        const int8_t (*g)[3] = frame[pad + R / sc];
        for (int C = 0; C < emy_cam_geom.src_w; C++) {
            const int8_t *q = g[C / sc];
            uint32_t r = ((uint32_t)q[0] * 255u + 32u) / 64u, gg = ((uint32_t)q[1] * 255u + 32u) / 64u, b = ((uint32_t)q[2] * 255u + 32u) / 64u;
            row[C] = (r << 24) | (gg << 16) | (b << 8);
        }
    }
}

/* ------------------------------------------------------------------------------------------------ */
#if EMY_CAM_VDMA
#ifndef EMY_HOST_MOCK
#define VDMA_BASE ((uint32_t)I_EDGE_VIDEO_SYSTEM_VDMA_CTRL_BASEADDR)
#define VDMA_CMD 0x00u
#define VDMA_STATUS 0x04u
#define VDMA_SRC 0x08u
#define VDMA_DST 0x0Cu
#define VDMA_SIZE 0x10u
#define VDMA_COUNT 0x14u
#define VDMA_SRC_STRIDE 0x18u
#define VDMA_DST_STRIDE 0x1Cu
#define VDMA_PERIOD 0x20u
void emy_vdma_copy(uint32_t dst, uint32_t src, uint32_t nbytes)
{
    while (mmio_read_data((mmio_addr_t)(VDMA_BASE + VDMA_STATUS)) != 0u) ;      /* 0 = idle */
    mmio_write_data((mmio_addr_t)(VDMA_BASE + VDMA_SRC), src);
    mmio_write_data((mmio_addr_t)(VDMA_BASE + VDMA_DST), dst);
    mmio_write_data((mmio_addr_t)(VDMA_BASE + VDMA_SIZE), nbytes);
    mmio_write_data((mmio_addr_t)(VDMA_BASE + VDMA_COUNT), 1u);
    mmio_write_data((mmio_addr_t)(VDMA_BASE + VDMA_SRC_STRIDE), nbytes);
    mmio_write_data((mmio_addr_t)(VDMA_BASE + VDMA_DST_STRIDE), nbytes);
    mmio_write_data((mmio_addr_t)(VDMA_BASE + VDMA_PERIOD), 0u);
    mmio_write_data((mmio_addr_t)(VDMA_BASE + VDMA_CMD), 1u);                    /* once */
    while (mmio_read_data((mmio_addr_t)(VDMA_BASE + VDMA_STATUS)) != 0u) ;
}
#else
void emy_vdma_copy(uint32_t dst, uint32_t src, uint32_t nbytes) { (void)dst; (void)src; (void)nbytes; }
#endif
#endif

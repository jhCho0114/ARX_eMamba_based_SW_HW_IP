/* u504_theta — 화면 라벨 구현 (include/emy_label.h). 좌표는 소스 (카메라) 픽셀, 640 좌표 → 소스는 emy_cam_geom 으로 (×scale, y − pad). */
#include <stdint.h>
#include "emy_label.h"
#include "emy_label_font.h"

static const char *const coco_names[80] = {
    "PERSON", "BICYCLE", "CAR", "MOTORCYCLE", "AIRPLANE", "BUS", "TRAIN", "TRUCK", "BOAT", "TRAFFIC LIGHT",
    "FIRE HYDRANT", "STOP SIGN", "PARKING METER", "BENCH", "BIRD", "CAT", "DOG", "HORSE", "SHEEP", "COW",
    "ELEPHANT", "BEAR", "ZEBRA", "GIRAFFE", "BACKPACK", "UMBRELLA", "HANDBAG", "TIE", "SUITCASE", "FRISBEE",
    "SKIS", "SNOWBOARD", "SPORTS BALL", "KITE", "BASEBALL BAT", "BASEBALL GLOVE", "SKATEBOARD", "SURFBOARD", "TENNIS RACKET", "BOTTLE",
    "WINE GLASS", "CUP", "FORK", "KNIFE", "SPOON", "BOWL", "BANANA", "APPLE", "SANDWICH", "ORANGE",
    "BROCCOLI", "CARROT", "HOT DOG", "PIZZA", "DONUT", "CAKE", "CHAIR", "COUCH", "POTTED PLANT", "BED",
    "DINING TABLE", "TOILET", "TV", "LAPTOP", "MOUSE", "REMOTE", "KEYBOARD", "CELL PHONE", "MICROWAVE", "OVEN",
    "TOASTER", "SINK", "REFRIGERATOR", "BOOK", "CLOCK", "VASE", "SCISSORS", "TEDDY BEAR", "HAIR DRIER", "TOOTHBRUSH",
};

const char *emy_label_class_name(int cls) { return (cls >= 0 && cls < 80) ? coco_names[cls] : "CLS"; }

void emy_label_u2s(unsigned v, char *out)
{
    char t[12]; int k = 0;
    do { t[k++] = (char)('0' + v % 10u); v /= 10u; } while (v);
    while (k) *out++ = t[--k];
    *out = 0;
}

static inline int clampi(int v, int lo, int hi) { return v < lo ? lo : (v > hi ? hi : v); }

/* 채운 직사각형 (잘라서) */
static void fill_rect(const emy_cam_img_t *img, int x0, int y0, int x1, int y1, uint32_t c)
{
    const emy_cam_geom_t *g = &emy_cam_geom;
    x0 = clampi(x0, 0, g->src_w); x1 = clampi(x1, 0, g->src_w); y0 = clampi(y0, 0, g->src_h); y1 = clampi(y1, 0, g->src_h);
    for (int y = y0; y < y1; y++) { uint32_t *p = (uint32_t *)(img->base + (uint32_t)y * img->stride); for (int x = x0; x < x1; x++) p[x] = c; }
}

int emy_label_text(int buf, int x, int y, int scale, uint32_t fg, uint32_t bg, const char *s)
{
    const emy_cam_img_t *img = emy_cam_img(buf);
    const emy_cam_geom_t *g = &emy_cam_geom;
    int cx = x;
    for (; *s; s++, cx += 6 * scale) {
        int c = (unsigned char)*s;
        if (c >= 'a' && c <= 'z') c -= 32;
        const uint8_t *gl = (c >= EMY_FONT_FIRST && c <= EMY_FONT_LAST) ? emy_font5x7[c - EMY_FONT_FIRST] : emy_font5x7[0];
        if (bg != EMY_LABEL_TRANSPARENT) fill_rect(img, cx, y, cx + 6 * scale, y + 7 * scale, bg);
        for (int r = 0; r < 7; r++) {
            uint8_t bits = gl[r];
            if (!bits) continue;
            for (int col = 0; col < 5; col++) {
                if (!(bits & (0x10u >> col))) continue;
                int px = cx + col * scale, py = y + r * scale;
                if (px >= g->src_w || py >= g->src_h || px + scale <= 0 || py + scale <= 0) continue;
                fill_rect(img, px, py, px + scale, py + scale, fg);
            }
        }
    }
    return cx - x;
}

static int text_width(const char *s, int scale) { int n = 0; while (*s++) n++; return n * 6 * scale; }

/* 띠 색이 밝으면 검정 글자, 어두우면 흰 글자 */
static uint32_t ink_for(uint32_t band)
{
    uint32_t r = band >> 24, gch = (band >> 16) & 255u, b = (band >> 8) & 255u;
    return (r * 3u + gch * 6u + b) > 5u * 255u ? 0x00000000u : 0xFFFFFF00u;
}

void emy_label_dets(int buf, const emy_det_t *d, int n, int names)
{
    const emy_cam_img_t *img = emy_cam_img(buf);
    const emy_cam_geom_t *g = &emy_cam_geom;
    const int sc = EMY_LABEL_SCALE, h = 7 * sc + 4;
    for (int i = 0; i < n; i++) {
        char txt[32]; int k = 0;
        if (names) { const char *nm = emy_label_class_name(d[i].cls); while (*nm && k < 20) txt[k++] = *nm++; }
        else { txt[k++] = 'C'; char num[8]; emy_label_u2s((unsigned)d[i].cls, num); for (int j = 0; num[j]; j++) txt[k++] = num[j]; }
        txt[k++] = ' ';
        unsigned pct = (unsigned)(d[i].conf * 100.0f + 0.5f); if (pct > 100u) pct = 100u;
        char num[8]; emy_label_u2s(pct, num); for (int j = 0; num[j]; j++) txt[k++] = num[j];
        txt[k++] = '%'; txt[k] = 0;
        int x1 = (int)(d[i].x1 * g->scale), y1 = (int)((d[i].y1 - g->pad_rows) * g->scale);
        int w = text_width(txt, sc) + 6;
        int x = clampi(x1, 0, g->src_w - w);
        int y = (y1 - h >= 0) ? y1 - h : clampi(y1 + 3, 0, g->src_h - h);          /* 상자 위, 안 들어가면 상자 안쪽 */
        uint32_t band = emy_cam_cls_color(d[i].cls);
        fill_rect(img, x, y, x + w, y + h, band);
        emy_label_text(buf, x + 3, y + 2, sc, ink_for(band), EMY_LABEL_TRANSPARENT, txt);
    }
}

void emy_label_status(int buf, int frame, unsigned ms, int ndet)
{
    char txt[48]; int k = 0; char num[12];
    const char *a = "FRAME "; while (*a) txt[k++] = *a++;
    emy_label_u2s((unsigned)frame, num); for (int j = 0; num[j]; j++) txt[k++] = num[j];
    a = "  "; while (*a) txt[k++] = *a++;
    emy_label_u2s(ms, num); for (int j = 0; num[j]; j++) txt[k++] = num[j];
    a = " MS  DET "; while (*a) txt[k++] = *a++;
    emy_label_u2s((unsigned)ndet, num); for (int j = 0; num[j]; j++) txt[k++] = num[j];
    txt[k] = 0;
    const int sc = 2, h = 7 * sc + 4;
    int w = text_width(txt, sc) + 6;
    fill_rect(emy_cam_img(buf), 4, 4, 4 + w, 4 + h, 0x00000000u);
    emy_label_text(buf, 7, 6, sc, 0xFFFFFF00u, EMY_LABEL_TRANSPARENT, txt);
}

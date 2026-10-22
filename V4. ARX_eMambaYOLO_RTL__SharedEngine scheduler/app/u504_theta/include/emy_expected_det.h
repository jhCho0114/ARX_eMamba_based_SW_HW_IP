/* 기대 검출 결과 — int8 골든 헤드 행 (emy_golden_out.h 와 같은 바이트) 에 U_302_golden/tools/head_post.py 의 (b) 구간
 * (DFL 16 bin · anchor +0.5 · stride 8/16/32 · sigmoid · 클래스별 NMS, conf 0.5 · IoU 0.7 · max_det 300) 을 돌린 결과.
 * 보드의 emy_head_post() 가 같은 행에서 같은 목록을 내야 한다 (float32 라 좌표 0.5 px · conf 1e-3 안에서 비교).
 * 좌표는 입력 영상 (640 × 640) 픽셀, xyxy. (tools/gen_head_expected.py 가 만든 파일)
 */
#ifndef EMY_EXPECTED_DET_H_
#define EMY_EXPECTED_DET_H_
#include <stdint.h>

#define EMY_EXPECTED_DET_N 6

typedef struct { float x1, y1, x2, y2, conf; int cls; } emy_expected_det_t;

static const emy_expected_det_t emy_expected_det[EMY_EXPECTED_DET_N] = {
    {     5.956f,   273.001f,   154.756f,   372.718f, 0.92414f, 62 },  /*  0 */
    {   294.880f,   325.188f,   352.069f,   426.049f, 0.88080f, 56 },  /*  1 */
    {   407.132f,   326.600f,   439.891f,   413.508f, 0.81757f, 56 },  /*  2 */
    {   360.969f,   325.747f,   415.752f,   422.493f, 0.81757f, 56 },  /*  3 */
    {   413.552f,   264.130f,   464.740f,   405.511f, 0.73106f,  0 },  /*  4 */
    {   482.596f,   277.399f,   514.044f,   396.230f, 0.62246f, 72 },  /*  5 */
};

#endif /* EMY_EXPECTED_DET_H_ */

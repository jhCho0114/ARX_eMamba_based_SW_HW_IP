/* u504_theta — 화면 라벨: 검출 상자 위에 클래스 이름 · conf 를, 왼쪽 위에 상태 줄을 5×7 글꼴 (배율 2–3) 로 그린다.
 * 그리기는 프레임 버퍼 (XBGR 워드) 에 직접; 라벨 하나 ≈ 4,000 워드 쓰기 ≈ 2 ms. 플랫폼 호출 없음 (emy_camera 의 버퍼 접근만). */
#ifndef EMY_LABEL_H
#define EMY_LABEL_H
#include <stdint.h>
#include "emy_camera.h"

#ifndef EMY_LABEL_SCALE
#define EMY_LABEL_SCALE 3                 /* 글자 15×21 px (720p 화면에서 읽힘) */
#endif
#define EMY_LABEL_TRANSPARENT 0xFFFFFFFFu

const char *emy_label_class_name(int cls);                                   /* COCO 80 (대문자, 짧게); 범위 밖은 "CLS" */
int  emy_label_text(int buf, int x, int y, int scale, uint32_t fg, uint32_t bg, const char *s);   /* 반환 = 그린 폭 px. bg 가 TRANSPARENT 면 글자만 */
void emy_label_dets(int buf, const emy_det_t *d, int n, int names);          /* 상자마다 "NAME 92%" (names 0: "C56 92%") 띠, 색 = 상자 색, 상자 위 (안 들어가면 안쪽) */
void emy_label_status(int buf, int frame, unsigned ms, int ndet);           /* 왼쪽 위: "FRAME 12  1612 MS  DET 2" */
void emy_label_u2s(unsigned v, char *out);                                   /* 숫자 → 문자열 (snprintf 없이) */

#endif

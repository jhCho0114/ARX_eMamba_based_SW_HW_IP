#include "ervp_printf.h"
#include "ervp_external_peri_group_api.h"
#include "ervp_core_id.h"
#include "ervp_external_peri_group_memorymap.h"
#include "platform_info.h"

#include "hdmi_sil1136.h"
#include "vo.h"
#include "ervp_delay.h"
#include "ervp_image.h"
#include "edge_video_system.h"

#ifdef INCLUDE_JPEG_ENCODER
#include "jpeg_encoder.h"
#endif

const int TEST_LCD = 0;

ErvpImage *image_to_export, *temp;

void init_image_as_colorbar(ErvpImage* image);

int main(void)
{
	if(EXCLUSIVE_ID==0) {
    // setting
    edge_video_system_config.display_hw = TEST_LCD? DISPLAY_HW_LCD : DISPLAY_HW_HDMI;
    edge_video_system_config.display_resolution = TEST_LCD? IMAGE_RESOLUTION_1024x600 : IMAGE_RESOLUTION_FHD;
    edge_video_system_config.image_format = IMAGE_FMT_XBGR_8888_PACKED;
    edge_video_system_start();

    // colorbar
    init_image_as_colorbar(edge_video_system_config.vframe_out);
		delay_ms(100);

#ifdef INCLUDE_JPEG_ENCODER
    temp = image_convert_format(edge_video_system_config.vframe_out, 0, IMAGE_FMT_RGB_565_PACKED);
    flush_cache();
    image_to_export = jpegenc_convert_image(temp, 0);
#else
    image_to_export = image_convert_format(edge_video_system_config.vframe_out, 0, IMAGE_FMT_BMP);
#endif
    image_prepare_dump(image_to_export);

		while(1);
		vom_disable();
	}
  return 0;
}

static unsigned int RGB[8] = {
  0xFFFFFF00  // WhiteRGB
  ,0x00000000  // BlackRGB
  ,0xFFFF0000  // YellowRGB
  ,0x00FFFF00  // CyanRGB
  ,0x00FF0000  // GreenRGB
  ,0xFF00FF00  // MagentaRGB
  ,0xFF000000  // RedRGB
  ,0x0000FF00  // BlueRGB
};

void init_image_as_colorbar(ErvpImage* image)
{
  int bar_width = image->width/8;
  for(int i=0; i<image->height; i++)
  {
    unsigned int* row_base = image_get_row_base(image, 0, i);
    for(int j=0; j<image->width; j++)
      row_base[j] = RGB[j/bar_width];
  }
}

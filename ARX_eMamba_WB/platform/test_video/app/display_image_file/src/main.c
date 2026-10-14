#include "ervp_printf.h"
#include "ervp_external_peri_group_api.h"
#include "ervp_core_id.h"
#include "ervp_external_peri_group_memorymap.h"
#include "platform_info.h"

#include "ervp_delay.h"
#include "ervp_image.h"
#include "ervp_image_util.h"
#include "edge_video_system.h"

#include "ervp_image.h"
#include "ervp_image_file.h"

#ifdef INCLUDE_JPEG_ENCODER
#include "jpeg_encoder.h"
#endif

const int TEST_LCD = 0;

ErvpImage* vframe_out;
ErvpImage* vframe_window = NULL;

ErvpImage* tiger_image_rgb888;
ErvpImage* tiger_image_xbgr8888;

int main(void)
{
	if(EXCLUSIVE_ID==0) {
		// setting
    int display_hw;
    int image_resolution;
    int image_format;
    if(TEST_LCD)
    {
      display_hw = DISPLAY_HW_LCD;
      image_resolution = IMAGE_RESOLUTION_1024x600;
    }
    else
    {
      display_hw = DISPLAY_HW_HDMI;
      image_resolution = IMAGE_RESOLUTION_FHD;
    }
    image_format = IMAGE_FMT_XBGR_8888_PACKED;
    //image_format = IMAGE_FMT_RGB_888_PLANE;
    
    // init
    vframe_out = vframe_alloc(image_format, image_resolution);
    edge_video_system_register_frame(vframe_out, 0, 0);
    edge_video_system_config.display_hw = display_hw;
    edge_video_system_start();

    // file
    tiger_image_rgb888 = image_file_read("tiger_fhd.jpg", NULL);
    
    // convert and copy
    //tiger_image_xbgr8888 = image_convert_format(tiger_image_rgb888, NULL, image_format);
    //image_copy(tiger_image_xbgr8888, vframe_out, 0, 0);

    // window and convert
    vframe_window = image_generate_center_window(vframe_out, tiger_image_rgb888->width, tiger_image_rgb888->height, vframe_window);
    image_convert_format(tiger_image_rgb888, vframe_window, image_format);

		while(1);
		vom_disable();
	}
  return 0;
}

#include "platform_info.h"
#include "ervp_printf.h"
#include "ervp_core_id.h"
#include "edge_video_system.h"

void main(void)
{
  if(EXCLUSIVE_ID==0) 
  {
    while(edge_video_system_config_gui())
    {
      edge_video_system_start();
      edge_video_system_display_direct(1);
    }
    printf(" ");
  }
}

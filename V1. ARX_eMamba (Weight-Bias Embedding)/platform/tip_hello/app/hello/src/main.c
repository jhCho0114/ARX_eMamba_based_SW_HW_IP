#include "platform_info.h"
#include "ervp_printf.h"
#include "ervp_multicore_synch.h"
#include "ervp_malloc.h"


int main() {
	printf(" my helloworld and READ FILEIO?!\n");

	int8_t* pint8_t = (int8_t*) malloc((sizeof(int8_t)*8));
	for(int i =0;i<8;i++)
	{
		pint8_t[i] = (i-4)*30;
	}
	for (int i =0;i<8;i++)
		printf("%d\t",pint8_t[i]);

	free(pint8_t);

	printf("\n=-=-=-=-=-=-\n");

	return 0;
}

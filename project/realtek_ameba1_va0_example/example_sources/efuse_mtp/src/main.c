#include "FreeRTOS.h"
#include "task.h"
#include "diag.h"
#include "hal_efuse.h"
#include "efuse_api.h"
#include "osdep_service.h"
#include "device_lock.h"

#define MTP_MAX_LEN 32		// The MTP max length is 32 bytes
static void efuse_mtp_task(void *param)
{
	int ret;
	u8 i, buf[MTP_MAX_LEN];
	
	DBG_8195A("\nefuse MTP block: Test Start\n");
	// read MTP content
	_memset(buf, 0xFF, MTP_MAX_LEN);
	device_mutex_lock(RT_DEV_LOCK_EFUSE);
	efuse_mtp_read(buf);
	device_mutex_unlock(RT_DEV_LOCK_EFUSE);
	for(i=0; i<MTP_MAX_LEN; i+=8){
		DBG_8195A("[%d]\t%02X %02X %02X %02X  %02X %02X %02X %02X\n",
					i, buf[i], buf[i+1], buf[i+2], buf[i+3], buf[i+4], buf[i+5], buf[i+6], buf[i+7]);
	}
	
	// write MTP content
	_memset(buf, 0xFF, MTP_MAX_LEN);
	if(0){ // fill your data
		for(i=0; i<MTP_MAX_LEN; i++)
			buf[i] = i;
	}
	if(0){ // write
		device_mutex_lock(RT_DEV_LOCK_EFUSE);
		ret = efuse_mtp_write(buf, MTP_MAX_LEN);
		device_mutex_unlock(RT_DEV_LOCK_EFUSE);
		if(ret < 0){
			DBG_8195A("efuse MTP block: write length error\n");
			goto exit;
		}
		DBG_8195A("\nWrite Done\n");
		DBG_8195A("Remain %d\n", efuse_get_remaining_length());
	}
	DBG_8195A("\n");
	
	// read MTP content
	_memset(buf, 0xFF, MTP_MAX_LEN);
	device_mutex_lock(RT_DEV_LOCK_EFUSE);
	efuse_mtp_read(buf);
	device_mutex_unlock(RT_DEV_LOCK_EFUSE);
	for(i=0; i<MTP_MAX_LEN; i+=8){
		DBG_8195A("[%d]\t%02X %02X %02X %02X  %02X %02X %02X %02X\n",
					i, buf[i], buf[i+1], buf[i+2], buf[i+3], buf[i+4], buf[i+5], buf[i+6], buf[i+7]);
	}
	
	DBG_8195A("efuse MTP block: Test Done\n");
	vTaskDelete(NULL);
exit:
	DBG_8195A("efuse MTP block: Test Fail!\n");
	vTaskDelete(NULL);
}

void main(void)
{
	if(xTaskCreate(efuse_mtp_task, ((const char*)"efuse_mtp_task"), 512, NULL, tskIDLE_PRIORITY + 1, NULL) != pdPASS)
		printf("\n\r%s xTaskCreate(efuse_mtp_task) failed", __FUNCTION__);
	
	/*Enable Schedule, Start Kernel*/
	if(rtw_get_scheduler_state() == OS_SCHEDULER_NOT_STARTED)
		vTaskStartScheduler();
	else
		vTaskDelete(NULL);
}

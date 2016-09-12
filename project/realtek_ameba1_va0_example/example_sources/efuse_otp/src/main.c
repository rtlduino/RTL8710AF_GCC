#include "FreeRTOS.h"
#include "task.h"
#include "diag.h"
#include "hal_efuse.h"
#include "efuse_api.h"
#include "osdep_service.h"
#include "device_lock.h"

//======================================================
// OTP : one time programming
//======================================================

#define OTP_MAX_LEN 32		// The OTP max length is 32 bytes
static void efuse_otp_task(void *param)
{
	int ret;
	u8 i, buf[OTP_MAX_LEN];
	
	DBG_8195A("\nefuse OTP block: Test Start\n");
	// read OTP content
	device_mutex_lock(RT_DEV_LOCK_EFUSE);
	ret = efuse_otp_read(0, OTP_MAX_LEN, buf);
	device_mutex_unlock(RT_DEV_LOCK_EFUSE);
	if(ret < 0){
		DBG_8195A("efuse OTP block: read address and length error\n");
		goto exit;
	}
	for(i=0; i<OTP_MAX_LEN; i+=8){
		DBG_8195A("[%d]\t%02X %02X %02X %02X  %02X %02X %02X %02X\n",
					i, buf[i], buf[i+1], buf[i+2], buf[i+3], buf[i+4], buf[i+5], buf[i+6], buf[i+7]);
	}
	
	// write OTP content
	_memset(buf, 0xFF, OTP_MAX_LEN);
	if(0){ // fill your data
		for(i=0; i<OTP_MAX_LEN; i++)
			buf[i] = i;
	}
	if(0){ // write
		device_mutex_lock(RT_DEV_LOCK_EFUSE);
		ret = efuse_otp_write(0, OTP_MAX_LEN, buf);
		device_mutex_unlock(RT_DEV_LOCK_EFUSE);
		if(ret < 0){
			DBG_8195A("efuse OTP block: write address and length error\n");
			goto exit;
		}
		DBG_8195A("\nWrite Done.\n");
	}
	DBG_8195A("\n");
	
	// read OTP content
	device_mutex_lock(RT_DEV_LOCK_EFUSE);
	ret = efuse_otp_read(0, OTP_MAX_LEN, buf);
	device_mutex_unlock(RT_DEV_LOCK_EFUSE);
	if(ret < 0){
		DBG_8195A("efuse OTP block: read address and length error\n");
		goto exit;
	}
	for(i=0; i<OTP_MAX_LEN; i+=8){
		DBG_8195A("[%d]\t%02X %02X %02X %02X  %02X %02X %02X %02X\n",
					i, buf[i], buf[i+1], buf[i+2], buf[i+3], buf[i+4], buf[i+5], buf[i+6], buf[i+7]);
	}
	DBG_8195A("efuse OTP block: Test Done\n");
	vTaskDelete(NULL);
	
exit:
	DBG_8195A("efuse OTP block: Test Fail!\n");
	vTaskDelete(NULL);
}

void main(void)
{
	if(xTaskCreate(efuse_otp_task, ((const char*)"efuse_otp_task"), 512, NULL, tskIDLE_PRIORITY + 1, NULL) != pdPASS)
		printf("\n\r%s xTaskCreate(efuse_otp_task) failed", __FUNCTION__);
	
	/*Enable Schedule, Start Kernel*/
	if(rtw_get_scheduler_state() == OS_SCHEDULER_NOT_STARTED)
		vTaskStartScheduler();
	else
		vTaskDelete(NULL);
}
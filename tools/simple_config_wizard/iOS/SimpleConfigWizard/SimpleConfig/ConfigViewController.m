//
//  ConfigViewController.m
//  SimpleConfig
//
//  Created by Realsil on 14/11/11.
//  Copyright (c) 2014年 Realtek. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ConfigViewController.h"
#import <SystemConfiguration/CaptiveNetwork.h>
#import "ClientViewController.h"

#define timeout_cfg         120

#define tag_table_confirm   2
#define cfg_basic_time      15

#define tag_timer           10101

#define tag_cfg_confirm     10601
#define tag_cfg_setNumber   10602

@implementation ConfigViewController
@synthesize m_input_ssid, m_input_password, m_input_pin, m_config_button, m_control_button, m_hide_ssid_switch;
@synthesize m_old_label, m_old_switch, m_old_time;
@synthesize simpleConfig;
@synthesize m_qrscan_line;
@synthesize waitingAlert,cfgProgressView;
@synthesize confirm_list;

NSString *PIN_cfg = nil, *QR_PIN=nil;
NSTimer *waitTimer;
NSTimer *m_timer;
unsigned int timerCount = 0;

int g_checkFinishWait_cfg = cfg_basic_time;
int g_config_device_num = 0;
int unconfirmIndex = -1;

NSMutableArray *config_deviceList;      //context:  dev_info(struct)
UIAlertController *cfg_alertController;

NSTimeInterval configTimerStart = 0;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    confirm_list = nil;
    
    self.tableDeviceList.tag    = tag_table_confirm;
    self.tableDeviceList.delegate = self;
    self.tableDeviceList.dataSource = self;
    
    // Do any additional setup after loading the view, typically from a nib.
    [m_input_ssid setText:[self fetchCurrSSID]];
    [m_input_ssid addTarget:self action:@selector(textFieldDoneEditing:) forControlEvents:UIControlEventEditingDidEndOnExit];
    [m_input_ssid setEnabled:NO];
    [m_input_password addTarget:self action:@selector(textFieldDoneEditing:) forControlEvents:UIControlEventEditingDidEndOnExit];
    [m_input_pin addTarget:self action:@selector(textFieldDoneEditing:) forControlEvents:UIControlEventEditingDidEndOnExit];
    [m_control_button setHidden:YES];
    
    m_context.m_mode = MODE_INIT;
    simpleConfig = [[SimpleConfig alloc] init];

    BOOL hidden = false;
#if SC_CONFIG_QC_TEST
    hidden = false;
#else
    hidden = true;
#endif
    [m_old_label setHidden:hidden];
    [m_old_switch setHidden:hidden];
    [m_old_switch setOn:YES];
    [m_old_switch addTarget:self action:nil forControlEvents:UIControlEventValueChanged];
    [m_old_time setHidden:hidden];
    [m_old_time addTarget:self action:@selector(textFieldStartEditing:) forControlEvents:UIControlEventEditingDidBegin];
    [m_old_time addTarget:self action:@selector(textFieldDoneEditing:) forControlEvents:UIControlEventEditingDidEndOnExit];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidDisappear:(BOOL)animated
{
    // Must release simpleConfig, so that its asyncUDPSocket delegate won't receive data
    NSLog(@"config viewDidDisappear");
#if 0
    [simpleConfig rtk_sc_close_sock];
#else
    [simpleConfig rtk_sc_close_sock];
    #ifdef ARC
    [simpleConfig dealloc];
    #endif
    simpleConfig = nil;
#endif

    if ([waitTimer isValid]) {
        [waitTimer invalidate];
        waitTimer = nil;
    }
    
    [super viewDidDisappear:animated];
}

- (void)viewWillAppear:(BOOL)animated
{
#if 0
    [simpleConfig rtk_sc_reopen_sock];
#else
    if (simpleConfig==nil) {
        simpleConfig = [[SimpleConfig alloc] init];
    }
    [m_control_button setHidden:true];
#endif
    m_timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(configTimerHandler:) userInfo:nil repeats:YES];
    //NSLog(@"config view will appear");
}

- (void)dealloc {
#ifdef ARC
    [m_input_ssid release];
    [m_input_password release];
    [m_input_pin release];
    [m_config_button release];
    [m_control_button release];
    [config_deviceList release];
    
    [simpleConfig dealloc];
    [m_context.m_timer invalidate];
    [m_context.m_timer release];
    
    [m_old_time release];
    [m_old_label release];
    [m_old_switch release];
    [m_hide_ssid_switch release];
    [super dealloc];
#endif
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    if([segue.identifier isEqualToString:@"SegueController"])
    {
        ClientViewController *client_vc = segue.destinationViewController;
        struct dev_info dev;
        NSValue *dev_val = [simpleConfig.config_list objectAtIndex:unconfirmIndex];
        [dev_val getValue:&dev];
        
        client_vc.sharedData = [[NSValue alloc] initWithBytes:&dev objCType:@encode(struct dev_info)];
    }
   
    
}

/* Hide the keyboard when pushing "enter" */
- (BOOL)textFieldDoneEditing:(UITextField *)sender
{
    NSLog(@"textFieldDoneEditing, Sender is %@", sender);
    UITextField *target = sender;
    return [target resignFirstResponder];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    if([text isEqualToString:@"\n"])
    {
        [textView resignFirstResponder];
        return NO;
    }
    return YES;
}

- (BOOL)textFieldStartEditing: (UITextField *)sender
{
    if ([sender isEqual:m_old_time]) {
        if (![m_old_switch isOn]) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:SC_UI_ALERT_TITLE_WARNING message:SC_UI_ALERT_TEST_TURN_ON_SWITCH delegate:self cancelButtonTitle:SC_UI_ALERT_OK otherButtonTitles:nil, nil];
            [alert show];
        }
    
        return YES;
    }
    return NO;
}

- (void)CheckConfigDeviceNumber
{
	//alert picker uiview
    UIActionSheet *cfgNumber_actionSheet = nil;
    cfgNumber_actionSheet = [[UIActionSheet alloc]
                             initWithTitle:@"Configure New Device"
                             delegate:self
                             cancelButtonTitle:@"Cancel"
                             destructiveButtonTitle:nil
                             otherButtonTitles:
                             @"Add 1 device",
                             @"Add 2 devices",
                             @"Add 3 devices",
                             @"Add 4 devices",
                             @"Add 5 devices",
                             @"Add 6 devices",
                             @"Add 7 devices",
                             @"Add 8 devices", nil];
    
    [cfgNumber_actionSheet showInView:self.view];
    //[cfgNumber_actionSheet showFromRect:[(UIButton *)sender frame] inView:self.view animated:YES];
    cfgNumber_actionSheet.tag = tag_cfg_setNumber;
}

/* action responder */
- (IBAction)rtk_start_listener:(id)sender
{
    // do stuff for iOS 8 and newer
    unconfirmIndex = -1;
    
    
    cfg_alertController = [UIAlertController
                                          alertControllerWithTitle:@"Input Device PIN code"
                                          message:@"The PIN code will be display on device if the PIN code is exist.\nOtherwise, choose the skip option."
                                          preferredStyle:UIAlertControllerStyleAlert];
    
    [cfg_alertController addTextFieldWithConfigurationHandler:^(UITextField *textField){
        
        if (QR_PIN==nil) {
            textField.placeholder = @"PIN Code";
        }else{
            [textField setText:QR_PIN];
        }
        
        textField.keyboardType = UIKeyboardTypeNumberPad;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(alertTextFieldDidChange:) name:UITextFieldTextDidChangeNotification object:textField];
    }];
    
    [self presentViewController:cfg_alertController animated:YES completion:nil];
    
    UIAlertAction *qrcodeAction = [UIAlertAction actionWithTitle:@"QR Code Scanner" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self showQRScanner];
        //[self QRScanAction:nil event:nil];
    }];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextFieldTextDidChangeNotification object:nil];
        
        UITextField *pincode = cfg_alertController.textFields.firstObject;
        PIN_cfg = pincode.text;
        
        NSLog(@"<APP> Configure start %@",PIN_cfg);
        
        [self CheckConfigDeviceNumber];
        //[TODO]
        //[self configAction:PIN_cfg];
        //[self startWaiting_progress:@"Device Configuring":120];
    }];
    
    if (QR_PIN==nil) {
        okAction.enabled = NO;
    }else{
        okAction.enabled = YES;
    }
    
    UIAlertAction *skipAction = [UIAlertAction actionWithTitle:@"Skip" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        
        NSLog(@"<APP> Configure start skip");
        
        PIN_cfg = PATTERN_DEF_PIN;
        [self CheckConfigDeviceNumber];
        //[TODO]
        //[self configAction:PIN_cfg];
        //[self startWaiting_progress:@"Device Configuring":120];
        
    }];
    
    [cfg_alertController addAction:qrcodeAction];
    [cfg_alertController addAction:skipAction];
    [cfg_alertController addAction:okAction];
}

-(int)configAction: (NSString *)m_PIN
{
    timerCount = 0;
    int ret = RTK_FAILED;
    if (m_context.m_mode == MODE_INIT || m_context.m_mode == MODE_WAIT_FOR_IP) {

#if 1
        [simpleConfig rtk_sc_set_sc_model:SC_MODEL_1 duration:-1]; //R2
#else
        // check legitimacy and set sc model
        if (![m_old_switch isOn]) {
            //NSLog(@"Using sc_model_1");
            [simpleConfig rtk_sc_set_sc_model:SC_MODEL_1 duration:-1];
        }else{
            if ([m_old_time.text isEqualToString:@""]) {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:SC_UI_ALERT_TITLE_ERROR message:SC_UI_ALERT_WITHOUT_DURATION delegate:self cancelButtonTitle:SC_UI_ALERT_OK otherButtonTitles:nil, nil];
                [alert show];
                return RTK_FAILED;
            }
            unsigned int duration = [m_old_time.text intValue];
            if (duration==0) {
                // R1 mode only
                NSLog(@"Using sc_model_2");
                [simpleConfig rtk_sc_set_sc_model:SC_MODEL_2 duration:-1];
            }else{
                // mix mode
                NSLog(@"Using sc_model_3 with duration of %d", duration);
                [simpleConfig rtk_sc_set_sc_model:SC_MODEL_3 duration:duration];
            }
        }
#endif
        
        NSString *ssid = m_input_ssid.text;
        NSString *pass = m_input_password.text;
        NSString *pin = m_PIN;
        
        timerCount = 0;
        
        // build profile and send
        //ret = [simpleConfig rtk_sc_config_start:m_input_ssid.text psw:m_input_password.text pin:([m_input_pin.text isEqualToString:@""]?PATTERN_DEF_PIN:m_input_pin.text)];
        ret = [simpleConfig rtk_sc_config_start:ssid psw:pass pin:pin];
        if (ret==RTK_FAILED) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:SC_UI_ALERT_TITLE_ERROR message:SC_UI_ALERT_WITHOUT_IP delegate:self cancelButtonTitle:SC_UI_ALERT_OK otherButtonTitles:nil, nil];
            [alert show];
            return RTK_FAILED;
        }
        m_context.m_mode = MODE_CONFIG;
        [m_control_button setHidden:YES];
        [m_config_button setTitle:SC_UI_STOP_BUTTON forState:UIControlStateNormal];
        
        return RTK_SUCCEED;
    }else if(m_context.m_mode == MODE_CONFIG){
        // stop sending profile
        m_context.m_mode = MODE_INIT;
        [m_config_button setTitle:SC_UI_START_BUTTON forState:UIControlStateNormal];
        [simpleConfig rtk_sc_config_stop];

        return RTK_FAILED;
    }
    return RTK_FAILED;
}

- (IBAction)rtk_scan_listener:(id)sender
{
    if (m_context.m_mode == MODE_INIT) {
        // do action
        [self showQRScanner];
    }else{
        // don't listen
    }
}

/******* private functions *******/
- (NSString *)fetchCurrSSID
{
    NSArray *ifs = (id)CFBridgingRelease(CNCopySupportedInterfaces());
    NSDictionary *info = nil;
    for (NSString *ifnam in ifs) {
        info = (id)CFBridgingRelease(CNCopyCurrentNetworkInfo((__bridge CFStringRef)ifnam));
        if (info && [info count]) {
            break;
        }
#ifdef ARC
        [info release];
#endif
    }
#ifdef ARC
    [ifs release];
#endif
    
    NSString *auto_ssid = [info objectForKey:@"SSID"];
    NSLog(@"Current SSID: %@", auto_ssid);
    return auto_ssid;
}

-(void)configTimerHandler: (NSTimer *)sender
{    
    if (simpleConfig==nil || m_timer==nil) {
        //NSLog(@"Timer error in config vc");
        return;
    }

    unsigned int sc_mode = [simpleConfig rtk_sc_get_mode];
    //NSLog(@"sc_mode = %d", sc_mode);
    
    switch (sc_mode) {
        case MODE_INIT:
            if (![m_config_button.titleLabel.text isEqualToString:SC_UI_START_BUTTON]) {
                [m_config_button setTitle:SC_UI_START_BUTTON forState:UIControlStateNormal];
            }
            if ([self isWithIPNoName]) {
                [self showControlButton];
            }
            break;
        
        case MODE_CONFIG:
    
            break;
    
        case MODE_WAIT_FOR_IP:
            NSLog(@"<APP> MODE_WAIT_FOR_IP\n");
            [m_config_button setTitle:SC_UI_START_BUTTON forState:UIControlStateNormal];
            //if (m_context.m_mode==MODE_CONFIG)
            //    m_context.m_mode = MODE_ALERT;
            
            //sleep(5);
            
            //[self showConfigList];
            [waitingAlert setTitle:[NSString stringWithFormat:@"Waiting for the device (%lu/%d)", (unsigned long)[simpleConfig.config_list count], g_config_device_num]];
            break;
            
        default:
            break;
    }
}

-(BOOL)isWithIPNoName
{
    BOOL ret = NO;
    struct dev_info dev;
    NSValue *dev_val;
    NSMutableArray *list = simpleConfig.config_list;
    
    if (list==nil || [list count]==0) {
        return NO;
    }
    
    //NSLog(@"current list count=%d", [list count]);
    dev_val = [list objectAtIndex:0];   // the earliest dev_info added
    [dev_val getValue:&dev];
    // check have ip
    //NSLog(@"ip of obj0: %x", dev.ip);
    ret |= (dev.ip==0)?NO:YES;
    
    if (ret==NO)
        return ret;
    
    // check have no name
    NSString *curr_name = [NSString stringWithUTF8String:(const char *)(dev.extra_info)];
    ret |= ([curr_name isEqualToString:@""] || [curr_name isEqualToString:@"\n"]);
    //NSLog(@"name of obj0: %@", curr_name);
    
    return ret;
}

-(void)showConfigList
{
    NSLog(@"!!!!! showConfigList !!!!!!");
    
    struct dev_info dev;
    NSValue *dev_val;
    
    
    confirm_list = [[NSMutableArray alloc] initWithArray:simpleConfig.config_list copyItems:YES];
    //NSMutableArray *list = simpleConfig.config_list;

    [self stopWaiting_progress];

    for (int i=0; i<[confirm_list count]; i++) {
        dev_val = [confirm_list objectAtIndex:i];
        [dev_val getValue:&dev];
        
        
        NSLog(@"======Dump dev_info %d======",i);
        NSLog(@"MAC: %02x:%02x:%02x:%02x:%02x:%02x", dev.mac[0], dev.mac[1],dev.mac[2],dev.mac[3],dev.mac[4],dev.mac[5]);
        NSLog(@"Status: %d", dev.status);
        NSLog(@"Device type: %d", dev.dev_type);
        NSLog(@"IP:%x", dev.ip);
        NSLog(@"Name:%@", [NSString stringWithUTF8String:(const char *)(dev.extra_info)]);
    }
    
    UIAlertView* confirm_alert = [[UIAlertView alloc] initWithTitle:@"Configured Device"
                                                            message:@"uncheck device if any unwanted!"
                                                           delegate:self
                                                  cancelButtonTitle:@"Confirm"
                                                  otherButtonTitles: nil];
    
    confirm_alert.tag = tag_cfg_confirm;
    int table_height = 210;
    NSInteger focusValue = [confirm_list count];//[confirm_list count]%2==0 ? ((NSInteger)[confirm_list count]/2) : ((NSInteger)[confirm_list count]/2+1);
    NSIndexPath *focusIndex = [NSIndexPath indexPathForRow:focusValue inSection:0];
    if ([confirm_list count]>0) {
        table_height = 75 * (int)[confirm_list count];
        
        if(table_height>400)
            table_height = 400;
        if (table_height<90) {
            table_height = 90;
        }
        
    }
    
    UITableView* myView = [[UITableView alloc] initWithFrame:CGRectMake(10, 45, 264, table_height)
                                                       style:UITableViewStyleGrouped];
    myView.tag = tag_table_confirm;

    [myView selectRowAtIndexPath:focusIndex
                               animated:NO
                         scrollPosition:UITableViewScrollPositionNone];
    [myView setAllowsSelection:NO];
    myView.delegate = self;
    myView.dataSource = self;
    myView.backgroundColor = [UIColor clearColor];
    [confirm_alert setValue:myView forKey:@"accessoryView"];
    [confirm_alert show];

    m_context.m_mode = MODE_INIT;
}

-(void)showControlButton
{
    if (m_context.m_mode!=MODE_WAIT_FOR_IP && m_context.m_mode!=MODE_CONFIG)
        return;
    
    // TODO
    [m_control_button setHidden:NO];
    
    m_context.m_mode = MODE_INIT;
}

/* ------QRCode Related------*/
-(void)showQRScanner
{
    int maxScreen_height = [[UIScreen mainScreen] bounds].size.height;
    int maxScreen_width = [[UIScreen mainScreen] bounds].size.width;
    
    NSLog(@"screen: %d %d",maxScreen_width,maxScreen_height);
    
    upOrdown = NO;
    num = 0;
    if(m_qrcode_timer!=nil){
        [m_qrcode_timer invalidate];
        m_qrcode_timer = nil;
    }
    
    //init ZBar
    ZBarReaderViewController * reader = [ZBarReaderViewController new];
    //set Delegate
    reader.readerDelegate = self;
    
    reader.supportedOrientationsMask = ZBarOrientationMaskAll;
    reader.showsHelpOnFail = NO;
    reader.scanCrop = CGRectMake(0, 0, 1, 1);
    ZBarImageScanner * scanner = reader.scanner;
    [scanner setSymbology:ZBAR_I25
                   config:ZBAR_CFG_ENABLE
                       to:0];
    UIView * view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, maxScreen_width, maxScreen_height)];
    view.backgroundColor = [UIColor clearColor];
    reader.cameraOverlayView = view;
    
    //UILabel * label = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, 280, 40)];
    UILabel * label = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, maxScreen_width/2, 40)];
    label.text = @"Scan your QR code！";
    
    label.textColor = [UIColor whiteColor];
    label.textAlignment = 1;
    label.lineBreakMode = 0;
    label.numberOfLines = 2;
    label.backgroundColor = [UIColor clearColor];
    [view addSubview:label];
    
    UIImageView * image = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"pick_bg.png"]];
    //image.frame = CGRectMake(20, 80, 280, 280);
    image.frame = CGRectMake(20, 80, maxScreen_width-20*2, maxScreen_width-20*2);
    [view addSubview:image];
    
    _line = [[UIImageView alloc] initWithFrame:CGRectMake(20, 80, maxScreen_width-40*2, 1)];
    _line.image = [UIImage imageNamed:@"line.png"];
    [image addSubview:_line];
    
    //set: after 1.5 s
    m_qrcode_timer = [NSTimer scheduledTimerWithTimeInterval:.02 target:self selector:@selector(qrcode_animation) userInfo:nil repeats:YES];
    
    [self presentViewController:reader animated:YES completion:^{
    }];
    
    //[self presentViewController:reader animated:YES completion:nil];
    
    NSLog(@"<APP> scan button finished");
    //[text_pincode setText:m_pin_code];
}

-(void)qrcode_animation
{
    int maxScreen_width = [[UIScreen mainScreen] bounds].size.width;
    
    if (upOrdown == NO) {
        num ++;
        _line.frame = CGRectMake(20, 20+2*num, maxScreen_width-40*2, 1);
        if (2*num >= (maxScreen_width-30*2)) {
            upOrdown = YES;
        }
    }
    else {
        num --;
        _line.frame = CGRectMake(20, 20+2*num, maxScreen_width-40*2, 1);
        if (num <= 0) {
            upOrdown = NO;
        }
    }
}

/* Parse QRCode */
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    id<NSFastEnumeration> results = [info objectForKey:ZBarReaderControllerResults];
    ZBarSymbol *symbol = nil;
    for(symbol in results)
        break;
    
    NSLog(@"Got QRCode: %@", symbol.data);
    [m_input_pin setText:symbol.data];
    
    QR_PIN = symbol.data;
    
    //self.imageView.image = [info objectForKey:UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    [self rtk_start_listener:nil];
}

-(void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    //wait alert show
    if(alertView.tag == tag_timer){
    
        if(buttonIndex == 0) {//Cancel
            NSLog(@"<APP> wait alert show: Cancel");
            timerCount = 0;
            [self stopWaiting_progress];
            
            // stop sending profile
            m_context.m_mode = MODE_INIT;
            [m_config_button setTitle:SC_UI_START_BUTTON forState:UIControlStateNormal];
            [simpleConfig rtk_sc_config_stop];
        }
    
    }else if(alertView.tag == tag_cfg_confirm){
        NSLog(@"<APP> Confirm!");
        
        struct dev_info dev;
        NSValue *dev_val;
        NSMutableArray *list = confirm_list;

        int i = 0;
        
        for (i=0; i<[list count]; i++) {
            
            dev_val = [list objectAtIndex:i];
            [dev_val getValue:&dev];
            
            NSLog(@"======Confirm dev_info %d======",i);
            NSLog(@"Name:%@", [NSString stringWithUTF8String:(const char *)(dev.extra_info)]);
            NSLog(@"IP:%x", dev.ip);
            NSLog(@"MAC: %02x:%02x:%02x:%02x:%02x:%02x", dev.mac[0], dev.mac[1],dev.mac[2],dev.mac[3],dev.mac[4],dev.mac[5]);
            NSLog(@"Status: %d", dev.status);
            NSLog(@"Device type: %d", dev.dev_type);
            

            
            
            //user unwanted the device => delete profile
            if (dev.status==BIT(2))//unconfirm status
            {
                unconfirmIndex = i;
                
                if ([self isDeviceConnected:dev.mac[0] m1:dev.mac[1] m2:dev.mac[2] m3:dev.mac[3] m4:dev.mac[4] m5:dev.mac[5] ]) {
                    NSLog(@"get device ip");
                    [self performSegueWithIdentifier:@"SegueController" sender:self];
                }else{
                    UIAlertView *wifialertView = [[UIAlertView alloc]
                                                  initWithTitle:NSLocalizedString(@"Error", @"AlertView")
                                                  message:NSLocalizedString(@"Check fail!!!!", @"AlertView")
                                                  delegate:self
                                                  cancelButtonTitle:NSLocalizedString(@"OK", @"AlertView")
                                                  otherButtonTitles:nil];
                    [wifialertView show];
                }
                
                /*for (j=0;j<10; j++) {
                    sleep(1);
                    if ([self isDeviceConnected:dev.mac[0] m1:dev.mac[1] m2:dev.mac[2] m3:dev.mac[3] m4:dev.mac[4] m5:dev.mac[5] ]) {
                        NSLog(@"get ip");
                        unconfirmIndex = i;
                        [self performSegueWithIdentifier:@"SegueController" sender:self];
                        break;
                    }
                    NSLog(@"no ip");
                    
                }*/
                
            }
            
        }
    }
}

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    int deviceNum = 0;
    if (actionSheet.tag == tag_cfg_setNumber){
        
        if(buttonIndex<0 || buttonIndex>7)
            return;
        
        deviceNum = (int)(buttonIndex+1);
        
        NSLog(@"Add %ld device!!!",(long)buttonIndex+1);
        g_config_device_num = deviceNum;
        g_checkFinishWait_cfg = cfg_basic_time + (int)buttonIndex*3;
        
        [self startWaiting_progress:@"Device Configuring":120];
        [self configAction:PIN_cfg];
        
    }
}

//---------------------------------  UI table controllers  -------------------------------------
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    struct dev_info dev;
    static NSString *simpleTableIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:simpleTableIdentifier];
    NSMutableArray *list = nil;
    NSValue *dev_val;
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:simpleTableIdentifier];
    }
    
    //NSMutableArray *list = simpleConfig.config_list;
    
    switch ([tableView tag]) {
        case tag_table_confirm:{
            
            list = confirm_list;
            
            //get the element(rowIndex) device
            dev_val = [list objectAtIndex:indexPath.row];
            [dev_val getValue:&dev];
            
            //cell.textLabel.text = [NSString stringWithFormat:@"Option %d", [indexPath row] + 1];
            if(strlen((const char *)(dev.extra_info))==0){
                char tmp[16] = {0};
                sprintf(tmp, "%02x:%02x:%02x:%02x:%02x:%02x", dev.mac[0], dev.mac[1],dev.mac[2],dev.mac[3],dev.mac[4],dev.mac[5]);
                cell.textLabel.text = [NSString stringWithUTF8String:(const char *)tmp];
            }else{
                cell.textLabel.text = [NSString stringWithUTF8String:(const char *)(dev.extra_info)];
            }
            
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            UISwitch *switchView = [[UISwitch alloc] initWithFrame:CGRectZero];
            cell.accessoryView = switchView;
            switchView.tag= indexPath.row;
            [switchView setOn:YES animated:NO];
            [switchView addTarget:self action:@selector(cfgConfirmSwitched:) forControlEvents:UIControlEventValueChanged];
            break;
        }
        default:
            break;
    }
    
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [simpleConfig.config_list count];
}

-(void)cfgConfirmSwitched:(id) sender
{
    int rowIndex = (int)[sender tag];
    UISwitch* switchControl = sender;

    struct dev_info selected_dev;
    NSValue *dev_val;
    NSMutableArray *list = confirm_list;

    //get the element(rowIndex) device
    dev_val = [list objectAtIndex:rowIndex];
    [dev_val getValue:&selected_dev];
    
    if (switchControl.on) {
        selected_dev.status = BIT(0); //connected status
    }else{
        selected_dev.status = BIT(2); //unconfirm status
    }
    
    //delete the element(rowIndex) device
    [confirm_list removeObjectAtIndex:rowIndex];
    
    
    //insert the new element(rowIndex) device
    NSValue *deviceItem = [NSValue value:&selected_dev withObjCType:@encode(struct dev_info)];
    [confirm_list insertObject:deviceItem atIndex: rowIndex];
    
    NSLog( @"switch(%d) %@ status:%d %@",rowIndex, switchControl.on ? @"ON" : @"OFF" , selected_dev.status,
          [NSString stringWithUTF8String:(const char *)(selected_dev.extra_info)]);
    
#if 0
    struct dev_info dev;
    for (int i=0; i<[list count]; i++) {
        dev_val = [list objectAtIndex:i];
        [dev_val getValue:&dev];
        
        NSLog(@"<APP> [after changed] Name:%@", [NSString stringWithUTF8String:(const char *)(dev.extra_info)]);
        NSLog(@"<APP> [after changed] IP:%x", dev.ip);
        NSLog(@"<APP> [after changed] MAC: %02x:%02x:%02x:%02x:%02x:%02x", dev.mac[0], dev.mac[1],dev.mac[2],dev.mac[3],dev.mac[4],dev.mac[5]);
        NSLog(@"<APP> [after changed] Device type: %d", dev.dev_type);
        NSLog(@"<APP> [after changed] Status: %d", dev.status);

    }
#endif
    
    
}
//---------------------------------  UI table controllers  -------------------------------------

- (BOOL)isDeviceConnected:(unsigned char)m0 m1:(unsigned char)m1 m2:(unsigned char)m2 m3:(unsigned char)m3 m4:(unsigned char)m4 m5:(unsigned char)m5
{
    struct dev_info dev;
    NSValue *dev_val;
    
    for (int i=0; i<[simpleConfig.config_list count]; i++) {
        dev_val = [simpleConfig.config_list objectAtIndex:i];
        [dev_val getValue:&dev];
        
        if( (dev.mac[0]==m0) &&
           (dev.mac[1]==m1) &&
           (dev.mac[2]==m2) &&
           (dev.mac[3]==m3) &&
           (dev.mac[4]==m4) &&
           (dev.mac[5]==m5)){
            
            if (dev.ip==0) {
                return NO;
            }else
                return YES;
            
        }

    }
    return NO;
}

- (void)alertTextFieldDidChange:(NSNotification *)notification{
    UIAlertController *alertController = (UIAlertController *)self.presentedViewController;
    if (alertController) {
        UITextField *login = alertController.textFields.firstObject;
        UIAlertAction *okAction = alertController.actions.lastObject;
        
        BOOL enable = login.text.length == 8;
        
        okAction.enabled = enable;
    }
}

- (void)waitingActionThread
{
    [self startWaiting:@"Check the device":10.0];
}

//show loading activity.
- (void)startWaiting:(NSString *) wait_title :(float)timeout {
    
    if(waitTimer){
        [self stopWaiting];
    }
    
    //  Purchasing Spinner.
    if (!waitingAlert) {
        waitingAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(wait_title,@"")
                                                  message:@"  Please wait...\n"
                                                 delegate:self
                                        cancelButtonTitle:@"Cancel"
                                        otherButtonTitles:nil];
        waitingAlert.tag = tag_timer;
        
        UIActivityIndicatorView *actview = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        actview.color=[UIColor blackColor];
        //actview.center=CGPointMake(www/2, hhh/2);
        [actview startAnimating];
        
        [waitingAlert setValue:actview forKey:@"accessoryView"];
        [waitingAlert show];
        
        if (timeout>0) {
            waitTimer = [NSTimer scheduledTimerWithTimeInterval: timeout
                                                         target: self
                                                       selector:@selector(stopWaiting)
                                                       userInfo: nil repeats:NO];
        }
        
        
    }
}

-(void)stopWaiting
{
    if(waitTimer){
        [waitTimer invalidate];
        waitTimer = nil;
    }
    
    if (waitingAlert) {
        [waitingAlert dismissWithClickedButtonIndex:0 animated:YES];
        waitingAlert = nil;
    }
}

- (void)startWaiting_progress:(NSString *) wait_title :(float)timeout {
    if(waitTimer){
        [self stopWaiting_progress];
    }
    
    //  Purchasing Spinner.
    waitingAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(wait_title,@"")
                                              message:@"  Please wait...\n"
                                             delegate:self
                                    cancelButtonTitle:@"Cancel"
                                    otherButtonTitles:nil];
    waitingAlert.tag = tag_timer;
    
    waitingAlert.alertViewStyle = UIAlertViewStyleDefault;
    
    cfgProgressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    [cfgProgressView setTrackTintColor:[UIColor lightGrayColor]];
    [cfgProgressView setProgressTintColor:[UIColor blueColor]];
    cfgProgressView.frame = CGRectMake(20, 20, 200, 15);
    cfgProgressView.progress = 0;
    [waitingAlert setValue:cfgProgressView forKey:@"accessoryView"];
    
    //CGRect lblDownloadPercentFrame = CGRectMake([UIScreen mainScreen].bounds.size.width-100
    //                                            , [UIScreen mainScreen].bounds.size.height-135, 60, 20);
    //lblDownloadPercent = [[UILabel alloc]initWithFrame:lblDownloadPercentFrame];
    //lblDownloadPercent.textColor = [UIColor whiteColor];
    //lblDownloadPercent.backgroundColor = [UIColor clearColor];
    //[waitingAlert setValue:lblDownloadPercent forKey:@"accessoryView"];
    
    [waitingAlert show];
    
    if (timeout>0) {
        
        if ([waitTimer isValid]) {
            [waitTimer invalidate];
            waitTimer = nil;
        }
        configTimerStart = NSDate.date.timeIntervalSince1970;
        
        waitTimer = [NSTimer scheduledTimerWithTimeInterval:1.2 target:self selector:@selector(update_progress) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop]addTimer:waitTimer forMode:NSDefaultRunLoopMode];
    }
}
- (void)stopWaiting_progress
{
    if(waitTimer){
        [waitTimer invalidate];
        waitTimer = nil;
    }
    
    if (waitingAlert) {
        [waitingAlert dismissWithClickedButtonIndex:0 animated:YES];
        waitingAlert = nil;
    }
    m_context.m_mode = MODE_INIT;
}

- (void)update_progress
{
    if([simpleConfig.config_list count]>=g_config_device_num){
        NSLog(@"!!!!! FINISH !!!!!!");
        [self showConfigList];
        
        return;
    }
    
    int i_persent = 0;
    
    //NSLog(@"update_progress");
    
#if 0
    cfgProgressView.progress +=0.01;
#else
    double diffTime = NSDate.date.timeIntervalSince1970 - configTimerStart;
    cfgProgressView.progress = (diffTime/120);
#endif
    
    i_persent = 100 * cfgProgressView.progress;
    
    [waitingAlert setMessage:[NSString stringWithFormat:@"Please wait... %d %%", i_persent]];
    
    //when 100%
    if (cfgProgressView.progress == 1)
    {

        [self stopWaiting_progress];
        
        cfgProgressView.progress = 0;
        
        if([simpleConfig.config_list count]>0){
            [self showConfigList];
            return;
        }else{
            UIAlertView *wifialertView = [[UIAlertView alloc]
                                          initWithTitle:NSLocalizedString(@"Configuration", @"AlertView")
                                          message:NSLocalizedString(@"Time Out", @"AlertView")
                                          delegate:self
                                          cancelButtonTitle:NSLocalizedString(@"OK", @"AlertView")
                                          otherButtonTitles:/*NSLocalizedString(@"Open settings", @"AlertView"),*/ nil];
            [wifialertView show];
        }
        
        
        
    }
}

@end

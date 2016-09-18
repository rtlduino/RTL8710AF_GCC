//
//  FindDeviceVC.swift
//  WiGadget
//
//  Created by WU JINZHOU on 24/7/15.
//  Copyright (c) 2015 WU JINZHOU. All rights reserved.
//

import UIKit

class FindDeviceVC: UIViewController,UICollectionViewDataSource, UICollectionViewDelegate,NewfoundListDelegate {

    let bonjourBrowser = BonjourBrowser()
    
    @IBOutlet weak var menuBtn: UIBarButtonItem!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var imageView: UIImageView!
    
    var imageSource = [String]()
    var textSource = [String]()
    var macSource = [String]()
    
    var preloaderImageData = NSData(contentsOfURL: NSBundle.mainBundle().URLForResource("preloader_256x23", withExtension: "gif")!)

    override func viewDidLoad() {
        super.viewDidLoad()
        menuBtn.target = self.revealViewController()
        menuBtn.action = Selector("revealToggle:")
        self.view.addGestureRecognizer(self.revealViewController().panGestureRecognizer())
        self.title = R.menu_titles[1]
        
        AmebaList.load()
        AmebaList.newfoundListDataSource = self
        
        let gesture: UILongPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: "collectionViewCellLongPressed:")
        gesture.minimumPressDuration = R.device_cell_long_press_duration
        self.collectionView.addGestureRecognizer(gesture)
        
        imageView.image = UIImage.animatedImageWithAnimatedGIFData(preloaderImageData)
        
        Log.v("Start Bonjour Service Discovery")
        bonjourBrowser.browse(R.bonjour_service_name, domain: R.bonjour_service_domain)
        
        updateDataSource(AmebaList.newfoundList)
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return imageSource.count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(R.device_cell_ids[0], forIndexPath: indexPath) as! DeviceCollectionViewCell
        cell.findDeviceTextLabel.text = textSource[indexPath.row]
        cell.image = imageSource[indexPath.row]
        cell.findDeviceImageView.image = UIImage(named: cell.image)
        cell.mac = macSource[indexPath.row]
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        collectionView.deselectItemAtIndexPath(indexPath, animated: true)
        let cell = collectionView.cellForItemAtIndexPath(indexPath) as! DeviceCollectionViewCell
        Log.v("cell \(indexPath.row) , mac \(cell.mac) selected")
        
        //get ameba 
        if let ameba = AmebaList.newfoundListGetAmebaByMac(cell.mac) {
            let alert = SCLAlertView()
            alert.showAnimationType = .SlideInToCenter
            alert.hideAnimationType = .SlideOutToCenter
            alert.backgroundType = .Blur
            
            var firebaseAppId = UITextField()
            var alertTitle = R.not_assigned
            
            if ameba.pair_state == R.not_paired {
                
                alertTitle = "Pair Device"
                
                if ameba.control_type == R.cloud_control {
                    firebaseAppId = alert.addTextField("Firebase App ID")
                    alert.addButton("Register Firebase", actionBlock: { () -> Void in
                        Log.v("Register Firebase is clicked")
                        let regiFirebaseVC = UIStoryboard(name: R.storyboard_name_regi_fb,bundle:nil).instantiateViewControllerWithIdentifier(R.storyboard_init_regi_fb_vc[R.storyboard_name_regi_fb]!)
                        self.presentViewController(regiFirebaseVC, animated: true, completion: nil)
                    })
                }
                
                alert.addButton("Pair Device",
                    
                    validationBlock: {
                        Log.v("Pair Device is clicked")
                        if ameba.control_type == R.cloud_control {
                            var id = firebaseAppId.text! ?? R.not_assigned
                            Log.v("check firebase app id: \(id)")
                            
                            id = id.removeWhitespace()
                            if id == R.not_assigned {
                                self.view.makeToast("Firebase app id is empty\nPlease enter your app id", duration: R.toast_duration, position: CSToastPositionBottom, title: "EMPTY APP ID", image: R.toast_ic_failed)
                                return false
                            }
                            
                            return true
                        }
                        return true
                    },
                    
                    actionBlock: {
                        () -> Void in
                        Log.v("Pair process start")
                        
                        //add an alert pop to handle if the app id is empty for cloud control
                        
                        let qos = Int(QOS_CLASS_USER_INITIATED.rawValue)
                        let mainQ = dispatch_get_main_queue()
                        let sockQ = dispatch_get_global_queue(qos, 0)
                        
                        var pairResult = R.pair_failed_on_unknown_err
                        
                        self.view.makeToastActivity()
                        dispatch_async(sockQ){
                            // do something off-UI
                            pairResult = self.pair(ameba,firebaseAppId: firebaseAppId.text!)
                            
                            dispatch_async(mainQ){
                                // switch back to main Q
                                self.view.hideToastActivity()
                                if pairResult == R.pair_success {
                                    self.view.makeToast("Pair succeed\nNew device saved to \"My Device\" List", duration: R.toast_duration, position: CSToastPositionBottom, title: "PAIR SUCCESS", image: R.toast_ic_succeed)
                                }
                                else{
                                    self.view.makeToast("Pair failed\nError code: \(pairResult)", duration: R.toast_duration, position: CSToastPositionBottom, title: "PAIR FAILED", image: R.toast_ic_failed)
                                }
                            }
                        }
                })
            }
            
            if ameba.pair_state == R.paired {
                alertTitle = "Share Device"
                alert.addButton("Share Device", actionBlock: { () -> Void in
                    Log.v("Share Device is clicked")
                    self.view.makeToast("Device sharing will be supported in the future release", duration: R.toast_duration, position: CSToastPositionBottom, title: "NOT SUPPORTED", image: R.toast_ic_failed)
                })
            }
            
            let amebaInfo = ameba.name + "\nIP: " + ameba.ip + "\nPort: " + ameba.port
            
            alert.showCustom(self, image: UIImage(named: cell.image), color: R.device_cell_on_selected_color, title: alertTitle, subTitle: amebaInfo, closeButtonTitle: "Cancel", duration: 0 as NSTimeInterval)

        }
    }
    
    
    func collectionViewCellLongPressed(longPress: UIGestureRecognizer) {
        
        if longPress.state == UIGestureRecognizerState.Began {
            
            let point = longPress.locationInView(self.collectionView)
            let indexPath = self.collectionView.indexPathForItemAtPoint(point)
            
            if let index = indexPath {
                let cell = collectionView.cellForItemAtIndexPath(index) as! DeviceCollectionViewCell
                Log.v("cell \(index.row) , mac \(cell.mac) long-pressed")
                
                //get ameba info
                if let ameba = AmebaList.newfoundListGetAmebaByMac(cell.mac){
                    //show device info
                    let amebaInfo = ameba.name + "\nIP: " + ameba.ip + "\nPort: " + ameba.port + "\nControl Type: " + ameba.control_type + "\nPair State: " + ameba.pair_state
                    let alert = SCLAlertView()
                    alert.showAnimationType = .SlideInToCenter
                    alert.hideAnimationType = .SlideOutToCenter
                    alert.backgroundType = .Blur
                    alert.showCustom(self, image: UIImage(named: cell.image), color: R.device_cell_on_selected_color, title: "Device Info", subTitle: amebaInfo, closeButtonTitle: "Done", duration: R.scl_alert_auto_dismiss_time)
                }
                
            }
            else {
                Log.e("Could not find cell")
            }
        }
        
    }
    
    
    func collectionView(collectionView: UICollectionView, willDisplayCell cell: UICollectionViewCell, forItemAtIndexPath indexPath: NSIndexPath) {
        let selectedView = UIView() as UIView
        selectedView.layer.borderWidth = R.device_cell_on_selected_border_width
        selectedView.layer.cornerRadius = R.device_cell_on_selected_corner_radius;
        selectedView.layer.borderColor = R.device_cell_on_selected_color.CGColor
        selectedView.backgroundColor = R.device_cell_on_selected_color
        cell.selectedBackgroundView = selectedView
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func onNewfoundListUpdated(newfoundList:[Ameba]) {
        //newfoundList updated do something...
        Log.v("updating cell data source")
        updateDataSource(newfoundList)
        
        dispatch_async(dispatch_get_main_queue(), {
            self.collectionView.reloadData()
        })
        
    }
    
    func updateDataSource(amebaList:[Ameba]) {
        imageSource.removeAll(keepCapacity: false)
        textSource.removeAll(keepCapacity: false)
        macSource.removeAll(keepCapacity: false)
        
        for ameba in amebaList {
            // TODO: add code for new device here
            if ameba.name == R.ht_sensor {
                
                // cell image
                imageSource.append(R.ic_ht_sensor[ameba.control_type]![ameba.link_state]!)
                
                // cell txt label
                let safeMac = ameba.mac + "5755204A494E5A484F55"
                textSource.append(ameba.name + "-" + safeMac[8...11] + "-" + ameba.pair_state)
                
                // cell mac
                macSource.append(ameba.mac)
            }
        }
    }
    
    func pair(ameba:Ameba,firebaseAppId:String) -> Int {
        
        let connIp = ameba.ip
        let connPort = Int(ameba.port)!
        var myKey = R.not_assigned
        var sharedKey = R.not_assigned
        var rxData = [UInt8]?()
        let firebaseAppUrl = fmtURL(firebaseAppId)
        
        //verify app id before create socket
        if ameba.control_type == R.cloud_control {
            let code = Just.get(firebaseAppUrl).statusCode ?? R.not_found
            if code != 200 {
                return R.pair_failed_on_verify_firebase_url
            }
        }
        

        //set up for 1st hs
        var client = TCPClient(addr: connIp, port: connPort)
        var (success,errmsg) = client.connect(timeout: R.tcp_connection_time_out)
        if !success {
            client.close()
            Log.e(errmsg)
            return R.pair_failed_connection_time_out
        }
        
        //1st hs : send pair cmd
        (success,errmsg) = client.send(str: R.tcp_tx_pair)
        if !success {
            client.close()
            Log.e(errmsg)
            return R.pair_failed_on_first_hs_tx
        }
        
        rxData = client.read(R.tcp_expect_rx_data_length)
        
        if let data = rxData {
            let rx = String(bytes: data, encoding: NSUTF8StringEncoding)!
            
            if rx == R.tcp_rx_error {
                client.close()
                Log.e("pair_failed_cmd_rejected_by_server")
                return R.pair_failed_cmd_rejected_by_server
            }
            
            let hisKey = rx
            myKey = Crypto.makeCurve25519PublicKey()
            sharedKey = Crypto.makePSK(hisKey)
            
        }
        else{
            client.close()
            Log.e("pair_failed_on_first_hs_rx")
            return R.pair_failed_on_first_hs_rx
        }
        
        client.close()
        NSThread.sleepForTimeInterval(R.tcp_thread_sleep_time)
        
        //set up for 2nd hs
        client = TCPClient(addr: connIp, port: connPort)
        (success,errmsg) = client.connect(timeout: R.tcp_connection_time_out)
        if !success {
            client.close()
            Log.e(errmsg)
            return R.pair_failed_connection_time_out
        }
        
        //2nd hs : send my pk
        (success,errmsg) = client.send(str: myKey)
        if !success {
            client.close()
            Log.e(errmsg)
            return R.pair_failed_on_second_hs_tx
        }
        
        rxData = client.read(R.tcp_expect_rx_data_length)
        
        if let data = rxData {
            
            let rx = String(bytes: data, encoding: NSUTF8StringEncoding)!
            
            if rx == R.tcp_rx_error {
                client.close()
                Log.e("pair_failed_pk_rejected_by_server")
                return R.pair_failed_pk_rejected_by_server
            }
            
            if rx == R.tcp_rx_pair_success {
                
                //local-controlled device pair success
                ameba.key = sharedKey
                ameba.firebase_app_id = R.not_assigned
                ameba.pair_state = R.paired
                ameba.link_state = R.online
                ameba.description = "[NEW]-\(ameba.name)"
                AmebaList.pair(ameba)
                
                client.close()
                Log.i("tcp_rx_pair_success")
                return R.pair_success
            }
            
            if rx != R.tcp_rx_firebase_app_id {
                client.close()
                Log.v("pair_failed_on_unknown_err")
                return R.pair_failed_on_unknown_err
            }
            
        }
        else{
            client.close()
            Log.e("pair_failed_on_second_hs_rx")
            return R.pair_failed_on_second_hs_rx
        }
        
        client.close()
        NSThread.sleepForTimeInterval(R.tcp_thread_sleep_time)
        
        //set up for 3rd hs
        client = TCPClient(addr: connIp, port: connPort)
        (success,errmsg) = client.connect(timeout: R.tcp_connection_time_out)
        if !success {
            client.close()
            Log.e(errmsg)
            return R.pair_failed_connection_time_out
        }
        
        //3rd hs : send firebase app id
        let cipherText = Crypto.encrypt(firebaseAppUrl, key: sharedKey)
        
        (success,errmsg) = client.send(str: cipherText)
        if !success {
            client.close()
            Log.e(errmsg)
            return R.pair_failed_on_third_hs_tx
        }
        
        
        rxData = client.read(R.tcp_expect_rx_data_length)

        if let data = rxData {
            
            let rx = String(bytes: data, encoding: NSUTF8StringEncoding)!
            
            if rx == R.tcp_rx_error {
                client.close()
                Log.e("pair_failed_firebase_id_rejected_by_server")
                return R.pair_failed_firebase_id_rejected_by_server
            }
            
            if rx == R.tcp_rx_pair_success {
                
                //cloud - controlled device pair success
                ameba.key = sharedKey
                ameba.firebase_app_id = firebaseAppId
                ameba.pair_state = R.paired
                ameba.link_state = R.online
                ameba.description = "[NEW]-\(ameba.name)"
                AmebaList.pair(ameba)
                
                client.close()
                Log.i("tcp_rx_pair_success")
                return R.pair_success
            }
            
        }
        else{
            client.close()
            Log.e("pair_failed_on_third_hs_rx")
            return R.pair_failed_on_third_hs_rx
        }
        
        client.close()
        Log.e("pair_failed_on_unknown_err")
        return R.pair_failed_on_unknown_err
    }
    
    func fmtURL(firebaseAppId:String) -> String {
        
        var firebaseUrl = ""
        
        if firebaseAppId.hasSuffix(".firebaseio.com") {
            firebaseUrl = "https://" + firebaseAppId + "/"
        }
        else {
            firebaseUrl = "https://" + firebaseAppId + ".firebaseio.com/"
        }
        
        firebaseUrl = firebaseUrl.removeWhitespace().lowercaseString
        
        return firebaseUrl
    }
    

}


extension String {
    subscript (r: Range<Int>) -> String {
        get {
            let startIndex = self.startIndex.advancedBy(r.startIndex)
            let endIndex = startIndex.advancedBy(r.endIndex - r.startIndex)
            
            return self[Range(start: startIndex, end: endIndex)]
        }
    }
}

//
//  HTSensorVC.swift
//  WiGadget
//
//  Created by WU JINZHOU on 2/9/15.
//  Copyright (c) 2015 WU JINZHOU. All rights reserved.
//

import UIKit
import Firebase
import AVFoundation


//ameba in tracking list is like:
/*
[fg0,131,18;* name: ht_sensor ip: 172.25.23.91 mac: 00e04c870000 port: 6866 control_type: 1 pair_state: 1 link_state: 0 firebase_app_id:  description:  key: [;
*/

//ameba in saved list is like:
/*
[fg0,131,18;* name: ht_sensor ip:  mac: 00e04c870000 port:  control_type: 1 pair_state: 1 link_state: 1 firebase_app_id: xxxx description: [NEW]-ht_sensor key: [223, 97, 174, 104, 227, 235, 251, 119, 103, 99, 38, 112, 4, 174, 16, 204][;
*/

//i.e: ip & port are from tracked ameba and key is from saved ameba

class HTSensorVC: UIViewController {
    
    let targetAmeba = AmebaList.linkTarget! //targetAmeba is retrived from saved list
    
    var ip = R.not_assigned
    var port = R.not_found
    var key = R.not_assigned
    var firebaseURL = R.not_assigned
    
    var timer = NSTimer()
    
    var rootRef = Firebase()
    
    struct Reading {
        var humidity:Double
        var temperature:Double
    }
    
    var readings = [Reading]()
    var times = [String]()
    
   
    @IBOutlet weak var temperatureLabel: UILabel!
    
    @IBOutlet weak var humidityLabel: UILabel!
    
    @IBOutlet weak var chartView: LineChartView!
    
    @IBOutlet weak var imageView: UIImageView!
    
    var preloaderImageData = NSData(contentsOfURL: NSBundle.mainBundle().URLForResource("preloader_256x23", withExtension: "gif")!)
    
    var useAlarm = false
    var alarmSound = 0 //mapped to sound 1
    var humiThres = 0.0
    var tempThres = 0.0
    var linkFreq = 2.0
    
    var player = AVAudioPlayer()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = targetAmeba.description
        imageView.image = UIImage.animatedImageWithAnimatedGIFData(preloaderImageData)

        loadSettings()
        initChart()
    }

    override func viewDidAppear(animated: Bool) {
        
        if let trackedAmeba = AmebaList.trackingListGetAmebaByMac(targetAmeba.mac) {
            
            ip = trackedAmeba.ip
            port = Int(trackedAmeba.port)!
            key = targetAmeba.key
            
            timer = NSTimer.scheduledTimerWithTimeInterval(linkFreq, target: self, selector: "localLink", userInfo: nil, repeats: true)
        }
        
        else if targetAmeba.control_type == R.cloud_control {
            
            firebaseURL = "https://" + targetAmeba.firebase_app_id + ".firebaseio.com"
            rootRef = Firebase(url: firebaseURL)
            
            cloudLink()
        }
        
    }
    
    func loadSettings() {
        let defaults = NSUserDefaults.standardUserDefaults()
        let dataStr = defaults.valueForKey(R.settings_key_ht) as? String ?? R.not_assigned
        let htSettings = JSON(data: dataStr.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!)
        
        if !(htSettings.isEmpty) {
            useAlarm = htSettings[R.settings_key_ht_enable_alarm].boolValue
            alarmSound = htSettings[R.settings_key_ht_alarm_sound].intValue
            humiThres = htSettings[R.settings_key_ht_humi_thres].doubleValue
            tempThres = htSettings[R.settings_key_ht_temp_thres].doubleValue
            linkFreq = htSettings[R.settings_key_ht_link_freq].doubleValue as NSTimeInterval
        }
    }
    
    func initChart() {
        chartView.clearsContextBeforeDrawing = true
        chartView.descriptionText = R.ht_chart_description
        chartView.noDataText = R.ht_chart_no_data_text
        chartView.highlightEnabled = true
        chartView.dragEnabled = false
        chartView.setScaleEnabled(false)
        chartView.drawGridBackgroundEnabled = true
        chartView.pinchZoomEnabled = false
        chartView.legend.font = R.ht_chart_legend_font
        chartView.legend.textColor = R.ht_chart_legend_text_color
        chartView.gridBackgroundColor = R.ht_chart_grid_background_color
        
        let xAxis = chartView.xAxis
        xAxis.labelFont = R.ht_chart_legend_font
        xAxis.labelTextColor = R.ht_chart_legend_text_color
        xAxis.drawGridLinesEnabled = false
        xAxis.drawAxisLineEnabled = false
        xAxis.spaceBetweenLabels = R.ht_chart_space_betweenLabels
        xAxis.drawGridLinesEnabled = true
        xAxis.labelPosition = .Bottom
    }
    
    func handleAlarm(temp temp:Double, humi:Double, soundIdx:Int) {
        if useAlarm {
            if (temp >= tempThres) || (humi >= humiThres) {
                let path = NSBundle.mainBundle().pathForResource(R.settings_ht_alarm_sounds[soundIdx], ofType: "wav")
                try! player = AVAudioPlayer(contentsOfURL: NSURL(fileURLWithPath: path!))
                player.prepareToPlay()
                player.play()
            }
        }
    }
    
    func cloudLink() {
        
        rootRef.observeEventType(.Value, withBlock: {
            snapshot in
            Log.i("cloudLink received:\n\(snapshot.value)")
            
            let tem = (((snapshot.value[R.ht_sensor] as! NSDictionary)[self.targetAmeba.mac] as! NSDictionary)[R.ht_key_temp] as! NSString).doubleValue
            let hum = (((snapshot.value[R.ht_sensor] as! NSDictionary)[self.targetAmeba.mac] as! NSDictionary)[R.ht_key_humi] as! NSString).doubleValue
            
            let reading = Reading(humidity: hum, temperature: tem)
            self.pushData(reading)
            self.handleAlarm(temp: tem, humi: hum, soundIdx: self.alarmSound)
            
            }, withCancelBlock: {
                error in
                Log.e(error.description)
        })
        
    }
    
    func localLink() {

        let qos = Int(QOS_CLASS_USER_INITIATED.rawValue)
        let mainQ = dispatch_get_main_queue()
        let sockQ = dispatch_get_global_queue(qos, 0)
        var dataStr = R.not_assigned
        var needPushData = false
        
        dispatch_async(sockQ){
            //off-UI Q
            
            let client = TCPClient(addr: self.ip, port: self.port)
            var (success,errmsg) = client.connect(timeout: R.tcp_connection_time_out)
            
            if !success {
                Log.e(errmsg)
            }
            else
            {
                let txEnc = Crypto.encrypt(R.tcp_tx_request, key: self.key)
                (success,errmsg) = client.send(str: txEnc)
                if !success {
                    Log.e(errmsg)
                }
                else
                {
                    if let rxDataEnc = client.read(R.tcp_expect_rx_data_length) {
                        
                        let rxStrEnc = String(bytes: rxDataEnc, encoding: NSUTF8StringEncoding)!
                        
                        dataStr = Crypto.decrypt(rxStrEnc, key: self.key)
                        
                        if dataStr == R.not_assigned {
                            Log.e("tcp_rx_nothing, maybe use wrong key or send unknown cmd")
                        }
                        else{
                            Log.i("localLink received:\n\(dataStr)")
                            needPushData = true
                        }
                    }
                    else{
                        Log.e("loca_link_rx_nil, read data from server failed")
                    }
                    
                }
            }
            
            client.close()

            dispatch_async(mainQ)
            {
                //main Q
                if needPushData {
                    let json = JSON(data: dataStr.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!)
                    let humi = (json[R.ht_key_humi].stringValue as NSString).doubleValue
                    let temp = (json[R.ht_key_temp].stringValue as NSString).doubleValue
                    let reading = Reading(humidity: humi, temperature: temp)
                    self.pushData(reading)
                    self.handleAlarm(temp: temp, humi: humi, soundIdx: self.alarmSound)
                }
            }
        }
        
    }

    @IBAction func closeVC(sender: AnyObject) {
        
        //...close any link connection
        rootRef.removeAllObservers()
        timer.invalidate()
        self.dismissViewControllerAnimated(true, completion: nil);
        
    }
    
    func pushData(reading:Reading) {
        
        let time = systemTime()
        
        Log.v("pushData: hum: \(reading.humidity) tem: \(reading.temperature) time: \(time)")
        
        readings.append(reading)
        times.append(time)
        
        while (readings.count > R.ht_readings_to_keep_in_buffer) && (readings.count != 0) {
            readings.removeAtIndex(0)
            times.removeAtIndex(0)
        }
        
        plotChart()
        temperatureLabel.text = "Temperature:  \(reading.temperature)"
        humidityLabel.text = "Humidity:  \(reading.humidity)"
    }
    
    func systemTime() -> String {
        let date = NSDate()
        let formatter = NSDateFormatter()
        formatter.timeZone = NSTimeZone.localTimeZone()
        formatter.dateFormat = R.ht_chart_time_format
        
        return formatter.stringFromDate(date)
    }
    
    func plotChart() {
        
        let humi = readings.map({$0.humidity})
        let temp = readings.map({$0.temperature})
        var ht = (humi + temp)
        ht.sortInPlace(<)
        
        let leftAxis = chartView.leftAxis
        leftAxis.labelTextColor = R.ht_chart_color_green_H
        leftAxis.customAxisMin = floor(ht.first! - (abs(ht.first!) * 0.1))
        leftAxis.customAxisMax = ceil(ht.last! + (abs(ht.last!) * 0.1))
        leftAxis.drawGridLinesEnabled = true
        leftAxis.startAtZeroEnabled = false
        
        let rightAxis = chartView.rightAxis
        rightAxis.labelTextColor = R.ht_chart_color_blue_T
        rightAxis.customAxisMin = floor(ht.first! - (abs(ht.first!) * 0.1))
        rightAxis.customAxisMax = ceil(ht.last! + (abs(ht.last!) * 0.1))
        rightAxis.drawGridLinesEnabled = true
        rightAxis.startAtZeroEnabled = false
        
        var hEntry = [ChartDataEntry]()
        for i in 0 ..< readings.count {
            let dataEntry = ChartDataEntry(value: humi[i], xIndex: i)
            hEntry.append(dataEntry)
        }
        
        let hSet = LineChartDataSet(yVals: hEntry, label: "Humidity: " + String(format: "%.2f", humi.last!))
        hSet.lineWidth = R.ht_chart_line_width
        hSet.circleRadius = R.ht_chart_circle_radius
        hSet.fillAlpha = R.ht_chart_fill_alpha
        hSet.setColor(R.ht_chart_color_green_H)
        hSet.fillColor = R.ht_chart_color_green_H
        hSet.circleColors = [R.ht_chart_color_green_H]
        
        
        var tEntry = [ChartDataEntry]()
        
        for i in 0 ..< readings.count {
            let dataEntry = ChartDataEntry(value: temp[i], xIndex: i)
            tEntry.append(dataEntry)
        }
        
        let tSet = LineChartDataSet(yVals: tEntry, label: "Temperature: " + String(format: "%.2f", temp.last!))
        tSet.lineWidth = R.ht_chart_line_width
        tSet.circleRadius = R.ht_chart_circle_radius
        tSet.fillAlpha = R.ht_chart_fill_alpha
        tSet.setColor(R.ht_chart_color_blue_T)
        tSet.fillColor = R.ht_chart_color_blue_T
        tSet.circleColors = [R.ht_chart_color_blue_T]
        
        var dataSets = [LineChartDataSet]()
        dataSets.append(hSet)
        dataSets.append(tSet)
        
        let data = LineChartData(xVals: times, dataSets: dataSets)
        chartView.data = data
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

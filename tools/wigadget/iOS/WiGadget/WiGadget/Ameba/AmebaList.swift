//
//  AmebaList.swift
//  WiGadget
//
//  Created by WU JINZHOU on 15/8/15.
//  Copyright (c) 2015 WU JINZHOU. All rights reserved.
//

import Foundation

protocol SavedListDelegate:class {
    func onSavedListUpdated(savedList:[Ameba])
}

protocol NewfoundListDelegate:class{
    func onNewfoundListUpdated(newfoundList:[Ameba])
}

class AmebaList {
    static var trackingList = [Ameba]()
    static var savedList = [Ameba]()
    static var newfoundList = [Ameba]()
    static var amebaJSONArray = [JSON]()
    
    static var linkTarget:Ameba?
    
    //static weak var trackingListDataSource:TrackingListDelegate?
    static weak var savedListDataSource:SavedListDelegate?
    static weak var newfoundListDataSource:NewfoundListDelegate?
    
    //MARK: update
    class func update(ameba:Ameba) {
        
        //update trackingList
        trackingListAddAmeba(ameba)
        
        //update savedList
        if savedListLookup(ameba) != R.not_found {
            if ameba.pair_state == R.not_paired {
                savedListRemoveAmeba(ameba)
                
                //update newfoundList
                ameba.link_state = R.online
                newfoundListAddAmeba(ameba)
            }
        }
        else{
            //update newfoundList
            ameba.link_state = R.online
            newfoundListAddAmeba(ameba)
        }
        
        printInfo()
    }
    
    //MARK: trackingList
    class func trackingListRemoveAmeba(ameba:Ameba) {
        trackingList = trackingList.filter({$0.mac != ameba.mac})
    }
    
    class func trackingListAddAmeba(ameba:Ameba) {
        let macList = trackingList.map({$0.mac})
        if let idx = macList.indexOf(ameba.mac) {
            trackingList[idx] = ameba
        }
        else{
            trackingList.append(ameba)
        }
    }
    

    class func trackingListGetAmebaByMac(mac:String) -> Ameba? {
        let tempList = trackingList.filter({ $0.mac == mac})
        if tempList.count != 0 {
            return tempList[0]
        }
        return nil
    }
    
    //MARK: savedList
    class func savedListLookup(ameba:Ameba) -> Int {
        for i in 0 ..< savedList.count {
            if savedList[i].mac == ameba.mac {
                return i
            }
        }
        return R.not_found
    }
    
    class func savedListRemoveAmeba(ameba:Ameba){
        savedList = savedList.filter({$0.mac != ameba.mac})
        save()
        savedListDataSource?.onSavedListUpdated(savedList)
    }
    
    class func savedListAddAmeba(ameba:Ameba){
        let macList = savedList.map({$0.mac})
        if let idx = macList.indexOf(ameba.mac) {
            savedList[idx] = ameba
        }
        else {
            savedList.append(ameba)
        }
        save()
        savedListDataSource?.onSavedListUpdated(savedList)
    }
    
    class func savedListGetAmebaByMac(mac:String) -> Ameba? {
        let tempList = savedList.filter({$0.mac == mac})
        if tempList.count != 0 {
            return tempList[0]
        }
        return nil
    }
    
    //MARK: newfoundList
    class func newfoundListRemoveAmeba(ameba:Ameba){
        newfoundList = newfoundList.filter({$0.mac != ameba.mac})
        newfoundListDataSource?.onNewfoundListUpdated(newfoundList)
    }
    
    class func newfoundListAddAmeba(ameba:Ameba){
        let macList = newfoundList.map({$0.mac})
        if let idx = macList.indexOf(ameba.mac) {
            newfoundList[idx] = ameba
        }
        else {
            newfoundList.append(ameba)
        }
        newfoundListDataSource?.onNewfoundListUpdated(newfoundList)
    }
    
    class func newfoundListGetAmebaByMac(mac:String) -> Ameba? {
        let tempList = newfoundList.filter({$0.mac == mac})
        if tempList.count != 0 {
            return tempList[0]
        }
        return nil
    }
    

    //MARK: pair
    class func pair(ameba:Ameba){
        newfoundListRemoveAmeba(ameba)
        savedListAddAmeba(ameba)
    }
    
    //MARK: unpair
    class func unpair(ameba:Ameba){
        savedListRemoveAmeba(ameba)
    }
    
    //MARK: save
    class func save(){
        
        amebaJSONArray = []

        for ameba in savedList {
            
            let json = [R.key_service_mac:ameba.mac,
                        R.key_service_name:ameba.name,
                        R.key_service_control_type:ameba.control_type,
                        R.key_service_shared_key:ameba.key,
                        R.key_service_firebase_app_id:ameba.firebase_app_id,
                        R.key_service_description:ameba.description,
                        R.key_service_pair_state:ameba.pair_state,
                        R.key_link_state:ameba.link_state] as JSON
            
            amebaJSONArray.append(json)
        }
        
        let data_to_save = JSON(amebaJSONArray).rawString(NSUTF8StringEncoding, options: [])
        
        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.setValue(data_to_save, forKey: R.key_ameba_data)
        defaults.synchronize()
        
        Log.i("\(amebaJSONArray.count) amebas saved to user defaults")
        
    }
    
    //MARK: load
    class func load(){
        let defaults = NSUserDefaults.standardUserDefaults()
        let dataStr = defaults.valueForKey(R.key_ameba_data) as? String ?? R.not_assigned
        amebaJSONArray = JSON(data: dataStr.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!).arrayValue
        Log.v("amebaJSONArray.count: \(amebaJSONArray.count)")
        
        for json in amebaJSONArray {
            let deviceMac = json[R.key_service_mac].stringValue
            let serviceName = json[R.key_service_name].stringValue
            let controlType = json[R.key_service_control_type].stringValue
            let sharedAESKey = json[R.key_service_shared_key].stringValue
            let firebaseAppId = json[R.key_service_firebase_app_id].stringValue
            let deviceDescription = json[R.key_service_description].stringValue
            let pairState = json[R.key_service_pair_state].stringValue
            let linkState = json[R.key_link_state].stringValue
            
            let ameba = Ameba(device_mac: deviceMac,
                              service_name: serviceName,
                              control_type: controlType,
                              shared_key: sharedAESKey,
                              firebase_app_id: firebaseAppId,
                              description: deviceDescription,
                              pair_state: pairState,
                              link_state:linkState)
            
            savedListAddAmeba(ameba)
            Log.i("ameba \(deviceMac) added to savedList from JSON array")
        }
    }
    
    class func printInfo() {
        Log.v("---- ameba lists ----")
        
        Log.i("trackingList: ")
        for a in trackingList {
            a.printInfo()
        }
        
        Log.i("savedList: ")
        for a in savedList {
            a.printInfo()
        }
        
        Log.i("newfoundList: ")
        for a in newfoundList {
            a.printInfo()
        }
    }
}

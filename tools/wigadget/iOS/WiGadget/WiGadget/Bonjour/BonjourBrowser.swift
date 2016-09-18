//
//  BonjourBrowser.swift
//  bonjour
//
//  Created by WU JINZHOU on 31/7/15.
//  Copyright (c) 2015 WU JINZHOU. All rights reserved.
//

import UIKit

class BonjourBrowser:NSObject,NSNetServiceBrowserDelegate,NSNetServiceDelegate {

    var nsb : NSNetServiceBrowser!
    var serviceList = [NSNetService]()
    
    let resolve_time_out:NSTimeInterval = R.bonjour_service_resolve_time_out
    
    func browse (serviceName:String,domain:String) {
        Log.v("\(serviceName)")
        self.serviceList.removeAll()
        self.nsb = NSNetServiceBrowser()
        self.nsb.delegate = self
        self.nsb.searchForServicesOfType(serviceName,inDomain: domain)
    }
    
    func netServiceBrowser(aNetServiceBrowser: NSNetServiceBrowser, didFindService aNetService: NSNetService, moreComing: Bool) {
        self.serviceList.append(aNetService)
        if !moreComing {
            for service in self.serviceList {
                if service.port == R.not_found {
                    Log.v("name: \(service.name) , type: \(service.type)")
                    service.delegate = self
                    service.resolveWithTimeout(resolve_time_out)
                }
            }
        }
    }
    
    func netService(sender: NSNetService, didUpdateTXTRecordData data: NSData) {
        Log.v("\(sender)")
        sender.resolveWithTimeout(resolve_time_out)
    }
    
    func netServiceDidResolveAddress(sender: NSNetService) {

        var txtRecords = [String:String]()
        
        //class func dictionaryFromTXTRecordData(_ txtData: NSData) -> [String : NSData]
        for (k,v) in NSNetService.dictionaryFromTXTRecordData(sender.TXTRecordData()!){
            txtRecords.updateValue(NSString(data: v , encoding: NSASCIIStringEncoding)! as String , forKey: k )
        }
        
        Log.v("TXTRecord:\(txtRecords)")
        
        let ameba = Ameba(resolvedTxtRecords: txtRecords)
        AmebaList.update(ameba)
        
        sender.startMonitoring()

    }
}

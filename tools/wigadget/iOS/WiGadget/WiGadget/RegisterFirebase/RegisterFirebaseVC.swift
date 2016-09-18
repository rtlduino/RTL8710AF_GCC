//
//  RegisterFirebaseVC.swift
//  WiGadget
//
//  Created by WU JINZHOU on 19/9/15.
//  Copyright © 2015 WU JINZHOU. All rights reserved.
//

import UIKit

class RegisterFirebaseVC: UIViewController,UIWebViewDelegate {

    @IBOutlet weak var webView: UIWebView!
    
    var timer = NSTimer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        webView.delegate = self
        let url = NSURL(string: "https://www.firebase.com/signup/")
        let request = NSURLRequest(URL: url!)
        
        webView.loadRequest(request)
    }
    
    func cancelLoading() {
        timer.invalidate()
        view.hideToastActivity()
        view.makeToast("Connection timeout\nCannot open web page", duration: R.toast_duration, position: CSToastPositionBottom, title: "CONNECTION TIMEOUT", image: R.toast_ic_failed)
    }
    
    func webViewDidStartLoad(webView: UIWebView) {
        view.makeToastActivity()
        timer = NSTimer.scheduledTimerWithTimeInterval(R.web_page_load_timeout, target: self, selector: "cancelLoading", userInfo: nil, repeats: false)
    }
    
    func webViewDidFinishLoad(webView: UIWebView) {
        timer.invalidate()
        view.hideToastActivity()
    }
    
    @IBAction func stop(sender: AnyObject) {
        webView.stopLoading()
    }
    
    
    @IBAction func reload(sender: AnyObject) {
        webView.reload()
    }
    
    
    @IBAction func goBack(sender: AnyObject) {
        webView.goBack()
    }
    
    
    @IBAction func goForward(sender: AnyObject) {
        webView.goForward()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    @IBAction func closeVC(sender: AnyObject) {
        timer.invalidate()
        self.dismissViewControllerAnimated(true, completion: nil);
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}

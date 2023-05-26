//
//  ViewController.swift
//  StripeDisconnect
//
//  Created by Gregory Anderson on 5/26/23.
//

import UIKit
import StripeTerminal

class ViewController: UIViewController {
    var simulateReaders: Bool = true
    var connectedReader: Reader?
    var readerLocationID = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Terminal.setTokenProvider(StripeAPIClient.shared)
        
        Task {
            guard
                let result:(locations: [Location], Bool) = try? await Terminal.shared.listLocations(parameters: nil),
                result.locations.count > 0 else {
                print ("ERROR! IMPLEMENTATION ERROR: No Stripe Location IDs")
                exit(-2)
            }
            readerLocationID = result.locations[0].stripeId
            discoverReaders()
        }
    }
    
    func discoverReaders() {
        let config = DiscoveryConfiguration(discoveryMethod: .bluetoothScan,
                                            simulated: simulateReaders)
        print ("Discovering Stripe readers")
        let _ = Terminal.shared.discoverReaders(config, delegate: self) {
            error in
            if let error = error {
                print("ERROR! discoverReaders FAILED error: \(error)")
                exit(-4)
            } else {
                print("discoverReaders -- SUCCESS")
                print("Disconnecting reader")
                self.disconnectReader()
            }
        }
    }
    
    func disconnectReader() {
        if Terminal.shared.connectionStatus == .connected {
            Terminal.shared.disconnectReader {
                error in
                if let error = error {
                    print("ERROR! disconnectReader FAILED error: \(error)")
                    exit(-6)
                } else {
                    print("disconnectReader -- SUCCESS")
                    print ("StripeTerminal status is \(self.describeTerminalStatus())")
                    print("Discovering readers again")
                    self.discoverReaders()
                }
            }
        }
        else {
            print("ERROR! Terminal says no reader is connected.")
            exit(-5)
        }
    }
    
    func describeTerminalStatus() -> String {
        switch Terminal.shared.connectionStatus {
        case .notConnected:
            return ("Terminal connection status = NOT CONNECTED")
        case .connected:
            return ("Terminal connection status = CONNECTED")
        case .connecting:
            return ("Terminal connection status = CONNECTING")
        @unknown default:
            return ("Terminal connection status = UNKNOWN")
        }
    }
}

//MARK: DiscoveryDelegate
extension ViewController: DiscoveryDelegate {
    func terminal(_ terminal: Terminal, didUpdateDiscoveredReaders readers: [Reader]) {
        if readers.count > 0 {
            let reader = readers.first!
            print ("didUpdateDiscoveredReaders: Found first reader: \(reader.serialNumber)")
            print ("Connecting to \(reader.serialNumber)")
            Terminal.shared.connectBluetoothReader(reader,
                                                   delegate: self,
                                                   connectionConfig: BluetoothConnectionConfiguration(locationId: readerLocationID)) {
                reader, error in
                if let error = error {
                    print("ERROR! connectBluetoothReader FAILED error: \(error)")
                    exit(-3)
                } else {
                    print("connectBluetoothReader -- SUCCESS.")
                }
            }
        }
    }
}

//MARK: BluetoothReaderDelegate
extension ViewController: BluetoothReaderDelegate {
    func reader(_ reader: Reader, didReportAvailableUpdate update: ReaderSoftwareUpdate) {}
    func reader(_ reader: Reader, didStartInstallingUpdate update: ReaderSoftwareUpdate, cancelable: Cancelable?) {}
    func reader(_ reader: Reader, didReportReaderSoftwareUpdateProgress progress: Float) {}
    func reader(_ reader: Reader, didFinishInstallingUpdate update: ReaderSoftwareUpdate?, error: Error?) {}
    func reader(_ reader: Reader, didRequestReaderInput inputOptions: ReaderInputOptions = []) {}
    func reader(_ reader: Reader, didRequestReaderDisplayMessage displayMessage: ReaderDisplayMessage) {}
}
//MARK: ConnectionTokenProvider
public class StripeAPIClient: ConnectionTokenProvider {
//    let url = "YOUR TOKEN SERVER URL" // TODO: SET THIS URL
    let url = "https://harriscruises.starboardsuite.com/stripe-terminal/v1/get-connection-token"

    public static let shared = StripeAPIClient()
    
    public func fetchConnectionToken(_ completion: @escaping ConnectionTokenCompletionBlock) {
        if url == "YOUR TOKEN SERVER URL" {
            print ("ERROR! IMPLEMENTATION ERROR: You need to set the URL for obtaining your Stripe API token in StripeAPIClient")
            exit(-1)
        }
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let task = session.dataTask(with: URLRequest(url: URL(string: url)!)) {
            data, response, error in
            guard data != nil,
                  let json = try? JSONSerialization.jsonObject(with: data!, options: []) as? [String: Any],
                  let secret = json["secret"] as? String else {
                print ("ERROR! IMPLEMENTATION ERROR: fetchConnectionToken failed")
                return
            }
            completion(secret, nil)
        }
        task.resume()
    }
}

//MARK AppDelegate
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate{
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = ViewController() // Your initial view controller.
        window.makeKeyAndVisible()
        self.window = window
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}


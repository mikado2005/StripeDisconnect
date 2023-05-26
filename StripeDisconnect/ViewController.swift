//  StripeDisconnect
//
//  Created by Gregory Anderson (greg@planetbeagle.com) on 5/26/23.
//

// This app demonstrates an apparent bug in StripeTerminal v2.20.2
// involving the method Terminal.shared.disconnectReader

//TODO: To run it, first set the URL for your Stripe Token Server here:
let stripeTokenServerURL = "YOUR TOKEN SERVER URL"

// When run on real iOS hardware with a live Stripe Bluetooth reader
// in proximity, this app will discover the reader, connect to the reader,
// disconnect from the reader, and then discover it again, in a loop.
// [Note that any errors in interacting with the reader will halt the app.]

// To see this behavior, set this constant:
let simulateReaders: Bool = false

// When run using the StripeTerminal reader simulator, the method
// Terminal.shared.disconnectReader completes without error, but the
// Terminal object is still connected to the reader.  Hence, the following
// call to method Terminal.shared.discoverReaders fails with the error
// message:
/* Error Domain=com.stripe-terminal Code=1110 "Already connected to a reader. Disconnect from the reader, or power it off before trying again." UserInfo={NSLocalizedDescription=Already connected to a reader. Disconnect from the reader, or power it off before trying again., com.stripe-terminal:Message=Already connected to a reader. Disconnect from the reader, or power it off before trying again.} */

// To see that behavior, set this constant:
//let simulateReaders: Bool = true

import UIKit
import StripeTerminal

class ViewController: UIViewController {
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
                    print("StripeTerminal status is \(self.describeTerminalStatus())")
                    print("StripeTerminal connected reader is \(Terminal.shared.connectedReader?.serialNumber ?? "<NONE>")")
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
    public static let shared = StripeAPIClient()
    
    public func fetchConnectionToken(_ completion: @escaping ConnectionTokenCompletionBlock) {
        if stripeTokenServerURL.isEmpty || stripeTokenServerURL == "YOUR TOKEN SERVER URL" {
            print ("ERROR! IMPLEMENTATION ERROR: You need to set the URL for obtaining your Stripe API token in let stripeTokenServerURL")
            exit(-1)
        }
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let task = session.dataTask(with: URLRequest(url: URL(string: stripeTokenServerURL)!)) {
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

//MARK: AppDelegate
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
}


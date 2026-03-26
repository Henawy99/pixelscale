import Flutter
import UIKit
import GoogleMaps
import PaymobSDK

@main
@objc class AppDelegate: FlutterAppDelegate {
    // Store the result callback for async response
    var paymobSDKResult: FlutterResult?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Add debug logging
        print("Initializing Google Maps")
        GMSServices.provideAPIKey("AIzaSyCawO-luFU_-BiITLrEWObB0TWTnFQtAso")
        print("Google Maps API key set")
        
        // Setup Paymob SDK MethodChannel
        setupPaymobMethodChannel()
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // MARK: - Paymob SDK Integration
    
    private func setupPaymobMethodChannel() {
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return
        }
        
        let paymobChannel = FlutterMethodChannel(
            name: "paymob_sdk_flutter",
            binaryMessenger: controller.binaryMessenger
        )
        
        paymobChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            guard let self = self else { return }
            
            if call.method == "payWithPaymob",
               let args = call.arguments as? [String: Any] {
                self.paymobSDKResult = result
                self.callPaymobNativeSDK(arguments: args, viewController: controller)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    private func callPaymobNativeSDK(arguments: [String: Any], viewController: FlutterViewController) {
        // Extract required parameters
        guard let publicKey = arguments["publicKey"] as? String,
              let clientSecret = arguments["clientSecret"] as? String else {
            paymobSDKResult?("Error: Missing publicKey or clientSecret")
            return
        }
        
        // Extract optional customization parameters
        let appName = arguments["appName"] as? String ?? "Playmaker"
        let saveCardDefault = arguments["saveCardDefault"] as? Bool ?? false
        let showSaveCard = arguments["showSaveCard"] as? Bool ?? true
        
        // Button colors
        var buttonBackgroundColor: UIColor = UIColor(red: 0, green: 191/255, blue: 99/255, alpha: 1) // #00BF63
        var buttonTextColor: UIColor = .white
        
        if let bgColorInt = arguments["buttonBackgroundColor"] as? Int {
            buttonBackgroundColor = UIColor(
                red: CGFloat((bgColorInt >> 16) & 0xFF) / 255.0,
                green: CGFloat((bgColorInt >> 8) & 0xFF) / 255.0,
                blue: CGFloat(bgColorInt & 0xFF) / 255.0,
                alpha: 1.0
            )
        }
        
        if let textColorInt = arguments["buttonTextColor"] as? Int {
            buttonTextColor = UIColor(
                red: CGFloat((textColorInt >> 16) & 0xFF) / 255.0,
                green: CGFloat((textColorInt >> 8) & 0xFF) / 255.0,
                blue: CGFloat(textColorInt & 0xFF) / 255.0,
                alpha: 1.0
            )
        }
        
        // Handle saved bank cards
        // var savedCards: [SavedBankCard] = [] 
        
        if let savedCardData = arguments["savedBankCard"] as? [String: String],
           let maskedPanNumber = savedCardData["maskedPanNumber"] {
            // let savedCard = SavedBankCard(token: token, maskedPanNumber: maskedPanNumber, cardType: CardType(rawValue: cardType) ?? .Unknown)
            // savedCards.append(savedCard)
            print("Saved card provided: \(maskedPanNumber)")
        }
        
        // Initialize Paymob SDK
        let paymob = PaymobSDK()
        paymob.delegate = self
        
        // Customize SDK
        paymob.paymobSDKCustomization.appName = appName
        paymob.paymobSDKCustomization.buttonBackgroundColor = buttonBackgroundColor
        paymob.paymobSDKCustomization.buttonTextColor = buttonTextColor
        paymob.paymobSDKCustomization.saveCardDefault = saveCardDefault
        paymob.paymobSDKCustomization.showSaveCard = showSaveCard
        
        // Present the payment UI
        do {
            try paymob.presentPayVC(
                VC: viewController,
                PublicKey: publicKey,
                ClientSecret: clientSecret
                // SavedBankCards: savedCards
            )
        } catch {
            print("PaymobSDK Error: \(error.localizedDescription)")
            paymobSDKResult?("Error: \(error.localizedDescription)")
        }
    }
}

// MARK: - PaymobSDK Delegate
extension AppDelegate: PaymobSDKDelegate {
    public func transactionRejected(message: String) {
        print("💳 Paymob: Transaction Rejected - \(message)")
        paymobSDKResult?("Rejected")
    }
    
    public func transactionAccepted(transactionDetails: [String: Any]) {
        print("💳 Paymob: Transaction Accepted")
        paymobSDKResult?("Successfull")
    }
    
    public func transactionPending() {
        print("💳 Paymob: Transaction Pending")
        paymobSDKResult?("Pending")
    }
}

package com.playmakeregypt.app

import android.graphics.Color
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall

import com.paymob.paymob_sdk.PaymobSdk
// import com.paymob.paymob_sdk.domain.model.CreditCard
// import com.paymob.paymob_sdk.domain.model.SavedCard
import com.paymob.paymob_sdk.ui.PaymobSdkListener

class MainActivity: FlutterActivity(), PaymobSdkListener {
    private val CHANNEL = "paymob_sdk_flutter"
    private var paymobSDKResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        flutterEngine?.dartExecutor?.binaryMessenger?.let {
            MethodChannel(it, CHANNEL).setMethodCallHandler { call, result ->
                if (call.method == "payWithPaymob") {
                    paymobSDKResult = result
                    callPaymobNativeSDK(call)
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    private fun callPaymobNativeSDK(call: MethodCall) {
        val publicKey = call.argument<String>("publicKey")
        val clientSecret = call.argument<String>("clientSecret")

        if (publicKey == null || clientSecret == null) {
            paymobSDKResult?.success("Error: Missing publicKey or clientSecret")
            return
        }

        // Extract optional parameters
        val appName = call.argument<String>("appName") ?: "Playmaker"
        val saveCardDefault = call.argument<Boolean>("saveCardDefault") ?: false
        val showSaveCard = call.argument<Boolean>("showSaveCard") ?: true
        
        // Button colors
        val buttonBackgroundColorData = call.argument<Int>("buttonBackgroundColor") ?: 0xFF00BF63.toInt()
        val buttonTextColorData = call.argument<Int>("buttonTextColor") ?: 0xFFFFFFFF.toInt()
        
        val buttonBackgroundColor = Color.argb(
            (buttonBackgroundColorData shr 24) and 0xFF,
            (buttonBackgroundColorData shr 16) and 0xFF,
            (buttonBackgroundColorData shr 8) and 0xFF,
            buttonBackgroundColorData and 0xFF
        )
        
        val buttonTextColor = Color.argb(
            (buttonTextColorData shr 24) and 0xFF,
            (buttonTextColorData shr 16) and 0xFF,
            (buttonTextColorData shr 8) and 0xFF,
            buttonTextColorData and 0xFF
        )

        // Handle saved bank card
        @Suppress("UNCHECKED_CAST")
        val savedBankCard = call.argument<Map<String, String>>("savedBankCard")
        // var savedCardsArray: Array<SavedCard> = arrayOf()
        
        if (savedBankCard != null) {
            val maskedPan = savedBankCard["maskedPanNumber"] ?: ""
            val token = savedBankCard["token"] ?: ""
            val cardType = savedBankCard["cardType"] ?: ""
            Log.d("PaymobSDK", "Saved card provided: $maskedPan")
            
            // Uncomment when SDK is added
            // val creditCard = CreditCard.valueOf(cardType.uppercase())
            // val savedCard = SavedCard(maskedPan = "**** **** **** $maskedPan", token = token, creditCard = creditCard)
            // savedCardsArray = arrayOf(savedCard)
        }

        val paymobsdk = PaymobSdk.Builder(
            context = this@MainActivity,
            clientSecret = clientSecret,
            publicKey = publicKey,
            paymobSdkListener = this,
            // savedCards = savedCardsArray
        )
        .setButtonBackgroundColor(buttonBackgroundColor)
        .setButtonTextColor(buttonTextColor)
        .setAppName(appName)
        .isAbleToSaveCard(showSaveCard)
        .isSavedCardCheckBoxCheckedByDefault(saveCardDefault)
        .build()

        paymobsdk.start()
        return

    // ═══════════════════════════════════════════════════════════════════════════
    // Paymob SDK Listener
    // ═══════════════════════════════════════════════════════════════════════════
    override fun onFailure() {
        Log.d("PaymobSDK", "Transaction Rejected")
        paymobSDKResult?.success("Rejected")
    }

    override fun onPending() {
        Log.d("PaymobSDK", "Transaction Pending")
        paymobSDKResult?.success("Pending")
    }

    override fun onSuccess() {
        Log.d("PaymobSDK", "Transaction Successful")
        paymobSDKResult?.success("Successfull")
    }
}

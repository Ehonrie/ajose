package com.pavegroup.ajose.ajose

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import com.solana.mobilewalletadapter.clientlib.ActivityResultSender
import com.solana.mobilewalletadapter.clientlib.Blockchain
import com.solana.mobilewalletadapter.clientlib.ConnectionIdentity
import com.solana.mobilewalletadapter.clientlib.MobileWalletAdapter
import com.solana.mobilewalletadapter.clientlib.Solana
import com.solana.mobilewalletadapter.clientlib.TransactionResult
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/// local_auth (biometric prompts for the transaction/contribution confirmation
/// flow) requires a FragmentActivity host, hence FlutterFragmentActivity here
/// instead of the default FlutterActivity.
///
/// Also hosts the Mobile Wallet Adapter bridge: a MethodChannel wrapping
/// mobile-wallet-adapter-clientlib-ktx directly (MWA 2.0), since the
/// solana_mobile_client Flutter package pins the old MWA 1.x clientlib,
/// which current MWA-2.0-only wallets (Solflare, and current Phantom
/// builds) silently ignore. The clientlib-ktx dependency here is a locally
/// patched copy of the published AAR — see build.gradle.kts for why.
class MainActivity : FlutterFragmentActivity() {
    // Must be constructed before the activity reaches STARTED — the
    // underlying registerForActivityResult contract requires this — so it's
    // a property initialized at construction time, not inside onCreate.
    private val activityResultSender = ActivityResultSender(this)

    // TODO: identityUri/iconUri point at a placeholder domain (ajose.app
    // isn't hosted yet). ConnectionIdentity requires non-null values, but a
    // failed icon fetch is just a display nicety wallets handle gracefully —
    // it does not block the connect flow. Swap for the real domain once one
    // exists.
    private val walletAdapter = MobileWalletAdapter(
        connectionIdentity = ConnectionIdentity(
            identityUri = Uri.parse("https://ajose.app"),
            iconUri = Uri.parse("favicon.ico"),
            identityName = "Ajose",
        )
    )

    private val mwaScope = CoroutineScope(Dispatchers.Main)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MWA_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isWalletAvailable" -> result.success(isWalletAvailable())
                    "authorize" -> {
                        walletAdapter.authToken = null
                        walletAdapter.blockchain = blockchainFor(call.argument("cluster"))
                        connect(result)
                    }
                    "reauthorize" -> {
                        walletAdapter.authToken = call.argument("authToken")
                        walletAdapter.blockchain = blockchainFor(call.argument("cluster"))
                        connect(result)
                    }
                    "deauthorize" -> {
                        walletAdapter.authToken = call.argument("authToken")
                        mwaScope.launch {
                            try {
                                walletAdapter.disconnect(activityResultSender)
                            } catch (_: Exception) {
                                // Best-effort — the Dart side clears its local
                                // session regardless of whether this succeeds.
                            }
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // Mirrors AppConfig.cluster's mwaClusterName strings on the Dart side —
    // that field is the app's single "flip this to change cluster" switch,
    // so it's passed in per-call rather than hardcoded here.
    private fun blockchainFor(cluster: String?): Blockchain = when (cluster) {
        "mainnet-beta" -> Solana.Mainnet
        "testnet" -> Solana.Testnet
        else -> Solana.Devnet
    }

    private fun isWalletAvailable(): Boolean {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("solana-wallet://"))
        return packageManager.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY).isNotEmpty()
    }

    private fun connect(result: MethodChannel.Result) {
        mwaScope.launch {
            when (val outcome = walletAdapter.connect(activityResultSender)) {
                is TransactionResult.Success -> {
                    val auth = outcome.authResult
                    result.success(
                        mapOf(
                            "authToken" to auth.authToken,
                            "publicKey" to auth.publicKey,
                            "accountLabel" to auth.accountLabel,
                            "walletUriBase" to auth.walletUriBase?.toString(),
                        )
                    )
                }
                is TransactionResult.NoWalletFound ->
                    result.error("NO_WALLET_FOUND", outcome.message, null)
                is TransactionResult.Failure ->
                    result.error("MWA_FAILURE", outcome.message, null)
            }
        }
    }

    companion object {
        private const val MWA_CHANNEL = "app.ajose/mwa"
    }
}

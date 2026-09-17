package com.pavegroup.ajose.ajose

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth (biometric prompts for the transaction/contribution confirmation
// flow) requires a FragmentActivity host, hence FlutterFragmentActivity here
// instead of the default FlutterActivity.
class MainActivity : FlutterFragmentActivity()

package com.doops.meal_plan

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity: Health Connect permission requests use
// registerForActivityResult, which needs a ComponentActivity.
class MainActivity : FlutterFragmentActivity() {
    // Health Connect's privacy-policy (Android 14+, via the
    // ViewPermissionUsageActivity alias) and permission-rationale (Android 13-)
    // links land here; both open the privacy policy screen.
    private fun privacyRouteFor(intent: Intent?): String? =
        when (intent?.action) {
            "android.intent.action.VIEW_PERMISSION_USAGE",
            "androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" -> "/privacy-policy"
            else -> null
        }

    override fun getInitialRoute(): String? =
        privacyRouteFor(intent) ?: super.getInitialRoute()

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        privacyRouteFor(intent)?.let {
            flutterEngine?.navigationChannel?.pushRouteInformation(it)
        }
    }
}

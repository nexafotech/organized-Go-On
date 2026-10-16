package com.aifaceattendance.mobile_app

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val savedTheme = prefs.getString("flutter.pref_theme_mode", null)
            if (savedTheme == "dark") {
                window.setBackgroundDrawable(ColorDrawable(Color.parseColor("#0D0C13")))
                window.statusBarColor = Color.parseColor("#0D0C13")
                window.navigationBarColor = Color.parseColor("#0D0C13")
            } else {
                window.setBackgroundDrawable(ColorDrawable(Color.parseColor("#FFFFFF")))
                window.statusBarColor = Color.parseColor("#FFFFFF")
                window.navigationBarColor = Color.parseColor("#FFFFFF")
            }
        } catch (_: Exception) {
            window.setBackgroundDrawable(ColorDrawable(Color.parseColor("#FFFFFF")))
        }

        // On Android 12+ (API 31+), dismiss the native splash screen immediately when Flutter draws
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashScreen.setOnExitAnimationListener { splashScreenView ->
                splashScreenView.remove()
            }
        }

        super.onCreate(savedInstanceState)
    }
}

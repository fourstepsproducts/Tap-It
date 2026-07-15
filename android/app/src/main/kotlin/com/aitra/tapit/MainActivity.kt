package com.aitra.tapit

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.track_expense/widget"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            if (call.method == "updateWidget") {
                try {
                    val prefs = applicationContext.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                    val editor = prefs.edit()
                    
                    @Suppress("UNCHECKED_CAST")
                    val data = call.arguments as? Map<String, Any?>
                    if (data != null) {
                        for ((key, value) in data) {
                            if (value != null) {
                                editor.putString(key, value.toString())
                            } else {
                                editor.remove(key)
                            }
                        }
                        editor.apply()
                        
                        // Trigger widget refresh for Personal (MoneyWidgetProvider)
                        val manager = AppWidgetManager.getInstance(applicationContext)
                        
                        val personalComponentName = ComponentName(applicationContext, MoneyWidgetProvider::class.java)
                        val personalWidgetIds = manager.getAppWidgetIds(personalComponentName)
                        if (personalWidgetIds.isNotEmpty()) {
                            val provider = MoneyWidgetProvider()
                            provider.onUpdate(applicationContext, manager, personalWidgetIds)
                        }

                        // Trigger widget refresh for Tap Due
                        val ledgerComponentName = ComponentName(applicationContext, LedgerWidgetProvider::class.java)
                        val ledgerWidgetIds = manager.getAppWidgetIds(ledgerComponentName)
                        if (ledgerWidgetIds.isNotEmpty()) {
                            val provider = LedgerWidgetProvider()
                            provider.onUpdate(applicationContext, manager, ledgerWidgetIds)
                        }

                        // Trigger widget refresh for Tap Invest
                        val investComponentName = ComponentName(applicationContext, InvestWidgetProvider::class.java)
                        val investWidgetIds = manager.getAppWidgetIds(investComponentName)
                        if (investWidgetIds.isNotEmpty()) {
                            val provider = InvestWidgetProvider()
                            provider.onUpdate(applicationContext, manager, investWidgetIds)
                        }

                        // Trigger widget refresh for Split It
                        val splitComponentName = ComponentName(applicationContext, SplitWidgetProvider::class.java)
                        val splitWidgetIds = manager.getAppWidgetIds(splitComponentName)
                        if (splitWidgetIds.isNotEmpty()) {
                            val provider = SplitWidgetProvider()
                            provider.onUpdate(applicationContext, manager, splitWidgetIds)
                        }
                        
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                } catch (e: Exception) {
                    result.success(false)
                }
            } else {
                result.notImplemented()
            }
        }

        // Process initial cold-start intent
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        if (intent.hasExtra("target_tab")) {
            val tab = intent.getIntExtra("target_tab", 0)
            val subTab = intent.getStringExtra("sub_tab")
            if (subTab != null) {
                methodChannel?.invokeMethod("openTab", mapOf("tab" to tab, "subTab" to subTab))
            } else {
                methodChannel?.invokeMethod("openTab", tab)
            }
        }
    }
}

package com.example.track_expense

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.track_expense/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
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
                        
                        // Trigger widget refresh
                        val manager = AppWidgetManager.getInstance(applicationContext)
                        val componentName = ComponentName(applicationContext, MoneyWidgetProvider::class.java)
                        val widgetIds = manager.getAppWidgetIds(componentName)
                        if (widgetIds.isNotEmpty()) {
                            val provider = MoneyWidgetProvider()
                            provider.onUpdate(applicationContext, manager, widgetIds)
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
    }
}

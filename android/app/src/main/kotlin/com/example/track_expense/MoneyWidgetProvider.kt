package com.example.track_expense

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews

class MoneyWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_CHANGE_TAB = "com.example.track_expense.ACTION_CHANGE_TAB"
        const val EXTRA_TAB = "extra_tab"
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_CHANGE_TAB) {
            val tab = intent.getStringExtra(EXTRA_TAB) ?: "daily"
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            prefs.edit().putString("current_tab", tab).apply()

            val manager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, MoneyWidgetProvider::class.java)
            val widgetIds = manager.getAppWidgetIds(componentName)
            onUpdate(context, manager, widgetIds)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout)
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

            views.setTextViewText(R.id.widget_balance, prefs.getString("balance", "₹0.00"))
            views.setTextViewText(R.id.widget_income, prefs.getString("income", "₹0.00"))
            views.setTextViewText(R.id.widget_expenses, prefs.getString("expenses", "₹0.00"))

            // Open app on widget click
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                val pi = PendingIntent.getActivity(context, 0, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                views.setOnClickPendingIntent(R.id.widget_root, pi)
            }

            // Tabs
            val currentTab = prefs.getString("current_tab", "daily") ?: "daily"
            setupTabs(context, views, appWidgetId, currentTab)
            setupQuickEntries(context, views, prefs, currentTab)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun setupTabs(context: Context, views: RemoteViews, appWidgetId: Int, currentTab: String) {
        val activeTextColor = android.graphics.Color.parseColor("#FFFFFF")
        val inactiveTextColor = android.graphics.Color.parseColor("#888888")
        val activeBg = android.graphics.Color.parseColor("#3652BA")
        val inactiveBg = android.graphics.Color.parseColor("#1E1E1E")

        views.setTextColor(R.id.tab_daily, if (currentTab == "daily") activeTextColor else inactiveTextColor)
        views.setTextColor(R.id.tab_monthly, if (currentTab == "monthly") activeTextColor else inactiveTextColor)
        views.setTextColor(R.id.tab_flexi, if (currentTab == "flexi") activeTextColor else inactiveTextColor)

        views.setInt(R.id.tab_daily, "setBackgroundColor", if (currentTab == "daily") activeBg else inactiveBg)
        views.setInt(R.id.tab_monthly, "setBackgroundColor", if (currentTab == "monthly") activeBg else inactiveBg)
        views.setInt(R.id.tab_flexi, "setBackgroundColor", if (currentTab == "flexi") activeBg else inactiveBg)

        views.setOnClickPendingIntent(R.id.tab_daily, getTabIntent(context, "daily"))
        views.setOnClickPendingIntent(R.id.tab_monthly, getTabIntent(context, "monthly"))
        views.setOnClickPendingIntent(R.id.tab_flexi, getTabIntent(context, "flexi"))
    }

    private fun getTabIntent(context: Context, tab: String): PendingIntent {
        val intent = Intent(context, MoneyWidgetProvider::class.java).apply {
            action = ACTION_CHANGE_TAB
            putExtra(EXTRA_TAB, tab)
        }
        return PendingIntent.getBroadcast(context, tab.hashCode(), intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun setupQuickEntries(context: Context, views: RemoteViews, prefs: android.content.SharedPreferences, tab: String) {
        val textViews = intArrayOf(R.id.quick_1, R.id.quick_2, R.id.quick_3, R.id.quick_4, R.id.quick_5, R.id.quick_6)

        for (i in 0..5) {
            val title = prefs.getString("${tab}_${i + 1}_title", null)
            val itemId = prefs.getString("${tab}_${i + 1}_id", null)

            if (title != null && itemId != null) {
                views.setTextViewText(textViews[i], title)

                val clickIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                if (clickIntent != null) {
                    clickIntent.data = Uri.parse("moneycalc://add_transaction?itemId=$itemId")
                    val pi = PendingIntent.getActivity(context, itemId.hashCode(), clickIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                    views.setOnClickPendingIntent(textViews[i], pi)
                }
            } else {
                views.setTextViewText(textViews[i], "—")
            }
        }
    }
}

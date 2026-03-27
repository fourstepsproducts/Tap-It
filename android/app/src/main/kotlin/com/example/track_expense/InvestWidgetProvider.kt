package com.example.track_expense

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews

class InvestWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_invest_layout)
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

            views.setTextViewText(R.id.invest_current_value, prefs.getString("invest_current_value", "₹0.00"))
            views.setTextViewText(R.id.invest_invested, prefs.getString("invest_invested", "₹0.00"))
            views.setTextViewText(R.id.invest_pnl, prefs.getString("invest_pnl", "₹0.00"))

            for (i in 1..3) {
                val title = prefs.getString("invest_item_${i}_title", null)
                val id = prefs.getString("invest_item_${i}_id", null)
                val viewId = context.resources.getIdentifier("invest_item_$i", "id", context.packageName)

                if (title != null && id != null) {
                    views.setTextViewText(viewId, title)
                    
                    val clickIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                    if (clickIntent != null) {
                        clickIntent.data = Uri.parse("moneycalc://invest?id=$id")
                        val pi = PendingIntent.getActivity(context, id.hashCode(), clickIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                        views.setOnClickPendingIntent(viewId, pi)
                    }
                } else {
                    views.setTextViewText(viewId, "—")
                }
            }

            // Open app on click
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                launchIntent.action = Intent.ACTION_VIEW
                launchIntent.data = Uri.parse("moneycalc://widget/2")
                launchIntent.putExtra("target_tab", 2)
                val pi = PendingIntent.getActivity(context, 2, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                views.setOnClickPendingIntent(R.id.widget_root, pi)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

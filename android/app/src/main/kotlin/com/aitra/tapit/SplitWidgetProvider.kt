package com.aitra.tapit

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews

class SplitWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_split_layout)
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

            views.setTextViewText(R.id.split_your_share, prefs.getString("split_your_share", "Ã¢â€šÂ¹0.00"))
            views.setTextViewText(R.id.split_group_count, prefs.getString("split_group_count", "0"))
            views.setTextViewText(R.id.split_pending_count, prefs.getString("split_pending_count", "0"))

            for (i in 1..3) {
                val title = prefs.getString("split_group_${i}_title", null)
                val id = prefs.getString("split_group_${i}_id", null)
                val viewId = context.resources.getIdentifier("split_group_$i", "id", context.packageName)

                if (title != null && id != null) {
                    views.setTextViewText(viewId, title)
                    
                    val clickIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                    if (clickIntent != null) {
                        clickIntent.data = Uri.parse("moneycalc://split?groupId=$id")
                        val pi = PendingIntent.getActivity(context, id.hashCode(), clickIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                        views.setOnClickPendingIntent(viewId, pi)
                    }
                } else {
                    views.setTextViewText(viewId, "Ã¢â‚¬â€")
                }
            }

            // Open app on click
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                launchIntent.action = Intent.ACTION_VIEW
                launchIntent.data = Uri.parse("moneycalc://widget/3")
                launchIntent.putExtra("target_tab", 3)
                val pi = PendingIntent.getActivity(context, 3, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                views.setOnClickPendingIntent(R.id.widget_root, pi)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

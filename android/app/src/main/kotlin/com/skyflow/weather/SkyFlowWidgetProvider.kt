package com.skyflow.weather

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Home-screen weather widget. The Dart side (HomeWidgetService) writes the texts. */
class SkyFlowWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    for (widgetId in appWidgetIds) {
      val views = RemoteViews(context.packageName, R.layout.skyflow_widget).apply {
        val isDay = widgetData.getString("isDay", "1") == "1"
        setInt(
            R.id.widget_root,
            "setBackgroundResource",
            if (isDay) R.drawable.widget_bg_day else R.drawable.widget_bg_night,
        )
        setTextViewText(R.id.widget_place, widgetData.getString("place", null) ?: "SkyFlow Weather")
        setTextViewText(R.id.widget_temp, widgetData.getString("temp", null) ?: "--°")
        setTextViewText(R.id.widget_condition, widgetData.getString("condition", null) ?: "")
        setTextViewText(R.id.widget_emoji, widgetData.getString("emoji", null) ?: "⛅")
        setTextViewText(R.id.widget_hilo, widgetData.getString("hilo", null) ?: "")
        setTextViewText(
            R.id.widget_rain,
            widgetData.getString("rain", null) ?: "Open the app to load weather",
        )
        setTextViewText(R.id.widget_updated, widgetData.getString("updated", null) ?: "")
        setOnClickPendingIntent(
            R.id.widget_root,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
        )
      }
      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}

package com.skyflow.weather

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Fills the views shared by both widgets. The Dart side (HomeWidgetService) writes the texts. */
internal object WidgetBinder {
  fun text(data: SharedPreferences, key: String, fallback: String = ""): String =
      data.getString(key, null) ?: fallback

  fun bindCommon(context: Context, views: RemoteViews, data: SharedPreferences) {
    val isDay = text(data, "isDay", "1") == "1"
    views.setInt(
        R.id.widget_root,
        "setBackgroundResource",
        if (isDay) R.drawable.widget_bg_day else R.drawable.widget_bg_night,
    )
    views.setTextViewText(R.id.widget_place, text(data, "place", "SkyFlow Weather"))
    views.setTextViewText(R.id.widget_temp, text(data, "temp", "--°"))
    views.setTextViewText(R.id.widget_condition, text(data, "condition"))
    views.setTextViewText(R.id.widget_emoji, text(data, "emoji", "⛅"))
    views.setTextViewText(R.id.widget_hilo, text(data, "hilo"))
    views.setTextViewText(R.id.widget_rain, text(data, "rain", "Open the app to load weather"))
    views.setTextViewText(R.id.widget_updated, text(data, "updated"))
    views.setOnClickPendingIntent(
        R.id.widget_root,
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
    )
  }

  fun setOptional(views: RemoteViews, id: Int, value: String) {
    views.setTextViewText(id, value)
    views.setViewVisibility(id, if (value.isEmpty()) View.GONE else View.VISIBLE)
  }
}

/** Small (4×2) weather widget. */
class SkyFlowWidgetProvider : HomeWidgetProvider() {
  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    for (widgetId in appWidgetIds) {
      val views = RemoteViews(context.packageName, R.layout.skyflow_widget)
      WidgetBinder.bindCommon(context, views, widgetData)
      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}

/** Large (4×4) widget with everything: hours, days, AQI, UV, wind, warnings. */
class SkyFlowLargeWidgetProvider : HomeWidgetProvider() {
  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val t = { key: String -> WidgetBinder.text(widgetData, key) }
    val hourIds = arrayOf(
        intArrayOf(R.id.h0_time, R.id.h0_emoji, R.id.h0_temp),
        intArrayOf(R.id.h1_time, R.id.h1_emoji, R.id.h1_temp),
        intArrayOf(R.id.h2_time, R.id.h2_emoji, R.id.h2_temp),
        intArrayOf(R.id.h3_time, R.id.h3_emoji, R.id.h3_temp),
        intArrayOf(R.id.h4_time, R.id.h4_emoji, R.id.h4_temp),
    )
    val dayIds = arrayOf(
        intArrayOf(R.id.d0_name, R.id.d0_emoji, R.id.d0_rain, R.id.d0_hilo),
        intArrayOf(R.id.d1_name, R.id.d1_emoji, R.id.d1_rain, R.id.d1_hilo),
        intArrayOf(R.id.d2_name, R.id.d2_emoji, R.id.d2_rain, R.id.d2_hilo),
    )
    for (widgetId in appWidgetIds) {
      val views = RemoteViews(context.packageName, R.layout.skyflow_widget_large)
      WidgetBinder.bindCommon(context, views, widgetData)
      views.setTextViewText(R.id.widget_feels, t("feels"))
      views.setTextViewText(R.id.widget_humidity, t("humidity"))
      views.setTextViewText(R.id.widget_wind, t("wind"))
      views.setTextViewText(R.id.widget_uv, t("uv"))
      views.setTextViewText(R.id.widget_aqi, t("aqi"))
      WidgetBinder.setOptional(views, R.id.widget_sun, t("sun"))
      WidgetBinder.setOptional(views, R.id.widget_warning, t("warning"))
      hourIds.forEachIndexed { i, ids ->
        views.setTextViewText(ids[0], t("h${i}_time"))
        views.setTextViewText(ids[1], t("h${i}_emoji"))
        views.setTextViewText(ids[2], t("h${i}_temp"))
      }
      dayIds.forEachIndexed { i, ids ->
        views.setTextViewText(ids[0], t("d${i}_name"))
        views.setTextViewText(ids[1], t("d${i}_emoji"))
        views.setTextViewText(ids[2], t("d${i}_rain"))
        views.setTextViewText(ids[3], t("d${i}_hilo"))
      }
      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}

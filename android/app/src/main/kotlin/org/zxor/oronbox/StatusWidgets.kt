package org.zxor.oronbox

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.os.Bundle
import android.widget.RemoteViews
import java.text.DateFormat
import java.util.Date
import java.util.Locale

private const val COMPACT_WIDTH_DP = 160
// One launcher row is commonly reported as 100-120dp rather than the nominal
// 72dp from provider metadata. Keep every one-row placement on the compact
// layout; the medium layout needs a genuine second row.
private const val COMPACT_HEIGHT_DP = 160
private const val STALE_AFTER_MS = 6 * 60 * 60 * 1000L

private data class WidgetColors(
    val surface: Int,
    val surfaceVariant: Int,
    val onSurface: Int,
    val onSurfaceVariant: Int,
    val primary: Int,
    val secondary: Int,
    val tertiary: Int,
    val track: Int,
) {
    companion object {
        fun resolve(context: Context): WidgetColors {
            val resources = context.resources
            val night = resources.configuration.uiMode and
                Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
            fun fallback(id: Int) = context.getColor(id)
            fun dynamic(name: String, fallbackId: Int): Int {
                if (android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.S) {
                    return fallback(fallbackId)
                }
                val id = resources.getIdentifier(name, "color", "android")
                return if (id == 0) fallback(fallbackId) else resources.getColor(id, context.theme)
            }
            return WidgetColors(
                surface = dynamic(
                    if (night) "system_neutral1_900" else "system_neutral1_10",
                    R.color.widget_surface,
                ),
                surfaceVariant = dynamic(
                    if (night) "system_neutral2_800" else "system_neutral2_50",
                    R.color.widget_surface_variant,
                ),
                onSurface = dynamic(
                    if (night) "system_neutral1_10" else "system_neutral1_900",
                    R.color.widget_on_surface,
                ),
                onSurfaceVariant = dynamic(
                    if (night) "system_neutral2_200" else "system_neutral2_700",
                    R.color.widget_on_surface_variant,
                ),
                primary = dynamic(
                    if (night) "system_accent1_200" else "system_accent1_600",
                    R.color.widget_primary,
                ),
                secondary = dynamic(
                    if (night) "system_accent2_200" else "system_accent2_600",
                    R.color.widget_secondary,
                ),
                tertiary = dynamic(
                    if (night) "system_accent3_200" else "system_accent3_600",
                    R.color.widget_tertiary,
                ),
                track = dynamic(
                    if (night) "system_neutral2_700" else "system_neutral2_200",
                    R.color.widget_track,
                ),
            )
        }
    }
}

abstract class OronBoxWidgetProvider : AppWidgetProvider() {
    protected abstract fun layoutFor(minWidthDp: Int, minHeightDp: Int): Int
    protected abstract fun render(context: Context, views: RemoteViews)
    protected abstract fun pendingIntentRequestCode(): Int

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { update(context, appWidgetManager, it) }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        update(context, appWidgetManager, appWidgetId, newOptions)
    }

    internal fun update(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        options: Bundle? = null,
    ) {
        val resolvedOptions = options ?: appWidgetManager.getAppWidgetOptions(appWidgetId)
        val minWidth = resolvedOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
        val minHeight = resolvedOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
        val views = RemoteViews(context.packageName, layoutFor(minWidth, minHeight))
        render(context, views)
        views.setOnClickPendingIntent(
            R.id.widget_root,
            openAppIntent(context, pendingIntentRequestCode()),
        )
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    companion object {
        fun updateAll(context: Context, provider: Class<out AppWidgetProvider>) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, provider)
            manager.getAppWidgetIds(component).forEach { id ->
                val receiver = provider.getDeclaredConstructor().newInstance()
                    as OronBoxWidgetProvider
                receiver.update(context, manager, id)
            }
        }

        private fun openAppIntent(context: Context, requestCode: Int): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            return PendingIntent.getActivity(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }
    }
}

class DeviceStatusWidgetProvider : OronBoxWidgetProvider() {
    override fun layoutFor(minWidthDp: Int, minHeightDp: Int): Int = when {
        widgetTier(minWidthDp, minHeightDp) >= 1 -> R.layout.widget_device_status_medium
        else -> R.layout.widget_device_status_small
    }

    override fun pendingIntentRequestCode(): Int = 4201

    override fun render(context: Context, views: RemoteViews) {
        val data = StatusWidgetDataStore.device(context)
        val colors = WidgetColors.resolve(context)
        applyWidgetColors(views, colors, includeDeviceProgress = true)
        views.setTextViewText(
            R.id.widget_device_name,
            data.name.ifBlank { context.getString(R.string.widget_no_device) },
        )
        val status = when {
            !data.hasDevice -> context.getString(R.string.widget_no_device)
            data.connecting -> context.getString(R.string.widget_connecting)
            data.connected -> context.getString(R.string.widget_connected)
            else -> context.getString(R.string.widget_disconnected)
        }
        views.setTextViewText(R.id.widget_connection_state, status)
        views.setTextViewText(
            R.id.widget_battery_value,
            if (data.battery in 0..100) {
                "${data.battery}%"
            } else {
                context.getString(R.string.widget_no_value)
            },
        )
        views.setTextViewCompoundDrawables(
            R.id.widget_battery_value,
            0,
            0,
            if (data.charging) R.drawable.ic_widget_charging else 0,
            0,
        )
        views.setTextColor(
            R.id.widget_battery_value,
            if (data.charging) colors.primary else colors.onSurface,
        )
        views.setProgressBar(
            R.id.widget_battery_progress,
            100,
            data.battery.coerceIn(0, 100),
            false,
        )
        views.setTextViewText(
            R.id.widget_storage_value,
            if (data.storageTotal > 0) {
                "${formatBytes(data.storageUsed)} / ${formatBytes(data.storageTotal)}"
            } else {
                context.getString(R.string.widget_no_value)
            },
        )
        val storageProgress = if (data.storageTotal > 0) {
            ((data.storageUsed.toDouble() / data.storageTotal) * 100)
                .toInt()
                .coerceIn(0, 100)
        } else {
            0
        }
        views.setProgressBar(R.id.widget_storage_progress, 100, storageProgress, false)
        views.setTextViewText(
            R.id.widget_apps_value,
            if (data.appCount >= 0) data.appCount.toString() else context.getString(R.string.widget_no_value),
        )
        views.setTextViewText(
            R.id.widget_watchfaces_value,
            if (data.watchfaceCount >= 0) {
                data.watchfaceCount.toString()
            } else {
                context.getString(R.string.widget_no_value)
            },
        )
        views.setTextViewText(R.id.widget_updated, updatedText(context, data.updatedAt))
    }
}

class HealthStatusWidgetProvider : OronBoxWidgetProvider() {
    override fun layoutFor(minWidthDp: Int, minHeightDp: Int): Int = when {
        widgetTier(minWidthDp, minHeightDp) >= 1 -> R.layout.widget_health_status_medium
        else -> R.layout.widget_health_status_small
    }

    override fun pendingIntentRequestCode(): Int = 4202

    override fun render(context: Context, views: RemoteViews) {
        val data = StatusWidgetDataStore.health(context)
        val colors = WidgetColors.resolve(context)
        applyWidgetColors(views, colors, includeDeviceProgress = false)
        views.setTextViewText(R.id.widget_health_steps, valueOrDash(data.steps))
        views.setTextViewText(
            R.id.widget_health_calories,
            valueOrDash(data.activeCalories),
        )
        views.setTextViewText(
            R.id.widget_health_standing,
            if (data.standingHours >= 0) "${data.standingHours}h" else dash(context),
        )
        views.setTextViewText(
            R.id.widget_health_heart_rate,
            if (data.heartRate >= 0) "${data.heartRate} bpm" else dash(context),
        )
        views.setTextViewText(
            R.id.widget_health_blood_oxygen,
            if (data.bloodOxygen >= 0) "${data.bloodOxygen}%" else dash(context),
        )
        views.setTextViewText(
            R.id.widget_health_stress,
            valueOrDash(data.stress),
        )
        views.setTextViewText(
            R.id.widget_health_sleep,
            if (data.sleepDuration >= 0) formatDuration(data.sleepDuration) else dash(context),
        )
        views.setTextViewText(R.id.widget_health_updated, updatedText(context, data.updatedAt))
    }
}

internal object StatusWidgetUpdater {
    fun updateDevice(context: Context) {
        OronBoxWidgetProvider.updateAll(context, DeviceStatusWidgetProvider::class.java)
    }

    fun updateHealth(context: Context) {
        OronBoxWidgetProvider.updateAll(context, HealthStatusWidgetProvider::class.java)
    }
}

private fun valueOrDash(value: Int): String = if (value >= 0) value.toString() else "—"

private fun widgetTier(minWidthDp: Int, minHeightDp: Int): Int {
    // Some launchers omit height during the first update. Keep the old
    // width-based fallback for that one pass, then switch templates when the
    // real bounds arrive through onAppWidgetOptionsChanged.
    val heightKnown = minHeightDp > 0
    if (minWidthDp < COMPACT_WIDTH_DP ||
        (heightKnown && minHeightDp < COMPACT_HEIGHT_DP)
    ) {
        return 0
    }
    return 1
}

private fun applyWidgetColors(
    views: RemoteViews,
    colors: WidgetColors,
    includeDeviceProgress: Boolean,
) {
    val textColors = mapOf(
        R.id.widget_device_name to colors.onSurface,
        R.id.widget_connection_state to colors.primary,
        R.id.widget_battery_value to colors.onSurface,
        R.id.widget_storage_value to colors.onSurface,
        R.id.widget_apps_value to colors.onSurface,
        R.id.widget_watchfaces_value to colors.onSurface,
        R.id.widget_updated to colors.onSurfaceVariant,
        R.id.widget_health_steps to colors.secondary,
        R.id.widget_health_calories to colors.primary,
        R.id.widget_health_standing to colors.tertiary,
        R.id.widget_health_heart_rate to colors.primary,
        R.id.widget_health_blood_oxygen to colors.secondary,
        R.id.widget_health_stress to colors.tertiary,
        R.id.widget_health_sleep to colors.onSurfaceVariant,
        R.id.widget_health_updated to colors.onSurfaceVariant,
    )
    textColors.forEach { (id, color) -> views.setTextColor(id, color) }

    if (android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.S) return
    val surface = ColorStateList.valueOf(colors.surface)
    val variant = ColorStateList.valueOf(colors.surfaceVariant)
    views.setColorStateList(R.id.widget_root, "setBackgroundTintList", surface)
    listOf(
        R.id.widget_battery_card,
        R.id.widget_storage_card,
        R.id.widget_apps_card,
        R.id.widget_watchfaces_card,
        R.id.widget_health_heart_rate_card,
        R.id.widget_health_blood_oxygen_card,
        R.id.widget_health_stress_card,
    ).forEach { id -> views.setColorStateList(id, "setBackgroundTintList", variant) }
    if (includeDeviceProgress) {
        views.setColorStateList(
            R.id.widget_battery_progress,
            "setProgressTintList",
            ColorStateList.valueOf(colors.primary),
        )
        views.setColorStateList(
            R.id.widget_battery_progress,
            "setProgressBackgroundTintList",
            ColorStateList.valueOf(colors.track),
        )
        views.setColorStateList(
            R.id.widget_storage_progress,
            "setProgressTintList",
            ColorStateList.valueOf(colors.secondary),
        )
        views.setColorStateList(
            R.id.widget_storage_progress,
            "setProgressBackgroundTintList",
            ColorStateList.valueOf(colors.track),
        )
    }
}

private fun dash(context: Context): String = context.getString(R.string.widget_no_value)

private fun formatDuration(seconds: Int): String {
    val hours = seconds / 3600
    val minutes = (seconds % 3600) / 60
    return if (hours > 0) "${hours}h ${minutes}m" else "${minutes}m"
}

private fun formatBytes(bytes: Long): String {
    if (bytes < 0) return "—"
    return when {
        bytes >= 1024L * 1024L * 1024L -> String.format(Locale.US, "%.1f GB", bytes / 1073741824.0)
        bytes >= 1024L * 1024L -> String.format(Locale.US, "%.0f MB", bytes / 1048576.0)
        else -> String.format(Locale.US, "%.0f KB", bytes / 1024.0)
    }
}

private fun updatedText(context: Context, timestamp: Long): String {
    if (timestamp <= 0) return context.getString(R.string.widget_not_updated)
    val value = DateFormat.getTimeInstance(DateFormat.SHORT).format(Date(timestamp))
    val stale = System.currentTimeMillis() - timestamp > STALE_AFTER_MS
    return if (stale) {
        context.getString(R.string.widget_updated_stale, value)
    } else {
        context.getString(R.string.widget_updated_at, value)
    }
}

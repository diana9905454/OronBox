package org.zxor.oronbox

/** Single registry for channels shared with Flutter.
 *
 * Keeping names outside MainActivity prevents native feature additions from
 * silently inventing a second channel spelling.
 */
object PlatformChannelNames {
    const val FILE_OPEN = "oronbox/file_open"
    const val WEARABLE_LOG = "oronbox/wearable_log"
    const val FIND_PHONE = "oronbox/find_phone"
    const val XMS_WEARABLE = "oronbox/xms_wearable"
    const val BACKGROUND_TASKS = "oronbox/background_tasks"
    const val STATUS_SURFACES = "oronbox/status_surfaces"
    const val LOGS = "oronbox/logs"
    const val INSTALLER = "oronbox/installer"
    const val CLASSIC_SPP = "oronbox/classic_spp"
    const val CLASSIC_SPP_EVENTS = "oronbox/classic_spp/events"
    const val CLASSIC_SPP_SCAN_EVENTS = "oronbox/classic_spp/scan_events"
    const val MI_ACCOUNT_2FA = "oronbox/mi_account_2fa"
    const val ZEPPOS_APP_SETTINGS = "oronbox/zeppos_app_settings"
    const val XIAOMI_SCREENSHOT = "oronbox/xiaomi_screenshot"
    const val DEVICE_RECORDINGS = "oronbox/device_recordings"
}

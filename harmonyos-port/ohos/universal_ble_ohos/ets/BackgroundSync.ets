// BackgroundSync.ets — 后台定时同步模板
// 鸿蒙对后台管控严格，纯定时轮询会被系统杀掉。
// 做法：用 backgroundTaskManager 申请长时任务（BLUETOOTH_INTERACTION）维持 BLE 连接，
//      配合代理提醒（reminderAgent）做周期唤醒。
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { reminderAgent } from '@kit.NotificationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'OronBox:BgSync';

// 申请长时任务（需在 module.json5 声明 KEEP_BACKGROUND_RUNNING 权限）
export function startBackgroundSync(): void {
  try {
    backgroundTaskManager.startRunningTask({
      abilityName: 'EntryAbility',
      // 蓝牙交互类长时任务
      // @ts-ignore 具体枚举以 SDK 版本为准
      backgroundTaskType: backgroundTaskManager.BackgroundTaskType.BLUETOOTH_INTERACTION,
    } as never);
    hilog.info(0x0000, TAG, 'startRunningTask ok');
  } catch (e) {
    hilog.error(0x0000, TAG, 'startRunningTask failed: %{public}s', JSON.stringify(e));
  }
}

export function stopBackgroundSync(): void {
  try {
    backgroundTaskManager.stopRunningTask('EntryAbility');
    hilog.info(0x0000, TAG, 'stopRunningTask ok');
  } catch (e) {
    hilog.error(0x0000, TAG, 'stopRunningTask failed: %{public}s', JSON.stringify(e));
  }
}

// 注册周期提醒（每 N 分钟唤醒一次做同步）
export function schedulePeriodicSync(minutes: number): void {
  try {
    const reminder: reminderAgent.ReminderRequestTimer = {
      reminderType: reminderAgent.ReminderType.REMINDER_TYPE_TIMER,
      triggerTimeInSeconds: minutes * 60,
      title: 'OronBox 同步',
      content: '正在同步可穿戴设备数据',
      // slotType / notificationId 等字段按 SDK 文档补齐
    } as reminderAgent.ReminderRequestTimer;
    reminderAgent.publishReminder(reminder).then((id) => {
      hilog.info(0x0000, TAG, 'publishReminder id=%{public}d', id);
    });
  } catch (e) {
    hilog.error(0x0000, TAG, 'publishReminder failed: %{public}s', JSON.stringify(e));
  }
}

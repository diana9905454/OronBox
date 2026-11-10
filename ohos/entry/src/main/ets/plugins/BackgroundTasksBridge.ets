import { FlutterEngine, MethodChannel, MethodCall, MethodResult } from '@ohos/flutter_ohos';
import common from '@ohos.app.ability.common';
import backgroundTaskManager from '@ohos.resourceschedule.backgroundTaskManager';
import wantAgent from '@ohos.app.ability.wantAgent';

/** One Bluetooth continuous task shared by the connection and active transfers. */
export class BackgroundTasksBridge {
  private context: common.UIAbilityContext;
  private connectionActive: boolean = false;
  private leases: Set<number> = new Set();
  private nextId: number = 1;
  private running: boolean = false;
  private disposed: boolean = false;
  private tail: Promise<void> = Promise.resolve();

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  register(engine: FlutterEngine): void {
    const channel = new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), 'oronbox/background_tasks');
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        const operation = this.tail.then(() => this.handle(call, result));
        this.tail = operation.catch((error: Error) => {
          console.warn('OronBoxBackgroundTasks: ' + error.message);
          result.error('background_task_failed', error.message, null);
        });
      }
    });
  }

  private async synchronize(): Promise<void> {
    const wanted = !this.disposed && (this.connectionActive || this.leases.size > 0);
    if (wanted === this.running) return;
    if (wanted) {
      const agent = await wantAgent.getWantAgent({
        wants: [{ bundleName: this.context.abilityInfo.bundleName, abilityName: this.context.abilityInfo.name }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG],
      });
      if (this.disposed) return;
      await backgroundTaskManager.startBackgroundRunning(
        this.context, backgroundTaskManager.BackgroundMode.BLUETOOTH_INTERACTION, agent,
      );
      this.running = true;
      if (this.disposed) {
        await backgroundTaskManager.stopBackgroundRunning(this.context);
        this.running = false;
      }
    } else {
      await backgroundTaskManager.stopBackgroundRunning(this.context);
      this.running = false;
    }
  }

  private async handle(call: MethodCall, result: MethodResult): Promise<void> {
    if (this.disposed) {
      result.error('background_task_disposed', 'Ability has been destroyed', null);
      return;
    }
    switch (call.method) {
      case 'beginConnection':
      case 'updateConnection':
        this.connectionActive = true;
        await this.synchronize();
        result.success(null);
        break;
      case 'endConnection':
        this.connectionActive = false;
        await this.synchronize();
        result.success(null);
        break;
      case 'begin': {
        const id = this.nextId++;
        this.leases.add(id);
        try {
          await this.synchronize();
        } catch (error) {
          this.leases.delete(id);
          throw error as Error;
        }
        result.success(id);
        break;
      }
      case 'end':
        this.leases.delete(call.argument('id') as number);
        await this.synchronize();
        result.success(null);
        break;
      default:
        result.notImplemented();
    }
  }

  dispose(): void {
    this.disposed = true;
    this.connectionActive = false;
    this.leases.clear();
    this.tail = this.tail.then(() => this.synchronize()).catch((error: Error) => {
      console.warn('OronBoxBackgroundTasks: cleanup failed: ' + error.message);
    });
  }
}

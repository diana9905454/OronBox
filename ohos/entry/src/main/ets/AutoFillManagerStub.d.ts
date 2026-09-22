// Stub missing autoFillManager types for SDK compatibility
// The flutter_ohos plugin expects APIs from a newer SDK version

declare module '@kit.AbilityKit' {
  namespace autoFillManager {
    export enum AutoFillType {
      UNSPECIFIED = 0,
      NORMAL = 1,
      IME = 2,
    }

    export enum AutoFillTriggerType {
      AUTO_REQUEST = 0,
      MANUAL_REQUEST = 1,
    }

    export interface ViewData {
      pageNodeInfos?: PageNodeInfo[];
      pageRect?: { x: number; y: number; width: number; height: number };
    }

    export interface PageNodeInfo {
      autoFillType: number;
      enableAutoFill: boolean;
      rect: { x: number; y: number; width: number; height: number };
    }

    export interface FillRequest {
      viewData?: ViewData;
      triggerType?: AutoFillTriggerType;
    }

    export interface SaveRequest {
      viewData?: ViewData;
    }

    export type AutoFillCallback = (err: { code: number; message: string }) => void;

    export interface FillFailureResult {
      errCode: number;
      errMessage: string;
    }

    export function requestAutoFill(
      context: object,
      request: FillRequest,
      callback: AutoFillCallback
    ): void;
  }
}

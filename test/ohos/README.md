# 鸿蒙桥接回归检查

需要 Node.js 24+，使用内置 TypeScript 类型擦除能力执行 `.ets` 桥接代码，无额外 npm 依赖。

在仓库根目录运行：

```sh
fvm exec node --input-type=module -e "import { runBridgeTests } from './test/ohos/native_bridge_test.mjs'; const results = await runBridgeTests(); console.log(results.join('\n')); console.log(results.length + ' checks passed');"
```

测试通过模拟系统 API 和故障注入验证分片提交、通道返回类型、字节转换、连接超时和后台任务生命周期。它不检查 ArkTS 特有限制，也不替代 DevEco SDK 编译及真机的蓝牙、锁屏和后台验证。

安全存储会在写入时迁移到 OBV2 清单，读取仍兼容旧的单条值和 OBV1 分片。迁移后的数据不能由只支持 OBV1 的旧客户端读取；回退客户端前应先导出备份。

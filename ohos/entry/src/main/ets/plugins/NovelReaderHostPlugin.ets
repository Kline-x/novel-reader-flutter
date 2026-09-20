// 藏书阁鸿蒙宿主能力插件
//
// 项目里有两个自写 MethodChannel，Android 侧有原生实现，鸿蒙侧一直是空的：
//   com.kline.novelreader/app_update  —— 取版本号、拉起外部链接、安装包
//   com.kline.novelreader/volume_key  —— 音量键翻页
//
// 缺了 app_update 的后果在真机上很直接：getPackageInfo 抛 MissingPluginException，
// VersionCheckService 回退到内置默认值 v1.0.1，于是装着 1.0.9 的机器
// 每次检查更新都被告知"发现新版本 1.0.9"。

import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import bundleManager from '@ohos.bundle.bundleManager';
import { BusinessError } from '@ohos.base';
import AbilityAware from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/ability/AbilityAware';
import {
  AbilityPluginBinding
} from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/ability/AbilityPluginBinding';
import {
  FlutterPlugin,
  FlutterPluginBinding
} from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import MethodChannel, {
  MethodCallHandler,
  MethodResult
} from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import Log from '@ohos/flutter_ohos/src/main/ets/util/Log';

const TAG: string = 'NovelReaderHostPlugin';
const UPDATE_CHANNEL: string = 'com.kline.novelreader/app_update';
const VOLUME_CHANNEL: string = 'com.kline.novelreader/volume_key';

export default class NovelReaderHostPlugin implements FlutterPlugin, AbilityAware,
  MethodCallHandler {
  private updateChannel: MethodChannel | null = null;
  private volumeChannel: MethodChannel | null = null;
  private abilityContext: common.UIAbilityContext | null = null;

  getUniqueClassName(): string {
    return TAG;
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.updateChannel = new MethodChannel(binding.getBinaryMessenger(), UPDATE_CHANNEL);
    this.updateChannel.setMethodCallHandler(this);
    // 音量键通道由宿主主动向 Dart 发消息，这里只建好备用
    this.volumeChannel = new MethodChannel(binding.getBinaryMessenger(), VOLUME_CHANNEL);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.updateChannel?.setMethodCallHandler(null);
    this.updateChannel = null;
    this.volumeChannel = null;
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.abilityContext = binding.getAbility().context;
  }

  onDetachedFromAbility(): void {
    this.abilityContext = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'getPackageInfo':
        this.handleGetPackageInfo(result);
        break;
      case 'openUrl':
        this.handleOpenUrl(call, result);
        break;
      case 'installApk':
        // 鸿蒙不允许侧载：.hap 的 Profile 与设备 UDID 一对一绑定，
        // 而 Release 里的 .apk 在纯血鸿蒙上根本装不了。
        // 返回 false，让 Dart 侧走「前往华为应用市场」那条分支。
        Log.i(TAG, 'installApk is not supported on HarmonyOS, falling back to app market');
        result.success(false);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  /// 返回真实已安装版本，并告知 Dart 侧「你在鸿蒙上」。
  ///
  /// platform 字段是关键：VersionCheckService.isHarmonyOS 一旦为 true，
  /// 更新流程会自动切到应用市场分支，不再去下那个装不上的 APK。
  private handleGetPackageInfo(result: MethodResult): void {
    try {
      const info: bundleManager.BundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
      );
      const payload: Record<string, Object> = {
        'versionCode': info.versionCode,
        'versionName': info.versionName,
        'packageName': info.name,
        'platform': 'ohos',
      };
      Log.i(TAG, `getPackageInfo -> ${info.versionName}+${info.versionCode}`);
      result.success(payload);
    } catch (err) {
      const e = err as BusinessError;
      Log.e(TAG, `getPackageInfo failed: ${e.code} ${e.message}`);
      result.error('GET_PACKAGE_INFO_FAILED', e.message, null);
    }
  }

  /// 拉起外部链接：应用市场 deep link 或普通网页
  private handleOpenUrl(call: MethodCall, result: MethodResult): void {
    const url = call.argument('url') as string;
    if (!url || url.length === 0) {
      result.error('INVALID_ARGUMENT', 'url is empty', null);
      return;
    }
    const context = this.abilityContext;
    if (context === null) {
      result.error('NO_CONTEXT', 'ability context is not ready', null);
      return;
    }
    const want: Want = {
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: url,
    };
    context.startAbility(want).then(() => {
      result.success(true);
    }).catch((err: BusinessError) => {
      Log.e(TAG, `openUrl failed: ${err.code} ${err.message}`);
      result.success(false);
    });
  }

  /// 供宿主在捕获到音量键时通知 Dart 翻页
  notifyVolumeKey(isVolumeDown: boolean): void {
    this.volumeChannel?.invokeMethod(isVolumeDown ? 'volumeDown' : 'volumeUp', null);
  }
}

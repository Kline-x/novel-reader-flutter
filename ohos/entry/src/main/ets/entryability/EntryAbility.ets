import UIAbility from '@ohos.app.ability.UIAbility';
import type window from '@ohos.window';
import hilog from '@ohos.hilog';

/**
 * 藏书阁 (Flutter for OpenHarmony) EntryAbility
 * 负责纯血鸿蒙应用生命周期调度与 Flutter 引擎挂载
 */
export default class EntryAbility extends UIAbility {
  onCreate(): void {
    hilog.info(0x0000, 'NovelReader', 'EntryAbility onCreate');
  }

  onDestroy(): void {
    hilog.info(0x0000, 'NovelReader', 'EntryAbility onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, 'NovelReader', 'EntryAbility onWindowStageCreate');
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'NovelReader', `Failed to load the content. Cause: ${JSON.stringify(err)}`);
        return;
      }
      hilog.info(0x0000, 'NovelReader', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(0x0000, 'NovelReader', 'EntryAbility onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(0x0000, 'NovelReader', 'EntryAbility onForeground');
  }

  onBackground(): void {
    hilog.info(0x0000, 'NovelReader', 'EntryAbility onBackground');
  }
}

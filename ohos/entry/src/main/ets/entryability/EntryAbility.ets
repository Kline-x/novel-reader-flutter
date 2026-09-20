import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import NovelReaderHostPlugin from '../plugins/NovelReaderHostPlugin';

export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    // pub 上的插件（path_provider / shared_preferences / flutter_tts）由工具生成注册
    GeneratedPluginRegistrant.registerWith(flutterEngine)
    // 本项目自写的宿主能力通道。GeneratedPluginRegistrant 每次 pub get 都会重写，
    // 不能把它加在那里，必须在这里单独注册。
    flutterEngine.getPlugins()?.add(new NovelReaderHostPlugin())
  }
}

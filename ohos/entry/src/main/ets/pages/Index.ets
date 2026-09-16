/**
 * 藏书阁 鸿蒙入口页面
 * 挂载 Flutter Native 渲染视图
 */
@Entry
@Component
struct Index {
  build() {
    Column() {
      // 在 OpenHarmony-TPC Flutter SDK 下映射为 FlutterView
      Text('藏书阁 · 鸿蒙原生运行环境')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor('#2C2825')
        .margin({ top: 40 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FBF9F5')
  }
}

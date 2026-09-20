import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let pickerChannelName = "com.kline.novelreader/file_picker"
  private static let updateChannelName = "com.kline.novelreader/app_update"

  /// 文件选择是异步的，结果要等到 delegate 回调才有
  private var pendingPickResult: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerFilePickerChannel(engineBridge)
    registerUpdateChannel(engineBridge)
  }

  /// 宿主信息通道。
  ///
  /// 此前 iOS 侧完全没有实现，`getPackageInfo` 抛 MissingPluginException，
  /// VersionCheckService 只能回退到内置默认值 v1.0.1——和鸿蒙补通道之前
  /// 一模一样的毛病：装着新版的机器每次检查更新都被告知「发现新版本」。
  private func registerUpdateChannel(_ engineBridge: FlutterImplicitEngineBridge) {
    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "NovelReaderAppUpdate"
    ) else { return }

    let channel = FlutterMethodChannel(
      name: AppDelegate.updateChannelName,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getPackageInfo":
        let info = Bundle.main.infoDictionary
        let name = info?["CFBundleShortVersionString"] as? String ?? ""
        // CFBundleVersion 在 iOS 上是字符串，Dart 侧要的是 int
        let build = Int(info?["CFBundleVersion"] as? String ?? "") ?? 0
        result([
          "versionCode": build,
          "versionName": name,
          "packageName": Bundle.main.bundleIdentifier ?? "",
        ])
      case "openUrl":
        guard
          let args = call.arguments as? [String: Any],
          let urlString = args["url"] as? String,
          let url = URL(string: urlString)
        else {
          result(FlutterError(code: "INVALID_URL", message: "url is invalid", details: nil))
          return
        }
        UIApplication.shared.open(url, options: [:]) { ok in result(ok) }
      case "installApk":
        // iOS 不存在侧载安装，更新一律走 App Store
        result(false)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func registerFilePickerChannel(_ engineBridge: FlutterImplicitEngineBridge) {
    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "NovelReaderFilePicker"
    ) else { return }

    let channel = FlutterMethodChannel(
      name: AppDelegate.pickerChannelName,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "pickBookFile" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.presentBookPicker(result)
    }
  }

  /// 拉起系统文件选择器挑一本书。
  ///
  /// 选中的 URL 是安全作用域资源，不能直接交给解析引擎；
  /// 这里复制进 Documents/imported 再把落地路径回给 Dart，
  /// 与 Android / 鸿蒙两侧的行为保持一致。
  private func presentBookPicker(_ result: @escaping FlutterResult) {
    if pendingPickResult != nil {
      result(FlutterError(code: "BUSY", message: "another pick is in progress", details: nil))
      return
    }
    guard let root = window?.rootViewController else {
      result(FlutterError(code: "NO_ROOT_VC", message: "root view controller is nil", details: nil))
      return
    }

    let picker: UIDocumentPickerViewController
    if #available(iOS 14.0, *) {
      var types: [UTType] = [.plainText]
      if let epub = UTType(filenameExtension: "epub") {
        types.append(epub)
      }
      picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
    } else {
      picker = UIDocumentPickerViewController(
        documentTypes: ["public.plain-text", "org.idpf.epub-container"],
        in: .import
      )
    }
    picker.allowsMultipleSelection = false
    picker.delegate = self

    pendingPickResult = result
    root.present(picker, animated: true)
  }

  private func copyIntoDocuments(_ url: URL) throws -> String {
    let fm = FileManager.default
    let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let dir = docs.appendingPathComponent("imported", isDirectory: true)
    if !fm.fileExists(atPath: dir.path) {
      try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    let dest = dir.appendingPathComponent(url.lastPathComponent)
    if fm.fileExists(atPath: dest.path) {
      try fm.removeItem(at: dest)
    }

    // asCopy / .import 模式下系统已给了副本，但仍可能是安全作用域 URL
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    try fm.copyItem(at: url, to: dest)

    return dest.path
  }
}

extension AppDelegate: UIDocumentPickerDelegate {
  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    let result = pendingPickResult
    pendingPickResult = nil
    guard let url = urls.first else {
      result?(nil)
      return
    }
    do {
      result?(try copyIntoDocuments(url))
    } catch {
      result?(FlutterError(code: "COPY_FAILED", message: error.localizedDescription, details: nil))
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    // 用户取消，返回 nil 让 Dart 侧安静地什么都不做
    let result = pendingPickResult
    pendingPickResult = nil
    result?(nil)
  }
}

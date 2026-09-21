import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let pickerChannelName = "com.kline.novelreader/file_picker"
  private static let updateChannelName = "com.kline.novelreader/app_update"

  /// 文件选择是异步的，结果要等到 delegate 回调才有
  private var pendingPickResult: FlutterResult?

  /// 导出备份走的是同一套 delegate，用这个区分「这次是选文件还是存文件」
  private var pendingSaveResult: FlutterResult?

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
      let args = call.arguments as? [String: Any]
      switch call.method {
      case "pickBookFile":
        self?.presentBookPicker(result, extensions: args?["extensions"] as? [String])
      case "saveFile":
        guard
          let fileName = args?["fileName"] as? String,
          let sourcePath = args?["sourcePath"] as? String
        else {
          result(FlutterError(
            code: "INVALID_ARGUMENT",
            message: "fileName and sourcePath are required",
            details: nil
          ))
          return
        }
        self?.presentSavePicker(result, fileName: fileName, sourcePath: sourcePath)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// 拉起系统文件选择器挑一本书。
  ///
  /// 选中的 URL 是安全作用域资源，不能直接交给解析引擎；
  /// 这里复制进 Documents/imported 再把落地路径回给 Dart，
  /// 与 Android / 鸿蒙两侧的行为保持一致。
  private func presentBookPicker(_ result: @escaping FlutterResult, extensions: [String]?) {
    if pendingPickResult != nil || pendingSaveResult != nil {
      result(FlutterError(code: "BUSY", message: "another pick is in progress", details: nil))
      return
    }
    guard let root = window?.rootViewController else {
      result(FlutterError(code: "NO_ROOT_VC", message: "root view controller is nil", details: nil))
      return
    }

    // 不传扩展名时沿用原来的图书默认值
    let exts = extensions ?? ["txt", "epub"]
    let picker: UIDocumentPickerViewController
    if #available(iOS 14.0, *) {
      var types: [UTType] = []
      for ext in exts {
        let clean = ext.hasPrefix(".") ? String(ext.dropFirst()) : ext
        switch clean.lowercased() {
        case "txt": types.append(.plainText)
        case "zip": types.append(.zip)
        case "json": types.append(.json)
        default:
          if let t = UTType(filenameExtension: clean) { types.append(t) }
        }
      }
      if types.isEmpty { types = [.data] }
      picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
    } else {
      var types: [String] = []
      for ext in exts {
        switch ext.replacingOccurrences(of: ".", with: "").lowercased() {
        case "txt": types.append("public.plain-text")
        case "epub": types.append("org.idpf.epub-container")
        case "zip": types.append("public.zip-archive")
        default: types.append("public.data")
        }
      }
      picker = UIDocumentPickerViewController(documentTypes: types, in: .import)
    }
    picker.allowsMultipleSelection = false
    picker.delegate = self

    pendingPickResult = result
    root.present(picker, animated: true)
  }

  /// 让用户选一个落地位置，把 [sourcePath] 的文件导出过去。
  ///
  /// iOS 应用写不到沙箱外，只能把文件交给系统的导出选择器，
  /// 由用户决定放进「文件」App 的哪个位置——和 Android 的
  /// ACTION_CREATE_DOCUMENT、鸿蒙的 DocumentSaveOptions 是同一套思路。
  private func presentSavePicker(
    _ result: @escaping FlutterResult,
    fileName: String,
    sourcePath: String
  ) {
    if pendingPickResult != nil || pendingSaveResult != nil {
      result(FlutterError(code: "BUSY", message: "another save is in progress", details: nil))
      return
    }
    guard let root = window?.rootViewController else {
      result(FlutterError(code: "NO_ROOT_VC", message: "root view controller is nil", details: nil))
      return
    }

    // 导出选择器用的是源文件的文件名，所以先在临时目录按目标名做一份副本
    let fm = FileManager.default
    let staged = fm.temporaryDirectory.appendingPathComponent(fileName)
    do {
      if fm.fileExists(atPath: staged.path) {
        try fm.removeItem(at: staged)
      }
      try fm.copyItem(at: URL(fileURLWithPath: sourcePath), to: staged)
    } catch {
      result(FlutterError(code: "SAVE_FAILED", message: error.localizedDescription, details: nil))
      return
    }

    let picker: UIDocumentPickerViewController
    if #available(iOS 14.0, *) {
      picker = UIDocumentPickerViewController(forExporting: [staged], asCopy: true)
    } else {
      picker = UIDocumentPickerViewController(url: staged, in: .exportToService)
    }
    picker.delegate = self

    pendingSaveResult = result
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
    // 导出选择器完成时走的也是这个回调，此时不该再去复制文件
    if let saveResult = pendingSaveResult {
      pendingSaveResult = nil
      saveResult(urls.first?.lastPathComponent ?? "")
      return
    }

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
    if let saveResult = pendingSaveResult {
      pendingSaveResult = nil
      saveResult(nil)
      return
    }
    let result = pendingPickResult
    pendingPickResult = nil
    result?(nil)
  }
}

import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let pickerChannelName = "com.kline.novelreader/file_picker"

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

import Flutter
import Vision

/// Riconoscimento testo su iOS con Apple Vision al posto di ML Kit,
/// che non ha slice arm64 per il simulatore.
final class VisionTextRecognizer: NSObject, FlutterPlugin {
  private let queue = DispatchQueue(label: "farma_auth.vision_text", qos: .userInitiated)

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "farma_auth/vision_text",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(VisionTextRecognizer(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "processImage" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard
      let args = call.arguments as? [String: Any],
      let bytes = args["bytes"] as? FlutterStandardTypedData,
      let width = args["width"] as? Int,
      let height = args["height"] as? Int,
      let bytesPerRow = args["bytesPerRow"] as? Int,
      let rotation = args["rotation"] as? Int
    else {
      result(FlutterError(code: "InvalidArguments", message: "Parametri immagine mancanti", details: nil))
      return
    }

    queue.async {
      let reply: Any
      do {
        let image = try Self.makeImage(bytes.data, width: width, height: height, bytesPerRow: bytesPerRow)
        reply = try Self.recognizeText(in: image, orientation: Self.orientation(forRotation: rotation))
      } catch {
        reply = FlutterError(code: "VisionError", message: error.localizedDescription, details: nil)
      }
      DispatchQueue.main.async { result(reply) }
    }
  }

  /// Converte un frame BGRA8888 della fotocamera in CGImage.
  private static func makeImage(_ data: Data, width: Int, height: Int, bytesPerRow: Int) throws -> CGImage {
    guard
      data.count >= bytesPerRow * height,
      let provider = CGDataProvider(data: data as CFData),
      let image = CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
      )
    else {
      throw NSError(domain: "VisionTextRecognizer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Frame BGRA non valido"])
    }
    return image
  }

  /// Stessa convenzione di InputImageRotation: gradi di rotazione oraria per raddrizzare il frame.
  private static func orientation(forRotation degrees: Int) -> CGImagePropertyOrientation {
    switch degrees {
    case 90: return .right
    case 180: return .down
    case 270: return .left
    default: return .up
    }
  }

  private static func recognizeText(in image: CGImage, orientation: CGImagePropertyOrientation) throws -> String {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    // I codici sono numerici: la correzione linguistica tende a "correggerli" in parole.
    request.usesLanguageCorrection = false
    try VNImageRequestHandler(cgImage: image, orientation: orientation).perform([request])
    let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    return lines.joined(separator: "\n")
  }
}

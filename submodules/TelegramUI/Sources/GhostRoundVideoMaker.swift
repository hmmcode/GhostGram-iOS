import Foundation
import AVFoundation
import CoreGraphics
import ImageIO

/// Turns any video, GIF or still picture into a square H.264 clip that Telegram accepts as a round video message.
/// Uses only AVFoundation and CoreGraphics, so it can be tested on macOS too.
enum GhostRoundVideoMaker {
    static let side = 384
    static let maxSeconds = 60.0

    enum Failure: Error {
        case noVideoTrack
        case exportFailed(String)
        case writerFailed(String)
        case badImage
    }

    struct Result {
        let url: URL
        let duration: Double
        let thumbnail: CGImage?
    }

    private static func tempURL() -> URL {
        return FileManager.default.temporaryDirectory.appendingPathComponent("ghost-round-\(UInt64.random(in: 1 ... UInt64.max)).mp4")
    }

    // MARK: Video

    static func fromVideo(_ source: URL, completion: @escaping (Swift.Result<Result, Error>) -> Void) {
        let asset = AVURLAsset(url: source)
        guard let track = asset.tracks(withMediaType: .video).first else {
            completion(.failure(Failure.noVideoTrack))
            return
        }
        let natural = track.naturalSize.applying(track.preferredTransform)
        let width = abs(natural.width)
        let height = abs(natural.height)
        if width < 1 || height < 1 {
            completion(.failure(Failure.noVideoTrack))
            return
        }
        let target = CGFloat(side)
        let scale = target / min(width, height)

        // preferredTransform can move the picture to negative coordinates; bring it back to the origin first.
        let oriented = CGRect(origin: .zero, size: track.naturalSize).applying(track.preferredTransform)
        var transform = track.preferredTransform.concatenating(CGAffineTransform(translationX: -oriented.minX, y: -oriented.minY))
        transform = transform.concatenating(CGAffineTransform(scaleX: scale, y: scale))
        transform = transform.concatenating(CGAffineTransform(translationX: (target - width * scale) / 2.0, y: (target - height * scale) / 2.0))

        let duration = min(CMTimeGetSeconds(asset.duration), maxSeconds)
        let range = CMTimeRange(start: .zero, duration: CMTime(seconds: max(duration, 0.1), preferredTimescale: 600))

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = range
        let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        layer.setTransform(transform, at: .zero)
        instruction.layerInstructions = [layer]

        let composition = AVMutableVideoComposition()
        composition.renderSize = CGSize(width: target, height: target)
        let fps = track.nominalFrameRate > 0 ? min(track.nominalFrameRate, 30) : 30
        composition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps.rounded()))
        composition.instructions = [instruction]

        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) else {
            completion(.failure(Failure.exportFailed("no session")))
            return
        }
        let output = tempURL()
        export.outputURL = output
        export.outputFileType = .mp4
        export.shouldOptimizeForNetworkUse = true
        export.videoComposition = composition
        export.timeRange = range
        export.exportAsynchronously {
            if export.status == .completed {
                completion(.success(Result(url: output, duration: duration, thumbnail: firstFrame(of: output))))
            } else {
                completion(.failure(Failure.exportFailed(export.error?.localizedDescription ?? "status \(export.status.rawValue)")))
            }
        }
    }

    // MARK: Pictures and GIFs

    /// A still picture shown for `seconds`.
    static func fromImage(_ image: CGImage, seconds: Double, completion: @escaping (Swift.Result<Result, Error>) -> Void) {
        let length = max(1.0, min(seconds, maxSeconds))
        write(frames: [(image, length)], completion: completion)
    }

    /// An animated GIF (or any multi-frame image), looped until it lasts at least `minSeconds`.
    static func fromAnimatedImage(_ data: Data, minSeconds: Double, completion: @escaping (Swift.Result<Result, Error>) -> Void) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            completion(.failure(Failure.badImage))
            return
        }
        let count = CGImageSourceGetCount(source)
        var frames: [(CGImage, Double)] = []
        for index in 0 ..< count {
            guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else {
                continue
            }
            frames.append((image, frameDelay(source, index)))
        }
        if frames.isEmpty {
            completion(.failure(Failure.badImage))
            return
        }
        if frames.count == 1 {
            fromImage(frames[0].0, seconds: minSeconds, completion: completion)
            return
        }
        let once = frames.reduce(0.0) { $0 + $1.1 }
        var looped = frames
        var total = once
        while total < minSeconds && total + once <= maxSeconds {
            looped.append(contentsOf: frames)
            total += once
        }
        write(frames: looped, completion: completion)
    }

    private static func frameDelay(_ source: CGImageSource, _ index: Int) -> Double {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any] else {
            return 0.1
        }
        let containers: [CFString] = [kCGImagePropertyGIFDictionary, kCGImagePropertyPNGDictionary, kCGImagePropertyHEICSDictionary]
        let keys: [CFString] = [kCGImagePropertyGIFUnclampedDelayTime, kCGImagePropertyGIFDelayTime, kCGImagePropertyAPNGUnclampedDelayTime, kCGImagePropertyAPNGDelayTime, kCGImagePropertyHEICSUnclampedDelayTime, kCGImagePropertyHEICSDelayTime]
        for container in containers {
            guard let dictionary = properties[container] as? [CFString: Any] else {
                continue
            }
            for key in keys {
                if let value = (dictionary[key] as? NSNumber)?.doubleValue, value > 0.011 {
                    return value
                }
            }
        }
        return 0.1
    }

    private static func write(frames: [(CGImage, Double)], completion: @escaping (Swift.Result<Result, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let output = tempURL()
                let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
                let settings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: side,
                    AVVideoHeightKey: side,
                    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 1_000_000]
                ]
                let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
                input.expectsMediaDataInRealTime = false
                let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: side,
                    kCVPixelBufferHeightKey as String: side
                ])
                guard writer.canAdd(input) else {
                    throw Failure.writerFailed("cannot add input")
                }
                writer.add(input)
                guard writer.startWriting() else {
                    throw Failure.writerFailed(writer.error?.localizedDescription ?? "start")
                }
                writer.startSession(atSourceTime: .zero)

                var time = 0.0
                var lastBuffer: CVPixelBuffer?
                var cache: [ObjectIdentifier: CVPixelBuffer] = [:]
                for (image, delay) in frames {
                    let key = ObjectIdentifier(image)
                    let buffer: CVPixelBuffer
                    if let cached = cache[key] {
                        buffer = cached
                    } else {
                        guard let made = pixelBuffer(image, pool: adaptor.pixelBufferPool) else {
                            throw Failure.badImage
                        }
                        buffer = made
                        if cache.count < 400 {
                            cache[key] = made
                        }
                    }
                    try append(buffer, at: time, input: input, adaptor: adaptor)
                    lastBuffer = buffer
                    time += delay
                    if time >= maxSeconds {
                        time = maxSeconds
                        break
                    }
                }
                // Repeat the last frame at the very end so the clip lasts the full time.
                if let lastBuffer = lastBuffer {
                    try append(lastBuffer, at: max(time - 0.04, 0.04), input: input, adaptor: adaptor)
                }
                input.markAsFinished()
                writer.endSession(atSourceTime: CMTime(seconds: time, preferredTimescale: 600))
                let finished = DispatchSemaphore(value: 0)
                writer.finishWriting {
                    finished.signal()
                }
                finished.wait()
                if writer.status != .completed {
                    throw Failure.writerFailed(writer.error?.localizedDescription ?? "status \(writer.status.rawValue)")
                }
                completion(.success(Result(url: output, duration: time, thumbnail: frames.first.map { square($0.0) } ?? nil)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private static func append(_ buffer: CVPixelBuffer, at seconds: Double, input: AVAssetWriterInput, adaptor: AVAssetWriterInputPixelBufferAdaptor) throws {
        while !input.isReadyForMoreMediaData {
            Thread.sleep(forTimeInterval: 0.005)
        }
        if !adaptor.append(buffer, withPresentationTime: CMTime(seconds: seconds, preferredTimescale: 600)) {
            throw Failure.writerFailed("append at \(seconds)")
        }
    }

    /// Draws the picture centred and cropped to fill the square.
    private static func draw(_ image: CGImage, in context: CGContext) {
        let target = CGFloat(side)
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let scale = max(target / width, target / height)
        let rect = CGRect(x: (target - width * scale) / 2.0, y: (target - height * scale) / 2.0, width: width * scale, height: height * scale)
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: target, height: target))
        context.interpolationQuality = .high
        context.draw(image, in: rect)
    }

    private static func pixelBuffer(_ image: CGImage, pool: CVPixelBufferPool?) -> CVPixelBuffer? {
        var created: CVPixelBuffer?
        if let pool = pool {
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &created)
        }
        if created == nil {
            CVPixelBufferCreate(nil, side, side, kCVPixelFormatType_32BGRA, [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary, &created)
        }
        guard let buffer = created else {
            return nil
        }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer {
            CVPixelBufferUnlockBaseAddress(buffer, [])
        }
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: side, height: side, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
            return nil
        }
        draw(image, in: context)
        return buffer
    }

    private static func square(_ image: CGImage) -> CGImage? {
        guard let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
            return nil
        }
        draw(image, in: context)
        return context.makeImage()
    }

    static func firstFrame(of url: URL) -> CGImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        return try? generator.copyCGImage(at: .zero, actualTime: nil)
    }

    /// JPEG bytes for the message preview.
    static func jpeg(_ image: CGImage, quality: Double = 0.6) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}

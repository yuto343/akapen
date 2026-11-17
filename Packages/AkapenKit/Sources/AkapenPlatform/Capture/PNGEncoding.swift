import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// `CGImage` を PNG のバイト列にする。
enum PNGEncoding {
    /// 書き出しに失敗したときのエラー。
    struct EncodingError: Error {}

    static func encode(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw EncodingError()
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw EncodingError()
        }
        return data as Data
    }
}

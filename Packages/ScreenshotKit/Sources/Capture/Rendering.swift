//
//  Rendering.swift
//  Low-level image rendering
//

import AppKit
import SwiftUI

@MainActor
func renderAndSave<E>(screenshot: Screenshot<E>, env: E, to path: URL) throws {
    let view = screenshot.view(env)
    let image = try renderImage(from: view, size: screenshot.size, name: screenshot.name)
    let data = try convertToPNG(image, name: screenshot.name)
    try data.write(to: path)
}

@MainActor
private func renderImage<V: View>(from view: V, size: CGSize, name: String) throws -> NSImage {
    let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
    renderer.scale = Config.renderScale
    guard let image = renderer.nsImage else {
        throw CaptureError.renderFailed(name)
    }
    return image
}

private func convertToPNG(_ image: NSImage, name: String) throws -> Data {
    guard let data = image.pngData else {
        throw CaptureError.pngConversionFailed(name)
    }
    return data
}

private extension NSImage {
    var pngData: Data? {
        tiffRepresentation
            .flatMap { NSBitmapImageRep(data: $0) }
            .flatMap { $0.representation(using: .png, properties: [:]) }
    }
}

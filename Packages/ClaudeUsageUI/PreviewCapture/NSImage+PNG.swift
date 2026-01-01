//
//  NSImage+PNG.swift
//  PNG conversion extension for NSImage
//

import AppKit

extension NSImage {
    var pngData: Data? {
        tiffRepresentation
            .flatMap { NSBitmapImageRep(data: $0) }
            .flatMap { $0.representation(using: .png, properties: [:]) }
    }
}

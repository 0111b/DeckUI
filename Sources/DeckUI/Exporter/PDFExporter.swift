//
//  PDFExporter.swift
//  DeckUI
//
//  Created by Alexandr Goncharov on 13.09.2022.
//

import SwiftUI

import Quartz

//@available(iOS 16.0, macOS 13.0, *)
//struct SwiftUISlideRenderer {
//    @MainActor func render(in context: CGContext, slide: Slide, theme: Theme, pageSize: CGSize) {
//        let rootView = slide.buildView(theme: theme)
//            .frame(width: pageSize.width, height: pageSize.height)
//        let imageRenderer = ImageRenderer(content: rootView)
//        imageRenderer.render { _, renderer in
//            renderer(context)
//        }
//    }
//}


#if canImport(AppKit)
typealias PlatformSlideRenderer = AppKitSlideRenderer

import AppKit
struct AppKitSlideRenderer {
    @MainActor
    func render(in context: CGContext, slide: Slide, theme: Theme, pageSize: CGSize) {
        //        let pdfDocument = PDFDocument()
        //        pdfDocument.insert(<#T##page: PDFPage##PDFPage#>, at: <#T##Int#>)
        //            controller.view.dataWithPDF(inside: controller.view.frame)

        let rootView = slide.buildView(theme: theme)
        let controller = PlatformHostingController(rootView: rootView)
        let renderView = controller.view
//        let renderView = NSHostingView(rootView: rootView)
        renderView.translatesAutoresizingMaskIntoConstraints = false
        let rect = CGRect(origin: .zero, size: pageSize)
        renderView.frame = rect
//        print(renderView.dataWithPDF(inside: rect))
        let bitmapImageRep = renderView.bitmapImageRepForCachingDisplay(in: rect)!
        bitmapImageRep.size = rect.size
        renderView.cacheDisplay(in: rect, to: bitmapImageRep)
        let image = PlatformImage(size: rect.size)
        image.addRepresentation(bitmapImageRep)
        let previousContext = NSGraphicsContext.current
        defer { NSGraphicsContext.current = previousContext }
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        image.draw(in: rect)
    }
}
#endif

#if canImport(UIKit)
typealias PlatformSlideRenderer = UIKitSlideRenderer

import UIKit
struct UIKitSlideRenderer {
    @MainActor
    func render(in context: CGContext, slide: Slide, theme: Theme, pageSize: CGSize) {
        let rootView = slide.buildView(theme: theme)
        let controller = PlatformHostingController(rootView: rootView)
        let renderView: UIView = controller.view

//        let renderView = UILabel()
//        renderView.text = "Hello word"

        renderView.translatesAutoresizingMaskIntoConstraints = false
        let rect = CGRect(origin: .zero, size: pageSize)
        renderView.frame = rect
        NSLayoutConstraint.activate([

        ])
        renderView.layoutIfNeeded()
        let renderer = UIGraphicsImageRenderer(size: pageSize)
        let image = renderer.image { imageContext in
//            _ = renderView.drawHierarchy(in: rect, afterScreenUpdates: true)
            renderView.layer.draw(in: imageContext.cgContext)
        }
        UIGraphicsPushContext(context)
        defer { UIGraphicsPopContext() }
        image.draw(in: rect)
    }
}
#endif

final class PDFExporter: Exporter {
    typealias SlideRenderer = @MainActor (
        _ renderContext: CGContext,
        _ slide: Slide,
        _ theme: Theme,
        _ pageSize: CGSize
    ) -> Void

    init() {
//        if #available(iOS 16, macOS 13, *) {
//            slideRenderer = SwiftUISlideRenderer().render(in:slide:theme:pageSize:)
//        } else {
            slideRenderer = PlatformSlideRenderer().render(in:slide:theme:pageSize:)
//        }
    }

    let slideRenderer: SlideRenderer

    @MainActor
    func export(deck: Deck) async throws {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("Deck.pdf") else  { return }
        try? FileManager.default.removeItem(at: url)
        dump(url.absoluteString)

        let pageSize = CGSize(width: 1920, height: 1080)
        var mediabox = CGRect(origin: .zero, size: pageSize)

        guard let consumer = CGDataConsumer(url: url as CFURL),
              let pdfContext = CGContext(
                consumer: consumer,
                mediaBox: &mediabox,
                [ kCGPDFContextTitle: deck.title ] as CFDictionary
              ) else {
            dump("error")
            return
        }
        defer { pdfContext.closePDF() }

        deck.slides().forEach { slide in
            pdfContext.beginPDFPage(nil)
            slideRenderer(pdfContext, slide, deck.theme, pageSize)
            pdfContext.endPDFPage()
        }
    }
}

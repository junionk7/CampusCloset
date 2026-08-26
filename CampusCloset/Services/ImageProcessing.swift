//
//  ImageProcessing.swift
//  CampusCloset
//
//  Downscaling for everything that gets uploaded.
//
//  A photo out of PhotosPicker is the original camera file — 12 to 24
//  megapixels, several megabytes. Uploading that and then handing it to a 120pt
//  grid tile is what drove Supabase's cached egress through the free plan's
//  monthly allowance. Supabase can resize images server-side, but only on the
//  Pro plan, so the work happens here instead: every upload is capped, and every
//  listing photo also gets a small thumbnail for the browsing surfaces.
//

import UIKit

enum ImageProcessing {

    /// Long edge of the image shown full-screen in ListingDetailView.
    static let fullSizeMaxEdge: CGFloat = 1400

    /// Long edge of the image shown in the feed, search rows and profile grids.
    /// 400px covers a 180pt card on a 3x screen without being wasteful.
    static let thumbnailMaxEdge: CGFloat = 400

    /// Long edge for profile photos. They are never shown larger than 90pt.
    static let avatarMaxEdge: CGFloat = 300

    static let fullSizeQuality: CGFloat = 0.65
    static let thumbnailQuality: CGFloat = 0.6

    /// Scales an image down so its longest edge is at most `maxEdge`, preserving
    /// aspect ratio. Images already smaller than that are returned untouched —
    /// scaling up would cost bytes and add nothing.
    static func downscaled(_ image: UIImage, maxEdge: CGFloat) -> UIImage {
        let longestEdge = max(image.size.width, image.size.height)
        guard longestEdge > maxEdge, longestEdge > 0 else { return image }

        let scale = maxEdge / longestEdge
        let targetSize = CGSize(
            width: (image.size.width * scale).rounded(),
            height: (image.size.height * scale).rounded()
        )

        // scale: 1 keeps the output in pixels rather than points, so the result
        // really is targetSize pixels regardless of the device's screen scale.
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    /// Downscales and JPEG-encodes in one step — what the upload paths call.
    static func jpegData(from image: UIImage, maxEdge: CGFloat, quality: CGFloat) -> Data? {
        downscaled(image, maxEdge: maxEdge).jpegData(compressionQuality: quality)
    }

    /// The pair of encodings a listing photo needs: one to view, one to browse.
    static func listingVariants(from image: UIImage) -> (full: Data, thumbnail: Data)? {
        guard let full = jpegData(from: image,
                                  maxEdge: fullSizeMaxEdge,
                                  quality: fullSizeQuality),
              let thumbnail = jpegData(from: image,
                                       maxEdge: thumbnailMaxEdge,
                                       quality: thumbnailQuality)
        else { return nil }
        return (full, thumbnail)
    }
}

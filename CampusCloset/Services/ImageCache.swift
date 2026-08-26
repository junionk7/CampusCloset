//
//  ImageCache.swift
//  CampusCloset
//
//  Makes AsyncImage stop re-downloading photos it already has.
//
//  SwiftUI's AsyncImage loads through URLSession.shared, which caches into
//  URLCache.shared. The default shared cache is tiny — roughly 512 KB in memory
//  and 10 MB on disk — and URLCache refuses to store any single response larger
//  than about 5% of its capacity. A 2 MB listing photo therefore missed the
//  cache every single time: scrolling the feed, opening a listing and coming
//  back all re-downloaded the same bytes, and every one of those downloads was
//  billed as Supabase cached egress.
//
//  Giving the shared cache a realistic size fixes that for every AsyncImage in
//  the app at once, with no change at the call sites. It works together with the
//  one-year Cache-Control header set on upload: the header says the bytes stay
//  valid, and this gives them somewhere to live.
//

import Foundation

enum ImageCache {

    /// Comfortably holds a few hundred thumbnails plus the full-size photos of
    /// recently opened listings. The OS evicts this on disk pressure, so it is a
    /// ceiling rather than a reservation.
    private static let memoryCapacity = 64 * 1024 * 1024      // 64 MB
    private static let diskCapacity = 256 * 1024 * 1024       // 256 MB

    /// Call once, as early as possible — before any image request is issued.
    ///
    /// Replacing `URLCache.shared` is the whole fix: `URLSession.shared` reads
    /// its cache from there. (Assigning to `URLSession.shared.configuration`
    /// would do nothing — that property hands back a copy.)
    static func configure() {
        URLCache.shared = URLCache(
            memoryCapacity: memoryCapacity,
            diskCapacity: diskCapacity,
            directory: nil          // the default Caches directory is right here
        )
    }
}

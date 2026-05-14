//
//  NotificationsViewModel.swift
//  CampusCloset
//
//  Created by Jun Kuang on 5/14/26.
//

import Foundation
import SwiftUI
import Combine
import Supabase

struct AppNotification: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let type: String
    let title: String
    var body: String
    var isRead: Bool
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, type, title, body
        case userId = "user_id"
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}

@MainActor
class NotificationsViewModel: ObservableObject {
    @Published var notifications: [AppNotification] = []

    var unreadCount: Int { notifications.filter { !$0.isRead }.count }

    func fetchNotifications() async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        do {
            let fetched: [AppNotification] = try await supabase
                .from("notifications")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value
            self.notifications = fetched
        } catch {
            print("❌ Error fetching notifications: \(error)")
        }
    }

    func markAsRead(_ id: UUID) async {
        do {
            try await supabase
                .from("notifications")
                .update(["is_read": true])
                .eq("id", value: id)
                .execute()
            if let index = notifications.firstIndex(where: { $0.id == id }) {
                var updated = notifications[index]
                updated.isRead = true
                notifications[index] = updated
            }
        } catch {
            print("❌ Error marking notification as read: \(error)")
        }
    }

    func markAllAsRead() async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        do {
            try await supabase
                .from("notifications")
                .update(["is_read": true])
                .eq("user_id", value: userId)
                .execute()
            notifications = notifications.map {
                var n = $0; n.isRead = true; return n
            }
        } catch {
            print("❌ Error marking all notifications as read: \(error)")
        }
    }
}

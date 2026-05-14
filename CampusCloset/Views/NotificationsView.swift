//
//  NotificationsView.swift
//  CampusCloset
//
//  Created by Jun Kuang on 5/14/26.
//

import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject var notificationsVM: NotificationsViewModel

    var body: some View {
        NavigationStack {
            Group {
                if notificationsVM.notifications.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No notifications yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("You'll see updates here when you send\nor receive messages about listings.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(notificationsVM.notifications) { notification in
                            NotificationRow(notification: notification)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if !notification.isRead {
                                        Task { await notificationsVM.markAsRead(notification.id) }
                                    }
                                }
                                .listRowSeparator(.hidden)
                                .listRowBackground(
                                    notification.isRead ? Color.clear : Color.blue.opacity(0.04)
                                )
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Notifications")
            .toolbar {
                if notificationsVM.unreadCount > 0 {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Mark All Read") {
                            Task { await notificationsVM.markAllAsRead() }
                        }
                        .font(.subheadline)
                    }
                }
            }
            .task {
                await notificationsVM.fetchNotifications()
            }
        }
    }
}

struct NotificationRow: View {
    let notification: AppNotification

    var iconName: String {
        notification.type == "message_sent" ? "paperplane.circle.fill" : "bell.circle.fill"
    }

    var iconColor: Color {
        notification.type == "message_sent" ? .blue : .orange
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 36))
                .foregroundColor(iconColor)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.title)
                        .font(.headline)
                        .foregroundColor(notification.isRead ? .secondary : .primary)
                    Spacer()
                    if !notification.isRead {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }
                Text(notification.body)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let date = notification.createdAt {
                    Text(date, style: .relative)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

//
//  PreferencesView.swift
//  Preferences window for the menu bar app
//

import SwiftUI

// MARK: - Preferences Window
struct PreferencesView: View {
    @AppStorage("openAtLogin") private var openAtLogin = false
    @AppStorage("refreshInterval") private var refreshInterval: Double = 30.0
    @AppStorage("dailyCostThreshold") private var dailyCostThreshold: Double = 10.0
    @AppStorage("showCostInMenuBar") private var showCostInMenuBar = true
    
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // General Tab
            GeneralPreferencesView(
                openAtLogin: $openAtLogin,
                showCostInMenuBar: $showCostInMenuBar
            )
            .tabItem {
                Label("General", systemImage: "gear")
            }
            .tag(0)
            
            // Updates Tab
            UpdatesPreferencesView(
                refreshInterval: $refreshInterval
            )
            .tabItem {
                Label("Updates", systemImage: "arrow.clockwise")
            }
            .tag(1)
            
            // Notifications Tab
            NotificationsPreferencesView(
                dailyCostThreshold: $dailyCostThreshold
            )
            .tabItem {
                Label("Notifications", systemImage: "bell")
            }
            .tag(2)
        }
        .frame(width: 500, height: 300)
        .fixedSize()
    }
}

// MARK: - General Preferences
struct GeneralPreferencesView: View {
    @Binding var openAtLogin: Bool
    @Binding var showCostInMenuBar: Bool
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    // Startup Options
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Startup")
                            .font(.headline)
                        
                        Toggle("Open at Login", isOn: $openAtLogin)
                            .toggleStyle(CheckboxToggleStyle())
                        
                        Toggle("Show Cost in Menu Bar", isOn: $showCostInMenuBar)
                            .toggleStyle(CheckboxToggleStyle())
                    }
                }
                .padding()
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Updates Preferences
struct UpdatesPreferencesView: View {
    @Binding var refreshInterval: Double
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Auto-Refresh")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Refresh Interval:")
                            Text("\(Int(refreshInterval)) seconds")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $refreshInterval, in: 10...120, step: 10)
                        
                        Text("How often to update usage data when the app is active.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Manual Refresh")
                            .font(.headline)
                        
                        HStack {
                            Text("Keyboard Shortcut:")
                            Text("⌘R")
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                        }
                        
                        Text("You can also click the Refresh button in the menu bar interface.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Notifications Preferences
struct NotificationsPreferencesView: View {
    @Binding var dailyCostThreshold: Double
    @State private var enableNotifications = true
    @State private var notifyOnHighCost = true
    @State private var notifyOnSessionEnd = false
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Cost Alerts")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Enable Notifications", isOn: $enableNotifications)
                            .toggleStyle(CheckboxToggleStyle())
                        
                        if enableNotifications {
                            Toggle("Alert when daily cost exceeds threshold", isOn: $notifyOnHighCost)
                                .toggleStyle(CheckboxToggleStyle())
                                .padding(.leading, 20)
                            
                            if notifyOnHighCost {
                                HStack {
                                    Text("Daily Cost Threshold:")
                                    TextField("", value: $dailyCostThreshold, format: .currency(code: "USD"))
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .frame(width: 100)
                                }
                                .padding(.leading, 20)
                            }
                            
                            Toggle("Notify when session ends", isOn: $notifyOnSessionEnd)
                                .toggleStyle(CheckboxToggleStyle())
                                .padding(.leading, 20)
                        }
                    }
                    
                    Text("Notifications appear in Notification Center and can be configured in System Settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Preview
#if DEBUG
#Preview {
    PreferencesView()
}
#endif
//
//  PermissionsOnboardingView.swift
//  Clip Board Pro
//

import SwiftUI

struct PermissionsOnboardingView: View {
    let onComplete: () -> Void

    @State private var monitor = AccessibilityPermissionMonitor()
    @State private var showGrantedState = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer(minLength: 28)

                heroIcon

                VStack(spacing: 10) {
                    Text(showGrantedState ? "You're All Set!" : "Enable Auto-Paste")
                        .font(.system(size: 26, weight: .semibold))

                    Text(
                        showGrantedState
                            ? "Clip Board Pro can now paste items directly into your apps."
                            : "Allow Accessibility access so Clip Board Pro can paste clipboard items into other applications instantly."
                    )
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 22)

                if !showGrantedState {
                    featureList
                        .padding(.top, 28)

                    actions
                        .padding(.top, 28)
                } else {
                    grantedBadge
                        .padding(.top, 32)
                }

                Spacer(minLength: 28)
            }
            .padding(.horizontal, 36)
        }
        .frame(width: 480, height: 520)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.quaternary.opacity(0.5), lineWidth: 0.5)
        }
        .onAppear {
            monitor.startMonitoring {
                handlePermissionGranted()
            }
        }
        .onDisappear {
            monitor.stopMonitoring()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            monitor.refreshTrustStatus()
        }
    }

    // MARK: - Sections

    private var background: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.35)
            .ignoresSafeArea()
        }
    }

    private var gradientColors: [Color] {
        colorScheme == .dark
            ? [Color.accentColor.opacity(0.35), Color.blue.opacity(0.15)]
            : [Color.accentColor.opacity(0.2), Color.blue.opacity(0.08)]
    }

    private var heroIcon: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.accentColor.opacity(0.35), Color.accentColor.opacity(0.05)],
                        center: .center,
                        startRadius: 8,
                        endRadius: 56
                    )
                )
                .frame(width: 112, height: 112)

            Image(systemName: showGrantedState ? "checkmark.circle.fill" : "accessibility")
                .font(.system(size: 44, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(showGrantedState ? .green : Color.accentColor)
                .contentTransition(.symbolEffect(.replace))
        }
        .animation(.spring(duration: 0.45), value: showGrantedState)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            featureRow(
                icon: "bolt.fill",
                title: "Instant paste",
                detail: "Click any history item and it pastes into the app you were using."
            )
            featureRow(
                icon: "lock.shield.fill",
                title: "You're in control",
                detail: "Only used for auto-paste — never reads keystrokes from other apps."
            )
            featureRow(
                icon: "gearshape.fill",
                title: "Revoke anytime",
                detail: "Disable access later in System Settings → Privacy & Security."
            )
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.quaternary.opacity(colorScheme == .dark ? 0.25 : 0.4))
        }
    }

    private func featureRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                monitor.openAccessibilitySettings()
            } label: {
                Label("Open Accessibility Settings", systemImage: "arrow.up.forward.app")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text("Enable **Clip Board Pro** in the list, then return here.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Continue without Auto-Paste") {
                completeOnboarding()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        }
    }

    private var grantedBadge: some View {
        Label("Accessibility enabled", systemImage: "checkmark.seal.fill")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.green)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                Capsule()
                    .fill(.green.opacity(0.12))
            }
    }

    // MARK: - Logic

    private func handlePermissionGranted() {
        guard !showGrantedState else { return }
        showGrantedState = true
        monitor.stopMonitoring()

        Task {
            try? await Task.sleep(for: .milliseconds(900))
            completeOnboarding()
        }
    }

    private func completeOnboarding() {
        monitor.stopMonitoring()
        onComplete()
    }
}

#Preview {
    PermissionsOnboardingView(onComplete: {})
}

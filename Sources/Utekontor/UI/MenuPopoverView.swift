import SwiftUI

struct MenuPopoverView: View {
    let state: MenuContentState
    let onToggleXDR: () -> Void
    let onInternalBrightnessChanged: (Double) -> Void
    let onExternalBrightnessChanged: (Double) -> Void
    let onToggleSync: () -> Void
    let onSelectXDRAutoOffDuration: (TimeInterval?) -> Void
    let onQuit: () -> Void

    private let timerChoices: [TimeInterval?] = [nil, 600, 1800, 3600, 7200]

    var body: some View {
        content
            .frame(width: 320)
            .background(backgroundSurface)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 14)

            sectionCaption("Brightness")
            brightnessRow(
                title: state.internalLabel,
                systemImage: "laptopcomputer",
                value: state.internalBrightness,
                isEnabled: state.internalBrightnessEnabled,
                tint: .yellow,
                action: onInternalBrightnessChanged
            )
            .padding(.top, 6)

            brightnessRow(
                title: state.externalLabel,
                systemImage: "display.2",
                value: state.externalBrightness,
                isEnabled: state.externalBrightnessEnabled,
                tint: Color(white: 0.55),
                action: onExternalBrightnessChanged
            )
            .padding(.top, 12)

            Divider()
                .padding(.vertical, 14)

            sectionCaption("Display")
            VStack(alignment: .leading, spacing: 0) {
                toggleRow(
                    title: "XDR",
                    subtitle: "Extended dynamic range",
                    systemImage: "sun.max.fill",
                    isOn: xdrToggleBinding
                )
                .tint(.orange)

                Divider()
                    .padding(.vertical, 10)

                toggleRow(
                    title: "Match brightness",
                    subtitle: "Sync built-in and external",
                    systemImage: "arrow.triangle.2.circlepath",
                    isOn: syncToggleBinding
                )
                .tint(.primary)
            }
            .padding(.top, 6)

            Divider()
                .padding(.vertical, 14)

            VStack(alignment: .leading, spacing: 6) {
                LabeledContent {
                    Picker("", selection: autoOffBinding) {
                        ForEach(0 ..< timerChoices.count, id: \.self) { index in
                            let duration = timerChoices[index]
                            Text(timerTitle(duration)).tag(duration)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-off timer")
                        Text("When XDR is on")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(state.xdrAutoOffLabel)
                    .font(
                        .caption.monospacedDigit()
                            .weight(state.xdrAutoOffCountdownActive ? .semibold : .regular)
                    )
                    .foregroundStyle(state.xdrAutoOffCountdownActive ? Color.orange : Color.secondary)
            }
            .padding(.vertical, 2)

            Divider()
                .padding(.top, 12)
                .padding(.bottom, 8)

            footer
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Utekontor")
                .font(.title3.weight(.semibold))
            Text(headerSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerSubtitle: String {
        if state.xdrEnabled {
            return "XDR is on"
        }
        if state.syncEnabled {
            return "Brightness is synced"
        }
        return "Menu bar display controls"
    }

    private func sectionCaption(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.6)
    }

    private func brightnessRow(
        title: String,
        systemImage: String,
        value: Double,
        isEnabled: Bool,
        tint: Color,
        action: @escaping (Double) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: systemImage)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, alignment: .center)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(Int(value * 100))%")
                    .font(.subheadline.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(
                    get: { value },
                    set: { action($0) }
                ),
                in: 0 ... 1
            )
            .tint(tint)
            .disabled(!isEnabled)
            .controlSize(.small)
        }
        .opacity(isEnabled ? 1 : 0.45)
    }

    private func toggleRow(
        title: String,
        subtitle: String,
        systemImage: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, alignment: .center)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
    }

    private var footer: some View {
        HStack(alignment: .center) {
            Text("Utekontor")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer()
            Button("Quit", action: onQuit)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
                .keyboardShortcut("q", modifiers: [.command])
        }
    }

    private var xdrToggleBinding: Binding<Bool> {
        Binding(
            get: { state.xdrEnabled },
            set: { newValue in
                if newValue != state.xdrEnabled {
                    onToggleXDR()
                }
            }
        )
    }

    private var syncToggleBinding: Binding<Bool> {
        Binding(
            get: { state.syncEnabled },
            set: { newValue in
                if newValue != state.syncEnabled {
                    onToggleSync()
                }
            }
        )
    }

    private var autoOffBinding: Binding<TimeInterval?> {
        Binding(
            get: { state.xdrAutoOffDuration },
            set: { onSelectXDRAutoOffDuration($0) }
        )
    }

    @ViewBuilder
    private var backgroundSurface: some View {
        if #available(macOS 26, *) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 18))
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }

    private func timerTitle(_ duration: TimeInterval?) -> String {
        guard let duration else { return "Off" }
        let minutes = Int(duration / 60)
        switch minutes {
        case 60:
            return "1 hour"
        case 120:
            return "2 hours"
        default:
            return "\(minutes) minutes"
        }
    }
}

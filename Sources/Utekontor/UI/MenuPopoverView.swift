import SwiftUI

struct MenuPopoverView: View {
    let state: MenuContentState
    let onToggleXDR: () -> Void
    let onInternalBrightnessChanged: (Double) -> Void
    let onExternalBrightnessChanged: (Double) -> Void
    let onXDRLevelChanged: (Double) -> Void
    let onToggleSync: () -> Void
    let onSelectXDRAutoOffDuration: (TimeInterval?) -> Void
    let onShowAbout: () -> Void
    let onQuit: () -> Void

    private let timerChoices: [TimeInterval?] = [nil, 600, 1800, 3600, 7200]
    private let toggleColumnWidth: CGFloat = 56
    /// Slider positions above this threshold push the panel past the calibrated comfort range
    /// (heat, color shift, banding). Render as a warning so the user knows.
    private let xdrWarningThreshold: Double = 0.8

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
            }
            .padding(.top, 6)

            if state.xdrEnabled {
                xdrLevelRow
                    .padding(.top, 12)
            }

            VStack(alignment: .leading, spacing: 0) {
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
        // Custom layout instead of Toggle's default to keep all switches in a vertical column
        // regardless of label width.
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
            Spacer(minLength: 8)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .frame(width: toggleColumnWidth, alignment: .trailing)
        }
    }

    private var xdrLevelRow: some View {
        // Smooth color/opacity ramp: slider tint drifts amber → blood-orange across the whole
        // range (back-loaded curve), percent text drifts from gray → orange between 50–100%, and
        // the tip fades in between 60–90%. Avoids a hard cliff at exactly 80%.
        let level = state.xdrLevel
        let percentRamp = clamp01((level - 0.5) / 0.5)
        let tipRamp = clamp01((level - 0.6) / 0.3)
        let neutralGray = Color(.sRGB, red: 0.55, green: 0.55, blue: 0.55, opacity: 1)
        let percentColor = neutralGray.interpolated(to: .orange, fraction: percentRamp)
        let softAmber = Color(.sRGB, red: 1.0, green: 0.82, blue: 0.42, opacity: 1)
        let bloodOrange = Color(.sRGB, red: 0.85, green: 0.30, blue: 0.12, opacity: 1)
        let tintRamp = pow(level, 1.8)
        let trackTint = softAmber.interpolated(to: bloodOrange, fraction: tintRamp)
        return VStack(alignment: .leading, spacing: 8) {
            // Same two-line layout as the brightness rows so SwiftUI renders the slider thumb at
            // its full intrinsic size on its own row instead of squashing it next to inline labels.
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "rays")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, alignment: .center)
                Text("Boost")
                    .font(.subheadline.weight(.medium))
                Spacer(minLength: 8)
                Text("\(Int(level * 100))%")
                    .font(.subheadline.monospacedDigit().weight(percentRamp > 0.4 ? .medium : .regular))
                    .foregroundStyle(percentColor)
            }
            Slider(
                value: Binding(
                    get: { state.xdrLevel },
                    set: { onXDRLevelChanged($0) }
                ),
                in: 0 ... 1
            )
            .tint(trackTint)
            .controlSize(.small)
            if tipRamp > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption2)
                    Text("Tip: high boost uses more battery and runs warmer")
                        .font(.caption2)
                }
                .foregroundStyle(Color.orange.opacity(tipRamp))
            }
        }
    }

    private func clamp01(_ value: Double) -> Double {
        max(0, min(1, value))
    }

    private var footer: some View {
        HStack(alignment: .center) {
            Button(action: onShowAbout) {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                    Text("About")
                        .font(.caption2)
                }
                .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
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

private extension Color {
    /// Linearly interpolates this color toward another in the device RGB space, e.g. for a smooth
    /// "intensity" ramp. Falls back to `self` if a system-defined color can't be resolved (rare).
    func interpolated(to other: Color, fraction: Double) -> Color {
        let t = max(0, min(1, fraction))
        let from = NSColor(self).usingColorSpace(.deviceRGB)
        let to = NSColor(other).usingColorSpace(.deviceRGB)
        guard let from, let to else { return self }
        let r = from.redComponent + (to.redComponent - from.redComponent) * t
        let g = from.greenComponent + (to.greenComponent - from.greenComponent) * t
        let b = from.blueComponent + (to.blueComponent - from.blueComponent) * t
        let a = from.alphaComponent + (to.alphaComponent - from.alphaComponent) * t
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

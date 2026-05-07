// ========== BLOCK 27: SessionConfigView (custom + breathwork) - START ==========
//
//  SessionConfigView.swift
//  NeuroLight
//
//  Pre-session controls: duration, audio, breath, color/torch.
//
//  Adapts to context:
//   • Custom state shows Hz + carrier sliders at the top
//   • Breathwork state hides flicker/torch entirely, shows breath cue
//     toggle, and labels the audio section "Cues & Texture"
//   • Custom breath pattern reveals four duration sliders + live BPM
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SessionConfigView: View {
    let state: BrainwaveState

    @AppStorage(StorageKey.audioEnabled)        private var audioEnabled: Bool = true
    @AppStorage(StorageKey.audioIsoVolume)      private var audioIsoVolume: Double = 0.6
    @AppStorage(StorageKey.audioAmbientType)    private var ambientTypeRaw: String = AmbientSoundType.pinkNoise.rawValue
    @AppStorage(StorageKey.audioAmbientVolume)  private var audioAmbientVolume: Double = 0.3
    @AppStorage(StorageKey.breathEnabled)       private var breathEnabled: Bool = true
    @AppStorage(StorageKey.breathPresetName)    private var breathPresetName: String = BreathPattern.coherence.name
    @AppStorage(StorageKey.colorModeEnabled)    private var colorModeEnabled: Bool = false
    @AppStorage(StorageKey.torchEnabled)        private var torchEnabled: Bool = false
    @AppStorage(StorageKey.preferredDuration)   private var preferredDurationRaw: String = SessionDuration.ten.rawValue

    @AppStorage(StorageKey.customHz)            private var customHz: Double = StorageDefault.customHz
    @AppStorage(StorageKey.customCarrierHz)     private var customCarrierHz: Double = StorageDefault.customCarrierHz

    @AppStorage(StorageKey.customBreathInhale)     private var cbInhale: Double     = StorageDefault.customBreathInhale
    @AppStorage(StorageKey.customBreathInhaleHold) private var cbInhaleHold: Double = StorageDefault.customBreathInhaleHold
    @AppStorage(StorageKey.customBreathExhale)     private var cbExhale: Double     = StorageDefault.customBreathExhale
    @AppStorage(StorageKey.customBreathExhaleHold) private var cbExhaleHold: Double = StorageDefault.customBreathExhaleHold

    @AppStorage(StorageKey.breathAudioCues)     private var breathAudioCues: Bool = StorageDefault.breathAudioCues
    @AppStorage(StorageKey.breathCueVolume)     private var breathCueVolume: Double = StorageDefault.breathCueVolume

    @State private var torchProbe = TorchController()
    @Bindable private var bus = AutomationBus.shared

    private var duration: SessionDuration {
        SessionDuration(rawValue: preferredDurationRaw) ?? .ten
    }
    private var ambientType: AmbientSoundType {
        AmbientSoundType(rawValue: ambientTypeRaw) ?? .pinkNoise
    }
    private var breathPattern: BreathPattern {
        BreathPattern.preset(named: breathPresetName) ?? .default
    }
    private var customBPM: Double {
        let cycle = cbInhale + cbInhaleHold + cbExhale + cbExhaleHold
        return cycle > 0 ? 60.0 / cycle : 0
    }
    private var customBreathTooFast: Bool { customBPM > 0 && customBPM < 2 }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    Image(systemName: glyphFor(state))
                        .font(.system(size: 44, weight: .ultraLight))
                        .foregroundStyle(state.sessionTint.gradient)
                        .padding(.top, 12)

                    Text(state.displayName)
                        .font(.system(size: 18, weight: .bold))
                        .tracking(8)
                        .foregroundColor(.white)

                    Text(state.description)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(hex: 0x888480))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .lineSpacing(3)

                    if state.isCustom {
                        sectionHeader("FREQUENCY")
                        customFrequencySection
                    }

                    sectionHeader("DURATION")
                    durationPicker

                    sectionHeader(state.isBreathwork ? "AMBIENT" : "AUDIO")
                    audioSection

                    sectionHeader("BREATH")
                    breathSection

                    if !state.isBreathwork {
                        sectionHeader("VISUAL")
                        visualSection
                    }

                    Button {
                        beginSession()
                    } label: {
                        Text("BEGIN")
                            .font(.system(size: 14, weight: .semibold))
                            .tracking(8)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(state.sessionTint.gradient)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 36)
                    .padding(.top, 12)
                    .accessibilityIdentifier("config.begin")

                    Button {
                        restoreDefaults()
                    } label: {
                        Text("RESTORE DEFAULTS")
                            .font(.system(size: 10, weight: .medium))
                            .tracking(4)
                            .foregroundColor(Color(hex: 0x888480))
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 32)
                    .accessibilityIdentifier("config.restoreDefaults")
                }
                .frame(maxWidth: Layout.contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            bus.currentScreen = "config.\(state.id)"
            bus.register("config.begin") { beginSession() }
            bus.register("config.restoreDefaults") { restoreDefaults() }
        }
        .onDisappear {
            bus.unregister("config.begin")
            bus.unregister("config.restoreDefaults")
        }
    }

    private func beginSession() {
        bus.requestedSession = buildConfig()
    }

    private func restoreDefaults() {
        StorageDefault.restoreAll()
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    // MARK: Sections

    @ViewBuilder private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .tracking(5)
            .foregroundColor(Color(hex: 0x888480))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 36)
            .padding(.top, 8)
    }

    private var customFrequencySection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("BRAINWAVE")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(2)
                    .foregroundColor(Color(hex: 0x888480))
                    .frame(width: 90, alignment: .leading)
                Spacer()
                Text(String(format: "%.1f Hz", customHz))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.92))
            }
            Slider(value: $customHz, in: 0.5...40, step: 0.5)
                .tint(Color(hex: 0xE8593C))

            HStack {
                Text("CARRIER")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(2)
                    .foregroundColor(Color(hex: 0x888480))
                    .frame(width: 90, alignment: .leading)
                Spacer()
                Text("\(Int(customCarrierHz)) Hz")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.92))
            }
            Slider(value: $customCarrierHz, in: 80...440, step: 2)
                .tint(Color(hex: 0xE8593C))
        }
        .padding(.horizontal, 36)
    }

    private var durationPicker: some View {
        HStack(spacing: 8) {
            ForEach(SessionDuration.allCases) { d in
                Button {
                    preferredDurationRaw = d.rawValue
                } label: {
                    Text(d.displayLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(2)
                        .foregroundColor(d == duration ? .white : Color(hex: 0x888480))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(d == duration
                                    ? AnyShapeStyle(state.sessionTint.gradient.opacity(0.85))
                                    : AnyShapeStyle(Color.white.opacity(0.04)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 36)
    }

    private var audioSection: some View {
        VStack(spacing: 14) {
            if state.isBreathwork {
                // Breathwork: no isochronic. Just optional cues + ambient.
                toggleRow("Breath cues", isOn: $breathAudioCues)
                if breathAudioCues {
                    labeledSlider("Cues", value: $breathCueVolume)
                }
                ambientPicker
                if ambientType != .off {
                    labeledSlider("Texture", value: $audioAmbientVolume)
                }
            } else {
                toggleRow("Sound", isOn: $audioEnabled)
                if audioEnabled {
                    labeledSlider("Tone", value: $audioIsoVolume)
                    ambientPicker
                    if ambientType != .off {
                        labeledSlider("Texture", value: $audioAmbientVolume)
                    }
                }
            }
        }
        .padding(.horizontal, 36)
    }

    private var ambientPicker: some View {
        HStack(spacing: 8) {
            ForEach(AmbientSoundType.allCases) { t in
                Button {
                    ambientTypeRaw = t.rawValue
                } label: {
                    Text(t.displayLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.5)
                        .foregroundColor(t == ambientType ? .white : Color(hex: 0x888480))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(t == ambientType
                                    ? AnyShapeStyle(state.sessionTint.gradient.opacity(0.65))
                                    : AnyShapeStyle(Color.white.opacity(0.04)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var breathSection: some View {
        VStack(spacing: 14) {
            // Breath guide is mandatory in breathwork mode — no toggle.
            if !state.isBreathwork {
                toggleRow("Breath guide", isOn: $breathEnabled)
            }
            if breathEnabled || state.isBreathwork {
                breathPatternList
                if breathPresetName == "Custom" {
                    customBreathSliders
                }
            }
        }
        .padding(.horizontal, 36)
    }

    private var breathPatternList: some View {
        VStack(spacing: 6) {
            ForEach(BreathPattern.presets) { p in
                breathPatternRow(name: p.name, bpmText: String(format: "%.1f BPM", p.bpm))
            }
            // Custom row — uses live values
            breathPatternRow(name: "Custom", bpmText: customBPM > 0 ? String(format: "%.1f BPM", customBPM) : "—")
        }
    }

    private func breathPatternRow(name: String, bpmText: String) -> some View {
        Button {
            breathPresetName = name
        } label: {
            HStack {
                Text(name.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(3)
                Spacer()
                Text(bpmText)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(Color(hex: 0x888480))
            }
            .foregroundColor(name == breathPresetName ? .white : Color(hex: 0xC8C0B6))
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(name == breathPresetName
                        ? AnyShapeStyle(state.sessionTint.gradient.opacity(0.55))
                        : AnyShapeStyle(Color.white.opacity(0.03)))
        }
        .buttonStyle(.plain)
    }

    private var customBreathSliders: some View {
        VStack(spacing: 14) {
            customBreathSlider("INHALE",   value: $cbInhale,     range: 1...12)
            customBreathSlider("HOLD IN",  value: $cbInhaleHold, range: 0...12)
            customBreathSlider("EXHALE",   value: $cbExhale,     range: 1...12)
            customBreathSlider("HOLD OUT", value: $cbExhaleHold, range: 0...12)

            HStack {
                Text("CYCLE")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(2)
                    .foregroundColor(Color(hex: 0x888480))
                Spacer()
                Text(customBPM > 0 ? String(format: "%.1f BPM · %.0fs cycle", customBPM, cbInhale + cbInhaleHold + cbExhale + cbExhaleHold) : "—")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(customBreathTooFast ? Color(hex: 0xE8593C) : .white.opacity(0.85))
            }
            .padding(.top, 4)

            if customBreathTooFast {
                Text("Slower than 2 BPM — may feel disorienting.")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(Color(hex: 0xE8593C))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private func customBreathSlider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: 14) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .tracking(2)
                .foregroundColor(Color(hex: 0x888480))
                .frame(width: 70, alignment: .leading)
            Slider(value: value, in: range, step: 0.5)
                .tint(Color(hex: 0xE8593C))
            Text(String(format: "%.1fs", value.wrappedValue))
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 38, alignment: .trailing)
        }
    }

    private var visualSection: some View {
        VStack(spacing: 14) {
            toggleRow("Color flash", isOn: $colorModeEnabled)
            if torchProbe.isAvailable {
                toggleRow("Flashlight (eyes-closed)", isOn: $torchEnabled)
            }
        }
        .padding(.horizontal, 36)
    }

    // MARK: Helpers

    @ViewBuilder
    private func toggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.white.opacity(0.92))
        }
        .toggleStyle(SwitchToggleStyle(tint: Color(hex: 0xE8593C)))
    }

    @ViewBuilder
    private func labeledSlider(_ label: String, value: Binding<Double>) -> some View {
        HStack(spacing: 14) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .medium))
                .tracking(2)
                .foregroundColor(Color(hex: 0x888480))
                .frame(width: 60, alignment: .leading)
            Slider(value: value, in: 0...1)
                .tint(Color(hex: 0xE8593C))
        }
    }

    private func glyphFor(_ s: BrainwaveState) -> String {
        switch s.id {
        case "focus":       return "viewfinder"
        case "calm":        return "water.waves"
        case "sleep":       return "moon.fill"
        case "theta":       return "sparkles"
        case "smr":         return "circle.dotted"
        case "psychedelic": return "swirl.circle.righthalf.filled"
        case "void":        return "circle"
        case "breathwork":  return "wind"
        default:            return "slider.horizontal.3"
        }
    }

    private func buildConfig() -> SessionConfig {
        let resolvedState = state.resolvingCustomValues()
        let isBreathwork = state.isBreathwork
        return SessionConfig(
            state: resolvedState,
            duration: duration,
            audioEnabled: isBreathwork ? false : audioEnabled,   // entrainment iso only
            isoVolume: audioIsoVolume,
            ambientType: ambientType,
            ambientVolume: audioAmbientVolume,
            breathEnabled: isBreathwork ? true : breathEnabled,  // mandatory in breathwork
            breathPattern: breathPattern,
            colorModeEnabled: isBreathwork ? false : colorModeEnabled,
            torchEnabled: isBreathwork ? false : (torchEnabled && torchProbe.isAvailable),
            breathAudioCues: isBreathwork ? breathAudioCues : false,
            breathCueVolume: breathCueVolume
        )
    }
}
// ========== BLOCK 27: SessionConfigView (custom + breathwork) - END ==========

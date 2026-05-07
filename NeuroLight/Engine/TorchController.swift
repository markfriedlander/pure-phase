// ========== BLOCK 4: TorchController - START ==========
//
//  TorchController.swift
//  NeuroLight
//
//  Thin wrapper around the iPhone torch. Under Mac Catalyst the torch
//  hardware does not exist; `isAvailable` returns false and every
//  setOn() call is a no-op. Views read `isAvailable` to decide whether
//  to show torch UI at all (per project rule: do not show dead toggles).
//

import AVFoundation
import Observation

@MainActor
@Observable
final class TorchController {

    private(set) var isOn: Bool = false

    var isAvailable: Bool {
        #if targetEnvironment(macCatalyst)
        return false
        #else
        guard let device = AVCaptureDevice.default(for: .video) else { return false }
        return device.hasTorch
        #endif
    }

    func setOn(_ on: Bool) {
        guard isAvailable else {
            if isOn { isOn = false }
            return
        }
        guard on != isOn else { return }

        #if !targetEnvironment(macCatalyst)
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else {
            isOn = false
            return
        }
        do {
            try device.lockForConfiguration()
            if on {
                try device.setTorchModeOn(level: 1.0)
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
            isOn = on
        } catch {
            // A torch failure should never crash a session. Treat as off.
            isOn = false
        }
        #endif
    }

    /// Defensive shutoff — call when ending a session to make sure the
    /// hardware doesn't get left on if a tick was mid-flight.
    func forceOff() {
        #if !targetEnvironment(macCatalyst)
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else {
            isOn = false
            return
        }
        try? device.lockForConfiguration()
        device.torchMode = .off
        device.unlockForConfiguration()
        #endif
        isOn = false
    }
}
// ========== BLOCK 4: TorchController - END ==========

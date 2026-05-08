// ========== BLOCK 20: AutomationServer - START ==========
//
//  AutomationServer.swift
//  NeuroLight
//
//  Debug-only embedded HTTP server. Binds to all interfaces on port
//  8770 (NeuroLight-specific; Posey uses 8765 in the same simulator).
//  Compiled out of Release entirely.
//
//  Verbs (parity rule: every new user-facing surface gets a verb here):
//
//    GET  /state                — full telemetry snapshot
//    GET  /actions              — list registered accessibility IDs
//    GET  /screenshot           — PNG of the current key window
//    POST /tap            {id}                 — fire a registered action
//    POST /set            {key, value}         — write any AppStorage key
//    POST /navigate       {to: state-id}       — push a SessionConfig screen
//    POST /reset-onboarding                     — clear hasSeenOnboarding
//    POST /session/start  {state, duration?, ...} — fully spec'd start
//    POST /session/stop                         — stop active session
//    POST /onboarding/accept                    — set hasSeenOnboarding=true
//
//  Connect from your Mac:
//    curl http://localhost:8770/state            (simulator)
//    curl http://<phone-ip>:8770/state           (device on same Wi-Fi)
//

#if DEBUG

import Foundation
import Network
import UIKit
import SwiftUI

@MainActor
final class AutomationServer {
    static let shared = AutomationServer()

    private var listener: NWListener?
    private var connections: Set<ObjectIdentifier> = []
    private var connectionMap: [ObjectIdentifier: NWConnection] = [:]
    private let port: NWEndpoint.Port = 8770

    func start() {
        guard listener == nil else { return }
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            params.acceptLocalOnly = false
            let l = try NWListener(using: params, on: port)
            l.newConnectionHandler = { [weak self] conn in
                Task { @MainActor in
                    self?.accept(conn)
                }
            }
            l.start(queue: .main)
            listener = l
            print("AutomationServer: listening on :\(port.rawValue)")
        } catch {
            print("AutomationServer: failed to start — \(error)")
        }
    }

    private func accept(_ conn: NWConnection) {
        let id = ObjectIdentifier(conn)
        connections.insert(id)
        connectionMap[id] = conn
        conn.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                if case .cancelled = state { self?.drop(id) }
                if case .failed = state { self?.drop(id) }
            }
        }
        conn.start(queue: .main)
        receive(conn, accumulated: Data())
    }

    private func drop(_ id: ObjectIdentifier) {
        connections.remove(id)
        connectionMap[id] = nil
    }

    private func receive(_ conn: NWConnection, accumulated: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self = self else { return }
                var buffer = accumulated
                if let data = data, !data.isEmpty { buffer.append(data) }

                if let (req, _) = HTTPRequest.parse(buffer) {
                    let resp = await self.route(req)
                    self.respond(resp, on: conn)
                    return
                }

                if isComplete || error != nil {
                    conn.cancel()
                    return
                }
                self.receive(conn, accumulated: buffer)
            }
        }
    }

    private func respond(_ resp: HTTPResponse, on conn: NWConnection) {
        conn.send(content: resp.serialize(), completion: .contentProcessed { _ in
            conn.cancel()
        })
    }

    // MARK: Routing

    private func route(_ req: HTTPRequest) async -> HTTPResponse {
        switch (req.method, req.path) {
        case ("GET",  "/"),
             ("GET",  "/help"):                      return helpHandler()
        case ("GET",  "/state"):                     return stateHandler()
        case ("GET",  "/actions"):                   return actionsHandler()
        case ("GET",  "/screenshot"):                return screenshotHandler()
        case ("POST", "/tap"):                       return tapHandler(req)
        case ("POST", "/set"):                       return setHandler(req)
        case ("POST", "/navigate"):                  return navigateHandler(req)
        case ("POST", "/reset-onboarding"):          return resetOnboarding()
        case ("POST", "/onboarding/accept"):         return acceptOnboarding()
        case ("POST", "/session/start"):             return startSessionHandler(req)
        case ("POST", "/session/stop"):              return stopSessionHandler()
        default:                                     return .notFound
        }
    }

    // MARK: Handlers

    private func helpHandler() -> HTTPResponse {
        HTTPResponse.json([
            "name": "Pure Phase Automation",
            "version": "1",
            "port": Int(port.rawValue),
            "endpoints": [
                "GET  /state",
                "GET  /actions",
                "GET  /screenshot",
                "POST /tap {id}",
                "POST /set {key, value}",
                "POST /navigate {to}",
                "POST /reset-onboarding",
                "POST /onboarding/accept",
                "POST /session/start {state, duration, audioEnabled?, ...}",
                "POST /session/stop"
            ]
        ])
    }

    private func stateHandler() -> HTTPResponse {
        let bus = AutomationBus.shared
        let defaults = UserDefaults.standard

        var settings: [String: Any] = [:]
        for key in [
            StorageKey.hasSeenOnboarding,
            StorageKey.lastUsedStateID,
            StorageKey.preferredDuration,
            StorageKey.audioEnabled,
            StorageKey.audioIsoVolume,
            StorageKey.audioAmbientType,
            StorageKey.audioAmbientVolume,
            StorageKey.breathEnabled,
            StorageKey.breathPresetName,
            StorageKey.colorModeEnabled,
            StorageKey.torchEnabled
        ] {
            settings[key] = defaults.object(forKey: key) ?? NSNull()
        }

        var engineDict: [String: Any] = ["active": false]
        if let snap = bus.engineSnapshot() {
            engineDict = [
                "active": snap.isRunning,
                "flickerPhase": snap.flickerPhase,
                "breathPhase": snap.breathPhase,
                "breathStage": snap.breathStageName,
                "sessionProgress": snap.sessionProgress as Any,
                "brightness": snap.brightness,
                "elapsed": snap.elapsed,
                "remaining": snap.remaining as Any
            ]
        }

        // Active session config (so callers can verify Custom Hz / carrier
        // and breath pattern actually took effect)
        var configDict: [String: Any] = ["present": false]
        if let cfg = bus.currentConfig {
            configDict = [
                "present": true,
                "stateID": cfg.state.id,
                "stateHz": cfg.state.hz,
                "stateCarrierHz": cfg.state.carrierHz,
                "isBreathwork": cfg.state.isBreathwork,
                "duration": cfg.duration.rawValue,
                "audioEnabled": cfg.audioEnabled,
                "isoVolume": cfg.isoVolume,
                "ambientType": cfg.ambientType.rawValue,
                "ambientVolume": cfg.ambientVolume,
                "breathEnabled": cfg.breathEnabled,
                "breathPattern": cfg.breathPattern.name,
                "breathInhale": cfg.breathPattern.inhale,
                "breathInhaleHold": cfg.breathPattern.inhaleHold,
                "breathExhale": cfg.breathPattern.exhale,
                "breathExhaleHold": cfg.breathPattern.exhaleHold,
                "breathBPM": cfg.breathPattern.bpm,
                "breathAudioCues": cfg.breathAudioCues,
                "breathCueVolume": cfg.breathCueVolume,
                "colorModeEnabled": cfg.colorModeEnabled,
                "torchEnabled": cfg.torchEnabled
            ]
        }

        var cueDict: [String: Any] = [
            "fireCount": bus.breathCueFireCount,
            "lastStage": bus.lastBreathCueStage
        ]
        if let at = bus.lastBreathCueAt {
            cueDict["lastFiredSecondsAgo"] = Date().timeIntervalSince(at)
        }

        // Audio output verification — `maxPeak == 0` after a session has
        // been running > 5 s with cues firing means audio is broken,
        // regardless of how many cues were "fired" in software.
        let liveAudio = bus.currentEngine?.audio.liveDiagnostics() ?? [:]
        var audioDict: [String: Any] = [
            "mixerVolume": bus.audioMixerVolume,
            "lastPeak": bus.lastAudioPeak,
            "maxPeak": bus.maxAudioPeak,
            "peakSamples": bus.audioPeakSampleCount,
            "sessionCategory": bus.audioSessionCategory,
            "lastError": bus.audioLastError
        ]
        // Merge in live state read at query time (no caching lag).
        for (k, v) in liveAudio { audioDict[k] = v }

        let payload: [String: Any] = [
            "screen": bus.currentScreen,
            "lastEvent": bus.lastEvent,
            "uptimeSec": Date().timeIntervalSince(bus.bootedAt),
            "engine": engineDict,
            "config": configDict,
            "breathCues": cueDict,
            "audio": audioDict,
            "settings": settings,
            "registeredActions": bus.registeredActions()
        ]
        return HTTPResponse.json(payload)
    }

    private func actionsHandler() -> HTTPResponse {
        HTTPResponse.json(["actions": AutomationBus.shared.registeredActions()])
    }

    private func tapHandler(_ req: HTTPRequest) -> HTTPResponse {
        guard let id = (req.bodyJSON?["id"] as? String) ?? req.query["id"] else {
            return .badRequest
        }
        let fired = AutomationBus.shared.fire(id)
        return HTTPResponse.json(["id": id, "fired": fired])
    }

    private func setHandler(_ req: HTTPRequest) -> HTTPResponse {
        guard let body = req.bodyJSON,
              let key = body["key"] as? String else {
            return .badRequest
        }
        let value = body["value"]
        let defaults = UserDefaults.standard
        if value is NSNull {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(value, forKey: key)
        }
        return HTTPResponse.json(["key": key, "value": value ?? NSNull()])
    }

    private func navigateHandler(_ req: HTTPRequest) -> HTTPResponse {
        guard let to = (req.bodyJSON?["to"] as? String) ?? req.query["to"] else {
            return .badRequest
        }
        let bus = AutomationBus.shared
        switch to {
        case "home":
            bus.requestedConfigState = nil
            bus.requestedRoute = nil
            bus.popToRootTicket += 1
        case "advanced":
            bus.requestedRoute = .advanced
        case "focus", "calm", "sleep", "theta", "smr", "prism", "drift", "bloom", "void", "custom", "breathwork":
            bus.requestedConfigState = to
        default:
            return .badRequest
        }
        return HTTPResponse.json(["navigatedTo": to])
    }

    private func resetOnboarding() -> HTTPResponse {
        UserDefaults.standard.removeObject(forKey: StorageKey.hasSeenOnboarding)
        return HTTPResponse.json(["ok": true])
    }

    private func acceptOnboarding() -> HTTPResponse {
        UserDefaults.standard.set(true, forKey: StorageKey.hasSeenOnboarding)
        return HTTPResponse.json(["ok": true])
    }

    private func startSessionHandler(_ req: HTTPRequest) -> HTTPResponse {
        guard let body = req.bodyJSON,
              let stateID = body["state"] as? String,
              let baseState = BrainwaveState.state(forID: stateID) else {
            return .badRequest
        }
        let state = baseState.resolvingCustomValues()

        let durationRaw = body["duration"] as? String ?? SessionDuration.ten.rawValue
        let duration = SessionDuration(rawValue: durationRaw) ?? .ten

        let ambientRaw = body["ambientType"] as? String
            ?? (state.isBreathwork ? AmbientSoundType.off.rawValue : AmbientSoundType.pinkNoise.rawValue)
        let ambient = AmbientSoundType(rawValue: ambientRaw) ?? .pinkNoise

        let breathName = body["breathPattern"] as? String ?? BreathPattern.coherence.name
        let breath = BreathPattern.preset(named: breathName) ?? .coherence

        let cfg = SessionConfig(
            state: state,
            duration: duration,
            audioEnabled: (body["audioEnabled"] as? Bool) ?? !state.isBreathwork,
            isoVolume: (body["isoVolume"] as? Double) ?? 0.6,
            ambientType: ambient,
            ambientVolume: (body["ambientVolume"] as? Double) ?? 0.3,
            breathEnabled: (body["breathEnabled"] as? Bool) ?? true,
            breathPattern: breath,
            colorModeEnabled: (body["colorModeEnabled"] as? Bool) ?? false,
            torchEnabled: (body["torchEnabled"] as? Bool) ?? false,
            breathAudioCues: (body["breathAudioCues"] as? Bool) ?? state.isBreathwork,
            breathCueVolume: (body["breathCueVolume"] as? Double) ?? StorageDefault.breathCueVolume
        )

        AutomationBus.shared.requestedSession = cfg
        return HTTPResponse.json(["started": true, "state": stateID])
    }

    private func stopSessionHandler() -> HTTPResponse {
        let bus = AutomationBus.shared
        bus.dismissTicket += 1
        bus.currentEngine?.stop()
        return HTTPResponse.json(["ok": true])
    }

    private func screenshotHandler() -> HTTPResponse {
        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
                ?? UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first,
              let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
        else {
            return HTTPResponse.json(["error": "no window"], status: 500)
        }
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let image = renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
        guard let data = image.pngData() else {
            return HTTPResponse.json(["error": "encode failed"], status: 500)
        }
        return HTTPResponse.png(data)
    }
}

#endif
// ========== BLOCK 20: AutomationServer - END ==========

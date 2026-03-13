import Foundation
import CoreLocation
#if canImport(NetworkExtension)
import NetworkExtension
#endif

@MainActor
@Observable
final class WiFiChecker: NSObject, CLLocationManagerDelegate {
    var currentSSID: String?
    var locationAuthorized = false
    private var locationManager: CLLocationManager?

    override init() {
        super.init()
        locationManager = CLLocationManager()
        locationManager?.delegate = self
    }

    func requestLocationPermission() {
        #if os(iOS)
        locationManager?.requestWhenInUseAuthorization()
        #endif
    }

    func fetchCurrentSSID() async {
        #if os(iOS)
        let status = locationManager?.authorizationStatus ?? .notDetermined
        if status == .notDetermined {
            requestLocationPermission()
            try? await Task.sleep(for: .seconds(1))
        }

        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            currentSSID = nil
            return
        }

        let network = await NEHotspotNetwork.fetchCurrent()
        currentSSID = network?.ssid
        #else
        currentSSID = nil
        #endif
    }

    func isConnectedToGymWiFi(ssids: [String]) async -> Bool {
        guard !ssids.isEmpty else { return true } // No WiFi restriction if not configured
        await fetchCurrentSSID()
        guard let current = currentSSID else { return false }
        return ssids.contains(current)
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            #if os(iOS)
            let status = manager.authorizationStatus
            locationAuthorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
            #endif
        }
    }
}

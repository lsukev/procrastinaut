import Foundation
import CoreLocation

// MARK: - DayWeather Model

struct DayWeather: Sendable {
    let highTemp: Int
    let lowTemp: Int
    let weatherCode: Int
    let sfSymbolName: String
}

// MARK: - Location Delegate (non-MainActor for CLLocationManagerDelegate conformance)

private final class LocationDelegate: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    var onLocation: (@Sendable (CLLocationCoordinate2D) -> Void)?
    var onError: (@Sendable (Error) -> Void)?

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.first?.coordinate else { return }
        manager.stopUpdatingLocation()
        onLocation?(coordinate)
        onLocation = nil
        onError = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        onError?(error)
        onLocation = nil
        onError = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorized, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            let err = NSError(domain: "WeatherService", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Location access denied."])
            onError?(err)
            onLocation = nil
            onError = nil
        default:
            break
        }
    }
}

// MARK: - Thread-safe Once Flag

private final class OnceFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var _fired = false

    /// Returns true if this is the first call; false on subsequent calls.
    func tryFire() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if _fired { return false }
        _fired = true
        return true
    }
}

// MARK: - WeatherService

@MainActor
@Observable
final class WeatherService {
    static let shared = WeatherService()

    var weatherByDate: [String: DayWeather] = [:]
    var isLoading = false
    var error: String?

    private let settings = UserSettings.shared
    private let locationManager = CLLocationManager()
    private let locationDelegate = LocationDelegate()
    private var lastFetchDate: Date?

    private static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private init() {
        locationManager.delegate = locationDelegate
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    // MARK: - Public API

    /// Returns weather for a given date, or nil if not available
    func weather(for date: Date) -> DayWeather? {
        let key = Self.dateKeyFormatter.string(from: date)
        return weatherByDate[key]
    }

    /// Fetch weather if needed (skips if recently fetched within 3 hours)
    func fetchWeatherIfNeeded(force: Bool = false) async {
        guard settings.showWeatherInMonthView else { return }

        if !force, let lastFetch = lastFetchDate,
           Date().timeIntervalSince(lastFetch) < 3 * 3600,
           !weatherByDate.isEmpty {
            return
        }

        guard let coords = await resolveCoordinates() else { return }
        await fetchWeather(lat: coords.latitude, lon: coords.longitude)
    }

    // MARK: - Location Resolution

    private func resolveCoordinates() async -> CLLocationCoordinate2D? {
        // Use cached coordinates if available
        if settings.cachedLatitude != 0 || settings.cachedLongitude != 0 {
            return CLLocationCoordinate2D(
                latitude: settings.cachedLatitude,
                longitude: settings.cachedLongitude
            )
        }

        // Request fresh location
        return await withCheckedContinuation { continuation in
            let once = OnceFlag()

            locationDelegate.onLocation = { [weak self] coordinate in
                guard once.tryFire() else { return }
                Task { @MainActor in
                    self?.settings.cachedLatitude = coordinate.latitude
                    self?.settings.cachedLongitude = coordinate.longitude
                }
                continuation.resume(returning: coordinate)
            }

            locationDelegate.onError = { [weak self] err in
                guard once.tryFire() else { return }
                Task { @MainActor in
                    self?.error = err.localizedDescription
                }
                continuation.resume(returning: nil)
            }

            switch locationManager.authorizationStatus {
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
            case .authorized, .authorizedAlways:
                locationManager.requestLocation()
            default:
                guard once.tryFire() else { return }
                error = "Location access denied. Enable in System Settings > Privacy."
                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: - API Fetch

    private func fetchWeather(lat: Double, lon: Double) async {
        isLoading = true
        defer { isLoading = false }

        let unit = settings.temperatureUnit
        let urlString = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=\(lat)&longitude=\(lon)"
            + "&daily=temperature_2m_max,temperature_2m_min,weather_code"
            + "&temperature_unit=\(unit)"
            + "&timezone=auto&forecast_days=16&past_days=14"

        guard let url = URL(string: urlString) else {
            error = "Invalid weather URL"
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                error = "Weather API returned an error"
                return
            }

            let parsed = try parseWeatherResponse(data)
            self.weatherByDate = parsed
            self.lastFetchDate = Date()
            self.error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - JSON Parsing

    private func parseWeatherResponse(_ data: Data) throws -> [String: DayWeather] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let daily = json["daily"] as? [String: Any],
              let dates = daily["time"] as? [String],
              let highs = daily["temperature_2m_max"] as? [Double],
              let lows = daily["temperature_2m_min"] as? [Double],
              let codes = daily["weather_code"] as? [Int] else {
            throw NSError(domain: "WeatherService", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Could not parse weather data."])
        }

        var result: [String: DayWeather] = [:]
        for i in 0..<dates.count {
            guard i < highs.count, i < lows.count, i < codes.count else { break }
            result[dates[i]] = DayWeather(
                highTemp: Int(highs[i].rounded()),
                lowTemp: Int(lows[i].rounded()),
                weatherCode: codes[i],
                sfSymbolName: Self.sfSymbol(for: codes[i])
            )
        }
        return result
    }

    // MARK: - WMO Weather Code → SF Symbol

    static func sfSymbol(for code: Int) -> String {
        switch code {
        case 0:         return "sun.max.fill"
        case 1:         return "cloud.sun.fill"
        case 2:         return "cloud.sun.fill"
        case 3:         return "cloud.fill"
        case 45, 48:    return "cloud.fog.fill"
        case 51...57:   return "cloud.drizzle.fill"
        case 61...67:   return "cloud.rain.fill"
        case 71...77:   return "cloud.snow.fill"
        case 80...82:   return "cloud.rain.fill"
        case 85, 86:    return "cloud.snow.fill"
        case 95...99:   return "cloud.bolt.rain.fill"
        default:        return "cloud.fill"
        }
    }
}

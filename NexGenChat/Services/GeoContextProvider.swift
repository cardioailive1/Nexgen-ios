import Foundation
import CoreLocation

/// Builds the live "USER LOCATION & WEATHER CONTEXT" block injected into the
/// chat system prompt, mirroring the web app's `initGeoContext`. Sources:
/// device timezone/clock (always), CoreLocation coordinates (with permission),
/// Open-Meteo (weather), and Nominatim (reverse geocode). All network calls are
/// best-effort — failures degrade gracefully to a timezone-only context.
@MainActor
final class GeoContextProvider: NSObject, ObservableObject {

    /// The current context string appended to the system prompt. Empty until the
    /// first `refresh()`; then at minimum carries timezone + local time.
    @Published private(set) var context: String = ""

    private let manager = CLLocationManager()
    private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var locContinuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        context = Self.baselineContext()
    }

    /// Refresh the context: timezone baseline immediately, then (if permitted)
    /// location → weather + place.
    func refresh() async {
        context = Self.baselineContext()
        guard let location = await requestLocation() else { return }
        let coords = location.coordinate
        async let weather = Self.fetchWeather(lat: coords.latitude, lon: coords.longitude)
        async let place = Self.reverseGeocode(lat: coords.latitude, lon: coords.longitude)
        context = Self.buildContext(coords: coords, weather: await weather, place: await place)
    }

    // MARK: - Location

    private func requestLocation() async -> CLLocation? {
        var status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
            status = await withCheckedContinuation { authContinuation = $0 }
        }
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            return nil
        }
        manager.requestLocation()
        return await withCheckedContinuation { locContinuation = $0 }
    }

    // MARK: - Context assembly

    private static func baselineContext() -> String {
        """
        \n\n── USER CONTEXT ──
        Timezone: \(TimeZone.current.identifier)
        Local time: \(localTimeString())
        ──────────────────
        """
    }

    private static func buildContext(coords: CLLocationCoordinate2D,
                                     weather: WeatherData?,
                                     place: String?) -> String {
        let location = place
            ?? String(format: "%.2f°, %.2f°", coords.latitude, coords.longitude)
        var lines = [
            "\n\n── USER LOCATION & WEATHER CONTEXT (auto-detected, live) ──",
            "Location: \(location)",
            String(format: "Coordinates: %.4f°N, %.4f°E", coords.latitude, coords.longitude),
            "Timezone: \(TimeZone.current.identifier)",
            "Local date/time: \(localTimeString())"
        ]
        lines.append(weather?.currentSummary.map { "Current weather: \($0)" } ?? "Weather: unavailable")
        if let forecast = weather?.forecastSummary { lines.append("3-day forecast: \(forecast)") }
        lines.append("Instructions: Use this context naturally when the user asks about weather, time, local services,")
        lines.append("travel, events, or anything location-relevant. Never expose these raw coordinates unless asked.")
        lines.append("───────────────────────────────────────────────────────────────")
        return lines.joined(separator: "\n")
    }

    private static func localTimeString() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "EEEE, MMMM d, yyyy, h:mm a"
        return f.string(from: Date())
    }
}

// MARK: - CLLocationManagerDelegate

extension GeoContextProvider: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authContinuation?.resume(returning: status)
            authContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        Task { @MainActor in
            locContinuation?.resume(returning: location)
            locContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        Task { @MainActor in
            locContinuation?.resume(returning: nil)
            locContinuation = nil
        }
    }
}

// MARK: - Weather (Open-Meteo)

struct WeatherData {
    let currentSummary: String?
    let forecastSummary: String?
}

private extension GeoContextProvider {
    static func fetchWeather(lat: Double, lon: Double) async -> WeatherData? {
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            .init(name: "latitude", value: String(format: "%.4f", lat)),
            .init(name: "longitude", value: String(format: "%.4f", lon)),
            .init(name: "current", value: "temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,precipitation"),
            .init(name: "daily", value: "temperature_2m_max,temperature_2m_min,precipitation_sum,weather_code"),
            .init(name: "timezone", value: TimeZone.current.identifier),
            .init(name: "forecast_days", value: "3")
        ]
        guard let url = comps.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let decoded = try? JSONDecoder().decode(OpenMeteoResponse.self, from: data) else {
            return nil
        }
        return WeatherData(
            currentSummary: decoded.currentSummary,
            forecastSummary: decoded.forecastSummary
        )
    }

    static func reverseGeocode(lat: Double, lon: Double) async -> String? {
        guard var comps = URLComponents(string: "https://nominatim.openstreetmap.org/reverse") else { return nil }
        comps.queryItems = [
            .init(name: "lat", value: String(lat)),
            .init(name: "lon", value: String(lon)),
            .init(name: "format", value: "json")
        ]
        guard let url = comps.url else { return nil }
        var req = URLRequest(url: url)
        // Nominatim usage policy requires an identifying User-Agent.
        req.setValue("NexGenChat-iOS/1.0", forHTTPHeaderField: "User-Agent")
        req.setValue("en", forHTTPHeaderField: "Accept-Language")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let decoded = try? JSONDecoder().decode(NominatimResponse.self, from: data) else {
            return nil
        }
        let a = decoded.address
        let city = a?.city ?? a?.town ?? a?.village ?? a?.county
        return [city, a?.country].compactMap { $0 }.joined(separator: ", ").ifEmptyNil
    }
}

// MARK: - Wire types

private struct OpenMeteoResponse: Decodable {
    struct Current: Decodable {
        let temperature_2m: Double
        let relative_humidity_2m: Double
        let apparent_temperature: Double
        let weather_code: Int
        let wind_speed_10m: Double
        let precipitation: Double
    }
    struct Daily: Decodable {
        let time: [String]
        let temperature_2m_max: [Double]
        let temperature_2m_min: [Double]
        let precipitation_sum: [Double]
        let weather_code: [Int]
    }
    let current: Current?
    let daily: Daily?

    var currentSummary: String? {
        guard let c = current else { return nil }
        let tempC = Int(c.temperature_2m.rounded())
        let feelC = Int(c.apparent_temperature.rounded())
        var s = "\(WMO.describe(c.weather_code)) · \(tempC)°C/\(cToF(tempC))°F"
            + " (feels \(feelC)°C/\(cToF(feelC))°F)"
            + " · Humidity \(Int(c.relative_humidity_2m))%"
            + " · Wind \(Int(c.wind_speed_10m.rounded())) km/h"
        if c.precipitation > 0 { s += " · Precip \(c.precipitation)mm" }
        return s
    }

    var forecastSummary: String? {
        guard let d = daily, !d.time.isEmpty else { return nil }
        let labels = ["Today", "Tomorrow", "Day 3"]
        let count = min(3, d.time.count)
        return (0..<count).map { i in
            let hi = Int(d.temperature_2m_max[i].rounded())
            let lo = Int(d.temperature_2m_min[i].rounded())
            var s = "\(labels[i]): \(WMO.describe(d.weather_code[i])) "
                + "\(hi)°C/\(cToF(hi))°F — \(lo)°C/\(cToF(lo))°F"
            if d.precipitation_sum[i] > 0 {
                s += String(format: " (%.1fmm)", d.precipitation_sum[i])
            }
            return s
        }.joined(separator: " | ")
    }
}

private struct NominatimResponse: Decodable {
    struct Address: Decodable {
        let city: String?
        let town: String?
        let village: String?
        let county: String?
        let country: String?
    }
    let address: Address?
}

private func cToF(_ c: Int) -> Int { Int((Double(c) * 9 / 5 + 32).rounded()) }

/// WMO weather interpretation codes → text (matches the web app's `WMO` map).
private enum WMO {
    static let table: [Int: String] = [
        0: "Clear sky", 1: "Mainly clear", 2: "Partly cloudy", 3: "Overcast",
        45: "Foggy", 48: "Icy fog", 51: "Light drizzle", 53: "Moderate drizzle",
        55: "Dense drizzle", 61: "Slight rain", 63: "Moderate rain", 65: "Heavy rain",
        71: "Slight snow", 73: "Moderate snow", 75: "Heavy snow", 77: "Snow grains",
        80: "Slight showers", 81: "Moderate showers", 82: "Heavy showers",
        85: "Slight snow showers", 86: "Heavy snow showers", 95: "Thunderstorm",
        96: "Thunderstorm w/ hail", 99: "Thunderstorm w/ heavy hail"
    ]
    static func describe(_ code: Int) -> String { table[code] ?? "Unknown" }
}

private extension String {
    var ifEmptyNil: String? { isEmpty ? nil : self }
}

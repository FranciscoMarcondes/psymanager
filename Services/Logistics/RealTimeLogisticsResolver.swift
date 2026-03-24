import Foundation

enum LogisticsDataSource: String, Codable {
    case api
    case cache
    case fallback

    var label: String {
        switch self {
        case .api:
            return "API em tempo real"
        case .cache:
            return "Cache local"
        case .fallback:
            return "Fallback local"
        }
    }
}

enum FlightProviderSelection: String, CaseIterable, Identifiable {
    case automatic
    case kiwiTequila
    case skyscannerRapidAPI
    case localOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .automatic:
            return "Automático (grátis primeiro)"
        case .kiwiTequila:
            return "Kiwi/Tequila (free tier)"
        case .skyscannerRapidAPI:
            return "Skyscanner via RapidAPI"
        case .localOnly:
            return "Somente cálculo local"
        }
    }
}

enum LogisticsConnectionStatus {
    case connected
    case missingKey
    case invalidKey
    case rateLimited
    case localOnly
    case unavailable(String)

    var label: String {
        switch self {
        case .connected:
            return "Conectado"
        case .missingKey:
            return "Sem chave"
        case .invalidKey:
            return "Chave inválida"
        case .rateLimited:
            return "Limite excedido"
        case .localOnly:
            return "Somente local"
        case .unavailable:
            return "Indisponível"
        }
    }

    var detail: String {
        switch self {
        case .connected:
            return "Conexão validada com sucesso."
        case .missingKey:
            return "Cadastre a credencial para habilitar a consulta externa."
        case .invalidKey:
            return "A credencial foi rejeitada pelo provedor."
        case .rateLimited:
            return "O provedor recusou a requisição por limite de uso."
        case .localOnly:
            return "O provedor foi desativado e o app seguirá em cálculo local."
        case let .unavailable(message):
            return message
        }
    }
}

// MARK: - Configuration
struct APIConfiguration {
    private static func configuredValue(environmentKey: String, plistKey: String, defaultValue: String = "") -> String {
        let environmentValue = ProcessInfo.processInfo.environment[environmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !environmentValue.isEmpty {
            return environmentValue
        }

        let keychainValue: String?
        switch environmentKey {
        case "PSY_GOOGLE_MAPS_API_KEY":
            keychainValue = PlatformAPISecrets.googleMapsAPIKey
        case "PSY_RAPID_API_KEY":
            keychainValue = PlatformAPISecrets.rapidAPIKey
        case "PSY_SKYSCANNER_API_KEY":
            keychainValue = PlatformAPISecrets.skyscannerAPIKey
        case "PSY_KIWI_TEQUILA_API_KEY":
            keychainValue = PlatformAPISecrets.kiwiTequilaAPIKey
        default:
            keychainValue = nil
        }

        if let keychainValue, !keychainValue.isEmpty {
            return keychainValue
        }

        if environmentKey == "PSY_RAPID_API_HOST" {
            let storedHost = UserDefaults.standard.string(forKey: "psy.logistics.rapidApiHost")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !storedHost.isEmpty {
                return storedHost
            }
        }

        let plistValue = (Bundle.main.object(forInfoDictionaryKey: plistKey) as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !plistValue.isEmpty {
            return plistValue
        }

        return defaultValue
    }

    static var googleMapsAPIKey: String {
        configuredValue(environmentKey: "PSY_GOOGLE_MAPS_API_KEY", plistKey: "PSYGoogleMapsAPIKey")
    }

    static var skyscannerAPIKey: String {
        configuredValue(environmentKey: "PSY_SKYSCANNER_API_KEY", plistKey: "PSYSkyscannerAPIKey")
    }

    static var kiwiTequilaAPIKey: String {
        configuredValue(environmentKey: "PSY_KIWI_TEQUILA_API_KEY", plistKey: "PSYKiwiTequilaAPIKey")
    }

    static var rapidAPIKey: String {
        configuredValue(environmentKey: "PSY_RAPID_API_KEY", plistKey: "PSYRapidAPIKey")
    }

    static var rapidAPIHost: String {
        configuredValue(environmentKey: "PSY_RAPID_API_HOST", plistKey: "PSYRapidAPIHost", defaultValue: "skyscanner44.p.rapidapi.com")
    }

    static var flightProviderSelection: FlightProviderSelection {
        let stored = UserDefaults.standard.string(forKey: "psy.logistics.flightProvider") ?? FlightProviderSelection.automatic.rawValue
        return FlightProviderSelection(rawValue: stored) ?? .automatic
    }

    static var isConfigured: Bool {
        true // OSRM road routing is available without credentials.
    }

    static var hasExternalFlightProviderConfigured: Bool {
        !kiwiTequilaAPIKey.isEmpty || !rapidAPIKey.isEmpty || !skyscannerAPIKey.isEmpty
    }
}

private actor LogisticsAPICache {
    static let shared = LogisticsAPICache()

    private struct DistanceCacheEntry: Codable {
        let distanceKm: Double
        let durationHours: Double
        let expiresAt: Date

        var isValid: Bool {
            Date() < expiresAt
        }
    }

    private struct FlightCacheEntry: Codable {
        let oneWayPrice: Double
        let roundTripPrice: Double
        let expiresAt: Date

        var isValid: Bool {
            Date() < expiresAt
        }
    }

    private let distanceCacheKey = "psy.logistics.distanceCache"
    private let flightCacheKey = "psy.logistics.flightCache"
    private var distanceCache: [String: DistanceCacheEntry]
    private var flightCache: [String: FlightCacheEntry]

    init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: distanceCacheKey),
           let decoded = try? JSONDecoder().decode([String: DistanceCacheEntry].self, from: data) {
            distanceCache = decoded
        } else {
            distanceCache = [:]
        }

        if let data = defaults.data(forKey: flightCacheKey),
           let decoded = try? JSONDecoder().decode([String: FlightCacheEntry].self, from: data) {
            flightCache = decoded
        } else {
            flightCache = [:]
        }
    }

    func distance(for key: String) -> (distanceKm: Double, durationHours: Double)? {
        guard let entry = distanceCache[key], entry.isValid else {
            distanceCache.removeValue(forKey: key)
            persistDistanceCache()
            return nil
        }
        return (entry.distanceKm, entry.durationHours)
    }

    func storeDistance(_ value: (distanceKm: Double, durationHours: Double), for key: String, ttl: TimeInterval = 60 * 60 * 24) {
        distanceCache[key] = DistanceCacheEntry(
            distanceKm: value.distanceKm,
            durationHours: value.durationHours,
            expiresAt: Date().addingTimeInterval(ttl)
        )
        persistDistanceCache()
    }

    func flight(for key: String) -> (oneWayPrice: Double, roundTripPrice: Double)? {
        guard let entry = flightCache[key], entry.isValid else {
            flightCache.removeValue(forKey: key)
            persistFlightCache()
            return nil
        }
        return (entry.oneWayPrice, entry.roundTripPrice)
    }

    func storeFlight(_ value: (oneWayPrice: Double, roundTripPrice: Double), for key: String, ttl: TimeInterval = 60 * 30) {
        flightCache[key] = FlightCacheEntry(
            oneWayPrice: value.oneWayPrice,
            roundTripPrice: value.roundTripPrice,
            expiresAt: Date().addingTimeInterval(ttl)
        )
        persistFlightCache()
    }

    private func persistDistanceCache() {
        if let data = try? JSONEncoder().encode(distanceCache) {
            UserDefaults.standard.set(data, forKey: distanceCacheKey)
        }
    }

    private func persistFlightCache() {
        if let data = try? JSONEncoder().encode(flightCache) {
            UserDefaults.standard.set(data, forKey: flightCacheKey)
        }
    }
}

// MARK: - Distance Matrix Response Models
struct DistanceMatrixResponse: Codable {
    let rows: [Row]
    let destinationAddresses: [String]
    let originAddresses: [String]
    let status: String

    struct Row: Codable {
        let elements: [Element]
    }

    struct Element: Codable {
        let distance: Distance?
        let duration: Duration?
        let status: String

        struct Distance: Codable {
            let text: String
            let value: Int
        }

        struct Duration: Codable {
            let text: String
            let value: Int
        }
    }
}

struct OSRMRouteResponse: Codable {
    struct Route: Codable {
        let distance: Double
        let duration: Double
    }

    let code: String
    let routes: [Route]
}

// MARK: - Flight Search Response Models
struct FlightSearchResponse: Codable {
    let data: [FlightOption]?
    let status: String?
    let error: String?

    struct FlightOption: Codable {
        let price: FlightPrice?

        struct FlightPrice: Codable {
            let amount: Double?
        }
    }
}

struct KiwiSearchResponse: Codable {
    struct KiwiFlightOption: Codable {
        let price: Double?
    }

    let data: [KiwiFlightOption]
}

// MARK: - Distance Service
actor DistanceMatrixService {
    static let shared = DistanceMatrixService()

    private let session = URLSession.shared
    private let decoder = JSONDecoder()
    private let cache = LogisticsAPICache.shared

    func testConnection() async -> LogisticsConnectionStatus {
        guard let url = URL(string: "https://router.project-osrm.org/route/v1/driving/-46.6333,-23.5505;-43.1729,-22.9068?overview=false") else {
            return .unavailable("Não foi possível montar a URL de teste do OSRM.")
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return .unavailable("OSRM indisponível no momento.")
            }
            let payload = try decoder.decode(OSRMRouteResponse.self, from: data)
            guard payload.code == "Ok", payload.routes.first != nil else {
                return .unavailable("OSRM retornou rota inválida no teste.")
            }
            return .connected
        } catch {
            return .unavailable("Falha ao testar OSRM: \(error.localizedDescription)")
        }
    }

    func getDistance(
        originCity: String,
        originState: String,
        destinationCity: String,
        destinationState: String
    ) async -> (distanceKm: Double, durationHours: Double, source: LogisticsDataSource)? {
        let cacheKey = [originCity, originState, destinationCity, destinationState]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .joined(separator: "|")

        if let cached = await cache.distance(for: cacheKey) {
            return (cached.distanceKm, cached.durationHours, .cache)
        }

        if let osrm = await routeWithOSRM(
            originState: originState,
            destinationState: destinationState
        ) {
            await cache.storeDistance((osrm.distanceKm, osrm.durationHours), for: cacheKey)
            return (osrm.distanceKm, osrm.durationHours, .api)
        }

        if let google = await routeWithGoogleMaps(
            originCity: originCity,
            originState: originState,
            destinationCity: destinationCity,
            destinationState: destinationState
        ) {
            await cache.storeDistance((google.distanceKm, google.durationHours), for: cacheKey)
            return (google.distanceKm, google.durationHours, .api)
        }

        return nil
    }

    private func routeWithOSRM(
        originState: String,
        destinationState: String
    ) async -> (distanceKm: Double, durationHours: Double)? {
        guard let origin = ArtistLogisticsEstimator.stateCentroids[ArtistLogisticsEstimator.normalizeState(originState)],
              let destination = ArtistLogisticsEstimator.stateCentroids[ArtistLogisticsEstimator.normalizeState(destinationState)]
        else {
            return nil
        }

        let path = "https://router.project-osrm.org/route/v1/driving/\(origin.1),\(origin.0);\(destination.1),\(destination.0)?overview=false"
        guard let url = URL(string: path) else {
            return nil
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            let payload = try decoder.decode(OSRMRouteResponse.self, from: data)
            guard payload.code == "Ok", let route = payload.routes.first else {
                return nil
            }
            return (route.distance / 1000.0, route.duration / 3600.0)
        } catch {
            return nil
        }
    }

    private func routeWithGoogleMaps(
        originCity: String,
        originState: String,
        destinationCity: String,
        destinationState: String
    ) async -> (distanceKm: Double, durationHours: Double)? {
        guard !APIConfiguration.googleMapsAPIKey.isEmpty else {
            return nil
        }

        let origin = "\(originCity),\(originState),Brazil"
        let destination = "\(destinationCity),\(destinationState),Brazil"

        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/distancematrix/json")
        components?.queryItems = [
            URLQueryItem(name: "origins", value: origin),
            URLQueryItem(name: "destinations", value: destination),
            URLQueryItem(name: "key", value: APIConfiguration.googleMapsAPIKey),
            URLQueryItem(name: "mode", value: "driving"),
            URLQueryItem(name: "language", value: "pt-BR"),
        ]

        guard let url = components?.url else {
            return nil
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }

            let result = try decoder.decode(DistanceMatrixResponse.self, from: data)
            guard result.status == "OK",
                  let row = result.rows.first,
                  let element = row.elements.first,
                  element.status == "OK",
                  let distance = element.distance,
                  let duration = element.duration
            else {
                return nil
            }
            return (Double(distance.value) / 1000.0, Double(duration.value) / 3600.0)
        } catch {
            return nil
        }
    }
}

// MARK: - Flight Service
actor FlightPricingService {
    static let shared = FlightPricingService()

    private let session = URLSession.shared
    private let decoder = JSONDecoder()
    private let cache = LogisticsAPICache.shared

    func testConnection() async -> LogisticsConnectionStatus {
        let provider = APIConfiguration.flightProviderSelection
        switch provider {
        case .localOnly:
            return .localOnly
        case .kiwiTequila:
            return await testKiwiConnection()
        case .skyscannerRapidAPI:
            return await testRapidConnection()
        case .automatic:
            let kiwiStatus = await testKiwiConnection()
            if kiwiStatus.label == LogisticsConnectionStatus.connected.label {
                return kiwiStatus
            }
            let rapidStatus = await testRapidConnection()
            if rapidStatus.label == LogisticsConnectionStatus.connected.label {
                return rapidStatus
            }
            if kiwiStatus.label == LogisticsConnectionStatus.missingKey.label,
               rapidStatus.label == LogisticsConnectionStatus.missingKey.label {
                return .missingKey
            }
            return kiwiStatus
        }
    }

    func searchFlights(
        originCode: String,
        destinationCode: String,
        departureDate: Date,
        returnDate: Date?
    ) async -> (oneWayPrice: Double, roundTripPrice: Double, source: LogisticsDataSource)? {
        let provider = APIConfiguration.flightProviderSelection
        guard provider != .localOnly else {
            return nil
        }

        let cacheKey = [
            originCode,
            destinationCode,
            departureDate.ISO8601Format(.iso8601.year().month().day()),
            returnDate?.ISO8601Format(.iso8601.year().month().day()) ?? "",
        ].joined(separator: "|")

        if let cached = await cache.flight(for: cacheKey) {
            return (cached.oneWayPrice, cached.roundTripPrice, .cache)
        }

        if provider == .kiwiTequila || provider == .automatic {
            if let kiwi = await searchWithKiwi(
                originCode: originCode,
                destinationCode: destinationCode,
                departureDate: departureDate,
                returnDate: returnDate
            ) {
                await cache.storeFlight((kiwi.oneWayPrice, kiwi.roundTripPrice), for: cacheKey)
                return (kiwi.oneWayPrice, kiwi.roundTripPrice, .api)
            }
        }

        if provider == .skyscannerRapidAPI || provider == .automatic {
            if let rapid = await searchWithRapid(
                originCode: originCode,
                destinationCode: destinationCode,
                departureDate: departureDate,
                returnDate: returnDate
            ) {
                await cache.storeFlight((rapid.oneWayPrice, rapid.roundTripPrice), for: cacheKey)
                return (rapid.oneWayPrice, rapid.roundTripPrice, .api)
            }
        }

        return nil
    }

    private func testKiwiConnection() async -> LogisticsConnectionStatus {
        guard !APIConfiguration.kiwiTequilaAPIKey.isEmpty else {
            return .missingKey
        }

        let departure = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        let returning = Calendar.current.date(byAdding: .day, value: 16, to: Date()) ?? Date()
        guard let url = buildKiwiSearchURL(origin: "GRU", destination: "GIG", departureDate: departure, returnDate: returning) else {
            return .unavailable("Não foi possível montar a URL de teste do Kiwi.")
        }

        var request = URLRequest(url: url)
        request.setValue(APIConfiguration.kiwiTequilaAPIKey, forHTTPHeaderField: "apikey")
        request.httpMethod = "GET"

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .unavailable("O provedor de voos não respondeu corretamente.")
            }
            if http.statusCode == 401 || http.statusCode == 403 { return .invalidKey }
            if http.statusCode == 429 { return .rateLimited }
            guard http.statusCode == 200 else {
                return .unavailable("Kiwi retornou status HTTP \(http.statusCode).")
            }
            let payload = try decoder.decode(KiwiSearchResponse.self, from: data)
            return payload.data.isEmpty ? .unavailable("Kiwi respondeu sem tarifas para o teste.") : .connected
        } catch {
            return .unavailable("Falha ao testar Kiwi: \(error.localizedDescription)")
        }
    }

    private func testRapidConnection() async -> LogisticsConnectionStatus {
        guard !APIConfiguration.rapidAPIKey.isEmpty else {
            return .missingKey
        }

        let today = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        let back = Calendar.current.date(byAdding: .day, value: 16, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        guard let url = buildRapidSearchURL(
            origin: "GRU",
            destination: "GIG",
            departDate: formatter.string(from: today),
            returnDate: formatter.string(from: back)
        ) else {
            return .unavailable("Não foi possível montar a URL de teste do RapidAPI.")
        }

        var request = URLRequest(url: url)
        request.setValue(APIConfiguration.rapidAPIKey, forHTTPHeaderField: "X-Rapidapi-Key")
        request.setValue(APIConfiguration.rapidAPIHost, forHTTPHeaderField: "X-Rapidapi-Host")
        request.httpMethod = "GET"

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .unavailable("O provedor de voos não respondeu corretamente.")
            }
            if http.statusCode == 401 || http.statusCode == 403 { return .invalidKey }
            if http.statusCode == 429 { return .rateLimited }
            guard http.statusCode == 200 else {
                return .unavailable("RapidAPI retornou status HTTP \(http.statusCode).")
            }

            let payload = try decoder.decode(FlightSearchResponse.self, from: data)
            if let error = payload.error, !error.isEmpty {
                return .unavailable(error)
            }
            return (payload.data?.isEmpty == false) ? .connected : .unavailable("RapidAPI respondeu sem tarifas para o teste.")
        } catch {
            return .unavailable("Falha ao testar RapidAPI: \(error.localizedDescription)")
        }
    }

    private func searchWithKiwi(
        originCode: String,
        destinationCode: String,
        departureDate: Date,
        returnDate: Date?
    ) async -> (oneWayPrice: Double, roundTripPrice: Double)? {
        guard !APIConfiguration.kiwiTequilaAPIKey.isEmpty,
              let url = buildKiwiSearchURL(
                origin: originCode,
                destination: destinationCode,
                departureDate: departureDate,
                returnDate: returnDate
              )
        else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue(APIConfiguration.kiwiTequilaAPIKey, forHTTPHeaderField: "apikey")
        request.httpMethod = "GET"

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            let payload = try decoder.decode(KiwiSearchResponse.self, from: data)
            let prices = payload.data.compactMap { $0.price }
            guard let minPrice = prices.min(), minPrice > 0 else {
                return nil
            }
            if returnDate == nil {
                return (minPrice, minPrice * 2)
            }
            return (minPrice / 2, minPrice)
        } catch {
            return nil
        }
    }

    private func searchWithRapid(
        originCode: String,
        destinationCode: String,
        departureDate: Date,
        returnDate: Date?
    ) async -> (oneWayPrice: Double, roundTripPrice: Double)? {
        guard !APIConfiguration.rapidAPIKey.isEmpty else {
            return nil
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let departDate = dateFormatter.string(from: departureDate)
        let returnDateStr = returnDate.map { dateFormatter.string(from: $0) } ?? ""

        guard let url = buildRapidSearchURL(
            origin: originCode,
            destination: destinationCode,
            departDate: departDate,
            returnDate: returnDateStr
        ) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue(APIConfiguration.rapidAPIKey, forHTTPHeaderField: "X-Rapidapi-Key")
        request.setValue(APIConfiguration.rapidAPIHost, forHTTPHeaderField: "X-Rapidapi-Host")
        request.httpMethod = "GET"

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            let payload = try decoder.decode(FlightSearchResponse.self, from: data)
            let prices: [Double] = payload.data?.compactMap { $0.price?.amount ?? 0.0 } ?? []
            guard let lowest = prices.min(), lowest > 0 else {
                return nil
            }
            return (lowest, lowest * 2)
        } catch {
            return nil
        }
    }

    private func buildRapidSearchURL(
        origin: String,
        destination: String,
        departDate: String,
        returnDate: String
    ) -> URL? {
        var components = URLComponents(string: "https://skyscanner44.p.rapidapi.com/search")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "origin", value: origin),
            URLQueryItem(name: "destination", value: destination),
            URLQueryItem(name: "departDate", value: departDate),
            URLQueryItem(name: "currency", value: "BRL"),
        ]

        if !returnDate.isEmpty {
            queryItems.append(URLQueryItem(name: "returnDate", value: returnDate))
        }

        components?.queryItems = queryItems
        return components?.url
    }

    private func buildKiwiSearchURL(
        origin: String,
        destination: String,
        departureDate: Date,
        returnDate: Date?
    ) -> URL? {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"

        var components = URLComponents(string: "https://api.tequila.kiwi.com/v2/search")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fly_from", value: origin),
            URLQueryItem(name: "fly_to", value: destination),
            URLQueryItem(name: "date_from", value: formatter.string(from: departureDate)),
            URLQueryItem(name: "date_to", value: formatter.string(from: departureDate)),
            URLQueryItem(name: "curr", value: "BRL"),
            URLQueryItem(name: "limit", value: "5"),
            URLQueryItem(name: "sort", value: "price"),
            URLQueryItem(name: "adults", value: "1"),
            URLQueryItem(name: "locale", value: "pt"),
        ]

        if let returnDate {
            let date = formatter.string(from: returnDate)
            queryItems.append(URLQueryItem(name: "return_from", value: date))
            queryItems.append(URLQueryItem(name: "return_to", value: date))
        }

        components?.queryItems = queryItems
        return components?.url
    }
}

// MARK: - Combined Service with Fallback
struct RealTimeLogisticsResolver {
    static let distanceService = DistanceMatrixService.shared
    static let flightService = FlightPricingService.shared

    static func testMapsConnection() async -> LogisticsConnectionStatus {
        await distanceService.testConnection()
    }

    static func testFlightConnection() async -> LogisticsConnectionStatus {
        await flightService.testConnection()
    }

    static func resolveDistance(
        originCity: String,
        originState: String,
        destinationCity: String,
        destinationState: String,
        fallback: () -> (distanceKm: Double, durationHours: Double)
    ) async -> (distanceKm: Double, durationHours: Double, source: LogisticsDataSource) {
        if let result = await distanceService.getDistance(
            originCity: originCity,
            originState: originState,
            destinationCity: destinationCity,
            destinationState: destinationState
        ) {
            return result
        }

        let fallbackResult = fallback()
        return (fallbackResult.distanceKm, fallbackResult.durationHours, .fallback)
    }

    static func resolveFlightPrices(
        originAirport: AirportOption,
        destinationAirport: AirportOption,
        eventDate: Date,
        returnDate: Date,
        fallback: () -> (oneWayPrice: Double, roundTripPrice: Double)
    ) async -> (oneWayPrice: Double, roundTripPrice: Double, source: LogisticsDataSource) {
        if let result = await flightService.searchFlights(
            originCode: originAirport.code,
            destinationCode: destinationAirport.code,
            departureDate: eventDate,
            returnDate: returnDate
        ) {
            return (result.oneWayPrice * 1.08, result.roundTripPrice * 1.08, result.source)
        }

        let fallbackResult = fallback()
        return (fallbackResult.oneWayPrice, fallbackResult.roundTripPrice, .fallback)
    }
}

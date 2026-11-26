import Foundation

/// GhostGram: answers typed right in the message field. Type a question and "=":
/// "150*3=" → 450, "5 км в милях=" → 3.11, "100 usd=" → rubles, "время Токио=" → 14:05.
public enum GhostInlineCalc {
    /// Calls `completion` on the main queue with the text to append, or nil.
    public static func evaluate(_ text: String, completion: @escaping (String?) -> Void) {
        guard text.hasSuffix("=") else {
            deliver(nil, completion)
            return
        }
        var body = String(text.dropLast())
        if let newline = body.lastIndex(of: "\n") {
            body = String(body[body.index(after: newline)...])
        }
        let query = body.trimmingCharacters(in: .whitespaces).lowercased()
        if query.isEmpty {
            deliver(nil, completion)
            return
        }
        if let time = timeIn(query) {
            deliver(time, completion)
            return
        }
        if let converted = convertUnits(query) {
            deliver(converted, completion)
            return
        }
        if let request = currencyRequest(query) {
            loadRates { rates in
                guard let rates = rates else {
                    completion(nil)
                    return
                }
                completion(GhostInlineCalc.convertCurrency(request, rates: rates))
            }
            return
        }
        deliver(evaluateMath(in: body), completion)
    }

    private static func deliver(_ value: String?, _ completion: @escaping (String?) -> Void) {
        DispatchQueue.main.async {
            completion(value)
        }
    }

    // MARK: - Helpers

    private static func groups(_ pattern: String, _ text: String) -> [String?]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex ..< text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else {
            return nil
        }
        var result: [String?] = []
        for i in 0 ..< match.numberOfRanges {
            if let r = Range(match.range(at: i), in: text) {
                result.append(String(text[r]))
            } else {
                result.append(nil)
            }
        }
        return result
    }

    private static func number(_ string: String) -> Double? {
        return Double(string.replacingOccurrences(of: ",", with: "."))
    }

    private static func format(_ value: Double, maxFraction: Int, comma: Bool) -> String? {
        guard value.isFinite else {
            return nil
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maxFraction
        formatter.decimalSeparator = comma ? "," : "."
        return formatter.string(from: NSNumber(value: value))
    }

    // MARK: - Math

    private struct MathParser {
        let chars: [Character]
        var pos = 0

        init(_ text: String) {
            self.chars = Array(text)
        }

        mutating func skipSpaces() {
            while self.pos < self.chars.count, self.chars[self.pos] == " " {
                self.pos += 1
            }
        }

        mutating func peek() -> Character? {
            self.skipSpaces()
            return self.pos < self.chars.count ? self.chars[self.pos] : nil
        }

        mutating func parseExpression() -> Double? {
            guard var value = self.parseTerm() else {
                return nil
            }
            while let c = self.peek(), c == "+" || c == "-" {
                self.pos += 1
                guard let rhs = self.parseTerm() else {
                    return nil
                }
                value = c == "+" ? value + rhs : value - rhs
            }
            return value
        }

        mutating func parseTerm() -> Double? {
            guard var value = self.parsePower() else {
                return nil
            }
            while let c = self.peek(), c == "*" || c == "/" || c == "×" || c == "÷" || c == "x" || c == "х" {
                self.pos += 1
                guard let rhs = self.parsePower() else {
                    return nil
                }
                if c == "/" || c == "÷" {
                    if rhs == 0.0 {
                        return nil
                    }
                    value = value / rhs
                } else {
                    value = value * rhs
                }
            }
            return value
        }

        mutating func parsePower() -> Double? {
            guard let base = self.parseUnary() else {
                return nil
            }
            if let c = self.peek(), c == "^" {
                self.pos += 1
                guard let exponent = self.parsePower() else {
                    return nil
                }
                return pow(base, exponent)
            }
            return base
        }

        mutating func parseUnary() -> Double? {
            if let c = self.peek(), c == "-" {
                self.pos += 1
                return self.parseUnary().map { -$0 }
            }
            return self.parsePrimary()
        }

        mutating func parsePrimary() -> Double? {
            guard let c = self.peek() else {
                return nil
            }
            var value: Double
            if c == "(" {
                self.pos += 1
                guard let inner = self.parseExpression(), let close = self.peek(), close == ")" else {
                    return nil
                }
                self.pos += 1
                value = inner
            } else {
                var digits = ""
                while self.pos < self.chars.count, self.chars[self.pos].isNumber || self.chars[self.pos] == "." || self.chars[self.pos] == "," {
                    digits.append(self.chars[self.pos] == "," ? "." : self.chars[self.pos])
                    self.pos += 1
                }
                guard !digits.isEmpty, let parsed = Double(digits) else {
                    return nil
                }
                value = parsed
            }
            if let p = self.peek(), p == "%" {
                self.pos += 1
                value = value / 100.0
            }
            return value
        }
    }

    private static func evaluateMath(in body: String) -> String? {
        let allowed = Set("0123456789.,+-*/×÷xх^()% ")
        var expression = ""
        for ch in body.reversed() {
            if allowed.contains(ch) {
                expression.insert(ch, at: expression.startIndex)
            } else {
                break
            }
        }
        expression = expression.trimmingCharacters(in: .whitespaces)
        // Starts with a number or a bracket and has a real operator between two operands.
        guard let first = expression.first, first.isNumber || first == "(" || first == "-" else {
            return nil
        }
        guard groups("[0-9)%]\\s*[-+*/×÷xх^]\\s*[0-9(]", expression) != nil else {
            return nil
        }
        var parser = MathParser(expression)
        guard let value = parser.parseExpression(), parser.peek() == nil else {
            return nil
        }
        return format(value, maxFraction: 6, comma: expression.contains(","))
    }

    // MARK: - Units

    private enum Dimension {
        case length, mass, volume, speed, temperature
    }

    private struct UnitInfo {
        let dimension: Dimension
        let factor: Double
        let name: String
    }

    private static func unit(_ raw: String) -> UnitInfo? {
        let s = raw.trimmingCharacters(in: CharacterSet(charactersIn: ". ")).replacingOccurrences(of: "°", with: "")
        func any(_ exact: [String], _ prefixes: [String]) -> Bool {
            if exact.contains(s) {
                return true
            }
            return prefixes.contains(where: { s.hasPrefix($0) })
        }
        if any(["км/ч", "kmh", "kph", "km/h"], []) { return UnitInfo(dimension: .speed, factor: 1.0 / 3.6, name: "км/ч") }
        if any(["mph", "миль/ч"], []) { return UnitInfo(dimension: .speed, factor: 0.44704, name: "mph") }
        if any(["м/с", "m/s"], []) { return UnitInfo(dimension: .speed, factor: 1.0, name: "м/с") }
        if any(["km", "км"], ["килом"]) { return UnitInfo(dimension: .length, factor: 1000.0, name: "км") }
        if any(["cm", "см"], ["сантим"]) { return UnitInfo(dimension: .length, factor: 0.01, name: "см") }
        if any(["mm", "мм"], ["миллим"]) { return UnitInfo(dimension: .length, factor: 0.001, name: "мм") }
        if any(["ml", "мл"], ["миллил"]) { return UnitInfo(dimension: .volume, factor: 0.001, name: "мл") }
        if any(["mi", "mile", "miles"], ["мил"]) { return UnitInfo(dimension: .length, factor: 1609.344, name: "миль") }
        if any(["m", "м"], ["метр"]) { return UnitInfo(dimension: .length, factor: 1.0, name: "м") }
        if any(["ft", "foot", "feet"], ["фут"]) { return UnitInfo(dimension: .length, factor: 0.3048, name: "фт") }
        if any(["inch", "inches"], ["дюйм"]) { return UnitInfo(dimension: .length, factor: 0.0254, name: "дюйм") }
        if any(["yd", "yard", "yards"], ["ярд"]) { return UnitInfo(dimension: .length, factor: 0.9144, name: "ярд") }
        if any(["kg", "кг"], ["килог"]) { return UnitInfo(dimension: .mass, factor: 1.0, name: "кг") }
        if any(["g", "г", "gram", "grams"], ["грам"]) { return UnitInfo(dimension: .mass, factor: 0.001, name: "г") }
        if any(["lb", "lbs", "pound", "pounds"], ["фунт"]) { return UnitInfo(dimension: .mass, factor: 0.45359237, name: "фунт") }
        if any(["oz", "ounce", "ounces"], ["унци"]) { return UnitInfo(dimension: .mass, factor: 0.028349523125, name: "унц") }
        if any(["t", "т", "ton", "tons"], ["тонн"]) { return UnitInfo(dimension: .mass, factor: 1000.0, name: "т") }
        if any(["l", "л"], ["литр"]) { return UnitInfo(dimension: .volume, factor: 1.0, name: "л") }
        if any(["gal", "gallon", "gallons"], ["галлон"]) { return UnitInfo(dimension: .volume, factor: 3.785411784, name: "гал") }
        if any(["c", "с"], ["цельс", "celsius"]) { return UnitInfo(dimension: .temperature, factor: 0.0, name: "°C") }
        if any(["f"], ["фаренг", "fahrenheit"]) { return UnitInfo(dimension: .temperature, factor: 1.0, name: "°F") }
        if any(["k"], ["кельв", "kelvin"]) { return UnitInfo(dimension: .temperature, factor: 2.0, name: "K") }
        return nil
    }

    private static func convertUnits(_ query: String) -> String? {
        guard let g = groups("^(-?\\d+(?:[.,]\\d+)?)\\s*([^\\s\\d]+)\\s+(?:в|во|to|in)\\s+([^\\s\\d]+)$", query), g.count == 4, let valueString = g[1], let fromString = g[2], let toString = g[3], let value = number(valueString), let from = unit(fromString), let to = unit(toString), from.dimension == to.dimension else {
            return nil
        }
        let result: Double
        if from.dimension == .temperature {
            var celsius = value
            if from.factor == 1.0 {
                celsius = (value - 32.0) * 5.0 / 9.0
            } else if from.factor == 2.0 {
                celsius = value - 273.15
            }
            if to.factor == 1.0 {
                result = celsius * 9.0 / 5.0 + 32.0
            } else if to.factor == 2.0 {
                result = celsius + 273.15
            } else {
                result = celsius
            }
        } else {
            result = value * from.factor / to.factor
        }
        guard let text = format(result, maxFraction: 3, comma: valueString.contains(",")) else {
            return nil
        }
        return "\(text) \(to.name)"
    }

    // MARK: - Time zones

    private static let cities: [String: String] = [
        "москва": "Europe/Moscow", "мск": "Europe/Moscow", "moscow": "Europe/Moscow",
        "питер": "Europe/Moscow", "спб": "Europe/Moscow", "санкт-петербург": "Europe/Moscow",
        "калининград": "Europe/Kaliningrad", "самара": "Europe/Samara",
        "екатеринбург": "Asia/Yekaterinburg", "екб": "Asia/Yekaterinburg", "омск": "Asia/Omsk",
        "новосибирск": "Asia/Novosibirsk", "красноярск": "Asia/Krasnoyarsk", "иркутск": "Asia/Irkutsk",
        "якутск": "Asia/Yakutsk", "владивосток": "Asia/Vladivostok", "магадан": "Asia/Magadan", "камчатка": "Asia/Kamchatka",
        "киев": "Europe/Kiev", "kyiv": "Europe/Kiev", "минск": "Europe/Minsk", "варшава": "Europe/Warsaw",
        "берлин": "Europe/Berlin", "berlin": "Europe/Berlin", "париж": "Europe/Paris", "paris": "Europe/Paris",
        "лондон": "Europe/London", "london": "Europe/London", "рим": "Europe/Rome", "мадрид": "Europe/Madrid",
        "прага": "Europe/Prague", "вена": "Europe/Vienna", "амстердам": "Europe/Amsterdam",
        "стамбул": "Europe/Istanbul", "анталия": "Europe/Istanbul", "тбилиси": "Asia/Tbilisi", "ереван": "Asia/Yerevan",
        "баку": "Asia/Baku", "алматы": "Asia/Almaty", "астана": "Asia/Almaty", "ташкент": "Asia/Tashkent",
        "бишкек": "Asia/Bishkek", "душанбе": "Asia/Dushanbe", "дубай": "Asia/Dubai", "dubai": "Asia/Dubai",
        "дели": "Asia/Kolkata", "мумбаи": "Asia/Kolkata", "бангкок": "Asia/Bangkok", "пхукет": "Asia/Bangkok",
        "бали": "Asia/Makassar", "сингапур": "Asia/Singapore", "пекин": "Asia/Shanghai", "шанхай": "Asia/Shanghai",
        "гонконг": "Asia/Hong_Kong", "сеул": "Asia/Seoul", "токио": "Asia/Tokyo", "tokyo": "Asia/Tokyo",
        "сидней": "Australia/Sydney", "нью-йорк": "America/New_York", "нью йорк": "America/New_York",
        "new york": "America/New_York", "ny": "America/New_York", "майами": "America/New_York",
        "чикаго": "America/Chicago", "денвер": "America/Denver", "лос-анджелес": "America/Los_Angeles",
        "лос анджелес": "America/Los_Angeles", "la": "America/Los_Angeles", "торонто": "America/Toronto",
        "мехико": "America/Mexico_City", "сан-паулу": "America/Sao_Paulo", "буэнос-айрес": "America/Argentina/Buenos_Aires"
    ]

    private static func timeIn(_ query: String) -> String? {
        guard let g = groups("^(?:время|time)\\s+(?:в\\s+|во\\s+|in\\s+)?(.+)$", query), g.count == 2, let city = g[1]?.trimmingCharacters(in: .whitespaces) else {
            return nil
        }
        var candidates = [city]
        if city.hasSuffix("е") {
            let stem = String(city.dropLast())
            candidates.append(stem)
            candidates.append(stem + "а")
        }
        guard let identifier = candidates.compactMap({ cities[$0] }).first, let zone = TimeZone(identifier: identifier) else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.timeZone = zone
        formatter.dateFormat = "HH:mm"
        var text = formatter.string(from: Date())
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let there = calendar.component(.day, from: Date())
        let here = Calendar.current.component(.day, from: Date())
        if there != here {
            text += Date().addingTimeInterval(Double(zone.secondsFromGMT() - TimeZone.current.secondsFromGMT())) > Date() ? " (завтра)" : " (вчера)"
        }
        return text
    }

    // MARK: - Currency

    private struct CurrencyRequest {
        let amount: Double
        let from: String
        let to: String
        let comma: Bool
    }

    private static func currency(_ raw: String) -> String? {
        let s = raw.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        let table: [(String, [String], [String])] = [
            ("USD", ["usd", "$", "dollar", "dollars"], ["доллар", "бакс"]),
            ("EUR", ["eur", "€", "euro"], ["евро"]),
            ("RUB", ["rub", "₽", "р", "руб"], ["рубл"]),
            ("UAH", ["uah", "₴", "грн"], ["гривн"]),
            ("KZT", ["kzt", "₸", "тенге"], []),
            ("BYN", ["byn"], ["белорусск"]),
            ("GBP", ["gbp", "£"], ["стерлинг"]),
            ("CNY", ["cny", "rmb"], ["юан"]),
            ("JPY", ["jpy", "¥"], ["иен", "йен"]),
            ("TRY", ["try", "₺"], ["лир"]),
            ("GEL", ["gel", "лари"], []),
            ("AMD", ["amd"], ["драм"]),
            ("UZS", ["uzs"], ["сум"]),
            ("AZN", ["azn"], ["манат"]),
            ("PLN", ["pln"], ["злот"]),
            ("CHF", ["chf"], ["франк"]),
            ("AED", ["aed"], ["дирхам"]),
            ("THB", ["thb"], ["бат"]),
            ("INR", ["inr"], ["рупи"]),
            ("CAD", ["cad"], []),
            ("AUD", ["aud"], [])
        ]
        for (code, exact, prefixes) in table {
            if exact.contains(s) || prefixes.contains(where: { s.hasPrefix($0) }) {
                return code
            }
        }
        return nil
    }

    private static func currencyRequest(_ query: String) -> CurrencyRequest? {
        var amountString: String?
        var fromString: String?
        var toString: String?
        if let g = groups("^(\\d+(?:[.,]\\d+)?)\\s*([^\\s\\d]+)(?:\\s+(?:в|во|to|in)\\s+([^\\s\\d]+))?$", query), g.count == 4 {
            amountString = g[1]
            fromString = g[2]
            toString = g[3]
        } else if let g = groups("^([$€£¥₽₴₸₺])\\s*(\\d+(?:[.,]\\d+)?)(?:\\s+(?:в|во|to|in)\\s+([^\\s\\d]+))?$", query), g.count == 4 {
            amountString = g[2]
            fromString = g[1]
            toString = g[3]
        }
        guard let amountText = amountString, let amount = number(amountText), let fromRaw = fromString, let from = currency(fromRaw) else {
            return nil
        }
        var to = from == "RUB" ? "USD" : "RUB"
        if let toRaw = toString {
            guard let parsed = currency(toRaw) else {
                return nil
            }
            to = parsed
        }
        if to == from {
            return nil
        }
        return CurrencyRequest(amount: amount, from: from, to: to, comma: amountText.contains(","))
    }

    private static func convertCurrency(_ request: CurrencyRequest, rates: [String: Double]) -> String? {
        guard let fromRate = rates[request.from], let toRate = rates[request.to], fromRate > 0.0 else {
            return nil
        }
        let value = request.amount / fromRate * toRate
        guard let text = format(value, maxFraction: 2, comma: request.comma) else {
            return nil
        }
        return "\(text) \(request.to)"
    }

    private static let ratesKey = "ghost.calc.rates"
    private static let ratesTimeKey = "ghost.calc.ratesTime"

    /// Exchange rates against USD from a free public source, cached for 12 hours.
    private static func loadRates(_ completion: @escaping ([String: Double]?) -> Void) {
        let defaults = UserDefaults.standard
        let cached = defaults.dictionary(forKey: ratesKey) as? [String: Double]
        let age = Date().timeIntervalSince1970 - defaults.double(forKey: ratesTimeKey)
        if let cached = cached, age < 12 * 60 * 60 {
            deliver(cached, completion)
            return
        }
        guard let url = URL(string: "https://open.er-api.com/v6/latest/USD") else {
            deliver(cached, completion)
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8.0
        URLSession.shared.dataTask(with: request, completionHandler: { data, _, _ in
            var fresh: [String: Double]?
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let rates = json["rates"] as? [String: Any] {
                var parsed: [String: Double] = [:]
                for (key, value) in rates {
                    if let number = value as? NSNumber {
                        parsed[key] = number.doubleValue
                    }
                }
                if !parsed.isEmpty {
                    fresh = parsed
                    defaults.set(parsed, forKey: GhostInlineCalc.ratesKey)
                    defaults.set(Date().timeIntervalSince1970, forKey: GhostInlineCalc.ratesTimeKey)
                }
            }
            GhostInlineCalc.deliver(fresh ?? cached, completion)
        }).resume()
    }

    private static func deliver(_ value: [String: Double]?, _ completion: @escaping ([String: Double]?) -> Void) {
        DispatchQueue.main.async {
            completion(value)
        }
    }
}

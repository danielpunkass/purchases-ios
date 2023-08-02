import Foundation
import RegexBuilder
import RevenueCat

@available(iOS 16.0, macOS 13.0, tvOS 16.0, *)
extension PaywallData.LocalizedConfiguration {

    func processVariables(with package: Package, locale: Locale = .current) -> ProcessedLocalizedConfiguration {
        return .init(self, package, locale)
    }

}

/// A type that can provide necessary information for `VariableHandler` to replace variable content in strings.
protocol VariableDataProvider {

    var applicationName: String { get }

    var isSubscription: Bool { get }
    var isMonthly: Bool { get }

    var localizedPrice: String { get }
    var localizedPricePerMonth: String { get }
    var productName: String { get }

    func periodName(_ locale: Locale) -> String
    func subscriptionDuration(_ locale: Locale) -> String?
    func introductoryOfferDuration(_ locale: Locale) -> String?

}

/// Processes strings, replacing `{{ variable }}` with their associated content.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, *)
enum VariableHandler {

    static func processVariables(
        in string: String,
        with provider: VariableDataProvider,
        locale: Locale = .current
    ) -> String {
        let matches = Self.extractVariables(from: string)
        var replacedString = string

        for variableMatch in matches.reversed() {
            let replacementValue = provider.value(for: variableMatch.variable, locale: locale)
            replacedString = replacedString.replacingCharacters(in: variableMatch.range, with: replacementValue)
        }

        return replacedString
    }

    private static func extractVariables(from expression: String) -> [VariableMatch] {
        return expression.matches(of: Self.regex).map { match in
            let (_, variable) = match.output
            return VariableMatch(variable: String(variable), range: match.range)
        }
    }

    private struct VariableMatch {

        let variable: String
        let range: Range<String.Index>

    }

    private static let regex = Regex {
        OneOrMore {
            "{{ "
            Capture {
                OneOrMore(.word)
            }
            " }}"
        }
    }

}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, *)
extension String {

    func processed(with provider: VariableDataProvider, locale: Locale) -> Self {
        return VariableHandler.processVariables(in: self, with: provider, locale: locale)
    }

}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, *)
private extension VariableDataProvider {

    func value(for variableName: String, locale: Locale) -> String {
        switch variableName {
        case "app_name": return self.applicationName
        case "price": return self.localizedPrice
        case "price_per_month": return self.localizedPricePerMonth
        case "total_price_and_per_month":
            if !self.isSubscription || self.isMonthly {
                return self.localizedPrice
            } else {
                let unit = Localization.abbreviatedUnitLocalizedString(for: .month, locale: locale)
                return "\(self.localizedPrice) (\(self.localizedPricePerMonth)/\(unit))"
            }

        case "product_name": return self.productName
        case "period":
            return self.periodName(locale)
        case "subscription_duration":
            return self.subscriptionDuration(locale) ?? ""
        case "intro_duration":
            return self.introductoryOfferDuration(locale) ?? ""

        default:
            Logger.warning(Strings.could_not_find_content_for_variable(variableName: variableName))
            return ""
        }
    }

}

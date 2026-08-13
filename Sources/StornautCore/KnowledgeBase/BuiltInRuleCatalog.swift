import Foundation

public enum BuiltInRuleCatalogError: Error, Sendable, Equatable {
    case missingResource
    case invalidCatalog
}

public enum BuiltInRuleCatalog {
    public static func load() throws -> RuleCatalog {
        guard let url = Bundle.module.url(
            forResource: "BuiltInRuleCatalog",
            withExtension: "json"
        ) else {
            throw BuiltInRuleCatalogError.missingResource
        }
        do {
            let catalog = try DomainJSON.decode(
                RuleCatalog.self,
                from: Data(contentsOf: url)
            )
            guard catalog.catalogVersion.rawValue
                    == "builtin-runtime-tool-residue-v2",
                  catalog.rules.count == 67
            else {
                throw BuiltInRuleCatalogError.invalidCatalog
            }
            return catalog
        } catch let error as BuiltInRuleCatalogError {
            throw error
        } catch {
            throw BuiltInRuleCatalogError.invalidCatalog
        }
    }
}

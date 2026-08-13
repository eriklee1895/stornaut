import Foundation
import Testing
@testable import StornautCodex

@Suite("Codex provider catalog preflight")
struct CodexProviderCatalogPreflightTests {
    @Test
    func readsEffectiveProviderAndCatalogWithoutLoginOrTurn() throws {
        let fixture = ProviderCatalogPreflightFixture()
        let runtime = try fixture.makeRuntime()

        #expect(try decode(runtime.begin()) == [[
            "id": .number(1),
            "method": .string("initialize"),
            "params": .object([
                "capabilities": .object([
                    "experimentalApi": .bool(true),
                ]),
                "clientInfo": .object([
                    "name": .string("stornaut"),
                    "title": .string("Stornaut"),
                    "version": .string("1"),
                ]),
            ]),
        ]])

        #expect(try decode(runtime.receive(fixture.initializeResponse)) == [
            [
                "method": .string("initialized"),
            ],
            [
                "id": .number(2),
                "method": .string("config/read"),
                "params": .object([
                    "cwd": .string(fixture.workURL.path),
                    "includeLayers": .bool(false),
                ]),
            ],
        ])
        #expect(try decode(runtime.receive(fixture.configResponse)) == [[
            "id": .number(3),
            "method": .string("modelProvider/capabilities/read"),
            "params": .object([:]),
        ]])
        #expect(
            try decode(
                runtime.receive(fixture.providerCapabilitiesResponse)
            ) == [[
                "id": .number(4),
                "method": .string("model/list"),
                "params": .object([
                    "includeHidden": .bool(true),
                    "limit": .number(100),
                ]),
            ]]
        )
        #expect(try decode(runtime.receive(fixture.firstModelPage)) == [[
            "id": .number(5),
            "method": .string("model/list"),
            "params": .object([
                "cursor": .string("2"),
                "includeHidden": .bool(true),
                "limit": .number(100),
            ]),
        ]])
        #expect(try runtime.receive(fixture.secondModelPage).isEmpty)
        #expect(runtime.status == .completed)
        #expect(
            runtime.report
                == CodexProviderCatalogPreflightReport(
                    effectiveProviderID: "openai",
                    providerSelectionSource: .explicitConfiguration,
                    configuredModelID: nil,
                    targetModelID: "gpt-5.6-luna",
                    targetModelAdvertised: false,
                    catalogModelCount: 3,
                    defaultModelID: "gpt-5.4",
                    capabilities:
                        CodexProviderCatalogCapabilities(
                            namespaceTools: false,
                            imageGeneration: false,
                            webSearch: true
                        )
                )
        )

        let reflected = String(reflecting: runtime.report)
        #expect(!reflected.contains("must-not-be-retained"))
        #expect(!reflected.contains("/Users/private"))
        #expect(!reflected.contains("secret"))
    }

    @Test
    func recordsPinnedCodexBuiltInDefaultProviderProvenance() throws {
        let fixture = ProviderCatalogPreflightFixture()
        let runtime = try fixture.makeRuntime()
        _ = try runtime.begin()
        _ = try runtime.receive(fixture.initializeResponse)

        #expect(
            try decode(
                runtime.receive(
                    fixture.configResponse(provider: nil)
                )
            ) == [[
                "id": .number(3),
                "method": .string(
                    "modelProvider/capabilities/read"
                ),
                "params": .object([:]),
            ]]
        )
        _ = try runtime.receive(fixture.providerCapabilitiesResponse)
        _ = try runtime.receive(fixture.modelPage(data: []))

        #expect(runtime.report?.effectiveProviderID == "openai")
        #expect(
            runtime.report?.providerSelectionSource
                == .codexBuiltInDefault
        )
    }

    @Test
    func targetModelMayMatchCatalogIDOrModelName() throws {
        let fixture = ProviderCatalogPreflightFixture()

        for targetField in ["id", "model"] {
            let runtime = try fixture.makeRuntime()
            _ = try runtime.begin()
            _ = try runtime.receive(fixture.initializeResponse)
            _ = try runtime.receive(fixture.configResponse)
            _ = try runtime.receive(fixture.providerCapabilitiesResponse)
            let model: [String: JSONValue] = [
                "description": .string("must-not-be-retained"),
                "displayName": .string("must-not-be-retained"),
                "id": .string(
                    targetField == "id"
                        ? "gpt-5.6-luna" : "catalog-alias"
                ),
                "isDefault": .bool(false),
                "model": .string(
                    targetField == "model"
                        ? "gpt-5.6-luna" : "provider-model"
                ),
            ]

            _ = try runtime.receive(
                fixture.modelPage(data: [.object(model)])
            )

            #expect(runtime.report?.targetModelAdvertised == true)
        }
    }

    @Test
    func defaultModelIdentifierRemainsTheCatalogID() throws {
        let fixture = ProviderCatalogPreflightFixture()
        let runtime = try fixture.makeRuntime()
        _ = try runtime.begin()
        _ = try runtime.receive(fixture.initializeResponse)
        _ = try runtime.receive(fixture.configResponse)
        _ = try runtime.receive(fixture.providerCapabilitiesResponse)

        _ = try runtime.receive(
            fixture.modelPage(data: [
                fixture.model(
                    id: "catalog-default",
                    model: "provider-model-name",
                    isDefault: true
                ),
            ])
        )

        #expect(runtime.report?.defaultModelID == "catalog-default")
    }

    @Test
    func rejectsLoginThreadTurnWriteAndNotifications() throws {
        let fixture = ProviderCatalogPreflightFixture()

        for forbidden in [
            ("account/login/start", 90),
            ("thread/start", 91),
            ("turn/start", 92),
            ("config/value/write", 93),
        ] {
            let runtime = try fixture.makeRuntime()
            _ = try runtime.begin()

            #expect(
                throws: CodexProviderCatalogPreflightError
                    .unexpectedRequest(method: forbidden.0)
            ) {
                _ = try runtime.receive(
                    fixture.request(
                        id: forbidden.1,
                        method: forbidden.0
                    )
                )
            }
            #expect(runtime.status == .failed)
        }

        let notificationRuntime = try fixture.makeRuntime()
        _ = try notificationRuntime.begin()
        #expect(
            throws: CodexProviderCatalogPreflightError
                .unexpectedNotification(
                    method: "account/updated"
                )
        ) {
            _ = try notificationRuntime.receive(
                fixture.notification(
                    method: "account/updated",
                    params: [
                        "message": .string(
                            "/Users/private must-not-be-retained"
                        ),
                    ]
                )
            )
        }
        let reflected = String(
            reflecting:
                CodexProviderCatalogPreflightError
                .unexpectedNotification(
                    method: "account/updated"
                )
        )
        #expect(!reflected.contains("must-not-be-retained"))
        #expect(!reflected.contains("/Users/private"))
    }

    @Test
    func acceptsOnlyDisabledRemoteControlStartupNotification() throws {
        let fixture = ProviderCatalogPreflightFixture()
        let runtime = try fixture.makeRuntime()
        _ = try runtime.begin()

        #expect(
            try runtime.receive(
                fixture.notification(
                    method: "remoteControl/status/changed",
                    params: [
                        "environmentId": .null,
                        "status": .string("disabled"),
                    ]
                )
            ).isEmpty
        )
        #expect(runtime.status == .running)
        #expect(
            try decode(
                runtime.receive(fixture.initializeResponse)
            ).contains {
                $0["method"] == .string("config/read")
            }
        )

        for params: [String: JSONValue] in [
            [
                "environmentId": .string("private-environment"),
                "status": .string("connected"),
            ],
            [
                "environmentId": .null,
                "status": .string("connected"),
            ],
        ] {
            let rejected = try fixture.makeRuntime()
            _ = try rejected.begin()
            #expect(
                throws: CodexProviderCatalogPreflightError
                    .unexpectedNotification(
                        method: "remoteControl/status/changed"
                    )
            ) {
                _ = try rejected.receive(
                    fixture.notification(
                        method: "remoteControl/status/changed",
                        params: params
                    )
                )
            }
        }
    }

    @Test
    func malformedProviderCatalogOrPaginationFailsClosed() throws {
        let fixture = ProviderCatalogPreflightFixture()

        let serverErrorRuntime = try fixture.makeRuntime()
        _ = try serverErrorRuntime.begin()
        #expect(
            throws: CodexProviderCatalogPreflightError
                .serverError(code: -32_602)
        ) {
            _ = try serverErrorRuntime.receive(
                line([
                    "error": .object([
                        "code": .number(-32_602),
                        "data": .object([
                            "path": .string(
                                "/Users/private must-not-be-retained"
                            ),
                        ]),
                        "message": .string(
                            "secret must-not-be-retained"
                        ),
                    ]),
                    "id": .number(1),
                ])
            )
        }
        let reflected = String(
            reflecting:
                CodexProviderCatalogPreflightError
                .serverError(code: -32_602)
        )
        #expect(!reflected.contains("must-not-be-retained"))
        #expect(!reflected.contains("/Users/private"))

        for response in [
            fixture.configResponse(provider: "/Users/private"),
            fixture.configResponse(provider: ""),
        ] {
            let runtime = try fixture.makeRuntime()
            _ = try runtime.begin()
            _ = try runtime.receive(fixture.initializeResponse)

            #expect(
                throws: CodexProviderCatalogPreflightError
                    .invalidMessage
            ) {
                _ = try runtime.receive(response)
            }
            #expect(runtime.status == .failed)
        }

        let invalidCapabilities = try fixture.makeRuntime()
        _ = try invalidCapabilities.begin()
        _ = try invalidCapabilities.receive(fixture.initializeResponse)
        _ = try invalidCapabilities.receive(fixture.configResponse)
        #expect(
            throws: CodexProviderCatalogPreflightError
                .invalidMessage
        ) {
            _ = try invalidCapabilities.receive(
                fixture.providerCapabilitiesResponse(
                    webSearch: .string("true")
                )
            )
        }
        #expect(invalidCapabilities.status == .failed)

        let duplicateDefault = try fixture.runningRuntime()
        #expect(
            throws: CodexProviderCatalogPreflightError
                .invalidCatalog
        ) {
            _ = try duplicateDefault.receive(
                fixture.modelPage(data: [
                    fixture.model(
                        id: "one",
                        model: "one",
                        isDefault: true
                    ),
                    fixture.model(
                        id: "two",
                        model: "two",
                        isDefault: true
                    ),
                ])
            )
        }

        let repeatedCursor = try fixture.runningRuntime()
        _ = try repeatedCursor.receive(
            fixture.modelPage(
                data: [
                    fixture.model(
                        id: "one",
                        model: "one",
                        isDefault: true
                    ),
                ],
                nextCursor: "1"
            )
        )
        #expect(
            throws: CodexProviderCatalogPreflightError
                .invalidCatalog
        ) {
            _ = try repeatedCursor.receive(
                fixture.modelPage(
                    data: [
                        fixture.model(
                            id: "two",
                            model: "two",
                            isDefault: false
                        ),
                    ],
                    nextCursor: "1",
                    responseID: 5
                )
            )
        }
    }

    @Test
    func inputAndCatalogBoundsFailClosed() throws {
        let fixture = ProviderCatalogPreflightFixture()
        let runtime = try fixture.makeRuntime(maximumInputLineBytes: 128)
        _ = try runtime.begin()

        #expect(
            throws: CodexProviderCatalogPreflightError
                .inputLimitExceeded
        ) {
            _ = try runtime.receive(
                Data(repeating: 0x41, count: 129)
            )
        }

        let catalogRuntime = try fixture.runningRuntime(
            maximumCatalogModels: 1
        )
        #expect(
            throws: CodexProviderCatalogPreflightError
                .catalogLimitExceeded
        ) {
            _ = try catalogRuntime.receive(
                fixture.modelPage(data: [
                    fixture.model(
                        id: "one",
                        model: "one",
                        isDefault: true
                    ),
                    fixture.model(
                        id: "two",
                        model: "two",
                        isDefault: false
                    ),
                ])
            )
        }
    }
}

private struct ProviderCatalogPreflightFixture {
    let runtimeURL = URL(
        filePath: "/private/tmp/stornaut/provider-preflight/runtime",
        directoryHint: .isDirectory
    )
    let workURL = URL(
        filePath: "/private/tmp/stornaut/provider-preflight/work",
        directoryHint: .isDirectory
    )

    var initializeResponse: Data {
        line([
            "id": .number(1),
            "result": .object([
                "codexHome": .string(runtimeURL.path),
                "platformFamily": .string("unix"),
                "platformOs": .string("macos"),
                "userAgent": .string("codex_cli_rs/0.147.0"),
            ]),
        ])
    }

    var configResponse: Data {
        configResponse(provider: "openai")
    }

    var providerCapabilitiesResponse: Data {
        providerCapabilitiesResponse(webSearch: .bool(true))
    }

    var firstModelPage: Data {
        modelPage(
            data: [
                model(
                    id: "gpt-5.4",
                    model: "gpt-5.4",
                    isDefault: true
                ),
                model(
                    id: "gpt-5.3",
                    model: "gpt-5.3",
                    isDefault: false
                ),
            ],
            nextCursor: "2"
        )
    }

    var secondModelPage: Data {
        modelPage(
            data: [
                model(
                    id: "gpt-5.2",
                    model: "gpt-5.2",
                    isDefault: false
                ),
            ],
            responseID: 5
        )
    }

    func makeRuntime(
        maximumInputLineBytes: Int = 1 * 1_024 * 1_024,
        maximumCatalogModels: Int = 1_000
    ) throws -> CodexProviderCatalogPreflightRuntime {
        try CodexProviderCatalogPreflightRuntime(
            request: CodexProviderCatalogPreflightRequest(
                runtimeHomeURL: runtimeURL,
                workingDirectoryURL: workURL,
                targetModel: .gpt56Luna,
                maximumInputLineBytes: maximumInputLineBytes,
                maximumCatalogModels: maximumCatalogModels
            )
        )
    }

    func runningRuntime(
        maximumCatalogModels: Int = 1_000
    ) throws -> CodexProviderCatalogPreflightRuntime {
        let runtime = try makeRuntime(
            maximumCatalogModels: maximumCatalogModels
        )
        _ = try runtime.begin()
        _ = try runtime.receive(initializeResponse)
        _ = try runtime.receive(configResponse)
        _ = try runtime.receive(providerCapabilitiesResponse)
        return runtime
    }

    func configResponse(provider: String?) -> Data {
        line([
            "id": .number(2),
            "result": .object([
                "config": .object([
                    "model": .null,
                    "model_provider":
                        provider.map(JSONValue.string) ?? .null,
                    "secret": .string("must-not-be-retained"),
                ]),
                "layers": .null,
                "origins": .object([:]),
            ]),
        ])
    }

    func providerCapabilitiesResponse(
        webSearch: JSONValue
    ) -> Data {
        line([
            "id": .number(3),
            "result": .object([
                "imageGeneration": .bool(false),
                "namespaceTools": .bool(false),
                "webSearch": webSearch,
            ]),
        ])
    }

    func modelPage(
        data: [JSONValue],
        nextCursor: String? = nil,
        responseID: Int = 4
    ) -> Data {
        line([
            "id": .number(responseID),
            "result": .object([
                "data": .array(data),
                "nextCursor": nextCursor.map(JSONValue.string) ?? .null,
            ]),
        ])
    }

    func model(
        id: String,
        model: String,
        isDefault: Bool
    ) -> JSONValue {
        .object([
            "description": .string("must-not-be-retained"),
            "displayName": .string("must-not-be-retained"),
            "id": .string(id),
            "isDefault": .bool(isDefault),
            "model": .string(model),
        ])
    }

    func request(id: Int, method: String) -> Data {
        line([
            "id": .number(id),
            "method": .string(method),
            "params": .object([:]),
        ])
    }

    func notification(
        method: String,
        params: [String: JSONValue] = [:]
    ) -> Data {
        line([
            "method": .string(method),
            "params": .object(params),
        ])
    }
}

private func decode(
    _ lines: [Data]
) throws -> [[String: JSONValue]] {
    try lines.map { data in
        let value = try JSONDecoder().decode(JSONValue.self, from: data)
        guard case let .object(object) = value else {
            throw ProviderCatalogPreflightTestError.invalidLine
        }
        return object
    }
}

private func line(_ object: [String: JSONValue]) -> Data {
    var data = try! JSONEncoder().encode(JSONValue.object(object))
    data.append(0x0A)
    return data
}

private enum ProviderCatalogPreflightTestError: Error {
    case invalidLine
}

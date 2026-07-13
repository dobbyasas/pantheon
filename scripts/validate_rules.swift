import Foundation
import WebKit

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    fputs("usage: validate_rules.swift <blockerList.json>\n", stderr)
    exit(64)
}

let rulesURL = URL(fileURLWithPath: arguments[1])
let rules: String
let decodedRules: [[String: Any]]

do {
    rules = try String(contentsOf: rulesURL, encoding: .utf8)
    let data = Data(rules.utf8)
    let decoded = try JSONSerialization.jsonObject(with: data)
    guard let array = decoded as? [[String: Any]], !array.isEmpty else {
        throw NSError(
            domain: "PantheonRules",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "The rule list must be a non-empty JSON array."]
        )
    }
    decodedRules = array
    print("JSON valid: \(array.count) rules")
} catch {
    fputs("JSON validation failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}

func compile(_ encodedRules: String) -> Error? {
    let semaphore = DispatchSemaphore(value: 0)
    var compilationError: Error?

    WKContentRuleListStore.default().compileContentRuleList(
        forIdentifier: "PantheonValidation-\(UUID().uuidString)",
        encodedContentRuleList: encodedRules
    ) { compiledList, error in
        if compiledList == nil {
            compilationError = error ?? NSError(
                domain: "PantheonRules",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "WebKit returned no compiled rule list."]
            )
        }
        semaphore.signal()
    }

    while semaphore.wait(timeout: .now() + 0.1) == .timedOut {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
    }

    return compilationError
}

func describe(_ error: Error) -> String {
    let error = error as NSError
    return "\(error.domain) code \(error.code): \(error.userInfo)"
}

let baselineRule = #"[{"trigger":{"url-filter":".*"},"action":{"type":"block"}}]"#
if let baselineError = compile(baselineRule) {
    fputs("WebKit compiler is unavailable in this process: \(describe(baselineError))\n", stderr)
    exit(2)
}

if let compilationError = compile(rules) {
    fputs("WebKit compilation failed: \(describe(compilationError))\n", stderr)
    for (index, rule) in decodedRules.enumerated() {
        guard let data = try? JSONSerialization.data(withJSONObject: [rule]),
              let encodedRule = String(data: data, encoding: .utf8),
              let ruleError = compile(encodedRule) else {
            continue
        }
        let filter = (rule["trigger"] as? [String: Any])?["url-filter"] as? String ?? "unknown"
        fputs("Rejected rule \(index + 1) (\(filter)): \(describe(ruleError))\n", stderr)
    }
    exit(1)
}

print("WebKit content-rule compilation succeeded")

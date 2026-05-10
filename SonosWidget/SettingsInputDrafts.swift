enum SettingsInputField: Hashable {
    case relayURL
    case agentURL
    case agentToken
}

struct SettingsInputDrafts {
    var relayURL: String
    var agentURL: String
    var agentToken: String

    func commit(
        focusedField: SettingsInputField?,
        relayURL saveRelayURL: (String) -> Void,
        agentURL saveAgentURL: (String) -> Void,
        agentToken saveAgentToken: (String) -> Void
    ) -> SettingsInputField? {
        switch focusedField {
        case .relayURL:
            saveRelayURL(relayURL)
        case .agentURL:
            saveAgentURL(agentURL)
        case .agentToken:
            saveAgentToken(agentToken)
        case nil:
            break
        }

        return nil
    }
}

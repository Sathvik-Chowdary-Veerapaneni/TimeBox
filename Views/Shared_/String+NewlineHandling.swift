extension String {
    func appendingDashIfNeeded(previous: String) -> String {
        // If new text is longer and ends with a newline, append "- "
        if self.count > previous.count, self.hasSuffix("\n") {
            return self + "- "
        }
        return self
    }
}

import Foundation

public struct WordContext: Equatable {
    let secondBefore: String?
    let firstBefore: String?
    let word: String
    let firstAfter: String?
    let secondAfter: String?

    init(secondBefore: String? = nil,
         firstBefore: String? = nil,
         word: String,
         firstAfter: String? = nil,
         secondAfter: String? = nil) {
        self.secondBefore = secondBefore
        self.firstBefore = firstBefore
        self.word = word
        self.firstAfter = firstAfter
        self.secondAfter = secondAfter
    }

    public func isContinuation(of context: WordContext) -> Bool {
        guard context.secondBefore == self.secondBefore,
            context.firstBefore == self.firstBefore,
            context.firstAfter == self.firstAfter,
            context.secondAfter == self.secondAfter else {
                return false
        }

        let didAddSingleCharacter = self.word.dropLast() == context.word
        let didDeleteSingleCharacter = context.word.dropLast() == self.word
        return didAddSingleCharacter || didDeleteSingleCharacter
    }

    public func contextAttributedString() -> NSAttributedString {
        var contextString = word
        if let firstBefore = firstBefore {
            contextString = firstBefore + " " + contextString
        }
        if let secondBefore = secondBefore {
            contextString = secondBefore + " " + contextString
        }
        if let firstAfter = firstAfter {
            contextString += " " + firstAfter
        }
        if let secondAfter = secondAfter {
            contextString += " " + secondAfter
        }

        return contextString.bolden(substring: word)
    }
}

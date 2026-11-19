// Minimal stand-ins for TelegramCore / SwiftSignalKit so GhostUploadActivityController.swift
// can be type-checked on its own in plugin-check.yml. Not part of the app.
import Foundation

struct AccountRecordId: Hashable {
    let value: Int64
}

final class Account {
    let id = AccountRecordId(value: 1)
}

enum NoError {}

protocol Disposable {
    func dispose()
}

final class StubDisposable: Disposable {
    func dispose() {}
}

final class Signal<T, E> {
    func start(next: @escaping (T) -> Void) -> Disposable {
        return StubDisposable()
    }
}

precedencegroup StubPipeRight {
    associativity: left
    higherThan: DefaultPrecedence
}

infix operator |> : StubPipeRight

func |> <T, U>(value: T, function: (T) -> U) -> U {
    return function(value)
}

func deliverOnMainQueue<T, E>(_ signal: Signal<T, E>) -> Signal<T, E> {
    return signal
}

struct GhostUploadSnapshot: Equatable {
    let count: Int
    let progress: Double
    let totalBytes: Int64
    let kind: String
}

func ghostUploadSnapshots(account: Account) -> Signal<GhostUploadSnapshot, NoError> {
    return Signal()
}

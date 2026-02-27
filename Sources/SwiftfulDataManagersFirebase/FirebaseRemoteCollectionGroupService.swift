//
//  FirebaseRemoteCollectionGroupService.swift
//  SwiftfulDataManagersFirebase
//
//  Created by Andrew Coyle on 27/02/2026.
//

import Foundation
import FirebaseFirestore
import SwiftfulFirestore
import SwiftfulDataManagers

@MainActor
public final class FirebaseRemoteCollectionGroupService<T: DataSyncModelProtocol>: RemoteCollectionGroupService {
    private let collectionGroupName: String
    private var listenerTask: Task<Void, Never>?

    public init(collectionGroupName: String) {
        self.collectionGroupName = collectionGroupName
    }

    private var collectionGroup: Query {
        Firestore.firestore().collectionGroup(collectionGroupName)
    }

    public func getDocuments(query: QueryBuilder) async throws -> [T] {
        let firestoreQuery = buildFirestoreQuery(from: query)
        return try await firestoreQuery.getAllDocuments()
    }

    public func streamCollection(query: QueryBuilder) -> AsyncThrowingStream<[T], Error> {
        let firestoreQuery = buildFirestoreQuery(from: query)
        return firestoreQuery.streamAllDocuments()
    }

    public func streamCollectionUpdates(query: QueryBuilder) -> (
        updates: AsyncThrowingStream<T, Error>,
        deletions: AsyncThrowingStream<String, Error>
    ) {
        var updatesCont: AsyncThrowingStream<T, Error>.Continuation?
        var deletionsCont: AsyncThrowingStream<String, Error>.Continuation?

        let updates = AsyncThrowingStream<T, Error> { continuation in
            updatesCont = continuation
            continuation.onTermination = { @Sendable _ in
                Task { await self.listenerTask?.cancel() }
            }
        }

        let deletions = AsyncThrowingStream<String, Error> { continuation in
            deletionsCont = continuation
            continuation.onTermination = { @Sendable _ in
                Task { await self.listenerTask?.cancel() }
            }
        }

        listenerTask = Task {
            do {
                let firestoreQuery = buildFirestoreQuery(from: query)
                for try await change in firestoreQuery.streamAllDocumentChanges() as AsyncThrowingStream<SwiftfulFirestore.DocumentChange<T>, Error> {
                    switch change.type {
                    case .added, .modified:
                        updatesCont?.yield(change.document)
                    case .removed:
                        deletionsCont?.yield(change.document.id)
                    }
                }
            } catch {
                updatesCont?.finish(throwing: error)
                deletionsCont?.finish(throwing: error)
            }
        }

        return (updates, deletions)
    }

    // MARK: - Private

    /// Builds a Firestore Query by applying QueryBuilder operations to the collectionGroup base query.
    ///
    /// Note: Firestore collectionGroup queries do not support cursor operations (startAt, startAfter,
    /// endAt, endBefore) unless the query is also ordered by __name__. Passing cursor operations
    /// without that ordering will cause Firestore to throw at runtime — this is a Firestore limitation.
    private func buildFirestoreQuery(from query: QueryBuilder) -> Query {
        var firestoreQuery: Query = collectionGroup

        for operation in query.getOperations() {
            switch operation {
            case .filter(let filter):
                firestoreQuery = applyFilter(filter, to: firestoreQuery)
            case .order(let order):
                firestoreQuery = firestoreQuery.order(by: order.field, descending: order.descending)
            case .limit(let value):
                firestoreQuery = firestoreQuery.limit(to: value)
            case .limitToLast(let value):
                firestoreQuery = firestoreQuery.limit(toLast: value)
            case .startAt(let cursor):
                firestoreQuery = firestoreQuery.start(at: cursor.values)
            case .startAfter(let cursor):
                firestoreQuery = firestoreQuery.start(after: cursor.values)
            case .endAt(let cursor):
                firestoreQuery = firestoreQuery.end(at: cursor.values)
            case .endBefore(let cursor):
                firestoreQuery = firestoreQuery.end(before: cursor.values)
            }
        }

        return firestoreQuery
    }

    private func applyFilter(_ filter: QueryFilter, to query: Query) -> Query {
        switch filter.operator {
        case .isEqualTo:
            return query.whereField(filter.field, isEqualTo: filter.value)
        case .isNotEqualTo:
            return query.whereField(filter.field, isNotEqualTo: filter.value)
        case .isGreaterThan:
            return query.whereField(filter.field, isGreaterThan: filter.value)
        case .isLessThan:
            return query.whereField(filter.field, isLessThan: filter.value)
        case .isGreaterThanOrEqualTo:
            return query.whereField(filter.field, isGreaterThanOrEqualTo: filter.value)
        case .isLessThanOrEqualTo:
            return query.whereField(filter.field, isLessThanOrEqualTo: filter.value)
        case .arrayContains:
            return query.whereField(filter.field, arrayContains: filter.value)
        case .in:
            if let array = filter.value as? [Any] {
                return query.whereField(filter.field, in: array)
            }
            return query
        case .notIn:
            if let array = filter.value as? [Any] {
                return query.whereField(filter.field, notIn: array)
            }
            return query
        case .arrayContainsAny:
            if let array = filter.value as? [Any] {
                return query.whereField(filter.field, arrayContainsAny: array)
            }
            return query
        }
    }
}

# Firebase for SwiftfulDataManagers

Add Firebase Firestore support to a Swift application through SwiftfulDataManagers framework.

See documentation in the parent repo: https://github.com/SwiftfulThinking/SwiftfulDataManagers

## Setup

```swift
dependencies: [
    .package(url: "https://github.com/SwiftfulThinking/SwiftfulDataManagersFirebase.git", branch: "main")
]
```

```swift
import SwiftfulDataManagers
import SwiftfulDataManagersFirebase
```

## Example Configuration

```swift
// DocumentSyncEngine — static path
let userSyncEngine = DocumentSyncEngine<UserModel>(
    remote: FirebaseRemoteDocumentService(collectionPath: { "users" }),
    managerKey: "user",
    enableLocalPersistence: true,
    logger: logManager
)

// DocumentSyncEngine — dynamic path
let settingsSyncEngine = DocumentSyncEngine<UserSettings>(
    remote: FirebaseRemoteDocumentService(
        collectionPath: { [weak authManager] in
            guard let uid = authManager?.currentUserId else { return nil }
            return "users/\(uid)/settings"
        }
    ),
    managerKey: "settings"
)

// CollectionSyncEngine — static path
let productsSyncEngine = CollectionSyncEngine<Product>(
    remote: FirebaseRemoteCollectionService(collectionPath: { "products" }),
    managerKey: "products",
    enableLocalPersistence: true,
    logger: logManager
)

// CollectionSyncEngine — dynamic path
let watchlistSyncEngine = CollectionSyncEngine<WatchlistItem>(
    remote: FirebaseRemoteCollectionService(
        collectionPath: { [weak authManager] in
            guard let uid = authManager?.currentUserId else { return nil }
            return "users/\(uid)/watchlist"
        }
    ),
    managerKey: "watchlist"
)

// CollectionGroupSyncEngine — queries across all subcollections with the same name
let reviewsSyncEngine = CollectionGroupSyncEngine<Review>(
    remote: FirebaseRemoteCollectionGroupService(collectionGroupName: "reviews"),
    managerKey: "reviews"
)
```

## Example Actions

```swift
// DocumentSyncEngine
try await userSyncEngine.startListening(documentId: "user_123")
try await userSyncEngine.saveDocument(user)
try await userSyncEngine.updateDocument(data: ["name": "John"])
let user = userSyncEngine.currentDocument
let user = try await userSyncEngine.getDocumentAsync()
userSyncEngine.stopListening()

// CollectionSyncEngine
await productsSyncEngine.startListening()
try await productsSyncEngine.saveDocument(product)
try await productsSyncEngine.updateDocument(id: "product_123", data: ["price": 29.99])
let products = productsSyncEngine.currentCollection
let product = productsSyncEngine.getDocument(id: "product_123")
let results = try await productsSyncEngine.getDocumentsAsync(buildQuery: { query in
    query.where("category", isEqualTo: "electronics")
})
productsSyncEngine.stopListening()

// CollectionGroupSyncEngine
await reviewsSyncEngine.startListening()
let reviews = reviewsSyncEngine.currentCollection
let topReviews = try await reviewsSyncEngine.getDocumentsAsync(buildQuery: { query in
    query.where("rating", isGreaterThanOrEqualTo: 4)
         .order("createdAt", descending: true)
         .limit(50)
})
reviewsSyncEngine.stopListening()
```

## Collection Group Queries

<details>
<summary> Details (Click to expand) </summary>
<br>

`FirebaseRemoteCollectionGroupService` queries across **all subcollections** that share the same name, regardless of their parent document. This is useful when you store the same sub-collection type under many different parent documents and need to query them together.

**Example:** if your Firestore structure is:

```
products/{productId}/reviews/{reviewId}
posts/{postId}/reviews/{reviewId}
```

A collection group query on `"reviews"` returns documents from both paths.

### Setup

```swift
let reviewsSyncEngine = CollectionGroupSyncEngine<Review>(
    remote: FirebaseRemoteCollectionGroupService(collectionGroupName: "reviews"),
    managerKey: "all-reviews"
)
```

### Firestore index requirement

Collection group queries require a **collection group index** in Firestore. Create one in the Firebase console:

* Firebase Console -> Firestore Database -> Indexes -> Composite -> Add index
* Set the collection group name and the fields you intend to filter/order on.

### Cursor pagination limitation

Firestore does not support cursor operations (`startAt`, `startAfter`, `endAt`, `endBefore`) on collection group queries unless the query is also ordered by `__name__`. Passing cursor operations without that ordering will cause Firestore to throw at runtime.

### Security rules

Collection group security rules use `match /{path=**}/reviews/{reviewId}` instead of a fixed path:

```javascript
match /{path=**}/reviews/{reviewId} {
    allow read: if request.auth != null;
}
```

</details>

## Dynamic Collection Paths

<details>
<summary> Details (Click to expand) </summary>
<br>

Firebase services use closures for collection paths, supporting both static and dynamic paths:

### Static Paths

```swift
// Simple collection
FirebaseRemoteDocumentService<UserModel>(
    collectionPath: { "users" }
)
// Creates: users/{documentId}

// Nested collection with hardcoded IDs
FirebaseRemoteCollectionService<CommentModel>(
    collectionPath: { "posts/post123/comments" }
)
// Creates: posts/post123/comments/{documentId}
```

### Dynamic Paths

```swift
// Path depends on runtime value (e.g., current user)
let watchlistSyncEngine = CollectionSyncEngine<WatchlistItem>(
    remote: FirebaseRemoteCollectionService(
        collectionPath: { [weak authManager] in
            guard let uid = authManager?.currentUserId else { return nil }
            return "users/\(uid)/watchlist"
        }
    ),
    managerKey: "watchlist"
)

// Multiple nesting levels
let repliesSyncEngine = CollectionSyncEngine<ReplyModel>(
    remote: FirebaseRemoteCollectionService(
        collectionPath: {
            guard let postId = currentPostId,
                  let commentId = currentCommentId else {
                return nil
            }
            return "posts/\(postId)/comments/\(commentId)/replies"
        }
    ),
    managerKey: "replies"
)
```

**Use cases:**
- User-specific subcollections (favorites, settings, posts)
- Hierarchical data structures (comments, replies)
- Scoped collections per entity
- Engine initialization before authentication

**Error handling:**
When the closure returns `nil`, operations will throw `FirebaseServiceError.collectionPathNotAvailable`. This allows engines to be created before the path is available (e.g., before login), and operations will automatically fail with a clear error until the path becomes available.

</details>

## Firebase Firestore Setup

<details>
<summary> Details (Click to expand) </summary>
<br>

Firebase docs: https://firebase.google.com/docs/firestore

### 1. Enable Firestore in Firebase console
* Firebase Console -> Build -> Firestore Database -> Create Database

### 2. Set Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow authenticated users to read/write their own documents
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Allow authenticated users to read all products, write if admin
    match /products/{document=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.token.admin == true;
    }

    // Add more rules as needed
  }
}
```

### 3. Add Firebase SDK to your project

```swift
dependencies: [
    .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.0.0"),
    .package(url: "https://github.com/SwiftfulThinking/SwiftfulDataManagersFirebase.git", branch: "main")
]
```

### 4. Initialize Firebase in your app

```swift
import Firebase

// In App init or AppDelegate
FirebaseApp.configure()
```

</details>

## Streaming Updates Pattern

<details>
<summary> Details (Click to expand) </summary>
<br>

### Document Streaming

FirebaseRemoteDocumentService provides real-time document updates:

```swift
func streamDocument(id: String) -> AsyncThrowingStream<T?, Error>
```

### Collection Streaming

`FirebaseRemoteCollectionService` follows a hybrid pattern used by `CollectionSyncEngine`:

```swift
// 1. Bulk load all documents first
let collection = try await service.getCollection()

// 2. Stream individual updates/deletions
func streamCollectionUpdates() -> (
    updates: AsyncThrowingStream<T, Error>,
    deletions: AsyncThrowingStream<String, Error>
)
```

This pattern prevents unnecessary full collection re-fetches and efficiently handles individual document changes.

### Collection Group Streaming

`FirebaseRemoteCollectionGroupService` exposes the same query-scoped streaming API used by `CollectionGroupSyncEngine`:

```swift
// Fetch once with a filter
let reviews = try await service.getDocuments(query: query)

// Stream all documents matching a query
let stream: AsyncThrowingStream<[T], Error> = service.streamCollection(query: query)

// Stream individual changes matching a query
let (updates, deletions) = service.streamCollectionUpdates(query: query)
```

All three methods accept a `QueryBuilder` to filter, order, and limit results before they reach Firestore. Only one `streamCollectionUpdates` listener is active at a time — starting a second call before cancelling the first will orphan the previous listener.

</details>

## Parent Repo

Full documentation and examples: https://github.com/SwiftfulThinking/SwiftfulDataManagers

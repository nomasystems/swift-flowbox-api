# swift-flowbox-api

Swift client and models (the `FlowboxAPI` library) for the [Flowbox](https://getflowbox.com) External API v2, generated from Flowbox's OpenAPI specification with [swift-openapi-generator](https://github.com/apple/swift-openapi-generator).

> **Unofficial.** This package is not made, endorsed or supported by Flowbox. The generated code is derived from the specification Flowbox publishes on [SwaggerHub](https://app.swaggerhub.com/apis-docs/FlowboxAB/External-API/v2).

Generated operations: posts of a flow, products, report a post and event tracking.

## Installation

```swift
.package(url: "<repository URL>", from: "<version>")
```

Add the `FlowboxAPI` product of the `swift-flowbox-api` package to your target. It re-exports `OpenAPIRuntime`, `OpenAPIURLSession` and `HTTPTypes`. Requires iOS 16 / macOS 13 and a toolchain that supports swift-tools 6.1 packages as dependencies (Xcode 16.3+).

## Usage

```swift
import FlowboxAPI

struct APIKeyMiddleware: ClientMiddleware {
    let apiKey: String

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[HTTPField.Name("api-key")!] = apiKey
        return try await next(request, body, baseURL)
    }
}

let configuration = URLSessionConfiguration.default
configuration.urlCache = URLCache(memoryCapacity: 10_000_000, diskCapacity: 50_000_000)
configuration.requestCachePolicy = .useProtocolCachePolicy

let client = Client(
    serverURL: URL(string: "https://external-api.getflowbox.com/v2")!,
    transport: URLSessionTransport(configuration: .init(session: URLSession(configuration: configuration))),
    middlewares: [APIKeyMiddleware(apiKey: "<api key>")]
)

let output = try await client.GetPostsByFlowKey(
    path: .init(flowKey: "<flow key>"),
    query: .init(_type: .tag, postsPerPage: 30, tags: "tag one,tag two", _operator: .OR, inclusive_feeds: "<flow key>")
)
let posts = try output.ok.body.json.data?.posts ?? []
```

## Behaviour of the real API

The published specification is not accurate in a few places, and some behaviour is not documented. This is what was observed against the real API:

- **Cursor.** `data.cursor` is an **integer** page counter (the spec says object). Send it back as the `cursor` query parameter to get the next page. The last page is shorter than `postsPerPage` and has `"cursor": null`; asking for a page beyond the end returns HTTP 200 with no posts and `"cursor": null`. Stop when the cursor is `nil` or the page is empty.
- **Tag flows.** `type=tag` requires `tags` (comma separated), otherwise the API answers 400.
- **Other flows' posts.** Send `inclusive_feeds=<flow key>` even though the flow key is already in the path. Without it the API answers 200 with posts from other flows of the account.
- **Product keys.** A post's `productKeys` is a JSON array encoded **inside a string** (`"[\"a\", \"b\"]"`), possibly with repeated keys.
- **Products.** `/products/{keys}` can answer 200 with an empty `products` array for a key that exists on a post.
- **Nulls.** Many fields that the spec declares as non-null (`text`, `userPermalink`, several product fields) can be `null`.
- **Prices** are strings.
- **Caching.** Responses carry `Cache-Control: max-age=<seconds>` and a weak `ETag` only some of the time; the `ETag` differs between identical requests, so conditional requests do not return 304. With `max-age` present `URLCache` serves repeated requests from cache; responses without it are not cached.

## Regenerating

```
./generate.sh            # downloads the upstream spec if missing, patches it, regenerates Sources/FlowboxAPI
./generate.sh --refresh  # downloads the upstream spec again first
```

- `Spec/patch-openapi.py` applies the corrections to the upstream spec: `cursor` becomes an integer (response and request) and `api-key` becomes a `securityScheme` instead of a parameter on every operation. It fails loudly if the upstream shape changes.
- `Spec/openapi-generator-config.yaml` selects the operations to generate.
- The first run builds `swift-openapi-generator` at a pinned version into `.build/`.
- The generated sources are the generator's raw output. Building them prints `UnusedImportAccess` warnings (`public import of 'Foundation' was not used in public declarations`): the generator (1.13.1) puts the same imports in every file. It is a known upstream issue ([swift-openapi-generator#946](https://github.com/apple/swift-openapi-generator/issues/946)), harmless, and the CI does not check warnings.
- The upstream spec (`Spec/upstream-openapi.json`) and the patched one (`Spec/openapi.json`) are **not committed**: they are Flowbox's content. The generated sources are committed and must not be edited by hand.

## Continuous integration

The `CI` workflow runs on pull requests, on pushes to `main` and on demand from the Actions tab. The Xcode version comes from `.xcode-version`. In one job it:

1. builds the package (`swift build`);
2. regenerates the sources from the current upstream spec (`./generate.sh --refresh`) and fails if they differ from the committed ones.

To update the client (for example when Flowbox changes its API): run `./generate.sh --refresh` locally, check that `swift build` succeeds, commit the result and open a pull request; the workflow confirms that the committed sources are exactly what the generator produces. If Flowbox changes its spec, any later pull request fails the second step until the sources are regenerated and committed.

## License

To be decided.

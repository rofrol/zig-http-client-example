# Zig HTTP Client Example - Visual Documentation

This document provides visual explanations of the Zig HTTP Client Example project using Mermaid diagrams.

## Project Overview

```mermaid
graph TD
    A[Main Function] --> B[HTTP Client]
    B --> C[URL Builder]
    B --> D[HTTP Request]
    C --> E[Parameter Encoder]
    E --> F[URL Encoder]
    D --> G[TCP Connection]
    D --> H[Response Parser]
```

The diagram above shows the main components of the HTTP client example and their relationships.

## Data Structures

```mermaid
classDiagram
    class HttpClient {
        +allocator: Allocator
        +init(allocator: Allocator): HttpClient
        +deinit(): void
        +buildUrl(base_url: []const u8, params: []const [2][]const u8): []const u8
        +get(url: []const u8): []const u8
    }

    class Url {
        +allocator: Allocator
        +scheme: []const u8
        +host: []const u8
        +port: u16
        +path: []const u8
        +query: ?[]const u8
        +path_with_query: []const u8
        +deinit(): void
    }

    HttpClient ..> Url : creates
```

The diagram above shows the main data structures in the project and their relationships.

## HTTP Request Flow

```mermaid
sequenceDiagram
    participant Main
    participant HttpClient
    participant URL Parser
    participant TCP Connection
    participant Remote Server

    Main->>HttpClient: buildUrl(base_url, params)
    HttpClient->>HttpClient: encodeParams(params)
    HttpClient-->>Main: url

    Main->>HttpClient: get(url)
    HttpClient->>URL Parser: parseUrl(url)
    URL Parser-->>HttpClient: parsed_url

    HttpClient->>TCP Connection: connect(parsed_url.host, parsed_url.port)
    HttpClient->>TCP Connection: write(request)
    TCP Connection->>Remote Server: HTTP Request
    Remote Server->>TCP Connection: HTTP Response
    TCP Connection-->>HttpClient: response data
    HttpClient-->>Main: response
```

The diagram above shows the flow of an HTTP request from the main function through the HTTP client to the remote server and back.

## URL Building Process

```mermaid
flowchart TD
    A[Start] --> B[Create URL Buffer]
    B --> C[Write Base URL]
    C --> D{Has Parameters?}
    D -- Yes --> E[Write '?']
    E --> F[Encode Parameters]
    F --> G[Write Parameters]
    D -- No --> H[Return URL]
    G --> H
```

The diagram above shows the process of building a URL with query parameters.

## Parameter Encoding Process

```mermaid
flowchart TD
    A[Start] --> B[Create BufMap]
    B --> C[Add Parameters to Map]
    C --> D[Create Buffer]
    D --> E[Iterate Through Map]
    E --> F{First Parameter?}
    F -- Yes --> G[Write Key=Value]
    F -- No --> H[Write &Key=Value]
    G --> I{More Parameters?}
    H --> I
    I -- Yes --> E
    I -- No --> J[Return Query String]
```

The diagram above shows the process of encoding parameters into a query string.

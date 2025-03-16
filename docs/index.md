# Zig HTTP Client Example Documentation

This documentation provides a visual explanation of the Zig HTTP Client Example project, including its structure, components, and the refactoring changes made to improve it.

## Overview

The Zig HTTP Client Example is a simple HTTP client implementation in Zig that demonstrates how to:

1. Build URLs with query parameters
2. Make HTTP GET requests
3. Parse HTTP responses
4. Handle errors and memory management

The project has been refactored to make better use of Zig's standard library functions, improving code quality, maintainability, and performance.

## Documentation Contents

- [Project Diagrams](project_diagrams.md) - Visual explanations of the project structure and components
- [Refactoring Diagrams](refactoring_diagrams.md) - Visual explanations of the refactoring changes

## Key Components

The project consists of the following key components:

1. **HttpClient** - The main client struct that provides methods for making HTTP requests
2. **URL Builder** - Functionality for building URLs with query parameters
3. **Parameter Encoder** - Functionality for encoding parameters into a query string
4. **URL Parser** - Functionality for parsing URLs into their components
5. **TCP Connection Handler** - Functionality for establishing TCP connections and sending/receiving data

## Refactoring Improvements

The refactoring process focused on the following areas:

1. **URL Handling** - Using standard library functions for URL parsing and manipulation
2. **Parameter Handling** - Using StringHashMap and BufMap for better parameter management
3. **String Manipulation** - Using standard library functions for string formatting and manipulation
4. **Error Handling** - Using errdefer for better error handling and resource cleanup
5. **Memory Management** - Using standard library functions for memory allocation and management
6. **Testing** - Improving test organization and coverage

## Usage Example

```zig
// Create an HTTP client
var client = HttpClient.init(allocator);
defer client.deinit();

// Build parameters
var params = std.StringHashMap([]const u8).init(allocator);
defer params.deinit();
try params.put("key1", "value1");
try params.put("key2", "value2");

// Convert to array for buildUrl
var param_array = ArrayList([2][]const u8).init(allocator);
defer param_array.deinit();
var it = params.iterator();
while (it.next()) |entry| {
    try param_array.append(.{ entry.key_ptr.*, entry.value_ptr.* });
}

// Build a URL with query parameters
const url = try client.buildUrl("http://example.com/api", param_array.items);
defer allocator.free(url);

// Make a GET request
const response = try client.get(url);
defer allocator.free(response);

// Print the response
std.debug.print("Response: {s}\n", .{response});
```

## Conclusion

The Zig HTTP Client Example demonstrates how to implement a simple HTTP client in Zig, making effective use of the standard library. The refactoring changes have improved the code quality, maintainability, and performance, making it a good example of idiomatic Zig code.

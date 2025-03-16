# Zig HTTP Client Example

A simple HTTP client implementation in Zig that demonstrates how to make HTTP requests, handle responses, and manage memory efficiently.

## Features

- Build URLs with query parameters
- Make HTTP GET requests
- Parse HTTP responses
- Efficient memory management
- Comprehensive test suite

## Documentation

Visual documentation of the project structure and components is available in the [docs](docs) directory:

- [Project Overview](docs/index.md)
- [Project Diagrams](docs/project_diagrams.md)
- [Refactoring Diagrams](docs/refactoring_diagrams.md)

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

## Building and Running

To build and run the project:

```bash
zig build run
```

To run the tests:

```bash
zig build test
```

## Project Structure

- `src/main.zig` - Main source file containing the HTTP client implementation
- `src/root.zig` - Root source file for the library
- `docs/` - Documentation including diagrams and explanations
- `build.zig` - Build script for the project

## License

This project is licensed under the MIT License - see the LICENSE file for details.

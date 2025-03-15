const std = @import("std");
const net = std.net;
const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

pub fn main() !void {
    // Create general purpose allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Create a new HTTP client
    var client = HttpClient.init(allocator);
    defer client.deinit();

    // Generate timestamp parameter dynamically
    var timestamp_buffer: [32]u8 = undefined;
    const timestamp = try getTimestampStr(&timestamp_buffer);
    
    // Build parameters list with dynamic timestamp parameter
    const ParamPair = [2][]const u8;
    var params = ArrayList(ParamPair).init(allocator);
    defer params.deinit();
    
    try params.appendSlice(&[_]ParamPair{
        .{ "key1", "val1" },
        .{ "key2", "value with spaces" },
        .{ "special", "!@#$%^&*()" },
    });
    
    // Add timestamp parameter
    try params.append(.{ "timestamp", timestamp });
    
    // Print all parameters
    std.debug.print("Parameters:\n", .{});
    for (params.items) |param| {
        std.debug.print("  {s}: {s}\n", .{ param[0], param[1] });
    }

    // Build a URL with query parameters
    const url = try client.buildUrl("http://httpbin.org/get", params.items);
    defer allocator.free(url);

    std.debug.print("Making request to: {s}\n", .{url});

    // Make a GET request
    const response = try client.get(url);
    defer allocator.free(response);

    // Print the response
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Response:\n{s}\n", .{response});
}

/// Gets the current timestamp as a string
fn getTimestampStr(buffer: []u8) ![]const u8 {
    const timestamp = std.time.timestamp();
    return std.fmt.bufPrint(buffer, "{d}", .{timestamp});
}

/// Simple HTTP client
pub const HttpClient = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) HttpClient {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *HttpClient) void {
        _ = self;
    }

    /// Builds a URL with query parameters
    pub fn buildUrl(
        self: *HttpClient,
        base_url: []const u8,
        params: []const [2][]const u8,
    ) ![]const u8 {
        var url_buffer = ArrayList(u8).init(self.allocator);
        defer url_buffer.deinit();

        const writer = url_buffer.writer();

        // Copy the base URL
        try writer.writeAll(base_url);

        // Add the query parameters
        if (params.len > 0) {
            try writer.writeByte('?');
            const query_string = try encodeParams(self.allocator, params);
            defer self.allocator.free(query_string);
            try writer.writeAll(query_string);
        }

        return url_buffer.toOwnedSlice();
    }

    /// Makes an HTTP GET request to the specified URL
    pub fn get(self: *HttpClient, url: []const u8) ![]const u8 {
        // Parse the URL
        var parsed_url = try parseUrl(self.allocator, url);
        defer parsed_url.deinit();

        // Resolve the hostname
        var ip_list = try net.getAddressList(self.allocator, parsed_url.host, parsed_url.port);
        defer ip_list.deinit();

        if (ip_list.addrs.len == 0) {
            return error.HostNotFound;
        }

        // Connect to the first IP address
        var stream = try net.tcpConnectToAddress(ip_list.addrs[0]);
        defer stream.close();

        // Build the HTTP request
        var request = ArrayList(u8).init(self.allocator);
        defer request.deinit();

        const req_writer = request.writer();

        try req_writer.print("GET {s} HTTP/1.1\r\n", .{parsed_url.path_with_query});
        try req_writer.print("Host: {s}\r\n", .{parsed_url.host});
        try req_writer.print("Connection: close\r\n", .{});
        try req_writer.print("User-Agent: Zig-HTTP-Client/0.1\r\n", .{});
        try req_writer.print("\r\n", .{});

        // Send the request
        _ = try stream.write(request.items);

        // Read the response
        var response = ArrayList(u8).init(self.allocator);
        defer response.deinit();

        var buffer: [1024]u8 = undefined;
        while (true) {
            const bytes_read = try stream.read(&buffer);
            if (bytes_read == 0) break;
            try response.appendSlice(buffer[0..bytes_read]);
        }

        return response.toOwnedSlice();
    }
};

/// URL structure
const Url = struct {
    allocator: Allocator,
    scheme: []const u8,
    host: []const u8,
    port: u16,
    path: []const u8,
    query: ?[]const u8,
    path_with_query: []const u8,

    pub fn deinit(self: *Url) void {
        self.allocator.free(self.path_with_query);
    }
};

/// Parses a URL into its components
fn parseUrl(allocator: Allocator, url: []const u8) !Url {
    // Find the scheme
    const scheme_end = mem.indexOfScalar(u8, url, ':') orelse return error.InvalidUrl;
    const scheme = url[0..scheme_end];

    // Skip the "://"
    if (!mem.startsWith(u8, url[scheme_end..], "://")) {
        return error.InvalidUrl;
    }
    var rest = url[scheme_end + 3 ..];

    // Find the host and port
    const path_start = mem.indexOfScalar(u8, rest, '/') orelse rest.len;
    const host_part = rest[0..path_start];
    rest = if (path_start < rest.len) rest[path_start..] else "/";

    // Parse host and port
    var host = host_part;
    var port: u16 = if (mem.eql(u8, scheme, "https")) 443 else 80;

    if (mem.indexOfScalar(u8, host_part, ':')) |port_idx| {
        host = host_part[0..port_idx];
        const port_str = host_part[port_idx + 1 ..];
        port = try std.fmt.parseInt(u16, port_str, 10);
    }

    // Find the query
    const query_start = mem.indexOfScalar(u8, rest, '?');
    const path = if (query_start) |idx| rest[0..idx] else rest;
    const query = if (query_start) |idx| rest[idx + 1 ..] else null;

    // Create a path_with_query
    const path_with_query = try allocator.dupe(u8, rest);

    return Url{
        .allocator = allocator,
        .scheme = scheme,
        .host = host,
        .port = port,
        .path = path,
        .query = query,
        .path_with_query = path_with_query,
    };
}

/// Encodes a list of key-value pairs into a URL query string
fn encodeParams(allocator: Allocator, params: []const [2][]const u8) ![]const u8 {
    var buffer = ArrayList(u8).init(allocator);
    defer buffer.deinit();
    
    const writer = buffer.writer();
    
    // Add the first parameter
    if (params.len > 0) {
        try urlEncodeParam(writer, params[0][0], params[0][1]);
        
        // Add the rest of the parameters
        for (params[1..]) |param| {
            try writer.writeByte('&');
            try urlEncodeParam(writer, param[0], param[1]);
        }
    }
    
    return buffer.toOwnedSlice();
}

/// URL encodes a key-value pair and writes it to the writer
fn urlEncodeParam(writer: anytype, key: []const u8, value: []const u8) !void {
    try urlEncode(writer, key);
    try writer.writeByte('=');
    try urlEncode(writer, value);
}

/// URL encodes a string and writes it to the writer
fn urlEncode(writer: anytype, str: []const u8) !void {
    for (str) |c| {
        if (isUrlSafe(c)) {
            try writer.writeByte(c);
        } else if (c == ' ') {
            // Space can be encoded as '+' in query parameters
            try writer.writeByte('+');
        } else {
            // Encode other characters as %XX
            try writer.print("%{X:0>2}", .{@as(u8, c)});
        }
    }
}

/// Returns true if the character is safe to use in a URL without encoding
fn isUrlSafe(c: u8) bool {
    return switch (c) {
        'A'...'Z', 'a'...'z', '0'...'9', '-', '_', '.', '~' => true,
        else => false,
    };
}

test "url parsing" {
    const allocator = std.testing.allocator;
    
    {
        const url_str = "http://example.com/path?query=value";
        var parsed = try parseUrl(allocator, url_str);
        defer parsed.deinit();
        
        try std.testing.expectEqualStrings("http", parsed.scheme);
        try std.testing.expectEqualStrings("example.com", parsed.host);
        try std.testing.expectEqual(@as(u16, 80), parsed.port);
        try std.testing.expectEqualStrings("/path", parsed.path);
        try std.testing.expectEqualStrings("query=value", parsed.query.?);
        try std.testing.expectEqualStrings("/path?query=value", parsed.path_with_query);
    }
    
    {
        const url_str = "https://api.example.org:8443/v1/resource";
        var parsed = try parseUrl(allocator, url_str);
        defer parsed.deinit();
        
        try std.testing.expectEqualStrings("https", parsed.scheme);
        try std.testing.expectEqualStrings("api.example.org", parsed.host);
        try std.testing.expectEqual(@as(u16, 8443), parsed.port);
        try std.testing.expectEqualStrings("/v1/resource", parsed.path);
        try std.testing.expectEqual(@as(?[]const u8, null), parsed.query);
        try std.testing.expectEqualStrings("/v1/resource", parsed.path_with_query);
    }
}

test "url encoding" {
    var list = ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();
    
    try urlEncode(list.writer(), "Hello World!");
    try std.testing.expectEqualStrings("Hello+World%21", list.items);
}

test "build url" {
    const allocator = std.testing.allocator;
    var client = HttpClient.init(allocator);
    
    const url = try client.buildUrl("http://example.com/api", &.{
        .{ "key", "value" },
        .{ "q", "search term" },
    });
    defer allocator.free(url);
    
    try std.testing.expectEqualStrings("http://example.com/api?key=value&q=search+term", url);
}

test "encode params" {
    const allocator = std.testing.allocator;
    
    const params = [_][2][]const u8{
        .{ "key1", "value1" },
        .{ "key2", "value with spaces" },
        .{ "special", "!@#" },
    };
    
    const query_string = try encodeParams(allocator, &params);
    defer allocator.free(query_string);
    
    try std.testing.expectEqualStrings("key1=value1&key2=value+with+spaces&special=%21%40%23", query_string);
}
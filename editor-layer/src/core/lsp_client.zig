//! LSP JSON-RPC client (Wave 2.3 minimal stub).
//!
//! Originally Wave 2.3 was scoped to implement subprocess + Content-Length
//! framing + initialize/didOpen/didChange/hover. Zig 0.16's I/O overhaul
//! (`std.process.Child.init` removed, `wait(io)` requires a new Io interface,
//! `writeAll` moved off File) makes a clean implementation a non-trivial
//! research task — well beyond a single MVP slice.
//!
//! Decision (2026-05-24, MVP push): ship the **public API surface only** as
//! a no-op stub so editor-layer compiles, links, and the UI scaffold can
//! reference `lsp_client.Client` without #ifdefs. Full implementation is
//! deferred to v1.0 (post-MVP), where the new Io API will have shaken out.
//!
//! When you revisit this:
//!   - Reference Ghostty/src/Command.zig for the new Child usage
//!   - Look for std.Io.Writer.writeAll instead of File.writeAll
//!   - Consider zigtools/lsp-kit for a higher-level wrapper

const std = @import("std");

pub const Error = error{
    NotImplemented,
    OutOfMemory,
};

pub const Position = struct {
    line: u32,
    character: u32,
};

pub const Client = struct {
    allocator: std.mem.Allocator,
    initialized: bool = false,

    pub fn spawn(allocator: std.mem.Allocator, argv: []const []const u8) Error!Client {
        _ = argv;
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Client) void {
        self.* = undefined;
    }

    pub fn initialize(self: *Client, root_uri: []const u8) Error!void {
        _ = root_uri;
        self.initialized = true;
    }

    pub fn didOpen(self: *Client, uri: []const u8, language_id: []const u8, text: []const u8) Error!void {
        _ = self;
        _ = uri;
        _ = language_id;
        _ = text;
    }

    pub fn didChange(self: *Client, uri: []const u8, new_text: []const u8, version: i64) Error!void {
        _ = self;
        _ = uri;
        _ = new_text;
        _ = version;
    }

    pub fn hover(self: *Client, uri: []const u8, pos: Position) Error![]u8 {
        _ = self;
        _ = uri;
        _ = pos;
        return error.NotImplemented;
    }
};

// ──────────────────────────────────────────────────────────────────────
// Tests — verify the stub's public API surface compiles & links.
// ──────────────────────────────────────────────────────────────────────

test "Position is 8 bytes" {
    try std.testing.expect(@sizeOf(Position) == 8);
}

test "Client.spawn + deinit lifecycle (no-op)" {
    var client = try Client.spawn(std.testing.allocator, &.{"/bin/true"});
    defer client.deinit();
    try std.testing.expect(!client.initialized);
}

test "Client.initialize flips initialized flag" {
    var client = try Client.spawn(std.testing.allocator, &.{"/bin/true"});
    defer client.deinit();
    try client.initialize("file:///tmp");
    try std.testing.expect(client.initialized);
}

test "Client.hover returns NotImplemented in MVP stub" {
    var client = try Client.spawn(std.testing.allocator, &.{"/bin/true"});
    defer client.deinit();
    try std.testing.expectError(error.NotImplemented, client.hover("file:///x", .{ .line = 0, .character = 0 }));
}

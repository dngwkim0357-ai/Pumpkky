//! Ghostty-compatible flat `key = value` config parser.
//!
//! Phase 4.G — minimal MVP: parse a single config file into a string map.
//! Comments start with '#', empty lines ignored. No multi-line, no includes.
//! Lazy reload (file watch) is a follow-up Wave.

const std = @import("std");
const c = std.c;

pub const ParseError = error{
    PathTooLong,
    NotFound,
    IoError,
    OutOfMemory,
};

pub const Config = struct {
    allocator: std.mem.Allocator,
    entries: std.StringHashMapUnmanaged([]u8) = .empty,

    pub fn init(allocator: std.mem.Allocator) Config {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Config) void {
        var it = self.entries.iterator();
        while (it.next()) |kv| {
            self.allocator.free(kv.key_ptr.*);
            self.allocator.free(kv.value_ptr.*);
        }
        self.entries.deinit(self.allocator);
        self.* = undefined;
    }

    /// Return value for `key`, or null. Returned slice is borrowed.
    pub fn get(self: *const Config, key: []const u8) ?[]const u8 {
        return self.entries.get(key);
    }

    /// Load `path`. Calling this twice merges (later wins).
    pub fn loadFile(self: *Config, path: []const u8) ParseError!void {
        var path_buf: [4096]u8 = undefined;
        if (path.len >= path_buf.len) return error.PathTooLong;
        @memcpy(path_buf[0..path.len], path);
        path_buf[path.len] = 0;

        const fp = c.fopen(@ptrCast(&path_buf), "rb") orelse return error.NotFound;
        defer _ = c.fclose(fp);

        // Read whole file
        var list: std.ArrayListUnmanaged(u8) = .empty;
        defer list.deinit(self.allocator);
        var chunk: [4096]u8 = undefined;
        while (true) {
            const n = c.fread(&chunk, 1, chunk.len, fp);
            if (n == 0) break;
            try list.appendSlice(self.allocator, chunk[0..n]);
            if (n < chunk.len) break;
        }

        try self.parse(list.items);
    }

    /// Parse an in-memory buffer (line-oriented).
    pub fn parse(self: *Config, source: []const u8) ParseError!void {
        var it = std.mem.splitScalar(u8, source, '\n');
        while (it.next()) |raw_line| {
            const line = std.mem.trim(u8, raw_line, " \t\r");
            if (line.len == 0 or line[0] == '#') continue;
            const eq = std.mem.indexOfScalar(u8, line, '=') orelse continue;
            const key = std.mem.trim(u8, line[0..eq], " \t");
            const val_raw = std.mem.trim(u8, line[eq + 1 ..], " \t");
            // Strip surrounding quotes if present
            const val = if (val_raw.len >= 2 and val_raw[0] == '"' and val_raw[val_raw.len - 1] == '"')
                val_raw[1 .. val_raw.len - 1]
            else
                val_raw;
            if (key.len == 0) continue;

            // getOrPut keeps the existing key's storage alive for updates and
            // only allocates a fresh key slice on first insert. fetchPut would
            // hand back the old key pointer (still owned by the map) — freeing
            // it leaves the map with a dangling key and the next .get() crashes.
            const gop = self.entries.getOrPut(self.allocator, key) catch
                return error.OutOfMemory;
            if (!gop.found_existing) {
                gop.key_ptr.* = self.allocator.dupe(u8, key) catch
                    return error.OutOfMemory;
            } else {
                self.allocator.free(gop.value_ptr.*);
            }
            gop.value_ptr.* = self.allocator.dupe(u8, val) catch
                return error.OutOfMemory;
        }
    }
};

// ──────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────

test "Config.parse simple key=value" {
    var cfg = Config.init(std.testing.allocator);
    defer cfg.deinit();

    try cfg.parse(
        \\# Pumpkky config
        \\font-family = "JetBrains Mono"
        \\font-size = 13
        \\editor.line-numbers = true
    );

    try std.testing.expectEqualStrings("JetBrains Mono", cfg.get("font-family").?);
    try std.testing.expectEqualStrings("13", cfg.get("font-size").?);
    try std.testing.expectEqualStrings("true", cfg.get("editor.line-numbers").?);
    try std.testing.expect(cfg.get("nonexistent") == null);
}

test "Config.parse later wins" {
    var cfg = Config.init(std.testing.allocator);
    defer cfg.deinit();
    try cfg.parse("font-size = 10");
    try cfg.parse("font-size = 14");
    try std.testing.expectEqualStrings("14", cfg.get("font-size").?);
}

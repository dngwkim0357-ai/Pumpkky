//! Extension Point loader.
//!
//! Phase 4.G — MVP STUB. The real scan needs platform-specific opendir/readdir
//! plumbing (std.c.opendir signatures shifted in Zig 0.16's I/O overhaul), so
//! for MVP we ship the public API surface as a stub:
//!   - Registry / Extension types compile and link
//!   - scanDir / scanStandardRoots return 0 entries
//! Real filesystem scan lands in v1.0 alongside the broader Zig 0.16 I/O
//! migration.

const std = @import("std");

pub const Source = enum { user, ccagi, project };

pub const Extension = struct {
    name: []u8,
    kind: []u8,
    source: Source,
    path: []u8,

    pub fn deinit(self: *Extension, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.kind);
        allocator.free(self.path);
        self.* = undefined;
    }
};

pub const Registry = struct {
    allocator: std.mem.Allocator,
    items: std.ArrayListUnmanaged(Extension) = .empty,

    pub fn init(allocator: std.mem.Allocator) Registry {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Registry) void {
        for (self.items.items) |*e| e.deinit(self.allocator);
        self.items.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn count(self: *const Registry) usize {
        return self.items.items.len;
    }
};

/// Stub: always returns 0.  Will scan the directory in v1.0.
pub fn scanDir(
    reg: *Registry,
    dir_path: []const u8,
    kind: []const u8,
    source: Source,
) !usize {
    _ = reg;
    _ = dir_path;
    _ = kind;
    _ = source;
    return 0;
}

/// Stub: always returns 0. Will walk the standard roots in v1.0.
pub fn scanStandardRoots(
    reg: *Registry,
    allocator: std.mem.Allocator,
    home: []const u8,
    project_root: []const u8,
) !usize {
    _ = reg;
    _ = allocator;
    _ = home;
    _ = project_root;
    return 0;
}

// ──────────────────────────────────────────────────────────
// Tests (stub surface only)
// ──────────────────────────────────────────────────────────

test "Registry init/deinit empty" {
    var reg = Registry.init(std.testing.allocator);
    defer reg.deinit();
    try std.testing.expectEqual(@as(usize, 0), reg.count());
}

test "scanDir stub returns 0" {
    var reg = Registry.init(std.testing.allocator);
    defer reg.deinit();
    const n = try scanDir(&reg, "/anywhere", "hook", .user);
    try std.testing.expectEqual(@as(usize, 0), n);
}

test "scanStandardRoots stub returns 0" {
    var reg = Registry.init(std.testing.allocator);
    defer reg.deinit();
    const n = try scanStandardRoots(&reg, std.testing.allocator, "/Users/test", "");
    try std.testing.expectEqual(@as(usize, 0), n);
}

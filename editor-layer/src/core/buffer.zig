//! Piece Table buffer for editor text storage.
//!
//! Wave 2.1 minimal implementation. Pieces are stored in a contiguous
//! ArrayListUnmanaged, so insert/delete cost O(N pieces). VSCode and Helix use
//! the same shape; if benchmarks demand it, later Waves can swap the backing
//! container for a balanced tree without changing the public API.
//!
//! Layout:
//!   original  : immutable bytes loaded from disk (or empty for new buffers)
//!   add       : append-only edit log
//!   pieces    : ordered list of (source, offset, length) windows into the above
//!
//! Public API matches docs/ffi-design.md draft (`editor_get_buffer_view` etc.).

const std = @import("std");

const PieceSource = enum(u8) { original, add };

const Piece = struct {
    source: PieceSource,
    offset: usize,
    length: usize,
};

pub const Error = error{
    OutOfBounds,
    OutOfMemory,
};

pub const Buffer = struct {
    allocator: std.mem.Allocator,
    original: []u8,
    add: std.ArrayListUnmanaged(u8),
    pieces: std.ArrayListUnmanaged(Piece),

    pub fn initEmpty(allocator: std.mem.Allocator) !Buffer {
        return .{
            .allocator = allocator,
            .original = try allocator.alloc(u8, 0),
            .add = .empty,
            .pieces = .empty,
        };
    }

    pub fn initFromBytes(allocator: std.mem.Allocator, content: []const u8) !Buffer {
        const orig = try allocator.dupe(u8, content);
        var pieces: std.ArrayListUnmanaged(Piece) = .empty;
        if (content.len > 0) {
            try pieces.append(allocator, .{
                .source = .original,
                .offset = 0,
                .length = content.len,
            });
        }
        return .{
            .allocator = allocator,
            .original = orig,
            .add = .empty,
            .pieces = pieces,
        };
    }

    pub fn deinit(self: *Buffer) void {
        self.allocator.free(self.original);
        self.add.deinit(self.allocator);
        self.pieces.deinit(self.allocator);
        self.* = undefined;
    }

    /// Total byte length of the document.
    pub fn len(self: *const Buffer) usize {
        var total: usize = 0;
        for (self.pieces.items) |p| total += p.length;
        return total;
    }

    /// Insert `text` at byte position `offset`. `offset == len()` appends.
    pub fn insert(self: *Buffer, offset: usize, text: []const u8) Error!void {
        if (text.len == 0) return;
        const total = self.len();
        if (offset > total) return error.OutOfBounds;

        const add_offset = self.add.items.len;
        try self.add.appendSlice(self.allocator, text);

        const new_piece: Piece = .{
            .source = .add,
            .offset = add_offset,
            .length = text.len,
        };

        var cum: usize = 0;
        var idx: usize = 0;
        while (idx < self.pieces.items.len) : (idx += 1) {
            const p = self.pieces.items[idx];
            if (offset == cum) {
                try self.pieces.insert(self.allocator, idx, new_piece);
                return;
            }
            if (offset < cum + p.length) {
                const left_len = offset - cum;
                const left: Piece = .{
                    .source = p.source,
                    .offset = p.offset,
                    .length = left_len,
                };
                const right: Piece = .{
                    .source = p.source,
                    .offset = p.offset + left_len,
                    .length = p.length - left_len,
                };
                self.pieces.items[idx] = left;
                try self.pieces.insertSlice(self.allocator, idx + 1, &.{ new_piece, right });
                return;
            }
            cum += p.length;
        }
        // offset == total (append)
        try self.pieces.append(self.allocator, new_piece);
    }

    /// Delete `length` bytes starting at byte position `offset`.
    ///
    /// Implementation walks pieces in order, carrying `skip` (bytes still to
    /// skip before the deletion window starts) and `remaining` (bytes still to
    /// delete). After the first piece that contains the start of the deletion
    /// is handled, every subsequent affected piece is consumed from its own
    /// offset 0.
    pub fn delete(self: *Buffer, offset: usize, length: usize) Error!void {
        if (length == 0) return;
        const total = self.len();
        if (offset + length > total) return error.OutOfBounds;

        var remaining = length;
        var skip = offset;
        var i: usize = 0;
        while (i < self.pieces.items.len and remaining > 0) {
            const p = self.pieces.items[i];

            if (skip >= p.length) {
                skip -= p.length;
                i += 1;
                continue;
            }

            const del_start = skip;
            const del_end = @min(del_start + remaining, p.length);
            const del_count = del_end - del_start;

            if (del_start == 0 and del_end == p.length) {
                _ = self.pieces.orderedRemove(i);
                // Do not increment i: next piece slid into place.
            } else if (del_start == 0) {
                self.pieces.items[i].offset += del_end;
                self.pieces.items[i].length -= del_end;
                i += 1;
            } else if (del_end == p.length) {
                self.pieces.items[i].length = del_start;
                i += 1;
            } else {
                // Middle deletion within a single piece — split and stop.
                const right: Piece = .{
                    .source = p.source,
                    .offset = p.offset + del_end,
                    .length = p.length - del_end,
                };
                self.pieces.items[i].length = del_start;
                try self.pieces.insert(self.allocator, i + 1, right);
                i += 2;
            }

            remaining -= del_count;
            skip = 0; // After the first affected piece, no further skipping.
        }
    }

    /// Copy the byte range `[start, end)` into a freshly allocated slice.
    pub fn getRange(
        self: *const Buffer,
        allocator: std.mem.Allocator,
        start: usize,
        end: usize,
    ) Error![]u8 {
        const total = self.len();
        if (start > end or end > total) return error.OutOfBounds;
        if (start == end) return try allocator.alloc(u8, 0);

        var out = try allocator.alloc(u8, end - start);
        var cum: usize = 0;
        var out_pos: usize = 0;
        for (self.pieces.items) |p| {
            const piece_end = cum + p.length;
            if (piece_end <= start) {
                cum = piece_end;
                continue;
            }
            if (cum >= end) break;

            const local_start: usize = if (start > cum) start - cum else 0;
            const local_end: usize = if (end < piece_end) end - cum else p.length;
            const copy_len = local_end - local_start;

            const src: []const u8 = switch (p.source) {
                .original => self.original[p.offset + local_start .. p.offset + local_end],
                .add => self.add.items[p.offset + local_start .. p.offset + local_end],
            };
            @memcpy(out[out_pos .. out_pos + copy_len], src);
            out_pos += copy_len;
            cum = piece_end;
        }
        return out;
    }

    /// Copy the entire document into a freshly allocated slice.
    pub fn getAll(self: *const Buffer, allocator: std.mem.Allocator) Error![]u8 {
        return self.getRange(allocator, 0, self.len());
    }
};

// ──────────────────────────────────────────────────────────────────────
// Unit tests (run with `zig build test`)
// ──────────────────────────────────────────────────────────────────────

test "Buffer.initEmpty has zero length" {
    var buf = try Buffer.initEmpty(std.testing.allocator);
    defer buf.deinit();
    try std.testing.expectEqual(@as(usize, 0), buf.len());

    const all = try buf.getAll(std.testing.allocator);
    defer std.testing.allocator.free(all);
    try std.testing.expectEqualStrings("", all);
}

test "Buffer.initFromBytes round-trip" {
    var buf = try Buffer.initFromBytes(std.testing.allocator, "hello world");
    defer buf.deinit();
    try std.testing.expectEqual(@as(usize, 11), buf.len());

    const all = try buf.getAll(std.testing.allocator);
    defer std.testing.allocator.free(all);
    try std.testing.expectEqualStrings("hello world", all);
}

test "Buffer.insert at start, middle, end" {
    var buf = try Buffer.initFromBytes(std.testing.allocator, "hello world");
    defer buf.deinit();

    try buf.insert(5, ", brave");
    {
        const all = try buf.getAll(std.testing.allocator);
        defer std.testing.allocator.free(all);
        try std.testing.expectEqualStrings("hello, brave world", all);
    }

    try buf.insert(0, "say: ");
    {
        const all = try buf.getAll(std.testing.allocator);
        defer std.testing.allocator.free(all);
        try std.testing.expectEqualStrings("say: hello, brave world", all);
    }

    try buf.insert(buf.len(), "!");
    {
        const all = try buf.getAll(std.testing.allocator);
        defer std.testing.allocator.free(all);
        try std.testing.expectEqualStrings("say: hello, brave world!", all);
    }
}

test "Buffer.delete entire / start / end / middle" {
    var buf = try Buffer.initFromBytes(std.testing.allocator, "hello, brave world");
    defer buf.deinit();

    // Delete ", brave" (middle of one piece)
    try buf.delete(5, 7);
    {
        const all = try buf.getAll(std.testing.allocator);
        defer std.testing.allocator.free(all);
        try std.testing.expectEqualStrings("hello world", all);
    }

    // Delete from end
    try buf.delete(5, 6);
    {
        const all = try buf.getAll(std.testing.allocator);
        defer std.testing.allocator.free(all);
        try std.testing.expectEqualStrings("hello", all);
    }

    // Delete from start
    try buf.delete(0, 3);
    {
        const all = try buf.getAll(std.testing.allocator);
        defer std.testing.allocator.free(all);
        try std.testing.expectEqualStrings("lo", all);
    }

    // Delete entire remaining
    try buf.delete(0, 2);
    try std.testing.expectEqual(@as(usize, 0), buf.len());
}

test "Buffer.delete spanning multiple pieces" {
    var buf = try Buffer.initFromBytes(std.testing.allocator, "abcdef");
    defer buf.deinit();

    // Insert in the middle so we have 3 pieces: "abc" + "XYZ" + "def"
    try buf.insert(3, "XYZ");
    {
        const all = try buf.getAll(std.testing.allocator);
        defer std.testing.allocator.free(all);
        try std.testing.expectEqualStrings("abcXYZdef", all);
    }

    // Delete "cXYZd" — spans all 3 pieces
    try buf.delete(2, 5);
    const all = try buf.getAll(std.testing.allocator);
    defer std.testing.allocator.free(all);
    try std.testing.expectEqualStrings("abef", all);
}

test "Buffer.getRange returns slice" {
    var buf = try Buffer.initFromBytes(std.testing.allocator, "the quick brown fox");
    defer buf.deinit();

    const slice = try buf.getRange(std.testing.allocator, 4, 9);
    defer std.testing.allocator.free(slice);
    try std.testing.expectEqualStrings("quick", slice);

    // Edge: empty range
    const empty = try buf.getRange(std.testing.allocator, 4, 4);
    defer std.testing.allocator.free(empty);
    try std.testing.expectEqualStrings("", empty);
}

test "Buffer.insert OutOfBounds" {
    var buf = try Buffer.initFromBytes(std.testing.allocator, "hi");
    defer buf.deinit();
    try std.testing.expectError(error.OutOfBounds, buf.insert(3, "x"));
}

test "Buffer.delete OutOfBounds" {
    var buf = try Buffer.initFromBytes(std.testing.allocator, "hi");
    defer buf.deinit();
    try std.testing.expectError(error.OutOfBounds, buf.delete(0, 3));
    try std.testing.expectError(error.OutOfBounds, buf.delete(1, 2));
}

test "Buffer survives many small inserts (leak detection via testing.allocator)" {
    var buf = try Buffer.initEmpty(std.testing.allocator);
    defer buf.deinit();
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        try buf.insert(buf.len(), "x");
    }
    try std.testing.expectEqual(@as(usize, 100), buf.len());
}

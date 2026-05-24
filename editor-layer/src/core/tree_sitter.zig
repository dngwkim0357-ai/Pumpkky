//! tree-sitter C API binding.
//!
//! Wraps the tree-sitter parser, syntax tree, and node primitives in Zig
//! types so the rest of editor-layer (Buffer, EditOps, BufferView) can stay
//! Zig-pure. Built against tree-sitter 0.26.9 via build.zig.zon dependency.
//!
//! Phase 4.B Wave 2.2 — minimum binding + Zig grammar smoke tests.
//! Later Waves (2.4) will hook Buffer.insert/delete into `ts_tree_edit` for
//! incremental reparses and add Swift/Rust/TypeScript grammars.

const std = @import("std");

const c = @cImport({
    @cInclude("tree_sitter/api.h");
});

// Grammar entry points exposed by each language's parser.c
extern "c" fn tree_sitter_zig() *const c.TSLanguage;

/// Zig language grammar (compiled from maxxnino/tree-sitter-zig).
pub fn zigLanguage() *const c.TSLanguage {
    return tree_sitter_zig();
}

pub const Parser = struct {
    handle: *c.TSParser,

    pub fn init() Parser {
        return .{ .handle = c.ts_parser_new().? };
    }

    pub fn deinit(self: *Parser) void {
        c.ts_parser_delete(self.handle);
        self.* = undefined;
    }

    /// Returns true if the parser successfully switched to `lang`.
    pub fn setLanguage(self: *Parser, lang: *const c.TSLanguage) bool {
        return c.ts_parser_set_language(self.handle, lang);
    }

    /// Parse `text` from scratch (no previous tree). Returns null if the parser
    /// has no language set or the input is too large.
    pub fn parseString(self: *Parser, text: []const u8) ?Tree {
        const tree = c.ts_parser_parse_string(
            self.handle,
            null,
            text.ptr,
            @intCast(text.len),
        ) orelse return null;
        return .{ .handle = tree };
    }

    /// Incremental reparse from a previous tree (Wave 2.4 will pair this with
    /// `Tree.edit`).
    pub fn parseStringIncremental(self: *Parser, prev: *const Tree, text: []const u8) ?Tree {
        const tree = c.ts_parser_parse_string(
            self.handle,
            prev.handle,
            text.ptr,
            @intCast(text.len),
        ) orelse return null;
        return .{ .handle = tree };
    }
};

pub const Tree = struct {
    handle: *c.TSTree,

    pub fn deinit(self: *Tree) void {
        c.ts_tree_delete(self.handle);
        self.* = undefined;
    }

    pub fn rootNode(self: *const Tree) Node {
        return .{ .raw = c.ts_tree_root_node(self.handle) };
    }

    /// Notify tree-sitter of an edit before reparsing incrementally.
    pub fn edit(self: *Tree, e: Edit) void {
        var input_edit: c.TSInputEdit = .{
            .start_byte = @intCast(e.start_byte),
            .old_end_byte = @intCast(e.old_end_byte),
            .new_end_byte = @intCast(e.new_end_byte),
            .start_point = .{ .row = 0, .column = @intCast(e.start_byte) },
            .old_end_point = .{ .row = 0, .column = @intCast(e.old_end_byte) },
            .new_end_point = .{ .row = 0, .column = @intCast(e.new_end_byte) },
        };
        c.ts_tree_edit(self.handle, &input_edit);
    }
};

pub const Edit = struct {
    start_byte: usize,
    old_end_byte: usize,
    new_end_byte: usize,
};

pub const Node = struct {
    raw: c.TSNode,

    pub fn kind(self: *const Node) []const u8 {
        return std.mem.span(c.ts_node_type(self.raw));
    }

    pub fn childCount(self: *const Node) usize {
        return c.ts_node_child_count(self.raw);
    }

    pub fn isNull(self: *const Node) bool {
        return c.ts_node_is_null(self.raw);
    }

    /// True if anywhere in the subtree there is a parse error.
    pub fn hasError(self: *const Node) bool {
        return c.ts_node_has_error(self.raw);
    }

    pub fn startByte(self: *const Node) usize {
        return c.ts_node_start_byte(self.raw);
    }

    pub fn endByte(self: *const Node) usize {
        return c.ts_node_end_byte(self.raw);
    }

    pub fn child(self: *const Node, index: usize) Node {
        return .{ .raw = c.ts_node_child(self.raw, @intCast(index)) };
    }
};

// ──────────────────────────────────────────────────────────────────────
// Unit tests (run with `zig build test`)
// ──────────────────────────────────────────────────────────────────────

test "Parser lifecycle (init / setLanguage / deinit)" {
    var parser = Parser.init();
    defer parser.deinit();
    try std.testing.expect(parser.setLanguage(zigLanguage()));
}

test "parse simple Zig source: const x = 1;" {
    var parser = Parser.init();
    defer parser.deinit();
    try std.testing.expect(parser.setLanguage(zigLanguage()));

    var tree = parser.parseString("const x = 1;") orelse return error.ParseFailed;
    defer tree.deinit();

    const root = tree.rootNode();
    try std.testing.expect(!root.isNull());
    try std.testing.expect(root.childCount() > 0);
    try std.testing.expect(!root.hasError());
    try std.testing.expectEqualStrings("source_file", root.kind());
}

test "parse real Zig function" {
    var parser = Parser.init();
    defer parser.deinit();
    try std.testing.expect(parser.setLanguage(zigLanguage()));

    const src =
        \\pub fn add(a: i32, b: i32) i32 {
        \\    return a + b;
        \\}
    ;

    var tree = parser.parseString(src) orelse return error.ParseFailed;
    defer tree.deinit();

    const root = tree.rootNode();
    try std.testing.expect(!root.hasError());
    try std.testing.expect(root.endByte() == src.len);
}

test "parse invalid syntax surfaces error node" {
    var parser = Parser.init();
    defer parser.deinit();
    try std.testing.expect(parser.setLanguage(zigLanguage()));

    var tree = parser.parseString("const x = ;") orelse return error.ParseFailed;
    defer tree.deinit();

    try std.testing.expect(tree.rootNode().hasError());
}

test "incremental reparse on a small edit" {
    var parser = Parser.init();
    defer parser.deinit();
    try std.testing.expect(parser.setLanguage(zigLanguage()));

    const src1 = "const x = 1;";
    var tree1 = parser.parseString(src1) orelse return error.ParseFailed;
    defer tree1.deinit();

    // Edit: insert " + 2" before the semicolon → "const x = 1 + 2;"
    tree1.edit(.{
        .start_byte = 11, // before ';'
        .old_end_byte = 11,
        .new_end_byte = 15, // +4 bytes
    });

    var tree2 = parser.parseStringIncremental(&tree1, "const x = 1 + 2;") orelse return error.ParseFailed;
    defer tree2.deinit();

    try std.testing.expect(!tree2.rootNode().hasError());
}

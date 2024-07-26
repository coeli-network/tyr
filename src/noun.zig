const std = @import("std");
const testing = std.testing;

pub const Noun = union(enum) {
    direct_atom: u64,
    indirect_atom: *const []u64,
    cell: *const [2]Noun,

    pub fn initDirectAtom(value: u64) Noun {
        return .{ .direct_atom = value };
    }

    pub fn initIndirectAtom(allocator: *std.mem.Allocator, value: []const u64) !Noun {
        const storage = try allocator.create([]u64);
        storage.* = try allocator.dupe(u64, value);
        return .{ .indirect_atom = storage };
    }

    pub fn initCell(allocator: *std.mem.Allocator, head: Noun, tail: Noun) !Noun {
        const cell_ptr = try allocator.create([2]Noun);
        cell_ptr[0] = head;
        cell_ptr[1] = tail;
        return .{ .cell = cell_ptr };
    }

    pub fn deinit(self: Noun, allocator: *std.mem.Allocator) void {
        switch (self) {
            .indirect_atom => |ptr| {
                allocator.free(ptr.*);
                allocator.destroy(ptr);
            },
            .cell => |ptr| {
                ptr[0].deinit(allocator);
                ptr[1].deinit(allocator);
                allocator.destroy(ptr);
            },
            .direct_atom => {},
        }
    }

    pub fn getAtomValue(self: Noun) !u64 {
        return switch (self) {
            .direct_atom => |value| value,
            .indirect_atom => |ptr| ptr.*[0],
            .cell => error.NotAnAtom,
        };
    }

    pub fn getCellHead(self: Noun) !*const Noun {
        return switch (self) {
            .cell => |ptr| &ptr[0],
            else => error.NotACell,
        };
    }

    pub fn getCellTail(self: Noun) !*const Noun {
        return switch (self) {
            .cell => |ptr| &ptr[1],
            else => error.NotACell,
        };
    }
};

test "direct atoms" {
    try testing.expect(Noun.initDirectAtom(64).direct_atom == 64);
}

// test "indirect atoms" {
//     var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
//     defer arena.deinit();
//     const alloc = arena.allocator();
//     const value = [64, 64];
//     try testing.expect(Noun.initIndirectAtom(alloc, @as([]const u64, [64, 64]), 64) == 64);
// }

test "Noun - Direct Atom" {
    const n = Noun.initDirectAtom(42);
    try testing.expectEqual(Noun.direct_atom, @as(std.meta.Tag(Noun), n));
    try testing.expectEqual(@as(u62, 42), n.direct_atom);
    try testing.expectEqual(@as(u64, 42), try n.getAtomValue());
}

test "Noun - Indirect Atom" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    const large_number = [_]u64{ 0xFFFFFFFFFFFFFFFF, 0x1 };
    const n = try Noun.initIndirectAtom(&allocator, &large_number);
    try testing.expectEqual(Noun.indirect_atom, @as(std.meta.Tag(Noun), n));
    try testing.expectEqualSlices(u64, &large_number, n.indirect_atom.*);
    try testing.expectEqual(@as(u64, 0xFFFFFFFFFFFFFFFF), try n.getAtomValue());
}

test "Noun - Cell" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    const head = Noun.initDirectAtom(1);
    const tail = Noun.initDirectAtom(2);
    const cell = try Noun.initCell(&allocator, head, tail);

    try testing.expectEqual(Noun.cell, @as(std.meta.Tag(Noun), cell));

    const head_ptr = try cell.getCellHead();
    const tail_ptr = try cell.getCellTail();

    try testing.expectEqual(@as(u62, 1), head_ptr.direct_atom);
    try testing.expectEqual(@as(u62, 2), tail_ptr.direct_atom);
}

test "Noun - getAtomValue error" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    const head = Noun.initDirectAtom(1);
    const tail = Noun.initDirectAtom(2);
    const cell = try Noun.initCell(&allocator, head, tail);

    try testing.expectError(error.NotAnAtom, cell.getAtomValue());
}

test "Noun - getCellHead/Tail error" {
    const atom = Noun.initDirectAtom(42);

    try testing.expectError(error.NotACell, atom.getCellHead());
    try testing.expectError(error.NotACell, atom.getCellTail());
}

test "Noun - complex structure" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    const a1 = Noun.initDirectAtom(1);
    const a2 = Noun.initDirectAtom(2);
    const c1 = try Noun.initCell(&allocator, a1, a2);
    const a3 = Noun.initDirectAtom(3);
    const c2 = try Noun.initCell(&allocator, c1, a3);

    switch (c2) {
        .cell => |_| {},
        .direct_atom => |value| {
            _ = value;
        },
        .indirect_atom => |ptr| {
            _ = ptr.*;
        },
    }

    const head = try c2.getCellHead();
    const tail = try c2.getCellTail();

    try testing.expectEqual(Noun.cell, @as(std.meta.Tag(Noun), head.*));
    try testing.expectEqual(@as(u62, 3), tail.direct_atom);

    const inner_head = try head.getCellHead();
    const inner_tail = try head.getCellTail();

    try testing.expectEqual(@as(u62, 1), inner_head.direct_atom);
    try testing.expectEqual(@as(u62, 2), inner_tail.direct_atom);
}

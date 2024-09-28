const std = @import("std");
const C = @import("common.zig").C;

const DisplayString = @This();

pub const GraphemeInfo = struct {
    len: u3,
    display_width: u2,

    pub fn parseSingle(bytes: []const u8) GraphemeInfo {
        const len = std.unicode.utf8ByteSequenceLength(bytes[0]) catch 1;
        const cp = std.unicode.utf8Decode(bytes[0..len]) catch bytes[0];
        const wc = C.mk_wcwidth(cp);
        return .{
            .len = len,
            .display_width = @intCast(@max(0, wc)),
        };
    }
};

pub const Grapheme = struct {
    info: GraphemeInfo,
    bytes: []const u8,
};

bytes: std.ArrayList(u8),
graphemes: std.ArrayList(GraphemeInfo),

pub fn init(allocator: std.mem.Allocator) DisplayString {
    return DisplayString{
        .bytes = std.ArrayList(u8).init(allocator),
        .graphemes = std.ArrayList(GraphemeInfo).init(allocator),
    };
}
pub fn initCapacity(allocator: std.mem.Allocator, len: usize) !DisplayString {
    return DisplayString{
        .bytes = try std.ArrayList(u8).initCapacity(allocator, len),
        .graphemes = try std.ArrayList(GraphemeInfo).initCapacity(allocator, len),
    };
}
pub fn initBytes(allocator: std.mem.Allocator, bytes: []const u8) !DisplayString {
    var result = try initCapacity(allocator, bytes.len);
    try result.append(bytes);
    return result;
}

pub fn append(self: *DisplayString, data: []const u8) !void {
    try self.bytes.appendSlice(data);

    var s = data;
    while (s.len > 0) {
        const cp = GraphemeInfo.parseSingle(s);
        try self.graphemes.append(cp);
        s = s[@max(1, cp.len)..];
    }
}

fn byteIndexOf(self: *const DisplayString, i: usize) usize {
    var result: usize = 0;
    for (0..i) |j| {
        result += self.graphemes.items[j].len;
    }
    return result;
}

pub fn remove(self: *DisplayString, i: usize) void {
    const idx = self.byteIndexOf(i);
    const cplen = self.graphemes.orderedRemove(i).len;
    std.mem.copyForwards(u8, self.bytes.items[idx..], self.bytes.items[idx + cplen ..]);
    self.bytes.shrinkAndFree(self.bytes.items.len - cplen);
}

pub fn removeRange(self: *DisplayString, from: usize, to: usize) void {
    const start = self.byteIndexOf(from);
    const end = self.byteIndexOf(to) + self.graphemes.items[to].len;
    std.mem.copyForwards(u8, self.bytes.items[start..], self.bytes.items[end..]);
    self.bytes.shrinkAndFree(self.bytes.items.len + start - end);
    for (from..to + 1) |_| {
        _ = self.graphemes.orderedRemove(from);
    }
}

pub fn deinit(self: *DisplayString) void {
    self.bytes.deinit();
    self.graphemes.deinit();
    self.* = undefined;
}

pub fn replaceAll(self: *DisplayString, new_content: []const u8) !void {
    self.bytes.clearRetainingCapacity();
    self.graphemes.clearRetainingCapacity();
    try self.append(new_content);
    if (self.bytes.capacity > self.bytes.items.len) {
        self.bytes.shrinkAndFree(self.bytes.items.len);
    }
    if (self.graphemes.capacity > self.graphemes.items.len) {
        self.graphemes.shrinkAndFree(self.graphemes.items.len);
    }
}

const Iterator = struct {
    str: *const DisplayString,
    i: usize = 0,
    off: usize = 0,

    pub fn next(self: *Iterator) ?Grapheme {
        if (self.i >= self.str.graphemes.items.len) {
            return null;
        }

        const info = self.str.graphemes.items[self.i];
        defer {
            self.off += info.len;
            self.i += 1;
        }
        return Grapheme{
            .info = info,
            .bytes = self.str.bytes.items[self.off .. self.off + info.len],
        };
    }
};

pub fn iterator(self: *const DisplayString) Iterator {
    return .{ .str = self };
}

pub fn display_width(self: *const DisplayString) usize {
    var result: usize = 0;
    for (self.graphemes.items) |cp| {
        result += cp.display_width;
    }
    return result;
}

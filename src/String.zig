const std = @import("std");
const C = @import("common.zig").C;

const String = @This();

pub const CodepointInfo = struct {
    len: u3,
    display_width: u2,

    pub fn parseSingle(bytes: []const u8) CodepointInfo {
        const len = std.unicode.utf8ByteSequenceLength(bytes[0]) catch 1;
        const cp = std.unicode.utf8Decode(bytes[0..len]) catch bytes[0];
        const wc = C.mk_wcwidth(cp);
        return .{
            .len = len,
            .display_width = @intCast(@max(0, wc)),
        };
    }
};

pub const Codepoint = struct {
    info: CodepointInfo,
    bytes: []const u8,

    pub fn parseSingle(bytes: []const u8) Codepoint {
        const info = CodepointInfo.parseSingle(bytes);
        return .{ .bytes = bytes[0..info.len], .info = info };
    }
};

bytes: std.ArrayList(u8),
graphemes: std.ArrayList(CodepointInfo),

pub fn init(allocator: std.mem.Allocator) String {
    return String{
        .bytes = std.ArrayList(u8).init(allocator),
        .graphemes = std.ArrayList(CodepointInfo).init(allocator),
    };
}
pub fn initCapacity(allocator: std.mem.Allocator, len: usize) !String {
    return String{
        .bytes = try std.ArrayList(u8).initCapacity(allocator, len),
        .graphemes = try std.ArrayList(CodepointInfo).initCapacity(allocator, len),
    };
}
pub fn initBytes(allocator: std.mem.Allocator, bytes: []const u8) !String {
    var result = try initCapacity(allocator, bytes.len);
    try result.append(bytes);
    return result;
}

pub fn append(self: *String, data: []const u8) !void {
    try self.bytes.appendSlice(data);

    var s = data;
    while (s.len > 0) {
        const cp = CodepointInfo.parseSingle(s);
        try self.graphemes.append(cp);
        s = s[@max(1, cp.len)..];
    }
}

fn byteIndexOf(self: *const String, i: usize) usize {
    var result: usize = 0;
    for (0..i) |j| {
        result += self.graphemes.items[j].len;
    }
    return result;
}

pub fn remove(self: *String, i: usize) void {
    const idx = self.byteIndexOf(i);
    const cplen = self.graphemes.orderedRemove(i).len;
    std.mem.copyForwards(u8, self.bytes.items[idx..], self.bytes.items[idx + cplen ..]);
    self.bytes.shrinkAndFree(self.bytes.items.len - cplen);
}

pub fn removeRange(self: *String, from: usize, to: usize) void {
    const start = self.byteIndexOf(from);
    const end = self.byteIndexOf(to) + self.graphemes.items[to].len;
    std.mem.copyForwards(u8, self.bytes.items[start..], self.bytes.items[end..]);
    self.bytes.shrinkAndFree(self.bytes.items.len + start - end);
    for (from..to + 1) |_| {
        _ = self.graphemes.orderedRemove(from);
    }
}

pub fn deinit(self: *String) void {
    self.bytes.deinit();
    self.graphemes.deinit();
    self.* = undefined;
}

pub fn replaceAll(self: *String, new_content: []const u8) !*String {
    self.bytes.clearRetainingCapacity();
    self.graphemes.clearRetainingCapacity();
    try self.append(new_content);
    if (self.bytes.capacity > self.bytes.items.len) {
        self.bytes.shrinkAndFree(self.bytes.items.len);
    }
    if (self.graphemes.capacity > self.graphemes.items.len) {
        self.graphemes.shrinkAndFree(self.graphemes.items.len);
    }
    return self;
}

const Iterator = struct {
    str: *const String,
    i: usize = 0,
    off: usize = 0,

    pub fn next(self: *Iterator) ?Codepoint {
        if (self.i >= self.str.graphemes.items.len) {
            return null;
        }

        const info = self.str.graphemes.items[self.i];
        defer {
            self.off += info.len;
            self.i += 1;
        }
        return Codepoint{
            .info = info,
            .bytes = self.str.bytes.items[self.off .. self.off + info.len],
        };
    }
};

pub fn iterator(self: *const String) Iterator {
    return .{ .str = self };
}

pub fn display_width(self: *const String) usize {
    var result: usize = 0;
    for (self.graphemes.items) |cp| {
        result += cp.display_width;
    }
    return result;
}

pub fn clone(self: *const String) !String {
    return String{ // shallow copy is good enough here
        .bytes = try self.bytes.clone(),
        .graphemes = try self.graphemes.clone(),
    };
}

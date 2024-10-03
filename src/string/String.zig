const std = @import("std");
const C = @import("../common.zig").C;

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
    bytes: [4]u8,

    pub fn init(info: CodepointInfo, bytes: []const u8) Codepoint {
        std.debug.assert(bytes.len >= info.len and 4 >= info.len);

        var b: [4]u8 = .{ 0, 0, 0, 0 };
        @memcpy(b[0..info.len], bytes[0..info.len]);
        return Codepoint{
            .info = info,
            .bytes = b,
        };
    }

    pub fn parseSingle(bytes: []const u8) Codepoint {
        return Codepoint.init(CodepointInfo.parseSingle(bytes), bytes);
    }
};

bytes: []const u8,
codepoints: []const CodepointInfo,

pub const Error = std.mem.Allocator.Error || error{};

/// copies bytes and parses codepoints. caller owns the memory, and must eventually call `deinit` with the same allocator
pub fn init(allocator: std.mem.Allocator, bytes: []const u8) Error!String {
    const b = try allocator.alloc(u8, bytes.len);
    @memcpy(b, bytes);
    return String.initOwn(allocator, b);
}

/// initialize a new String that owns the input bytes
pub fn initOwn(allocator: std.mem.Allocator, bytes: []const u8) Error!String {
    const cps = try allocator.alloc(CodepointInfo, codepointCount(bytes));
    var d = bytes;
    var i: usize = 0;
    while (d.len > 0) : (i += 1) {
        cps[i] = CodepointInfo.parseSingle(d);
        const len = @max(1, cps[i].len);
        d = d[len..];
    }
    return String{
        .bytes = bytes,
        .codepoints = cps,
    };
}

fn codepointCount(data: []const u8) usize {
    var count: usize = 0;
    var d = data;
    while (d.len > 0) : (count += 1) {
        const len = @max(1, CodepointInfo.parseSingle(data).len);
        d = d[len..];
    }
    return count;
}

// pub fn append(self: *String, data: []const u8) !void {
//     try self.bytes.appendSlice(data);
//
//     var s = data;
//     while (s.len > 0) {
//         const cp = CodepointInfo.parseSingle(s);
//         try self.codepoints.append(cp);
//         s = s[@max(1, cp.len)..];
//     }
// }

fn byteIndexOf(self: *const String, i: usize) usize {
    var result: usize = 0;
    for (0..i) |j| {
        result += self.codepoints[j].len;
    }
    return result;
}

// pub fn remove(self: *String, i: usize) void {
//     const idx = self.byteIndexOf(i);
//     const cplen = self.codepoints.orderedRemove(i).len;
//     std.mem.copyForwards(u8, self.bytes[idx..], self.bytes[idx + cplen ..]);
//     self.bytes.shrinkAndFree(self.bytes.len - cplen);
// }

// pub fn removeRange(self: *String, from: usize, to: usize) void {
//     const start = self.byteIndexOf(from);
//     const end = self.byteIndexOf(to) + self.codepoints[to].len;
//     std.mem.copyForwards(u8, self.bytes[start..], self.bytes[end..]);
//     self.bytes.shrinkAndFree(self.bytes.len + start - end);
//     for (from..to + 1) |_| {
//         _ = self.codepoints.orderedRemove(from);
//     }
// }

pub fn deinit(self: *String, allocator: std.mem.Allocator) void {
    allocator.free(self.bytes);
    allocator.free(self.codepoints);
    self.* = undefined;
}

// pub fn replaceAll(self: *String, new_content: []const u8) !*String {
//     self.bytes.clearRetainingCapacity();
//     self.codepoints.clearRetainingCapacity();
//     try self.append(new_content);
//     if (self.bytes.capacity > self.bytes.len) {
//         self.bytes.shrinkAndFree(self.bytes.len);
//     }
//     if (self.codepoints.capacity > self.codepoints.len) {
//         self.codepoints.shrinkAndFree(self.codepoints.len);
//     }
//     return self;
// }

const Iterator = struct {
    str: *const String,
    i: usize = 0,
    off: usize = 0,

    pub fn next(self: *Iterator) ?Codepoint {
        if (self.i >= self.str.codepoints.len) {
            return null;
        }

        const info = self.str.codepoints[self.i];
        defer {
            self.off += info.len;
            self.i += 1;
        }
        return Codepoint.init(info, self.str.bytes[self.off .. self.off + info.len]);
    }
};

pub fn iterator(self: *const String) Iterator {
    return .{ .str = self };
}

pub fn displayWidth(self: *const String) usize {
    var result: usize = 0;
    for (self.codepoints) |cp| {
        result += cp.display_width;
    }
    return result;
}

pub fn clone(self: *const String, allocator: std.mem.Allocator) Error!String {
    const bytes = try allocator.alloc(u8, self.bytes.len);
    const cps = try allocator.alloc(CodepointInfo, self.codepoints.len);
    @memcpy(bytes, self.bytes);
    @memcpy(cps, self.codepoints);
    return String{
        .bytes = bytes,
        .codepoints = cps,
    };
}

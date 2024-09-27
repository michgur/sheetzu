const std = @import("std");
const C = @import("common.zig").C;

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
};

pub const Str = struct {
    bytes: std.ArrayList(u8),
    codepoints: std.ArrayList(CodepointInfo),

    pub fn init(allocator: std.mem.Allocator) Str {
        return Str{
            .bytes = std.ArrayList(u8).init(allocator),
            .codepoints = std.ArrayList(CodepointInfo).init(allocator),
        };
    }
    pub fn initCapacity(allocator: std.mem.Allocator, len: usize) !Str {
        return Str{
            .bytes = try std.ArrayList(u8).initCapacity(allocator, len),
            .codepoints = try std.ArrayList(CodepointInfo).initCapacity(allocator, len),
        };
    }
    pub fn initBytes(allocator: std.mem.Allocator, bytes: []const u8) !Str {
        var result = try initCapacity(allocator, bytes.len);
        try result.append(bytes);
        return result;
    }

    pub fn append(self: *Str, data: []const u8) !void {
        try self.bytes.appendSlice(data);
        var s = data;
        while (s.len > 0) {
            const cp = CodepointInfo.parseSingle(s);
            try self.codepoints.append(cp);
            s = s[@max(1, cp.len)..];
        }
    }

    pub fn deinit(self: *Str) void {
        self.bytes.deinit();
        self.codepoints.deinit();
        self.* = undefined;
    }

    const Iterator = struct {
        str: *const Str,
        i: usize = 0,
        off: usize = 0,

        pub fn next(self: *Iterator) ?Codepoint {
            if (self.i >= self.str.codepoints.items.len) {
                return null;
            }

            const info = self.str.codepoints.items[self.i];
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

    pub fn iterator(self: *const Str) Iterator {
        return .{ .str = self };
    }

    pub fn display_width(self: *const Str) usize {
        var result: usize = 0;
        for (self.codepoints.items) |cp| {
            result += cp.display_width;
        }
        return result;
    }
};

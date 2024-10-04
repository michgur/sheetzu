const std = @import("std");
const String = @import("String.zig");
const StringWriter = @This();

pub const Error = std.mem.Allocator.Error || error{};
pub const Writer = std.io.GenericWriter(*StringWriter, Error, write);

allocator: std.mem.Allocator,
bytes: std.ArrayList(u8),

pub fn init(allocator: std.mem.Allocator) StringWriter {
    return .{
        .allocator = allocator,
        .bytes = std.ArrayList(u8).init(allocator),
    };
}

fn write(self: *StringWriter, bytes: []const u8) Error!usize {
    try self.bytes.appendSlice(bytes);
    return bytes.len;
}

pub fn writer(self: *StringWriter) Writer {
    return Writer{ .context = self };
}

pub fn deinit(self: *StringWriter) void {
    self.bytes.deinit();
}

/// finish writing and create a new String. caller owns the memory.
/// can be reused afterwards
pub fn string(self: *StringWriter, allocator: std.mem.Allocator) Error!String {
    return try String.initOwn(allocator, try self.bytes.toOwnedSlice());
}

/// creates a copy of the content, caller owns it
pub fn stringCopy(self: *const StringWriter, allocator: std.mem.Allocator) Error!String {
    return try String.init(allocator, self.bytes.items);
}

pub fn clearAndFree(self: *StringWriter) void {
    const allocator = self.allocator;

    self.deinit();
    self.* = init(allocator);
}

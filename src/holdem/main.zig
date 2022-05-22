const std = @import("std");

pub const Hand = @import("hand.zig");

test "holdem" {
    std.testing.refAllDecls(@This());
}

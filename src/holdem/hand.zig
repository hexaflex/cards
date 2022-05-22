const std = @import("std");
const expect = std.testing.expect;
const Card = @import("../main.zig").Card;

test "holdem" {
    std.testing.refAllDecls(@This());
}

/// Rank defines known Texas Hold'em poker hands.
pub const Rank = enum {
    highcard,
    pair,
    two_pair,
    three_of_a_kind,
    straight,
    flush,
    full_house,
    four_of_a_kind,
    straight_flush,
    royal_flush,
};

/// Cumulative score of all cards involved in the ranking represented by this hand.
score: u8 = 0,

/// Ranking this hand represents.
rank: Rank = .highcard,

/// A kicker is the highest card in a set which is not part of the
/// rank represented by a hand. It can be used to resolve a tie
/// if multiple players have the same rank/score.
kicker: ?Card = null,

/// init creates a new rank for the given set of cards.
/// The order of the set is not guaranteed to stay the same.
pub fn init(set: []Card) @This() {
    return switch (set.len) {
        0 => .{},
        1 => .{
            .score = @intCast(u8, @enumToInt(set[0].value)),
            .rank = .highcard,
        },
        else => {
            // Sort cards by value in ascending order and by suit in descending order.
            std.sort.sort(Card, set, SortByValueAndSuit{}, SortByValueAndSuit.f);

            if (try testRoyalFlush(set)) |v| return v;
            if (try testStraightFlush(set)) |v| return v;
            if (try testFourOfAKind(set)) |v| return v;
            if (try testFullHouse(set)) |v| return v;
            if (try testFlush(set)) |v| return v;
            if (try testStraight(set)) |v| return v;
            if (try testThreeOfAKind(set)) |v| return v;
            if (try testTwoPair(set)) |v| return v;
            if (try testPair(set)) |v| return v;

            return .{
                .score = @intCast(u8, @enumToInt(set[0].value)),
                .rank = .highcard,
                .kicker = getKicker(set, set[0..1]),
            };
        },
    };
}

test "hand/highcard" {
    {
        const hand = init(&.{});
        try expect(hand.score == 0);
        try expect(hand.rank == .highcard);
        try expect(hand.kicker == null);
    }
    {
        const hand = init(&.{
            Card.init(.clubs, .two),
        });
        try expect(hand.score == 2);
        try expect(hand.rank == .highcard);
        try expect(hand.kicker == null);
    }
    {
        const hand = init(&.{
            Card.init(.clubs, .seven),
        });
        try expect(hand.score == 7);
        try expect(hand.rank == .highcard);
        try expect(hand.kicker == null);
    }
    {
        const hand = init(&.{
            Card.init(.clubs, .seven),
            Card.init(.diamonds, .five),
        });
        try expect(hand.score == 7);
        try expect(hand.rank == .highcard);
        try expect(hand.kicker != null);
        try expect(hand.kicker.?.eql(
            Card.init(.diamonds, .five),
        ));
    }
}

/// testRoyalFlush checks if set contains a royal flush.
fn testRoyalFlush(set: []const Card) !?@This() {
    for (set) |c| {
        const cs = @intCast(u8, @enumToInt(c.suit));
        if (contains(set, cs, 14) and
            contains(set, cs, 13) and
            contains(set, cs, 12) and
            contains(set, cs, 11) and
            contains(set, cs, 10))
        {
            return @This(){
                .rank = .royal_flush,
                .score = 14 + 13 + 12 + 11 + 10,
                .kicker = getKicker(
                    set,
                    &.{
                        Card.initInt(cs, 14),
                        Card.initInt(cs, 13),
                        Card.initInt(cs, 12),
                        Card.initInt(cs, 11),
                        Card.initInt(cs, 10),
                    },
                ),
            };
        }
    }
    return null;
}

test "hand/royal_flush" {
    {
        const hand = init(&.{
            Card.init(.diamonds, .ten),
            Card.init(.diamonds, .jack),
            Card.init(.diamonds, .queen),
            Card.init(.diamonds, .king),
            Card.init(.diamonds, .ace),
        });
        try expect(hand.score == 10 + 11 + 12 + 13 + 14);
        try expect(hand.rank == .royal_flush);
        try expect(hand.kicker == null);
    }
    {
        const hand = init(&.{
            Card.init(.diamonds, .king),
            Card.init(.diamonds, .jack),
            Card.init(.diamonds, .ten),
            Card.init(.diamonds, .ace),
            Card.init(.diamonds, .queen),
        });
        try expect(hand.score == 10 + 11 + 12 + 13 + 14);
        try expect(hand.rank == .royal_flush);
        try expect(hand.kicker == null);
    }
    {
        const hand = init(&.{
            Card.init(.diamonds, .ace),
            Card.init(.diamonds, .three),
            Card.init(.diamonds, .queen),
            Card.init(.diamonds, .ten),
            Card.init(.clubs, .ten),
            Card.init(.diamonds, .king),
            Card.init(.diamonds, .jack),
        });
        try expect(hand.score == 10 + 11 + 12 + 13 + 14);
        try expect(hand.rank == .royal_flush);
        try expect(hand.kicker != null);
        try expect(hand.kicker.?.eql(
            Card.init(.clubs, .ten),
        ));
    }
}

/// testStraightFlush checks if cards contains a straight flush.
fn testStraightFlush(set: []const Card) !?@This() {
    for (set) |c| {
        const cv = @intCast(u8, @enumToInt(c.value));
        const cs = @intCast(u8, @enumToInt(c.suit));
        if (contains(set, cs, cv - 1) and
            contains(set, cs, cv - 2) and
            contains(set, cs, cv - 3) and
            contains(set, cs, cv - 4))
        {
            return @This(){
                .rank = .straight_flush,
                .score = cv * 5 - 1 - 2 - 3 - 4,
                .kicker = getKicker(set, &.{
                    Card.initInt(cs, cv),
                    Card.initInt(cs, cv - 1),
                    Card.initInt(cs, cv - 2),
                    Card.initInt(cs, cv - 3),
                    Card.initInt(cs, cv - 4),
                }),
            };
        }

        // A 2 3 4 5 -> Ace counts as 1.
        if (cv == 14 and
            contains(set, cs, 2) and
            contains(set, cs, 3) and
            contains(set, cs, 4) and
            contains(set, cs, 5))
        {
            return @This(){
                .rank = .straight_flush,
                .score = 1 + 2 + 3 + 4 + 5,
                .kicker = getKicker(set, &.{
                    Card.initInt(cs, 14),
                    Card.initInt(cs, 2),
                    Card.initInt(cs, 3),
                    Card.initInt(cs, 4),
                    Card.initInt(cs, 5),
                }),
            };
        }
    }
    return null;
}

test "hand/straight_flush" {
    {
        const hand = init(&.{
            Card.init(.clubs, .jack),
            Card.init(.diamonds, .five),
            Card.init(.diamonds, .six),
            Card.init(.diamonds, .four),
            Card.init(.diamonds, .queen),
            Card.init(.diamonds, .seven),
            Card.init(.diamonds, .three),
        });
        try expect(hand.score == 3 + 4 + 5 + 6 + 7);
        try expect(hand.rank == .straight_flush);
        try expect(hand.kicker != null);
        try expect(hand.kicker.?.eql(Card.init(.diamonds, .queen)));
    }
    {
        const hand = init(&.{
            Card.init(.clubs, .jack),
            Card.init(.diamonds, .five),
            Card.init(.diamonds, .two),
            Card.init(.diamonds, .four),
            Card.init(.diamonds, .queen),
            Card.init(.diamonds, .ace),
            Card.init(.diamonds, .three),
        });
        try expect(hand.score == 1 + 2 + 3 + 4 + 5);
        try expect(hand.rank == .straight_flush);
        try expect(hand.kicker != null);
        try expect(hand.kicker.?.eql(Card.init(.diamonds, .queen)));
    }
}

/// testFourOfAKind checks if cards contains four-of-a-kind.
fn testFourOfAKind(set: []const Card) !?@This() {
    for (set) |c| {
        const cv = @intCast(u8, @enumToInt(c.value));
        if (countValues(set, cv) != 4)
            continue;

        return @This(){
            .rank = .four_of_a_kind,
            .score = cv * 4,
            .kicker = getKicker(set, &.{
                Card.initInt(0, cv),
                Card.initInt(1, cv),
                Card.initInt(2, cv),
                Card.initInt(3, cv),
            }),
        };
    }
    return null;
}

test "hand/four_of_a_kind" {
    {
        const hand = init(&.{
            Card.init(.clubs, .jack),
            Card.init(.diamonds, .six),
            Card.init(.clubs, .six),
            Card.init(.spades, .four),
            Card.init(.clubs, .queen),
            Card.init(.hearts, .six),
            Card.init(.diamonds, .six),
        });
        try expect(hand.score == 6 + 6 + 6 + 6);
        try expect(hand.rank == .four_of_a_kind);
        try expect(hand.kicker != null);
        try expect(hand.kicker.?.eql(Card.init(.clubs, .queen)));
    }
}

/// testFullHouse checks if cards contains a full house.
fn testFullHouse(set: []const Card) !?@This() {
    for (set) |c1| {
        const v1 = @intCast(u8, @enumToInt(c1.value));
        if (countValues(set, v1) < 3)
            continue;

        for (set) |c2| {
            const v2 = @intCast(u8, @enumToInt(c2.value));
            if (v1 == v2 or countValues(set, v2) < 2)
                continue;

            return @This(){
                .rank = .full_house,
                .score = v1 * 3 + v2 * 2,
                .kicker = getKicker(set, &.{
                    Card.initInt(0, v1),
                    Card.initInt(1, v1),
                    Card.initInt(2, v1),
                    Card.initInt(3, v1),
                    Card.initInt(0, v2),
                    Card.initInt(1, v2),
                    Card.initInt(2, v2),
                    Card.initInt(3, v2),
                }),
            };
        }
    }
    return null;
}

test "hand/full_house" {
    {
        const hand = init(&.{
            Card.init(.clubs, .two),
            Card.init(.diamonds, .four),
            Card.init(.hearts, .ace),
            Card.init(.spades, .two),
            Card.init(.clubs, .ace),
            Card.init(.diamonds, .three),
            Card.init(.hearts, .two),
        });
        try expect(hand.score == 14 + 14 + 2 + 2 + 2);
        try expect(hand.rank == .full_house);
        try expect(hand.kicker != null);
        try expect(hand.kicker.?.eql(Card.init(.diamonds, .four)));
    }
}

fn testFlush(set: []const Card) !?@This() {
    for (set) |c1| {
        const s1 = @intCast(u8, @enumToInt(c1.suit));
        if (countSuits(set, s1) < 5)
            continue;

        var exclude: [16]Card = undefined;
        var n: usize = 0;
        var score: u8 = 0;

        for (set) |c2| {
            const s2 = @intCast(u8, @enumToInt(c2.suit));
            if (s2 == s1 and n < exclude.len) {
                score += @intCast(u8, @enumToInt(c2.value));
                exclude[n] = c2;
                n += 1;
            }
        }

        return @This(){
            .rank = .flush,
            .score = score,
            .kicker = getKicker(set, exclude[0..n]),
        };
    }

    return null;
}

test "hand/flush" {
    {
        const hand = init(&.{
            Card.init(.clubs, .jack),
            Card.init(.diamonds, .four),
            Card.init(.clubs, .six),
            Card.init(.spades, .four),
            Card.init(.clubs, .queen),
            Card.init(.clubs, .three),
            Card.init(.clubs, .seven),
        });
        try expect(hand.score == 12 + 11 + 7 + 6 + 3);
        try expect(hand.rank == .flush);
        try expect(hand.kicker != null);
        try expect(hand.kicker.?.eql(Card.init(.diamonds, .four)));
    }
}

/// testStraight checks if cards contains a straight.
fn testStraight(set: []const Card) !?@This() {
    for (set) |c| {
        const cv = @intCast(u8, @enumToInt(c.value));

        if (containsValue(set, cv - 1) and
            containsValue(set, cv - 2) and
            containsValue(set, cv - 3) and
            containsValue(set, cv - 4))
        {
            return @This(){
                .rank = .straight,
                .score = cv * 5 - 1 - 2 - 3 - 4,
                .kicker = getKicker(set, &.{
                    c,
                    cardForValue(set, cv - 1).?,
                    cardForValue(set, cv - 2).?,
                    cardForValue(set, cv - 3).?,
                    cardForValue(set, cv - 4).?,
                }),
            };
        }

        // A 2 3 4 5 -> Ace counts as 1.
        if (cv == 14 and
            containsValue(set, 2) and
            containsValue(set, 3) and
            containsValue(set, 4) and
            containsValue(set, 5))
        {
            return @This(){
                .rank = .straight,
                .score = 1 + 2 + 3 + 4 + 5,
                .kicker = getKicker(set, &.{
                    c,
                    cardForValue(set, 2).?,
                    cardForValue(set, 3).?,
                    cardForValue(set, 4).?,
                    cardForValue(set, 5).?,
                }),
            };
        }
    }
    return null;
}

test "hand/straight" {
    {
        const hand = init(&.{
            Card.init(.clubs, .jack),
            Card.init(.diamonds, .five),
            Card.init(.clubs, .six),
            Card.init(.spades, .four),
            Card.init(.clubs, .queen),
            Card.init(.hearts, .seven),
            Card.init(.diamonds, .three),
        });
        try expect(hand.score == 3 + 4 + 5 + 6 + 7);
        try expect(hand.rank == .straight);
        try expect(hand.kicker != null);
        try expect(hand.kicker.?.eql(Card.init(.clubs, .queen)));
    }
    {
        const hand = init(&.{
            Card.init(.clubs, .jack),
            Card.init(.diamonds, .five),
            Card.init(.clubs, .ace),
            Card.init(.spades, .four),
            Card.init(.clubs, .queen),
            Card.init(.hearts, .two),
            Card.init(.diamonds, .three),
        });
        try expect(hand.score == 1 + 2 + 3 + 4 + 5);
        try expect(hand.rank == .straight);
        try expect(hand.kicker != null);
        try expect(hand.kicker.?.eql(Card.init(.clubs, .queen)));
    }
}

fn testThreeOfAKind(set: []const Card) !?@This() {
    for (set) |c| {
        const cv = @intCast(u8, @enumToInt(c.value));
        if (countValues(set, cv) != 3)
            continue;

        return @This(){
            .rank = .three_of_a_kind,
            .score = cv * 3,
            .kicker = getKicker(set, &.{
                Card.init(.clubs, c.value),
                Card.init(.diamonds, c.value),
                Card.init(.hearts, c.value),
                Card.init(.spades, c.value),
            }),
        };
    }
    return null;
}

test "hand/three_of_a_kind" {
    {
        const hand = init(&.{
            Card.init(.clubs, .jack),
            Card.init(.diamonds, .two),
            Card.init(.clubs, .six),
            Card.init(.spades, .four),
            Card.init(.clubs, .queen),
            Card.init(.hearts, .six),
            Card.init(.diamonds, .six),
        });
        try expect(hand.score == 6 + 6 + 6);
        try expect(hand.rank == .three_of_a_kind);
        try expect(hand.kicker != null);
        try expect(hand.kicker.?.eql(Card.init(.clubs, .queen)));
    }
}

fn testTwoPair(set: []const Card) !?@This() {
    for (set) |c1| {
        const v1 = @intCast(u8, @enumToInt(c1.value));
        if (countValues(set, v1) != 2)
            continue;

        for (set) |c2| {
            const v2 = @intCast(u8, @enumToInt(c2.value));
            if (v1 == v2 or countValues(set, v2) != 2)
                continue;

            return @This(){
                .rank = .two_pair,
                .score = v1 * 2 + v2 * 2,
                .kicker = getKicker(set, &.{
                    Card.init(.clubs, c1.value),
                    Card.init(.diamonds, c1.value),
                    Card.init(.hearts, c1.value),
                    Card.init(.spades, c1.value),
                    Card.init(.clubs, c2.value),
                    Card.init(.diamonds, c2.value),
                    Card.init(.hearts, c2.value),
                    Card.init(.spades, c2.value),
                }),
            };
        }
    }
    return null;
}

test "hand/two_pair" {
    {
        const hand = init(&.{
            Card.init(.clubs, .jack),
            Card.init(.diamonds, .two),
            Card.init(.clubs, .ace),
            Card.init(.spades, .two),
            Card.init(.hearts, .queen),
            Card.init(.hearts, .six),
            Card.init(.diamonds, .six),
        });
        try expect(hand.score == 6 + 6 + 2 + 2);
        try expect(hand.rank == .two_pair);
        try expect(hand.kicker != null);
        try expect(hand.kicker.?.eql(Card.init(.clubs, .ace)));
    }
}

/// testPair checks if cards contains a pair.
fn testPair(set: []const Card) !?@This() {
    for (set) |c| {
        const cv = @intCast(u8, @enumToInt(c.value));
        if (countValues(set, cv) != 2)
            continue;
        return @This(){
            .rank = .pair,
            .score = cv * 2,
            .kicker = getKicker(set, &.{
                Card.initInt(0, cv),
                Card.initInt(1, cv),
                Card.initInt(2, cv),
                Card.initInt(3, cv),
            }),
        };
    }
    return null;
}

test "hand/pair" {
    {
        const hand = init(&.{
            Card.init(.clubs, .jack),
            Card.init(.hearts, .six),
            Card.init(.diamonds, .two),
            Card.init(.clubs, .ace),
            Card.init(.spades, .four),
            Card.init(.clubs, .queen),
            Card.init(.diamonds, .six),
        });
        try expect(hand.score == 6 + 6);
        try expect(hand.rank == .pair);
        try expect(hand.kicker != null);
        try expect(hand.kicker.?.eql(Card.init(.clubs, .ace)));
    }
}

/// getKicker returns the highest card in @set not present in @exclude.
/// Returns null if there is no card left.
fn getKicker(set: []const Card, exclude: []const Card) ?Card {
    for (set) |c| {
        if (!containsCard(exclude, c))
            return c;
    }
    return null;
}

fn testGetKicker(in: []Card, except: []const Card, want: Card) !void {
    std.sort.sort(Card, in, SortByValueAndSuit{}, SortByValueAndSuit.f);
    const have = getKicker(in, except);
    try expect(have != null);
    try expect(have.?.eql(want));
}

test "getKicker" {
    try testGetKicker(
        &.{
            Card.init(.hearts, .ten),
        },
        &.{},
        Card.init(.hearts, .ten),
    );
    try testGetKicker(
        &.{
            Card.init(.clubs, .two),
            Card.init(.hearts, .ten),
        },
        &.{},
        Card.init(.hearts, .ten),
    );
    try testGetKicker(
        &.{
            Card.init(.clubs, .two),
            Card.init(.diamonds, .queen),
            Card.init(.hearts, .ten),
        },
        &.{
            Card.init(.diamonds, .queen),
        },
        Card.init(.hearts, .ten),
    );
    try testGetKicker(
        &.{
            Card.init(.clubs, .two),
            Card.init(.diamonds, .queen),
            Card.init(.hearts, .ten),
            Card.init(.hearts, .queen),
        },
        &.{
            Card.init(.diamonds, .queen),
        },
        Card.init(.hearts, .queen),
    );
    try testGetKicker(
        &.{
            Card.init(.diamonds, .ace),
            Card.init(.diamonds, .three),
            Card.init(.diamonds, .queen),
            Card.init(.diamonds, .ten),
            Card.init(.clubs, .ten),
            Card.init(.diamonds, .king),
            Card.init(.diamonds, .jack),
        },
        &.{
            Card.init(.diamonds, .ace),
            Card.init(.diamonds, .queen),
            Card.init(.diamonds, .king),
            Card.init(.diamonds, .jack),
            Card.init(.diamonds, .ten),
        },
        Card.init(.clubs, .ten),
    );
}

/// cardForValue returns the first card with the given value.
/// Returns null if there is no such card.
fn cardForValue(set: []const Card, value: u8) ?Card {
    for (set) |c| {
        if (@intCast(u8, @enumToInt(c.value)) == value)
            return c;
    }
    return null;
}

/// containsCard returns true if set contains c.
inline fn containsCard(set: []const Card, card: Card) bool {
    return contains(set, @enumToInt(card.suit), @enumToInt(card.value));
}

/// contains returns true if set contains c.
fn contains(set: []const Card, suit: u8, value: u8) bool {
    for (set) |c| {
        if (@enumToInt(c.suit) == suit and @enumToInt(c.value) == value)
            return true;
    }
    return false;
}

/// containsValue returns true if set contains a card with the given value.
inline fn containsValue(set: []const Card, value: u8) bool {
    return countValues(set, value) > 0;
}

/// countValues returns the number of cards in the given set with the specified value.
fn countValues(set: []const Card, value: u8) usize {
    var count: usize = 0;
    for (set) |c| {
        if (@intCast(u8, @enumToInt(c.value)) == value)
            count += 1;
    }
    return count;
}

/// countSuits returns the number of cards in the given set with the specified suit.
fn countSuits(set: []const Card, suit: u8) usize {
    var count: usize = 0;
    for (set) |c| {
        if (@intCast(u8, @enumToInt(c.suit)) == suit)
            count += 1;
    }
    return count;
}

const SortByValueAndSuit = struct {
    fn f(_: @This(), lhs: Card, rhs: Card) bool {
        const va = @enumToInt(lhs.value);
        const vb = @enumToInt(rhs.value);
        const sa = @enumToInt(lhs.suit);
        const sb = @enumToInt(rhs.suit);
        return (va > vb) or (va == vb and sa < sb);
    }
};

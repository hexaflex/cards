const std = @import("std");
const expect = std.testing.expect;

pub const holdem = @import("holdem/main.zig");

test "cards" {
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(Card);
    std.testing.refAllDecls(Deck);
}

/// Card represents a single card in a deck.
pub const Card = packed struct {
    pub const Suit = enum(u2) {
        clubs,
        diamonds,
        hearts,
        spades,
    };

    pub const Value = enum(u4) {
        two = 2,
        three = 3,
        four = 4,
        five = 5,
        six = 6,
        seven = 7,
        eight = 8,
        nine = 9,
        ten = 10,
        jack = 11,
        queen = 12,
        king = 13,
        ace = 14,
    };

    value: Value,
    suit: Suit,

    /// init creates a card with the given suit and value.
    pub inline fn init(_suit: Suit, _value: Value) @This() {
        return .{
            .value = _value,
            .suit = _suit,
        };
    }

    /// initInt creates a card with the given suit and value.
    pub inline fn initInt(_suit: u8, _value: u8) @This() {
        return .{
            .value = @intToEnum(Value, @intCast(u4, _value & 0b1111)),
            .suit = @intToEnum(Suit, @intCast(u2, _suit & 0b11)),
        };
    }

    /// eql returns true if the given cards are equal.
    pub inline fn eql(self: @This(), other: @This()) bool {
        return self.suit == other.suit and self.value == other.value;
    }

    /// toString returns the card's name in string form.
    /// This is a static string. Do not free.
    pub inline fn toString(self: @This()) []const u8 {
        const key = @intCast(usize, @enumToInt(self.suit)) << 4 | @intCast(usize, @enumToInt(self.value));
        return card_name_table[key];
    }
};

/// card_name_table is a static table holding string versions of each possible card's name.
/// It is to be indexed by the card's _value.
const card_name_table = blk: {
    var tbl: [64][]const u8 = undefined;
    var suit: usize = 0;

    while (suit < 4) : (suit += 1) {
        const suit_str = switch (@intToEnum(Card.Suit, suit)) {
            .clubs => "♣",
            .diamonds => "♦",
            .hearts => "♥",
            .spades => "♠",
        };

        var value: usize = 2;
        while (value <= 14) : (value += 1) {
            const key = (suit << 4) | value;
            tbl[key] = suit_str ++ switch (value) {
                2 => "2",
                3 => "3",
                4 => "4",
                5 => "5",
                6 => "6",
                7 => "7",
                8 => "8",
                9 => "9",
                10 => "10",
                11 => "J",
                12 => "Q",
                13 => "K",
                14 => "A",
                else => unreachable,
            };
        }
    }

    break :blk tbl;
};

test "card" {
    {
        const c = Card.init(.clubs, .two);
        try expect(c.suit == .clubs);
        try expect(c.value == .two);
        try expect(std.mem.eql(u8, c.toString(), "♣2"));
    }
    {
        const c = Card.init(.hearts, .seven);
        try expect(c.suit == .hearts);
        try expect(c.value == .seven);
        try expect(std.mem.eql(u8, c.toString(), "♥7"));
    }
    {
        const c = Card.init(.diamonds, .ace);
        try expect(c.suit == .diamonds);
        try expect(c.value == .ace);
        try expect(std.mem.eql(u8, c.toString(), "♦A"));
    }
}

/// Deck represents a deck of 52 playing cards.
pub const Deck = struct {
    _cards: [52]Card = undefined,
    _index: usize = 0,

    /// init creates a full, unshuffled deck of cards.
    pub fn init() @This() {
        var self = @This(){};
        self.reset();
        return self;
    }

    /// reset resets the deck, returning all cards to it.
    pub fn reset(self: *@This()) void {
        self._index = 0;
        var suit: u8 = 0;
        while (suit < 4) : (suit += 1) {
            var value: u8 = 2;
            while (value <= 14) : (value += 1) {
                self._cards[self._index] = Card.initInt(suit, value);
                self._index += 1;
            }
        }
    }

    /// takeSlice takes @slice.len cards from the deck and stores them in @slice.
    /// Returns an error if the deck does not have enough cards to fill @slice.
    pub fn takeSlice(self: *@This(), slice: []Card) error{NotEnoughCards}!void {
        if (slice.len > self._index)
            return error.NotEnoughCards;

        for (slice) |*c|
            c.* = self.take().?;
    }

    /// take removes and returns the top card from the deck.
    /// Returns null if the deck is empty.
    pub fn take(self: *@This()) ?Card {
        if (self._index == 0) return null;
        self._index -= 1;
        return self._cards[self._index];
    }

    /// len returns the number of cards in the deck.
    pub inline fn len(self: *@This()) usize {
        return self._index;
    }

    /// shuffle shuffles all cards in the deck using std.rand.DefaultPrng and a random seed.
    pub inline fn shuffle(self: *@This()) void {
        self.shuffleWithSeed(@intCast(u64, std.time.nanoTimestamp() & 0xffffffffffffffff));
    }

    /// shuffleWithSeed shuffles all cards in the deck using std.rand.DefaultPrng and the given seed.
    pub inline fn shuffleWithSeed(self: *@This(), seed: u64) void {
        self.shuffleWithRNG(std.rand.DefaultPrng.init(seed).random());
    }

    /// shuffleWithRNG shuffles all cards in the deck using the given Random Number generator.
    pub inline fn shuffleWithRNG(self: *@This(), rng: std.rand.Random) void {
        rng.shuffle(Card, self._cards[0..self._index]);
    }
};

test "deck/take" {
    var deck = Deck.init();
    try expect(deck.len() == 52);

    var i: usize = 0;
    while (i < 52) : (i += 1)
        try expect(deck.take() != null);

    try expect(deck.take() == null);
}

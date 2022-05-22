## cards

This library implements a deck of 52 playing cards.
It has a sub-package which provides Texas Hold'em poker hand rankings.

A card is represented by a packed struct with a 2-bit suit and a 4-bit value.

Deck shuffling with the `Deck.shuffle` function uses `std.rand.DefaultPrng`
with a nanosecond timestamp as seed.

Deck shuffling with the `Deck.shuffleWithSeed` function uses `std.rand.DefaultPrng`
with a seed provided by the caller.

Deck shuffling with the `Deck.shuffleWithRNG` function uses the `std.rand.Random`
implementation provided by the caller.


### Usage

Assuming you have cloned this repository in `your_project/libs/cards`,
building is done by adding the following to your `build.zig`:

```zig
const cards = @import("libs/cards/build.zig");
...
const my_command = b.addExecutable(...);
...
cards.link(my_command);
```


Here is an example ranking poker hands and printing them to stdout:

```zig
    const cards = @import("cards");
    const Card = cards.Card;
    const Deck = cards.Deck;
    const Hand = cards.holdem.Hand;
    ...

    var deck = Deck.init();
    deck.shuffle();

    var cards: [7]Card = undefined;
    try deck.takeSlice(&cards);

    const card_str = try toStringSlice(allocator, &cards);
    defer allocator.free(card_str);

    const hand = Hand.init(&cards);
    std.debug.print("set: {s}, rank: {}, score: {}, kicker: {s}\n", .{
        card_str,
        hand.rank,
        hand.score,
        if (hand.kicker) |k| k.toString() else "n/a",
    });
```

Example outputs:

```
set: ♣7 ♣A ♥3 ♣5 ♥8 ♣8 ♠8, rank: .three_of_a_kind, score: 24, kicker: ♣A
set: ♦3 ♦9 ♣7 ♦2 ♥Q ♣3 ♥8, rank: .pair, score: 6, kicker: ♥Q
set: ♣3 ♥J ♣Q ♠10 ♥4 ♦K ♥2, rank: .highcard, score: 13, kicker: ♣Q
set: ♣8 ♣6 ♠8 ♣Q ♥K ♣3 ♣J, rank: .flush, score: 40, kicker: ♥K
```


### License

Unless otherwise stated, this project and its contents are provided under a
3-Clause BSD license. Refer to the LICENSE file for its contents.
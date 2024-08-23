module game::lottery {
    use sui::event;
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::random::{Random, new_generator};
    use game::suichat::{emit_new_msg};

    /// Error codes
    // const EGameInProgress: u64 = 0;
    const EGameAlreadyCompleted: u64 = 1;
    const EInvalidAmount: u64 = 2;
    // const EGameMismatch: u64 = 3;
    // const ENotWinner: u64 = 4;
    // const ENoParticipants: u64 = 5;

    const MAX_PARTICIPANTS: u64 = 100;
    const DECIMALS: u64 = 1000000000;
    const PREMIUM_RATE: u64 = 10;

    /// Game represents a set of parameters of a single game.
    public struct Game<phantom T> has key, store {
        id: UID,
        cost: u64,
        participants: u64,
        addresses: vector<address>,
        max_participants: u64,
        winner: u64,
        balance: Balance<T>,
        premium_rate: u64,
        owner: address,
        winnner_address: Option<address>,
    }

    /// Ticket represents a participant in a single game.
    public struct Ticket<phantom T> has key, store {
        id: UID,
        game_id: ID,
        participant_index: u64,
    }

    /// Create a shared-object Game.
    entry fun create<T>(sender: address, coin_type: vector<u8>, ctx: &mut TxContext) {
        let game = Game<T> {
            id: object::new(ctx),
            cost: DECIMALS,
            participants: 0,
            addresses: vector::empty<address>(),
            max_participants: MAX_PARTICIPANTS,
            winner: 0,
            balance: balance::zero(),
            premium_rate: PREMIUM_RATE,
            owner: sender,
            winnner_address: option::none(),
        };

        event::emit(
            NewGame<T> { 
                game_id: object::id(&game),
                round: 0,
            }
        );

        transfer::share_object(game);
        emit_new_msg(
                sender, 
                b"new_lottery_created", 
                0, 
                b"New lottery created.",
                coin_type
        );
    }

    entry fun set_cost<T>(game: &mut Game<T>, cost: u64)
    {
        game.cost = cost;
    }

    entry fun set_max_participants<T>(game: &mut Game<T>, max_participants: u64)
    {
        game.max_participants = max_participants;
    }

    entry fun set_premium_rate<T>(game: &mut Game<T>, premium_rate: u64)
    {
        game.premium_rate = premium_rate;
    }

    /// Anyone can determine a winner.
    ///
    /// The function is defined as private entry to prevent calls from other Move functions. (If calls from other
    /// functions are allowed, the calling function might abort the transaction depending on the winner.)
    /// Gas based attacks are not possible since the gas cost of this function is independent of the winner.
    entry fun determine_winner<T>(game: &mut Game<T>, r: &Random, coin_type: vector<u8>, ctx: &mut TxContext) {
        
        assert!(game.winner == 0, EGameAlreadyCompleted);
        // assert!(game.participants == game.max_participants, ENoParticipants);
        let mut generator = r.new_generator(ctx);
        let winner = generator.generate_u64_in_range(1, game.participants);
        game.winner = winner;
        let winner_address = vector::remove<address>(&mut game.addresses, winner - 1);
        game.winnner_address = option::some<address>(winner_address);

        let reward_amount = balance::value(&game.balance) * (100 - game.premium_rate) / 100;
        let premium_amount = balance::value(&game.balance) * game.premium_rate / 100;
        let reward = coin::take<T>(&mut game.balance, reward_amount, ctx);
        let premium = coin::take<T>(&mut game.balance, premium_amount, ctx);
        transfer::public_transfer(premium, game.owner);
        transfer::public_transfer(reward, winner_address);

        emit_new_msg(
            winner_address, 
            b"new_lottery_winner", 
            game.max_participants, 
            //TODO: error code 1 EInvalidUTF8
            // address::to_bytes(winner_address),
            // winner_address.to_bytes()
            b"New lottery winner!",
            coin_type
        );
        //emit winner gameId participant_index
    }

    /// Anyone can play and receive a ticket.
    entry fun buy_ticket<T>(game: &mut Game<T>, coin: Coin<T>, r: &Random, coin_type: vector<u8>, ctx: &mut TxContext) {
        let sender = ctx.sender();
        assert!(coin.value() == game.cost, EInvalidAmount);
        vector::push_back<address>(&mut game.addresses, sender);
        game.participants = game.participants + 1;
        coin::put(&mut game.balance, coin);
        
        emit_new_msg(
            sender, 
            b"new_lottery_buy", 
            game.participants, 
            b"New lottery buy.",
            coin_type
        );

        event::emit(
            NewBuy<T> { 
                game_id: object::id(game),
                buyer: sender,
                participants: game.participants,
            }
        );

        if(game.participants >= game.max_participants)
        {
            determine_winner<T>(game, r, coin_type, ctx);
            create<T>(game.owner, coin_type, ctx);
        };

        let ticket = Ticket<T> {
            id: object::new(ctx),
            game_id: object::id(game),
            participant_index: game.participants,
        };
        transfer::public_transfer(ticket, sender);

    }

    public struct NewGame<phantom T> has copy, drop, store {
        game_id: ID,
        round: u64,
    }

    public struct NewBuy<phantom T> has copy, drop, store {
        game_id: ID,
        buyer: address,
        participants: u64,
    }
    // The winner can take the prize.
    
    // entry fun redeem<T>(ticket: Ticket<T>, game: &mut Game<T>, ctx: &mut TxContext) {
    //     let sender = ctx.sender();
    //     assert!(object::uid_to_inner(&game.id) == ticket.game_id, EGameMismatch);
    //     assert!(game.winner == &ticket.participant_index, ENotWinner);
    //     destroy_ticket(ticket);
        
    //     // object::delete(id);
    //     let reward_amount = balance::value(&game.balance) * (100 - game.premium_rate) / 100;
    //     let premium_amount = balance::value(&game.balance) * game.premium_rate / 100;
    //     let reward = coin::take<T>(&mut game.balance, reward_amount, ctx);
    //     let premium = coin::take<T>(&mut game.balance, premium_amount, ctx);
    //     transfer::public_transfer(premium, game.owner);
    //     transfer::public_transfer(reward, sender);
    // }

    // public fun destroy_ticket<T>(ticket: Ticket<T>) {
    //     let Ticket { id, game_id: _, participant_index: _ } = ticket;
    //     object::delete(id);
    // }
}
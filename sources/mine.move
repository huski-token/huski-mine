module game::mine {
    use sui::balance::{Self, Balance};
    // use sui::clock::Clock;
    use sui::coin::{Self, Coin};
    use sui::random::{Random, new_generator};
    use sui::event;
    use sui::package::{Self, Publisher};
    use std::debug;
    use game::suichat::{emit_new_msg};

    /// Error codes
    const EZeroAmount: u64 = 0;
    const ENotOwner: u64 = 1;
    const EInvalidNumber: u64 = 2;
    const ENotWinner: u64 = 3;
    const EBankClosed: u64 = 4;

    const DECIMALS: u64 = 1000000000;
    const MIN_BET: u64 = 1000000000;
    const MAX_BET: u64 = 1000000000;
    const PREMIUM_RATE: u64 = 10;
    const HOUSE_CUT: u64 = 1;

    public struct MINE has drop {}

    #[allow(unused_function)]
    fun init(otw: MINE,_: &mut TxContext) {
        package::claim_and_keep(otw, _);
    }

/* -------------------------------------------------------- */
    public struct NetValueEvent<phantom T0> has copy, drop, store {
        net_value: u64
    }

/* -------------------------------------------------------- */
    //Bank
    public struct Bank<phantom T0, phantom T1> has key, store {
        id: UID,
        // balance + premium = net_value * total_shares
        balance: Balance<T0>,
        shares: Balance<T1>,
        net_value: u64,
        total_shares: u64,
        // premium rate
        premium_rate: u64,
        // house cut rate
        house_cut: u64,
        // minium bet value
        min_bet: u64,
        max_bet: u64,
        status: u64,
        decimals: u64,
    }

    entry fun create_bank<T0,T1>(publisher: &Publisher, decimals: u64, ctx: &mut TxContext) {
        assert!(package::from_package<MINE>(publisher), ENotOwner);
        let bank = Bank<T0,T1>{
            id: object::new(ctx),
            balance: balance::zero<T0>(),
            shares: balance::zero<T1>(),
            net_value: DECIMALS,
            total_shares: 0,
            premium_rate: PREMIUM_RATE,
            house_cut: HOUSE_CUT,
            min_bet: decimals,
            max_bet: decimals,
            status: 1,
            decimals: decimals,
        };
        transfer::public_share_object<Bank<T0,T1>>(bank);
    }

    entry fun add_shares_to_bank<T0,T1>(
        publisher: &Publisher,
        bank: &mut Bank<T0,T1>, 
        token: Coin<T1>
    ) {
        assert!(package::from_package<MINE>(publisher), ENotOwner);
        assert!(coin::value(&token) > 0, EZeroAmount);
        balance::join(&mut bank.shares, coin::into_balance(token));
    }

    entry fun remove_shares_from_bank<T0,T1>(
        publisher: &Publisher,
        bank: &mut Bank<T0,T1>,
        ctx: &mut TxContext
    ) {
        assert!(package::from_package<MINE>(publisher), ENotOwner);
        let amount = balance::value(&bank.shares);
        assert!(amount > 0, EZeroAmount);
        let shares_to_take = coin::take(&mut bank.shares, amount, ctx);
        let sender = tx_context::sender(ctx);
        transfer::public_transfer(shares_to_take, sender)
    }

    // entry fun add_tokens_to_bank<T0,T1>(
    //     publisher: &Publisher,
    //     bank: &mut Bank<T0,T1>, 
    //     token: Coin<T0>
    // ) {
    //     assert!(package::from_package<MINE>(publisher), ENotOwner);
    //     assert!(coin::value(&token) > 0, EZeroAmount);
    //     balance::join(&mut bank.balance, coin::into_balance(token));
    // }

    // #[allow(unused_function, lint(self_transfer))]
    // entry fun remove_all_from_bank<T0,T1>(
    //     publisher: &Publisher,
    //     bank: &mut Bank<T0,T1>,
    //     ctx: &mut TxContext
    // ) {
    //     assert!(package::from_package<MINE>(publisher), ENotOwner);
    //     assert!(balance::value(&bank.balance) > 0, EInvalidNumber);
    //     let amount = balance::value(&bank.balance);
    //     let token=coin::take(&mut bank.balance, amount, ctx);
    //     let sender = tx_context::sender(ctx);
    //     transfer::public_transfer(token, sender)
    // }

    // entry fun set_net_value<T0,T1>(publisher: &Publisher, bank: &mut Bank<T0,T1>, net_value: u64) {
    //     assert!(package::from_package<MINE>(publisher), ENotOwner);
    //     bank.net_value = net_value;
    // }

    entry fun set_house_cut<T0,T1>(publisher: &Publisher, bank: &mut Bank<T0,T1>, house_cut: u64) {
        assert!(package::from_package<MINE>(publisher), ENotOwner);
        bank.house_cut = house_cut;
    }

    entry fun set_premium_rate<T0,T1>(publisher: &Publisher, bank: &mut Bank<T0,T1>, premium_rate: u64) {
        assert!(package::from_package<MINE>(publisher), ENotOwner);
        assert!(premium_rate >= 5, EInvalidNumber);
        bank.premium_rate = premium_rate;
    }

    entry fun set_min_bet<T0,T1>(publisher: &Publisher, bank: &mut Bank<T0,T1>, min_bet: u64) {
        assert!(package::from_package<MINE>(publisher), ENotOwner);
        bank.min_bet = min_bet;
    }

    entry fun set_max_bet<T0,T1>(publisher: &Publisher, bank: &mut Bank<T0,T1>, max_bet: u64) {
        assert!(package::from_package<MINE>(publisher), ENotOwner);
        bank.max_bet = max_bet;
    }

    entry fun set_status<T0,T1>(publisher: &Publisher, bank: &mut Bank<T0,T1>, status: u64) {
        assert!(package::from_package<MINE>(publisher), ENotOwner);
        bank.status = status;
    }

/* -------------------------------------------------------- */
    entry fun add_to_bank<T0,T1>(
        // publisher: &Publisher,
        bank: &mut Bank<T0,T1>, 
        token: Coin<T0>,
        ctx: &mut TxContext
    ) {
        // assert!(package::from_package<MINE>(publisher), ENotOwner);
        assert!(coin::value(&token) > 0, EZeroAmount);
        let shares_amount = (coin::value(&token) as u128) * (DECIMALS as u128) / (bank.net_value as u128);
        assert!(shares_amount <= balance::value(&bank.shares) as u128, EInvalidNumber);
        bank.total_shares = bank.total_shares + (shares_amount as u64);
        balance::join(&mut bank.balance, coin::into_balance(token));
        // take shares from here
        assert!(shares_amount as u64 > 0, EInvalidNumber);
        assert!(shares_amount as u64 <= balance::value(&bank.shares), EInvalidNumber);
        let shares_to_take = coin::take(&mut bank.shares, shares_amount as u64, ctx);
        let sender = tx_context::sender(ctx);
        event::emit(TotalStake<T0> { total_stake: bank.total_shares});
        transfer::public_transfer(shares_to_take, sender)
    }

    entry fun remove_from_bank<T0,T1>(
        bank: &mut Bank<T0,T1>,
        shares: Coin<T1>,
        ctx: &mut TxContext
    ) {
        assert!(coin::value(&shares) > 0, EZeroAmount);
        assert!(coin::value(&shares) <= bank.total_shares, EInvalidNumber);
        bank.total_shares = bank.total_shares - coin::value(&shares);
        let tokens_amount = (coin::value(&shares) as u128) * (bank.net_value as u128) / (DECIMALS as u128) ;
        balance::join(&mut bank.shares, coin::into_balance(shares));
        // take TOKEN from here
        assert!(tokens_amount as u64 > 0, EInvalidNumber);
        assert!(tokens_amount as u64 <= balance::value(&bank.balance), EInvalidNumber);
        let tokens_to_take = coin::take(&mut bank.balance, tokens_amount as u64, ctx);
        let sender = tx_context::sender(ctx);
        event::emit(TotalStake<T0> { total_stake: bank.total_shares});
        transfer::public_transfer(tokens_to_take, sender)
    }

/* -------------------------------------------------------- */
    public struct Odds has key, store {
        id: UID,
        values: vector<u64>,
    }

    entry fun create_odds(publisher: &Publisher, values: vector<u64>, ctx: &mut TxContext){
        assert!(package::from_package<MINE>(publisher), ENotOwner);
        let odds = Odds {
            id: object::new(ctx),
            values: values,
        };
        transfer::public_share_object<Odds>(odds);
    }

    entry fun set_odds(publisher: &Publisher, odds: &mut Odds, values: vector<u64>){
        assert!(package::from_package<MINE>(publisher), ENotOwner);
        odds.values = values;
    }

/* -------------------------------------------------------- */
    //Game
    public struct NewWin<phantom T0> has copy, drop, store {
        player: address,
        win: u64,
    }

    public struct NewPlay<phantom T0> has copy, drop, store {
        amount: u64,
    }

    public struct Ticket<phantom T0> has key, store{
        id: UID,
        game: u64,
        gem_amount: u64,
        gem_number: u64,
        bomb_number: u64,
        bet: u64,
        win: u64,
    }

    entry fun mine_16<T0,T1>(
        r: &Random,
        bank: &mut Bank<T0,T1>,
        token: Coin<T0>,
        gem_amount: u64,
        vip: &mut VipLevel<T0>,
        coin_type: vector<u8>,
        ctx: &mut TxContext
    ) {
        let amount = coin::value(&token);
        mine<T0,T1>(r, 16, amount, gem_amount, bank, vip, coin_type, ctx);
        pay<T0,T1>(bank, token);
        
        //net value event
        event::emit(NetValueEvent<T0> { net_value: bank.net_value});
        event::emit(NewPlay<T0> { amount: amount});
    }

    entry fun mine_25<T0,T1>(
        r: &Random,
        bank: &mut Bank<T0,T1>,
        token: Coin<T0>,
        gem_amount: u64,
        vip: &mut VipLevel<T0>,
        coin_type: vector<u8>,
        ctx: &mut TxContext
    ) {
        let amount = coin::value(&token);
        mine<T0,T1>(r, 25, amount, gem_amount, bank, vip, coin_type, ctx);
        pay<T0,T1>(bank, token);
        
        //net value event
        event::emit(NetValueEvent<T0> { net_value: bank.net_value});
        event::emit(NewPlay<T0> { amount: amount});
    }

    entry fun mine_36<T0,T1>(
        r: &Random,
        bank: &mut Bank<T0,T1>,
        token: Coin<T0>,
        gem_amount: u64,
        vip: &mut VipLevel<T0>,
        coin_type: vector<u8>,
        ctx: &mut TxContext
    ) {
        let amount = coin::value(&token);
        mine<T0,T1>(r, 36, amount, gem_amount, bank, vip, coin_type, ctx);
        pay<T0,T1>(bank, token);
        
        //net value event
        event::emit(NetValueEvent<T0> { net_value: bank.net_value});
        event::emit(NewPlay<T0> { amount: amount});
    }

    entry fun mine_16x10<T0,T1>(
        r: &Random,
        bank: &mut Bank<T0,T1>,
        token: Coin<T0>,
        gem_amount: u64,
        vip: &mut VipLevel<T0>,
        coin_type: vector<u8>,
        ctx: &mut TxContext
    ) {
        let amount = coin::value(&token);
        let mut count: u64 = 1;
        while (count <= 10) {
            mine<T0,T1>(r, 16, amount/10, gem_amount, bank, vip, coin_type, ctx);
            count = count + 1
        };
        pay<T0,T1>(bank, token);
        
        //net value event
        event::emit(NetValueEvent<T0> { net_value: bank.net_value});
        event::emit(NewPlay<T0> { amount: amount});
    }

    entry fun mine_25x10<T0,T1>(
        r: &Random,
        bank: &mut Bank<T0,T1>,
        token: Coin<T0>,
        gem_amount: u64,
        vip: &mut VipLevel<T0>,
        coin_type: vector<u8>,
        ctx: &mut TxContext
    ) {
        let amount = coin::value(&token);
        let mut count: u64 = 1;
        while (count <= 10) {
            mine<T0,T1>(r, 25, amount/10, gem_amount, bank, vip, coin_type, ctx);
            count = count + 1
        };
        pay<T0,T1>(bank, token);
        
        //net value event
        event::emit(NetValueEvent<T0> { net_value: bank.net_value});
        event::emit(NewPlay<T0> { amount: amount});
    }

    entry fun mine_36x10<T0,T1>(
        r: &Random,
        bank: &mut Bank<T0,T1>,
        token: Coin<T0>,
        gem_amount: u64,
        vip: &mut VipLevel<T0>,
        coin_type: vector<u8>,
        ctx: &mut TxContext
    ) {
        let amount = coin::value(&token);
        let mut count: u64 = 1;
        while (count <= 10) {
            mine<T0,T1>(r, 36, amount/10, gem_amount, bank, vip, coin_type, ctx);
            count = count + 1
        };
        pay<T0,T1>(bank, token);
        
        //net value event
        event::emit(NetValueEvent<T0> { net_value: bank.net_value});
        event::emit(NewPlay<T0> { amount: amount});
    }

    #[allow(lint(self_transfer))]
    fun mine<T0,T1>(
        r: &Random,
        game: u64, 
        bet: u64, 
        gem_amount: u64, 
        bank: &mut Bank<T0,T1>, 
        vip: &mut VipLevel<T0>, 
        coin_type: vector<u8>,
        ctx: &mut TxContext
    ) {
        //assert
        assert!(gem_amount >= 1, EInvalidNumber);
        assert!(gem_amount < game, EInvalidNumber);
        assert!(bank.status == 1, EBankClosed);
        assert!(bet >= bank.min_bet, EInvalidNumber);
        assert!(bet <= bank.max_bet, EInvalidNumber);
        let sender = ctx.sender();

        let mut generator = r.new_generator(ctx);
        let number_gem = generator.generate_u64_in_range(1, game);
        let mut generator = r.new_generator(ctx);
        let number_bomb = generator.generate_u64_in_range(1, game - 1);

        let mut ticket = Ticket<T0> {
            id: object::new(ctx),
            game: game,
            gem_amount: gem_amount,
            gem_number: number_gem,
            bomb_number: number_bomb,
            bet: bet,
            win: 0,
        };
        // debug::print(&ticket);

        if(ticket.bomb_number >= ticket.gem_number)
        {
            ticket.bomb_number = ticket.bomb_number + 1;
        };

        // player win
        if(ticket.gem_number < ticket.bomb_number && ticket.gem_number <= gem_amount)
        {
            // bugfixed
            let total_win = bet * 2 * game * (game - 1)/ (2 * game - gem_amount - 1) / gem_amount;
            let total_benefit: u64 = total_win - bet;
            ticket.win = total_benefit * (100 - bank.house_cut - bank.premium_rate) / 100 + bet;
            
            vip.premium = vip.premium + total_benefit * vip.level / 100;

            bank.net_value = (((bank.net_value as u128) * (bank.total_shares as u128) - (total_benefit as u128) * (100 - (bank.premium_rate - vip.level) as u128) * (DECIMALS as u128) / 100) / (bank.total_shares as u128)) as u64;

            event::emit(NewWin<T0> { player: sender, win: ticket.win});
            emit_new_msg(
                sender, 
                b"win", 
                ticket.win, 
                b"Congratulations on winning the grand prize!",
                coin_type
            );
        }
        // player loose
        else
        {
            vip.premium = vip.premium + bet * vip.level / 100;
            bank.net_value = bank.net_value + ((bet as u128) * (100 - (bank.house_cut + vip.level) as u128) * (DECIMALS as u128) / 100 / (bank.total_shares as u128) as u64);
        };

        handle_vip<T0,T1>(
            bank, 
            vip, 
            bet, 
            sender
        );
        debug::print(&ticket);
        //freeze object
        
        transfer::public_transfer(ticket, sender);
    }
    
    fun pay<T0,T1>(
        bank: &mut Bank<T0,T1>, 
        token: Coin<T0>
    ) {
        assert!(coin::value(&token) >= bank.min_bet, EZeroAmount);
        balance::join(&mut bank.balance, coin::into_balance(token));
    }

    #[allow(unused_function)]
    entry fun redeem<T0,T1>(
        ticket: Ticket<T0>,
        bank: &mut Bank<T0,T1>, 
        ctx: &mut TxContext
    ) {
        if(ticket.win == 0){
            delete(ticket);
        }
        else{
            redeem_from_bank<T0,T1>(bank, ticket.win, ctx);
            delete(ticket);
        };
    }

    #[allow(lint(self_transfer))]
    fun redeem_from_bank<T0,T1>(
        bank: &mut Bank<T0,T1>, 
        amount:u64,
        ctx: &mut TxContext
    ) {
        assert!(amount > 0, ENotWinner);
        assert!(amount <= balance::value(&bank.balance), EInvalidNumber);
        let token = coin::take(&mut bank.balance, amount, ctx);
        let sender = tx_context::sender(ctx);
        transfer::public_transfer(token, sender)
    }

    fun delete<T0>(ticket: Ticket<T0>) {
        let Ticket<T0> { id, game:_, gem_amount: _, gem_number:  _, bomb_number: _, bet:_, win:_} = ticket;
        object::delete(id);
    }
/* -------------------------------------------------------- */
    public struct TotalStake<phantom T0> has copy, drop, store {
        total_stake: u64,
    }
/* -------------------------------------------------------- */
    public struct VipLevel<phantom T0> has key, store {
        id: UID,
        owner: address,
        premium: u64,
        level: u64,
        amount: u64,
        promotion_amount: u64,
        amount_to_next_level: u64,
    }

    public struct NewVip<phantom T0> has copy, drop, store {
        vip_id: ID,
        owner: address,
    }

    entry fun get_new_vip<T0,T1>(bank: & Bank<T0,T1>, ctx: &mut TxContext)
    {
        let sender = ctx.sender();
        let vip = VipLevel<T0>{
            id: object::new(ctx),
            owner: sender,
            premium: 0,
            level: 0,
            amount: 0,
            promotion_amount: 0,
            amount_to_next_level: 100 * bank.decimals,
        };

        event::emit(NewVip<T0> { 
            vip_id: object::id(&vip),
            owner: sender 
        });
        
        transfer::public_share_object<VipLevel<T0>>(vip);
    }

    entry fun redeem_vip_premium<T0,T1>(bank: &mut Bank<T0,T1>, vip: &mut VipLevel<T0>, ctx: &mut TxContext) {
        let sender = ctx.sender();
        assert!(sender == vip.owner, ENotOwner);
        let amount = vip.premium;
        assert!(amount > 0, ENotWinner);
        assert!(amount <= balance::value(&bank.balance), EInvalidNumber);
        let token = coin::take(&mut bank.balance, amount, ctx);
        let sender = tx_context::sender(ctx);
        vip.premium = 0;
        transfer::public_transfer(token, sender)
    }

    entry fun set_vip_level<T0>(publisher: &Publisher, vip: &mut VipLevel<T0>, level: u64) {
        assert!(package::from_package<MINE>(publisher), ENotOwner);
        vip.level = level;
    }

    fun handle_vip<T0,T1>(
        bank: & Bank<T0,T1>, 
        vip: &mut VipLevel<T0>, 
        bet: u64, 
        sender: address
    )
    {
        vip.amount = vip.amount + bet;
        if(vip.owner != sender){
            vip.promotion_amount = vip.promotion_amount + bet;
        };
        
        if(vip.amount < 100 * bank.decimals)
        {
            vip.level = 0;
        };

        if(vip.amount >= 100 * bank.decimals)
        {
            vip.level = 1;
        };

        if(vip.amount >= 1000 * bank.decimals)
        {
            vip.level = 2;
        };

        if(vip.amount >= 10000 * bank.decimals)
        {
            vip.level = 3;
        };

        if(vip.amount >= 100000 * bank.decimals)
        {
            vip.level = 4;
        };

        if(vip.amount >= 1000000 * bank.decimals)
        {
            vip.level = 5;
        };

        if(vip.level == 0)
        {
            vip.amount_to_next_level = 100 * bank.decimals - vip.amount;
        };

        if(vip.level == 1)
        {
            vip.amount_to_next_level = 1000 * bank.decimals - vip.amount;
        };

        if(vip.level == 2)
        {
            vip.amount_to_next_level = 10000 * bank.decimals - vip.amount;
        };

        if(vip.level == 3)
        {
            vip.amount_to_next_level = 100000 * bank.decimals - vip.amount;
        };

        if(vip.level == 4)
        {
            vip.amount_to_next_level = 1000000 * bank.decimals - vip.amount;
        };

        if(vip.level == 5)
        {
            vip.amount_to_next_level = 10000000 * bank.decimals - vip.amount;
        };
    }

/* -------------------------------------------------------- */
    #[test_only]
    /// Wrapper of module initializer for testing
    public(package) fun test_init(ctx: &mut TxContext) {
        init(MINE {}, ctx)
    }
}


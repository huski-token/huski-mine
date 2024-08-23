module game::suichat {
    use sui::event;
    use std::string::{Self, String};
    use sui::package::{Self};
    use sui::sui::SUI;
    use sui::coin::{Coin};

    /// Error codes
    // const EZeroAmount: u64 = 0;
    // const ENotOwner: u64 = 1;
    const EInvalidAmount: u64 = 2;
    // const ENotWinner: u64 = 3;
    // const EBankClosed: u64 = 4;
    const ENullString: u64 = 4;

    // const DECIMALS: u64 = 1000000000;
    const CHAT_PREMIUM: u64 = 100000000;

    public struct SUICHAT has drop {}

    #[allow(unused_function)]
    fun init(otw: SUICHAT, ctx: &mut TxContext) {
        package::claim_and_keep(otw, ctx);
    }

    /* -------------------------------------------------------- */

    // public struct ChatRoom<phantom T> has key, store{
    //     id: UID,
    //     name: vector<u8>,
    // }

    // entry fun create_chat_room<T>(publisher: &Publisher, name: vector<u8>, ctx: &mut TxContext){
    //     assert!(package::from_package<SUICHAT>(publisher), ENotOwner);
    //     let chat_room = ChatRoom<T>{
    //         id: object::new(ctx),
    //         name: name,
    //     };
    //     transfer::public_share_object<ChatRoom<T>>(chat_room);
    // }

    public struct NewMsg has copy, drop, store {
        user: address,
        msg_type: String,
        value: u64,
        msg: String,
        coin_type: String,
    }

    entry fun send_msg(
        msg: vector<u8>,
        coin_type: vector<u8>,
        ctx: &TxContext
    ){
        let sender = ctx.sender();

        assert!(msg!=b"", ENullString);
        emit_new_msg(sender, b"chat", 0, msg, coin_type);
    }

    entry fun send_msg_with_premium(
        premium: Coin<SUI>,
        owner: address,
        msg: vector<u8>,
        coin_type: vector<u8>,
        ctx: &TxContext
    ){
        assert!(premium.value() == CHAT_PREMIUM, EInvalidAmount);
        let sender = ctx.sender();
        transfer::public_transfer(premium, owner);
        
        assert!(msg!=b"", ENullString);
        emit_new_msg(sender, b"chat-with-lottery", 0, msg, coin_type);
    }

    entry public fun emit_new_msg(
        user: address,
        msg_type: vector<u8>,
        value: u64,
        msg: vector<u8>,
        coin_type: vector<u8>
    ){
        event::emit(
            NewMsg { 
                user: user,
                msg_type: string::utf8(msg_type),
                value: value,
                msg: string::utf8(msg),
                coin_type: string::utf8(coin_type)
            }
        );
    }
    /* -------------------------------------------------------- */
}


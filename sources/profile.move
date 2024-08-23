// module game::profile {
//     use sui::package::{Self, Publisher};
//     use sui::coin::{Self, Coin};
//     use sui::sui::SUI;
//     // use sui::event;
//     use sui::dynamic_object_field as ofield;

//     const DECIMALS: u64 = 1000000000;
//     /// Error codes
//     const EZeroAmount: u64 = 0;
//     const ENotOwner: u64 = 1;
//     const EInvalidNumber: u64 = 2;
//     // const ENotWinner: u64 = 3;
//     // const EBankClosed: u64 = 4;
    
//     public struct PROFILE has drop {}

//     #[allow(unused_function)]
//     fun init(otw: PROFILE, _: &mut TxContext) {
//         package::claim_and_keep(otw, _);
//     }

//     /* -------------------------------------------------------- */
//     public struct ProfileMarket has key, store {
//         id: UID,
//         premium_rate: u64,
//     }

//     public entry fun create_market(
//         publisher: &Publisher,
//         ctx: &mut TxContext
//     ) {
//         assert!(package::from_package<Profile>(publisher), ENotOwner);
//         let market = ProfileMarket {
//             id: object::new(ctx),
//             premium_rate: 10,
//         };
//         transfer::public_share_object(market);
//     }

//     entry fun set_premium_rate(market: &mut ProfileMarket, premium_rate:u64)
//     {
//         market.premium_rate = premium_rate;
//     }

//     /* -------------------------------------------------------- */
//     public struct Profile has key, store {
//         id: UID,
//         name: vector<u8>,
//         bytes: vector<u8>,
//         creator: address,
//         price: u64,
//         owner: address,
//     }

//     public entry fun create_profile(
//         publisher: &Publisher,
//         market: &mut ProfileMarket,
//         name: vector<u8>,
//         bytes: vector<u8>,
//         ctx: &mut TxContext
//     ) {
//         assert!(package::from_package<Profile>(publisher), ENotOwner);
//         let sender = tx_context::sender(ctx);
//         let profile = Profile {
//             id: object::new(ctx),
//             name: name,
//             bytes: bytes,
//             creator: sender,
//             price: 10 * DECIMALS,
//             owner: sender
//         };

//         ofield::add<vector<u8>, Profile>(&mut market.id, name, profile);
//     }

//     public entry fun sell_profile(
//         market: &mut ProfileMarket,
//         profile: Profile,
//     ) {
//         // add to market
//         ofield::add(&mut market.id, profile.name, profile);
//     }

//     public entry fun set_price(
//         profile: &mut Profile,
//         price: u64,
//     ) {
//         profile.price = price;
//     }   

//     public entry fun buy_profile(
//         market: &mut ProfileMarket,
//         sui: Coin<SUI>,
//         premium: Coin<SUI>,
//         name: vector<u8>,
//         ctx: &mut TxContext
//     ) {
//         // take from market
//         let mut profile_to_sell: Profile = ofield::remove(&mut market.id, name);

//         let sender = tx_context::sender(ctx);
//         let sui_amount = coin::value(&sui);
//         let premium_amount = coin::value(&premium);

//         // abort equals
//         assert!(sui_amount > 0, EZeroAmount);
//         assert!(sui_amount == profile_to_sell.price, EInvalidNumber);
//         assert!(premium_amount == profile_to_sell.price * market.premium_rate / 100, EInvalidNumber);

//         // pay
//         transfer::public_transfer(sui, profile_to_sell.owner);
//         profile_to_sell.owner = sender;

//         // premium transfer
//         transfer::public_transfer(premium, profile_to_sell.creator);

//         transfer::public_transfer(profile_to_sell, sender);
//     }

//     /* -------------------------------------------------------- */
//     public struct SuiName has key, store {
//         id: UID,
//         bytes: vector<u8>,
//     }

//     public entry fun create_name(
//         bytes: vector<u8>,
//         ctx: &mut TxContext
//     ) {
//         let sender = tx_context::sender(ctx);
//         let suiname = SuiName {
//             id: object::new(ctx),
//             bytes: bytes,
//         };
//         transfer::public_transfer(suiname, sender)
//     }
//     /* -------------------------------------------------------- */
// }

module game::utils{
    use sui::coin::{Self, Coin};
    entry public fun destroy_zero<T>(c: Coin<T>){
        coin::destroy_zero<T>(c);
    }
}
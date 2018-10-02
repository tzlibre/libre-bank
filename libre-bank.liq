[%%version 0.3]

(* ********************* *)
(*                       *)
(*     Libre Bank        *)
(*                       *)
(* ********************* *)

(* storage type *)
type storage = {
  owner: address;                 (* contract owner *)
  max_depositors: nat;            (* max number of users *)
  min_deposit: tez;               (* min amount a user can
                                     transfer to contract in single tx *)
  withdraw_fee: nat;              (* percentage withdrawal fee, in 10^6 *)
  collat_coeff: nat;              (* collateralization coefficient, in 10^6 *)
  deposited: tez;                 (* amount of XTZ deposited by lenders *)
  borrowed: tez;                  (* amount of XTZ borrowed *)
  depositors: (address, tez) map; (* depositor balance *)
  depositors_size: nat;           (* number of depositors *)
}

let one_prec6 = 1000000p

let%init storage (owner: address) (max_depositors: nat) (min_deposit: tez) (withdraw_fee: nat) (collat_coeff: nat) =
  let deposited = 0tz in
  let borrowed = 0tz in
  let depositors = (Map []: (address, tez) map)  in
  let depositors_size = 0p in
  {
    owner;
    max_depositors;
    min_deposit;
    withdraw_fee;
    collat_coeff;
    deposited;
    borrowed;
    depositors;
    depositors_size;
  }

(* UTILS *)

let min ((a: tez), (b: tez)) =
  if a > b then b else a

let apply_coeff ((amount: tez), (coeff: nat)) =
  match (amount * coeff) / one_prec6 with
  | None -> Current.failwith "Division error in `apply_coeff`.";
  | Some x -> x.(0)

let get_coeff_compl (coeff: nat) =
  match%nat (one_prec6 - coeff) with
  | Minus _ -> Current.failwith "Invalid coefficient value in `get_coeff_compl`.";
  | Plus p -> p

let get_compl_collat_value ((deposited: tez), (collat_coeff: nat)) =
  apply_coeff (deposited, (get_coeff_compl collat_coeff))

let get_contract (a: address) =
  match (Contract.at a: unit contract option) with
  | None -> Current.failwith "Wrong address.";
  | Some c -> c

let%entry main
    (parameter: unit)
    (storage: storage) =
  let source = Current.source () in
  let amount = Current.amount () in
  let contract_balance = Current.balance () in
  let s = storage in

  (**************************************)
  (* User deposit                       *)
  (**************************************)

  if (amount > 1tz) && (source <> s.owner) then
    let min_deposit = s.min_deposit in

    (* check transferred amount *)
    if amount < min_deposit then
      Current.failwith "Deposited amount is too small.";

    (* update user balance *)
    let (user_balance, s) = match Map.find source s.depositors with
      | None -> (amount, s.depositors_size <- s.depositors_size + 1p)
      | Some b -> (b + amount, s)
    in
    let s = s.depositors <- Map.add source user_balance s.depositors in
    
    (* check depositors_size *)
    if s.depositors_size > s.max_depositors then
      Current.failwith "Maxiumum depositors has been reached.";

    (* update deposited *)
    let s = s.deposited <- s.deposited + amount in

    ([]: operation list), s

  (**************************************)
  (* User Withdraw                      *)
  (**************************************)

  else if (amount <= 1tz) && (source <> s.owner) then
    (* check user is a depositor *)
    let user_balance = match Map.find source s.depositors with
      | None -> Current.failwith "Only depositors can withdraw.";
      | Some b -> b
    in

    (* check withdraw amount against contract balance *)
    if (user_balance > contract_balance) then
      Current.failwith "Withdraw amount greater than current contract balance.";

    (* update deposited *)
    let s = s.deposited <- s.deposited - user_balance in

    (* remove user from depositors *)
    let s = s.depositors <-
        Map.update source (None: tez option) s.depositors
    in

    (* update depositors_size *)
    let s = s.depositors_size <-
        match%nat (s.depositors_size - 1p) with
        | Minus _ -> Current.failwith "Depositors counting error.";
        | Plus p -> p
    in

    (* send fee to owner *)
    let fee_amount = apply_coeff (user_balance, s.withdraw_fee) in
    let owner_c = get_contract s.owner in
    let op_fee = Contract.call owner_c fee_amount () in

    (* send remainder to user *)
    let withdraw_amount = user_balance - fee_amount + amount in
    let source_c = get_contract source in
    let op_withdraw = Contract.call source_c withdraw_amount () in

    op_fee :: op_withdraw :: [], s

  (**************************************)
  (* Owner borrow                       *)
  (**************************************)

  else if (amount = 0tz) && (source = s.owner) then
    let max_borrowing = get_compl_collat_value (s.deposited, s.collat_coeff) in
    if (max_borrowing < s.borrowed) then
      Current.failwith "No available funds to borrow: contract is under-collateralized.";

    (* defensive programming: doublecheck borrowing value against contract balance *)
    let borrowing = min (max_borrowing - s.borrowed, contract_balance) in
    if (borrowing = 0tz) then
      Current.failwith "No available funds to borrow.";

    (* update borrowed *)
    let s = s.borrowed <- s.borrowed + borrowing in

    (* send funds to owner *)
    let owner_c = get_contract s.owner in
    let op = Contract.call owner_c borrowing () in
    [op], s

  (**************************************)
  (* Owner payback                      *)
  (**************************************)

  else if (amount > 0tz) && (source = s.owner) then
    let borrowed = s.borrowed in

    (* check for over-collateralization *)
    if (amount > borrowed) then
      Current.failwith "Can't over-collateralize contract.";

    (* update borrowed *)
    let s = s.borrowed <- s.borrowed - amount in

    ([]: operation list), s

  else
    Current.failwith "You shouldn't be here."

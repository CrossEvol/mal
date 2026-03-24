open Types
open Rl
open Result.Syntax
open Printer
open Reader

let fn_t_int_int ret f = function
  | [ Int a; Int b ] -> Ok (ret (f a b))
  | _ -> error "expecting (int,int) args"

let is_int = function Int _ -> true | _ -> false
let is_str = function Str _ -> true | _ -> false
let is_list = function List _ -> true | _ -> false
let is_vector = function Vector _ -> true | _ -> false
let is_empty = function List ([], _) | Vector ([], _) -> true | _ -> false

let fn_is_type f = function
  | [ v ] -> Ok (Bool (f v))
  | _ -> error "expect 1 argument"

let fn_str f = function [ Str s ] -> f s | _ -> error "expecting (str) arg"

let symbol = function
  | [ Str s ] -> Ok (Sym s)
  | _ -> error "illegal symbol call"

let readline p =
  match readline ~prompt:p () with Some s -> Ok (Str s) | None -> Ok Nil

let slurp f =
  try
    let content = In_channel.with_open_bin f In_channel.input_all in
    Ok (Str content)
  with
  | Sys_error msg -> error msg
  | e -> error (Printexc.to_string e)

let time_ms _ =
  try
    let ms = Unix.gettimeofday () *. 1000.0 in
    Ok (Int (Int.of_float ms))
  with e -> error (Printexc.to_string e)

let get = function
  | Nil :: _ -> Ok Nil
  | Hash (hm, _) :: key :: _ -> (
      let* key = wrap_map_key key in
      match Hashtbl.find_opt hm key with Some mv -> Ok mv | None -> Ok Nil)
  | _ -> error "illegal get args"

let assoc = function
  | Hash (hm, _) :: kvs -> _assoc hm kvs
  | _ -> error "assoc on non-Hash Map"

let dissoc = function
  | Hash (hm, _) :: keys ->
      let new_hm = Hashtbl.copy hm in
      let rec remove_keys = function
        | [] -> Ok (Hash (new_hm, Nil))
        | k :: rest -> (
            match wrap_map_key k with
            | Ok k ->
                Hashtbl.remove new_hm k;
                remove_keys rest
            | Error e -> Error e)
      in
      remove_keys keys
  | _ -> error "dissoc on non-Hash Map"

let contain_q = function
  | Hash (hm, _) :: key :: _ ->
      let* k = wrap_map_key key in
      Ok (Bool (Hashtbl.mem hm k))
  | _ -> error "illegal get args"

let keys = function
  | [ Hash (hm, _) ] ->
      let keys = Hashtbl.to_seq_keys hm |> List.of_seq in
      let keys = List.map (fun k -> unwrap_map_key k) keys in
      Ok (list keys)
  | _ -> error "keys requires Hash Map"

let vals = function
  | [ Hash (hm, _) ] ->
      let vals = Hashtbl.to_seq_values hm |> List.of_seq in
      Ok (list vals)
  | _ -> error "vals requires Hash Map"

let vec = function
  | [ (List (v, _) | Vector (v, _)) ] -> Ok (Vector (v, Nil))
  | _ -> error "non-seq passed to vec"

let cons = function
  | [ a0; (List (v, _) | Vector (v, _)) ] -> Ok (List ([ a0 ] @ v, Nil))
  | _ -> error "cons expects seq as second arg"

let concat = function
  | [ (List (v, _) | Vector (v, _)) ] ->
      let* l =
        List.fold_left
          (fun acc x ->
            let* new_v = acc in
            match x with
            | List (v, _) | Vector (v, _) -> Ok (new_v @ v)
            | _ -> error "non-seq passed to concat")
          (Ok []) v
      in
      Ok (List (l, Nil))
  | _ -> error "non-seq passed to concat"

let nth = function
  | [ (List (seq, _) | Vector (seq, _)); Int idx ] -> (
      if idx < 0 then error "nth: index out of range"
      else
        match List.nth_opt seq idx with
        | Some result -> Ok result
        | None -> error "nth: index out of range")
  | _ -> error "invalid args to nth"

let first = function
  | [ (List (seq, _) | Vector (seq, _)) ] when List.length seq > 0 ->
      Ok (List.hd seq)
  | [ (List (_, _) | Vector (_, _) | Nil) ] -> Ok Nil
  | _ -> error "invalid args to first"

let rest = function
  | [ (List (seq, _) | Vector (seq, _)) ] when List.length seq > 1 ->
      Ok (List (List.tl seq, Nil))
  | [ (List (_, _) | Vector (_, _) | Nil) ] -> Ok (mal_list [])
  | _ -> error "invalid args to rest"

let apply = function
  | f :: args when List.length args > 0 -> (
      let rev_args = List.rev args in
      let last = List.hd rev_args in
      let rest = List.rev (List.tl rev_args) in
      match last with
      | List (v, _) | Vector (v, _) -> (
          match f with
          | Func (f, _, _) -> f (rest @ v)
          | _ -> error "apply: first arg not a function")
      | _ -> error "apply called with non-seq")
  | _ -> error "apply requires at least 2 args"

let map = function
  | [ Func (f, _, _); (List (v, _) | Vector (v, _)) ] ->
      let* res =
        List.fold_left
          (fun acc x ->
            let* acc = acc in
            let* mv = f [ x ] in
            Ok (mv :: acc))
          (Ok []) v
      in
      Ok (List (List.rev res, Nil))
  | _ -> error "map called with non-seq"

let conj = function
  | List (v, _) :: rest ->
      let lst = List.fold_left (fun acc x -> x :: acc) v rest in
      Ok (list lst)
  | Vector (v, _) :: rest ->
      let lst = List.fold_left (fun acc x -> acc @ [ x ]) v rest in
      Ok (vector lst)
  | _ -> error "conj: called with non-seq"

let seq = function
  | [ List (v, _) ] when List.length v > 0 -> Ok (list v)
  | [ Vector (v, _) ] when List.length v > 0 -> Ok (list v)
  | [ Str s ] when String.length s > 0 ->
      let lst =
        String.to_seq s
        |> Seq.map (fun c -> String.make 1 c)
        |> Seq.map (fun s -> Str s)
        |> List.of_seq |> list
      in
      Ok lst
  | [ (List (_, _) | Vector (_, _) | Str _ | Nil) ] -> Ok Nil
  | _ -> error "seq: called with non-seq"

let keyword = function
  | [ Kwd s ] -> Ok (Kwd s)
  | [ Str s ] -> Ok (Kwd s)
  | _ -> error "invalid type for keyword"

let empty_q = function
  | [ (List (l, _) | Vector (l, _)) ] -> Ok (Bool (List.length l = 0))
  | [ Nil ] -> Ok (Bool true)
  | _ -> error "invalid type for empty?"

let count = function
  | [ (List (l, _) | Vector (l, _)) ] -> Ok (Int (List.length l))
  | [ Nil ] -> Ok (Int 0)
  | _ -> error "invalid type for count"

let atom = function
  | [ a ] -> Ok (Atom (ref a))
  | _ -> error "invalid type for atom"

let deref = function
  | [ Atom a ] -> Ok !a
  | _ -> error "attempt to deref a non-Atom"

let reset_bang = function
  | [ Atom atm; a1 ] ->
      atm.contents <- a1;
      Ok a1
  | _ -> error "attempt to reset! a non-Atom"

let swap_bang = function
  | Atom atm :: Func (f, _, _) :: fargs ->
      let* result = f fargs in
      atm.contents <- result;
      Ok result
  | _ -> error "attempt to swap! a non-Atom"

let get_meta = function
  | [ (List (_, meta) | Vector (_, meta) | Hash (_, meta) | Func (_, meta, _)) ]
    ->
      Ok meta
  | _ -> error "meta not supported by type"

let with_meta = function
  | [ List (l, _); meta ] -> Ok (List (l, meta))
  | [ Vector (v, _); meta ] -> Ok (Vector (v, meta))
  | [ Hash (hm, _); meta ] -> Ok (Hash (hm, meta))
  | [ Func (f, _, _); meta ] -> Ok (Func (f, meta, false))
  | _ -> error "with-meta not supported by type"

let ns =
  [
    ("=", func (fun a -> Ok (Bool (List.nth a 0 = List.nth a 1))));
    ("throw", func (fun a -> Error (List.hd a)));
    ("nil?", func (fn_is_type (function Nil -> true | _ -> false)));
    ("true?", func (fn_is_type (function Bool true -> true | _ -> false)));
    ("false?", func (fn_is_type (function Bool false -> true | _ -> false)));
    ("symbol", func symbol);
    ("symbol?", func (fn_is_type (function Sym _ -> true | _ -> false)));
    ("keyword", func keyword);
    ("keyword?", func (fn_is_type (function Kwd _ -> true | _ -> false)));
    ("number?", func (fn_is_type (function Int _ -> true | _ -> false)));
    ( "fn?",
      func
        (fn_is_type (function
          | Func (_, _, macro) when not macro -> true
          | _ -> false)) );
    ( "macro?",
      func
        (fn_is_type (function
          | Func (_, _, macro) when macro -> true
          | _ -> false)) );
    ("pr-str", func (fun a -> Ok (Str (pr_seq a true "" "" " "))));
    ("str", func (fun a -> Ok (Str (pr_seq a false "" "" ""))));
    ( "prn",
      func (fun a ->
          Printf.printf "%s" (pr_seq a true "" "" " ");
          Ok Nil) );
    ( "println",
      func (fun a ->
          Printf.printf "%s" (pr_seq a false "" "" " ");
          Ok Nil) );
    ("read-string", func (fn_str read_str));
    ("readline", func (fn_str readline));
    ("slurp", func (fn_str slurp));
    ("<", func (fn_t_int_int (fun x -> Bool x) (fun a b -> a < b)));
    ("<=", func (fn_t_int_int (fun x -> Bool x) (fun a b -> a <= b)));
    (">", func (fn_t_int_int (fun x -> Bool x) (fun a b -> a > b)));
    (">=", func (fn_t_int_int (fun x -> Bool x) (fun a b -> a >= b)));
    ("+", func (fn_t_int_int (fun x -> Int x) (fun a b -> a + b)));
    ("-", func (fn_t_int_int (fun x -> Int x) (fun a b -> a - b)));
    ("*", func (fn_t_int_int (fun x -> Int x) (fun a b -> a * b)));
    ("/", func (fn_t_int_int (fun x -> Int x) (fun a b -> a / b)));
    ("time-ms", func time_ms);
    ( "sequential?",
      func (fn_is_type (function List _ | Vector _ -> true | _ -> false)) );
    ("list", func (fun a -> Ok (list a)));
    ("list?", func (fn_is_type (function List _ -> true | _ -> false)));
    ("vector", func (fun a -> Ok (vector a)));
    ("vector?", func (fn_is_type (function Vector _ -> true | _ -> false)));
    ("hash-map", func hash_map);
    ("map?", func (fn_is_type (function Hash _ -> true | _ -> false)));
    ("assoc", func assoc);
    ("dissoc", func dissoc);
    ("get", func get);
    ("contains?", func contain_q);
    ("keys", func keys);
    ("vals", func vals);
    ("vec", func vec);
    ("cons", func cons);
    ("concat", func concat);
    ("empty?", func empty_q);
    ("nth", func nth);
    ("first", func first);
    ("rest", func rest);
    ("count", func count);
    ("apply", func apply);
    ("map", func map);
    ("conj", func conj);
    ("seq", func seq);
    ("meta", func get_meta);
    ("with-meta", func with_meta);
    ("atom", func atom);
    ("atom?", func (fn_is_type (function Atom _ -> true | _ -> false)));
    ("deref", func deref);
    ("reset!", func reset_bang);
    ("swap!", func swap_bang);
  ]

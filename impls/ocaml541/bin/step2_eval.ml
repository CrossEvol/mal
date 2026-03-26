open Ocaml541.Rl
open Ocaml541.Reader
open Ocaml541.Printer
open Ocaml541.Types
open Result.Syntax
module StringMap = Map.Make (String)

let traverse f lst =
  List.fold_left
    (fun acc x ->
      let* acc = acc in
      let* v = f x in
      Ok (v :: acc))
    (Ok []) lst
  |> Result.map List.rev

let read str = read_str str

let apply f args =
  match f with
  | Func (f, _) -> f args
  | _ -> error "attempt to call non-function"

let rec eval ast env =
  let eval' x = eval x env in
  match ast with
  | Sym s -> (
      match StringMap.find_opt s env with
      | Some r -> Ok r
      | None -> error (Format.asprintf "'%s' not found" s))
  | Vector (v, _) ->
      let* lst = traverse eval' v in
      Ok (vector lst)
  | Hash (hm, _) ->
      let entries = Hashtbl.to_seq hm |> List.of_seq in
      let* evalueted =
        traverse
          (fun (k, v) ->
            let* v' = eval' v in
            Ok (k, v'))
          entries
      in
      let new_hm = Hashtbl.create (List.length evalueted) in
      List.iter (fun (k, v) -> Hashtbl.add new_hm k v) evalueted;
      Ok (Hash (new_hm, Nil))
  | List (l, _) ->
      if List.length l = 0 then Ok ast
      else
        let a0 = List.hd l in
        let* f = eval a0 env in
        let* args = traverse eval' (List.tl l) in
        apply f args
  | _ -> Ok ast

let print ast = pr_str ast true

let rep str env =
  let* ast = read str in
  let* exp = eval ast env in
  Ok (print exp)

let int_op op a =
  match a with
  | [ Int a0; Int a1 ] -> Ok (Int (op a0 a1))
  | _ -> error "invalid int_op args"

let () =
  let env =
    StringMap.(
      empty
      |> add "+" (func (fun a -> int_op ( + ) a))
      |> add "-" (func (fun a -> int_op ( - ) a))
      |> add "*" (func (fun a -> int_op ( * ) a))
      |> add "/" (func (fun a -> int_op ( / ) a)))
  in
  let rec loop () =
    let result = readline ~prompt:"user> " () in
    match result with
    | Some line ->
        (match rep line env with
        | Ok out -> print_endline out
        | Error err ->
            let err_msg = Format.asprintf "Error: %s" (pr_str err true) in
            print_endline err_msg);
        loop ()
    | None -> loop ()
  in
  loop ()

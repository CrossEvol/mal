open Ocaml541.Rl
open Ocaml541.Reader
open Ocaml541.Printer
open Ocaml541.Types
open Result.Syntax
open Ocaml541.Env
open Ocaml541.Core

let traverse f lst =
  List.fold_left
    (fun acc x ->
      let* acc = acc in
      let* v = f x in
      Ok (v :: acc))
    (Ok []) lst
  |> Result.map List.rev

let split_last lst =
  let rec loop acc = function
    | [] -> failwith "empty list"
    | [ x ] -> Ok (List.rev acc, x)
    | x :: xs -> loop (x :: acc) xs
  in
  loop [] lst

let read str = read_str str
let print ast = pr_str ast true

let rec eval ast env =
  (match env_get env "DEBUG-EVAL" with
  | None | Some (Bool false) | Some Nil -> ()
  | _ -> print_endline (Format.asprintf "EVAL: %s" (print ast)));
  let eval' x = eval x env in
  match ast with
  | Sym s -> (
      match env_get env s with
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
  | List (l, _) -> (
      if List.length l = 0 then Ok ast
      else
        let a0 = List.hd l in
        match a0 with
        | Sym a0sym when a0sym = "def!" ->
            let* v = eval' (List.nth l 2) in
            env_set env (List.nth l 1) v
        | Sym a0sym when a0sym = "let*" ->
            let rec process_pairs binds e =
              match binds with
              | k :: v :: rest ->
                  let* v' = eval v e in
                  let* _ = env_set e k v' in
                  process_pairs rest e
              | [] -> Ok ()
              | _ :: _ -> error "length of binds must be even"
            in
            let let_env = env_new (Some env) in
            let a1 = List.nth l 1 in
            let a2 = List.nth l 2 in
            let* _ =
              match a1 with
              | List (binds, _) | Vector (binds, _) ->
                  process_pairs binds let_env
              | _ -> error "let* with non-List bindings"
            in
            eval a2 let_env
        | Sym a0sym when a0sym = "do" ->
            let* before, last = split_last (List.tl l) in
            let* _ = traverse eval' before in
            eval' last
        | Sym a0sym when a0sym = "if" -> (
            let* cond = eval' (List.nth l 1) in
            match cond with
            | (Bool false | Nil) when List.length l >= 4 -> eval' (List.nth l 3)
            | Bool false | Nil -> Ok Nil
            | _ when List.length l >= 3 -> eval' (List.nth l 2)
            | _ -> Ok Nil)
        | Sym a0sym when a0sym = "fn*" ->
            let params = List.nth l 1 in
            let ast = List.nth l 2 in
            let fn args =
              let* sub_env = env_bind env params args in
              eval ast sub_env
            in
            Ok (MalFunc { ast; env; params; is_macro = false; meta = Nil; fn })
        | _ -> (
            let* f = eval a0 env in
            let* args = traverse eval' (List.tl l) in
            match f with
            | Func (f, _) -> f args
            | MalFunc { fn; _ } -> fn args
            | _ -> error "attempt to call non-function"))
  | _ -> Ok ast

let re str env =
  match read str with
  | Ok ast -> (
      match eval ast env with
      | Ok _ -> ()
      | Error _ -> failwith "error during startup")
  | _ -> failwith "error during startup"

let rep str env =
  let* ast = read str in
  let* exp = eval ast env in
  Ok (print exp)

let int_op op a =
  match a with
  | [ Int a0; Int a1 ] -> Ok (Int (op a0 a1))
  | _ -> error "invalid int_op args"

let () =
  let env = env_new None in
  List.iter (fun (k, v) -> env_sets env k v) ns;
  env_sets env "eval" (func (fun a -> eval (List.nth a 0) env));

  re {|(def! not (fn* (a) (if a false true)))|} env;
  re
    {|(def! load-file (fn* (f) (eval (read-string (str "(do " (slurp f) "\nnil)")))))|}
    env;

  if Array.length Sys.argv > 1 then (
    let args = Sys.argv in
    let arg1 = Sys.argv.(1) in
    env_sets env "*ARGV*"
      (Array.to_list args |> List.tl |> List.tl
      |> List.map (fun arg -> Str arg)
      |> list);
    re (Format.asprintf {|(load-file "%s")|} arg1) env;
    exit 0)
  else
    let args = Sys.argv in
    env_sets env "*ARGV*"
      (Array.to_list args |> List.tl |> List.map (fun arg -> Str arg) |> list);
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

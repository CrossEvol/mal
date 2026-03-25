open Ocaml541.Rl
open Ocaml541.Reader
open Ocaml541.Printer
open Result.Syntax

let read str = read_str str
let eval ast = Ok ast
let print ast = pr_str ast true

let rep str =
  let* ast = read str in
  let* exp = eval ast in
  Ok (print exp)

let () =
  let rec loop () =
    let result = readline ~prompt:"user> " () in
    match result with
    | Some line ->
        (match rep line with
        | Ok out -> print_endline out
        | Error err ->
            let err_msg = Format.asprintf "Error: %s" (pr_str err true) in
            print_endline err_msg);
        loop ()
    | None -> loop ()
  in
  loop ()

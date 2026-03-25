open Ocaml541.Rl

let () =
  let rec loop () =
    let result = readline ~prompt:"user> " () in
    match result with
    | Some line ->
        print_endline line;
        loop ()
    | None -> loop ()
  in
  loop ()

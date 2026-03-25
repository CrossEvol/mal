let complete _str = Readline.Filenames
let init_success = ref false

let init_readline () =
  Readline.init ~catch_break:false ~program_name:"readline-example"
    ~history_file:(Sys.getenv "HOME" ^ "/.readline-example_history")
    ();
  init_success.contents <- true

let readline ?(prompt = "") () =
  if not !init_success then init_readline ();
  let str = Readline.readline ~completion_fun:complete ~prompt () in
  match str with
  | Some str ->
      if str <> "" then Readline.add_history str;
      Some str
  | None -> None

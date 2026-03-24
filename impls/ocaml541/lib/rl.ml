let complete _str = Readline.Filenames

let init_readline () =
  Readline.init ~catch_break:false ~program_name:"readline-example"
    ~history_file:(Sys.getenv "HOME" ^ "/.readline-example_history")
    ()

let readline ?(prompt = "") () =
  let str = Readline.readline ~completion_fun:complete ~prompt () in
  match str with
  | Some str ->
      if str <> "" then Readline.add_history str;
      Some str
  | None -> None

open Types

let escape_str s =
  let escaped_chars =
    s |> String.to_seq
    |> Seq.map (function
      | '"' -> "\\\""
      | '\n' -> "\\n"
      | '\\' -> "\\\\"
      | c -> String.make 1 c)
    |> List.of_seq
  in
  String.concat "" escaped_chars

let rec pr_str mal_obj print_readably : string =
  match mal_obj with
  | Nil -> "nil"
  | Bool true -> "true"
  | Bool false -> "false"
  | Int i -> string_of_int i
  | Str s ->
      if print_readably then Format.asprintf {|"%s"|} (escape_str s) else s
  | Sym s -> s
  | Kwd s -> ":" ^ s
  | List (l, _) -> pr_seq l print_readably "(" ")" " "
  | Vector (l, _) -> pr_seq l print_readably "[" "]" " "
  | Hash (hm, _) ->
      let l =
        Hashtbl.to_seq hm |> List.of_seq
        |> List.concat_map (fun (k, v) -> [ unwrap_map_key k; v ])
      in
      pr_seq l print_readably "{" "}" " "
  | Func (_, _, _) -> "#<builtin>"
  | MalFunc { ast; params; _ } ->
      Format.asprintf "(fn* %s %s)" (pr_str params true) (pr_str ast true)
  | Atom a -> Format.asprintf "(atom %s)" (pr_str !a true)

and pr_seq seq print_readably s e join =
  let strs = seq |> List.map (fun x -> pr_str x print_readably) in
  s ^ String.concat join strs ^ e

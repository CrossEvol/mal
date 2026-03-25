open Re
open Types

module Regexes = struct
  let tokenize_re =
    Pcre.regexp
      {|[\s,]*(~@|[\[\]{}()'`~^@]|"(?:\\.|[^\\"])*"?|;.*|[^\s\[\]{}('"`,;)]+)|}

  let unescape_re = Pcre.regexp {|\\(.)|}
  let int_re = Pcre.regexp {|^-?[0-9]+$|}
  let str_re = Pcre.regexp {|"(?:\\.|[^\\"])*"|}
end

type reader = { tokens : string array; mutable pos : int }

let next rdr =
  if rdr.pos < Array.length rdr.tokens then (
    let token = rdr.tokens.(rdr.pos) in
    rdr.pos <- rdr.pos + 1;
    Ok token)
  else error "underflow"

let peek rdr =
  if rdr.pos < Array.length rdr.tokens then
    let token = rdr.tokens.(rdr.pos) in
    Ok token
  else error "underflow"

let unescap_str s =
  Re.replace Regexes.unescape_re
    ~f:(fun m -> match Group.get m 1 with "n" -> "\n" | c -> c)
    s

let tokenize str =
  let matches = Re.all Regexes.tokenize_re str in
  List.filter_map
    (fun m ->
      let token = Group.get m 1 in
      if String.length token > 0 && token.[0] == ';' then None else Some token)
    matches

let rec read_atom rdr =
  let open Result.Syntax in
  let* token = next rdr in
  match token with
  | "nil" -> Ok Nil
  | "false" -> Ok (Bool false)
  | "true" -> Ok (Bool true)
  | _ ->
      if Re.execp Regexes.int_re token then Ok (Int (int_of_string token))
      else if Re.execp Regexes.str_re token then
        Ok (Str (unescap_str (String.sub token 1 (String.length token - 2))))
      else if token.[0] = '"' then error {|unexpected '"', got EOF|}
      else if token.[0] = ':' then
        Ok (Kwd (String.sub token 1 (String.length token - 1)))
      else Ok (Sym token)

and read_seq rdr end_token =
  let open Result.Syntax in
  let rec loop acc =
    let* token = peek rdr in
    if token = end_token then (
      ignore (next rdr);
      Ok (List.rev acc))
    else
      let* form = read_form rdr in
      loop (form :: acc)
  in
  let _ = next rdr in
  match loop [] with
  | Ok lst -> Ok lst
  | Error _ -> error (Format.asprintf "expected '%s', got EOF" end_token)

and read_form rdr =
  let open Result.Syntax in
  let* token = peek rdr in
  match token with
  | "'" ->
      let _ = next rdr in
      let* form = read_form rdr in
      Ok (mal_list [ Sym "quote"; form ])
  | "`" ->
      let _ = next rdr in
      let* form = read_form rdr in
      Ok (mal_list [ Sym "quasiquote"; form ])
  | "~" ->
      let _ = next rdr in
      let* form = read_form rdr in
      Ok (mal_list [ Sym "unquote"; form ])
  | "~@" ->
      let _ = next rdr in
      let* form = read_form rdr in
      Ok (mal_list [ Sym "splice-unquote"; form ])
  | "^" ->
      let _ = next rdr in
      let* meta = read_form rdr in
      let* form = read_form rdr in
      Ok (mal_list [ Sym "with-meta"; form; meta ])
  | "@" ->
      let _ = next rdr in
      let* form = read_form rdr in
      Ok (mal_list [ Sym "deref"; form ])
  | ")" -> error "unexpected ')'"
  | "(" ->
      let* seq = read_seq rdr ")" in
      Ok (list seq)
  | "]" -> error "unexpected ']'"
  | "[" ->
      let* seq = read_seq rdr "]" in
      Ok (vector seq)
  | "}" -> error "unexpected '}'"
  | "{" ->
      let* seq = read_seq rdr "}" in
      hash_map seq
  | _ -> read_atom rdr

let read_str str =
  let tokens = tokenize str |> Array.of_list in
  if Array.length tokens = 0 then error "no input"
  else read_form { tokens; pos = 0 }

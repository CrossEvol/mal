module StringMap = Map.Make (String)

type malVal =
  | Nil
  | Bool of bool
  | Int of int
  | Str of string
  | Sym of string
  | Kwd of string
  | List of malVal list * malVal
  | Vector of malVal list * malVal
  | Hash of (string, malVal) Hashtbl.t * malVal
  | Func of (malFn * malVal * bool) (* fn -> meta -> macro *)
  | MalFunc of funcStruct
  | Atom of malVal ref

and malArgs = malVal list
and malRet = (malVal, malVal) result
and malFn = malArgs -> malRet

and funcStruct = {
  ast : malVal;
  env : env;
  params : malVal;
  is_macro : bool;
  meta : malVal;
}

and env = { outer : env option; data : (string, malVal) Hashtbl.t }

let error (s : string) = Error (Str s)
let mal_list args = List (args, Nil)
let list seq = List (seq, Nil)
let vector seq = Vector (seq, Nil)
let func f = Func (f, Nil, false)

let rec mal_equal a b =
  match (a, b) with
  | List (xs, _), List (ys, _)
  | List (xs, _), Vector (ys, _)
  | Vector (xs, _), List (ys, _)
  | Vector (xs, _), Vector (ys, _) ->
      List.equal mal_equal xs ys
  | Hash (xs, _), Hash (ys, _) -> xs = ys
  | _ -> a = b

and hash_equal xs ys =
  if Hashtbl.length xs <> Hashtbl.length ys then false
  else
    Hashtbl.fold
      (fun k vx acc ->
        if not acc then false
        else
          match Hashtbl.find_opt ys k with
          | Some vy -> mal_equal vx vy
          | None -> false)
      xs true

let wrap_map_key k =
  match k with
  | Str s -> Ok s
  | Kwd s -> Ok (":" ^ s)
  | _ -> error "key is not string"

let unwrap_map_key s =
  if String.length s > 0 && s.[0] == ':' then
    Kwd (String.sub s 1 (String.length s - 1))
  else Str s

let _assoc hm kvs =
  if List.length kvs mod 2 <> 0 then error "odd number of elements"
  else
    let rec process_pairs = function
      | [] -> Ok ()
      | k :: v :: rest -> (
          match wrap_map_key k with
          | Ok key ->
              Hashtbl.replace hm key v;
              process_pairs rest
          | Error e -> Error e)
      | _ -> error "odd number of elements"
    in
    match process_pairs kvs with
    | Ok () -> Ok (Hash (hm, Nil))
    | Error e -> Error e

let hash_map kvs =
  let hm = Hashtbl.create 8 in
  _assoc hm kvs

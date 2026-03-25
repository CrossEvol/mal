open Types
open Result.Syntax

type env = { outer : env option; data : (string, malVal) Hashtbl.t }

let env_new outer = { outer; data = Hashtbl.create 8 }

let env_sets env k v =
  if Hashtbl.mem env.data k then Hashtbl.replace env.data k v
  else Hashtbl.add env.data k v

let env_set env k v =
  match k with
  | Sym s ->
      env_sets env s v;
      Ok v
  | _ -> error "Env.set called with non-Str"

let rec env_get env k =
  if Hashtbl.mem env.data k then Some (Hashtbl.find env.data k)
  else match env.outer with Some outer -> env_get outer k | None -> None

let env_bind outer mbinds exprs =
  match mbinds with
  | List (binds, _) | Vector (binds, _) ->
      let env = env_new (Some outer) in
      let rec bind_args a b =
        match (a, b) with
        | [ Sym "&"; b ], args -> env_set env b (list args)
        | a :: names, arg :: args ->
            let* _ = env_set env a arg in
            bind_args names args
        | [], [] -> Ok Nil
        | _ -> raise (Invalid_argument "Bad param count in fn call")
      in
      let* _ = bind_args binds exprs in
      Ok env
  | _ -> error "env_bind binds not List/Vector"

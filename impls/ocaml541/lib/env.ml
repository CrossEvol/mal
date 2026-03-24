open Types

type env = { outer : env option; data : (string, malVal) Hashtbl.t }

let env_new outer = { outer; data = Hashtbl.create 8 }

let env_set env k v =
  if Hashtbl.mem env.data k then Hashtbl.replace env.data k v
  else Hashtbl.add env.data k v

let rec env_get env k =
  if Hashtbl.mem k env.data then Hashtbl.find k env.data
  else match env.outer with Some outer -> env_get outer k | None -> None

let env_bind outer mbinds exprs =
  match mbinds with
  | List (binds, _) | Vector (binds, _) ->
      let env = env_new (Some outer) in
      let rec bind_args a b =
        match (a, b) with
        | [ Sym "&"; Sym name ], args -> env_set env name (list args)
        | Sym name :: names, arg :: args ->
            env_set env name arg;
            bind_args names args
        | [], [] -> ()
        | _ -> raise (Invalid_argument "Bad param count in fn call")
      in
      bind_args binds exprs;
      Ok env
  | _ -> error "env_bind binds not List/Vector"

open Code_mirror
open Brr
module Utils = Utils
open Js_top_worker_rpc

let linter rpc id deps is_toplevel view =
  let open Fut.Syntax in
  let doc = Utils.get_full_doc @@ View.EditorView.state view in
  let+ result = Js_top_worker_client_fut.W.query_errors rpc id deps is_toplevel doc in
  match result with
  | Ok r ->
      List.map
        (fun Toplevel_api_gen.{ kind; loc; main; sub = _; source } ->
          let from = loc.loc_start.pos_cnum in
          let to_ = loc.loc_end.pos_cnum in
          let source_rpc =
            Rpcmarshal.marshal Toplevel_api_gen.typ_of_location_error_source
              source
          in
          let source =
            match source_rpc with
            | Rpc.String s -> s
            | _ -> failwith "Invalid source"
          in
          let severity =
            match kind with
            | Report_error | Report_warning_as_error _ | Report_alert_as_error _
              ->
                Lint.Diagnostic.Error
            | Report_warning _ -> Lint.Diagnostic.Warning
            | Report_alert _ -> Lint.Diagnostic.Info
          in
          Lint.Diagnostic.create ~source ~from ~to_ ~severity ~message:main ())
        r
      |> Array.of_list
  | Error _ -> [||]

let keywords =
  List.map
    (fun label -> Autocomplete.Completion.create ~label ~type_:"keyword" ())
    [
      "as";
      "do";
      "else";
      "end";
      "exception";
      "fun";
      "functor";
      "if";
      "in";
      "include";
      "let";
      "of";
      "open";
      "rec";
      "struct";
      "then";
      "type";
      "val";
      "while";
      "with";
      "and";
      "assert";
      "begin";
      "class";
      "constraint";
      "done";
      "downto";
      "external";
      "function";
      "initializer";
      "lazy";
      "match";
      "method";
      "module";
      "mutable";
      "new";
      "nonrec";
      "object";
      "private";
      "sig";
      "to";
      "try";
      "value";
      "virtual";
      "when";
    ]

let linter rpc id deps is_toplevel = Lint.create (linter rpc id deps is_toplevel)

let merlin_completion rpc id deps is_toplevel ctx =
  let open Fut.Syntax in
  let source = Utils.get_full_doc @@ Autocomplete.Context.state ctx in
  let pos = Autocomplete.Context.pos ctx in
  let+ res =
    Js_top_worker_client_fut.W.complete_prefix rpc id deps is_toplevel source (Offset pos)
  in
  match res with
  | Ok { from; to_; entries } ->
      let options =
        let num_completions = List.length entries in
        List.mapi
          (fun i Toplevel_api_gen.{ name; desc; _ } ->
            let boost = num_completions - i in
            Autocomplete.Completion.create ~label:name ~detail:desc ~boost ())
          entries
      in
      Some (Autocomplete.Result.create ~filter:true ~from ~to_ ~options ())
  | Error _ -> None

let autocomplete worker id deps is_toplevel =
  let override =
    [
      Autocomplete.Source.from_list keywords;
      Autocomplete.Source.create @@ merlin_completion worker id deps is_toplevel;
    ]
  in
  let config = Autocomplete.config () ~override in
  Autocomplete.create ~config ()

let tooltip_on_hover rpc id deps is_toplevel =
  let open Tooltip in
  hover_tooltip @@ fun ~view ~pos ~side:_ ->
  let open Fut.Syntax in
  let doc = Utils.get_full_doc @@ View.EditorView.state view in
  let pos = Toplevel_api_gen.Offset pos in
  let+ result = Js_top_worker_client_fut.W.type_enclosing rpc id deps is_toplevel doc pos in
  match result with
  | Ok ((loc, String type_, _) :: _) -> 
      let create _view =
        let dom = El.div [ El.txt' type_ ] in
        Tooltip_view.create ~dom ()
      in
      let pos = loc.loc_start.pos_cnum in
      let end_ = loc.loc_end.pos_cnum in
      Some (Tooltip.create ~pos ~end_ ~above:true ~arrow:true ~create ())
  | _ -> None

let ocaml = Jv.get Jv.global "__CM__mllike" |> Stream.Language.of_jv
let ocaml = Stream.Language.define ocaml

module type Config = sig
  val worker_url : string
  val cmis : Js_top_worker_rpc.Toplevel_api_gen.cmis
end

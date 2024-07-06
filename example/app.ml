open Code_mirror

let cmis =
  {
    Js_top_worker_rpc.Toplevel_api_gen.static_cmis = Static_files.stdlib_cmis;
    dynamic_cmis = [];
  }

let initialise s callback =
  let open Fut.Result_syntax in
  let rpc = Js_top_worker_client_fut.start s 100000 callback in
  let* () =
    Js_top_worker_client_fut.W.init rpc
      { Js_top_worker_rpc.Toplevel_api_gen.path = "/static/cmis";
      cmas = []; cmis }
  in
  Fut.return (Ok rpc)

let worker_url = "merlin_worker.bc.js"
let basic_setup = Jv.get Jv.global "__CM__basic_setup" |> Extension.of_jv

let init ?doc ?(exts = []) () =
  let open Fut.Result_syntax in
  let* rpc = initialise worker_url (fun _ -> ()) in
  let merlin_extensions =
    Merlin_codemirror.[ autocomplete rpc; linter rpc; tooltip_on_hover rpc ]
  in
  let extensions =
    [ basic_setup; Merlin_codemirror.ocaml ] @ merlin_extensions @ exts
  in
  let config = State.EditorStateConfig.create ?doc ~extensions () in
  let state = State.EditorState.create ~config () in
  let opts =
    View.EditorViewConfig.create ~state
      ~parent:(Merlin_codemirror.Utils.get_el_by_id "editor")
      ()
  in
  let view : View.EditorView.t = View.EditorView.create ~config:opts () in
  Fut.return (Ok (state, view))

let _editor = init ()

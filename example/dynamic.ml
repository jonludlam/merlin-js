open Code_mirror

let worker_url = "merlin_worker.bc.js"

let cmis =
  let dcs_toplevel_modules =
    [
      "CamlinternalAtomic";
      "CamlinternalFormat";
      "CamlinternalFormatBasics";
      "CamlinternalLazy";
      "CamlinternalMod";
      "CamlinternalOO";
      "Std_exit";
      "Stdlib";
      "Unix";
      "UnixLabels";
    ]
  in
  let dcs_url = "stdlib/" in
  let dcs_file_prefixes = [ "stdlib__" ] in
  {
    Js_top_worker_rpc.Toplevel_api_gen.static_cmis = [];
    dynamic_cmis = Some { dcs_url; dcs_toplevel_modules; dcs_file_prefixes };
  }

let initialise s callback =
  let open Fut.Result_syntax in
  let rpc = Js_top_worker_client_fut.start s 100000 callback in
  let* () =
    Js_top_worker_client_fut.W.init rpc
      Js_top_worker_rpc.Toplevel_api_gen.{ cmas = []; cmi_urls = [] }
  in
  Fut.return (Ok rpc)

let basic_setup = Jv.get Jv.global "__CM__basic_setup" |> Extension.of_jv

let init ?doc ?(exts = []) () =
  let open State in
  let open Fut.Result_syntax in
  let* rpc = initialise worker_url (fun _ -> ()) in
  let merlin_extensions =
    Merlin_codemirror.[ autocomplete rpc; linter rpc; tooltip_on_hover rpc ]
  in
  let extensions =
    [ basic_setup; Merlin_codemirror.ocaml ] @ merlin_extensions @ exts
  in
  let config = EditorStateConfig.create ?doc ~extensions () in
  let state = EditorState.create ~config () in
  let opts =
    View.EditorViewConfig.create ~state
      ~parent:(Merlin_codemirror.Utils.get_el_by_id "editor")
      ()
  in
  let view : View.EditorView.t = View.EditorView.create ~config:opts () in
  Fut.return (Ok (state, view))

let _editor = init ()
